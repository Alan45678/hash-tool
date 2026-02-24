#!/usr/bin/env bash
# integrity.sh - Vérification d'intégrité par hachage BLAKE3
#
# Point d'entrée CLI. Orchestre les modules :
#   src/lib/core.sh    - logique métier (hachage, vérification, comparaison)
#   src/lib/ui.sh      - interface terminal (affichage, ETA, progression)
#   src/lib/results.sh - écriture des fichiers de résultats
#   src/lib/report.sh  - génération des rapports HTML
#
# Usage :
#   ./integrity.sh [--quiet] compute <dossier> <base.b3>
#   ./integrity.sh [--quiet] verify  <base.b3> [dossier]
#   ./integrity.sh [--quiet] compare <ancienne.b3> <nouvelle.b3>
#
# Options :
#   --quiet   Supprime toute sortie terminal. Écrit uniquement dans les
#             fichiers de résultats. Exit code propagé sans modification.
#
# Dépendances : b3sum, bash >= 4, find, sort, awk, comm, join, stat, du, mktemp
#
# Exit codes :
#   0 - succès (voir contrat de chaque mode dans src/lib/core.sh)
#   1 - erreur (argument manquant, fichier introuvable, corruption détectée)

set -euo pipefail

# == Prérequis bash =============================================================

(( BASH_VERSINFO[0] >= 4 )) || {
  echo "ERREUR : bash >= 4 requis (actuel : $BASH_VERSION)" >&2
  exit 1
}

# == Résolution des chemins =====================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# == Chargement des modules =====================================================

for _module in ui core results report; do
  _path="$SCRIPT_DIR/lib/${_module}.sh"
  [ -f "$_path" ] || { echo "ERREUR : module introuvable : $_path" >&2; exit 1; }
  # shellcheck source=/dev/null
  source "$_path"
done
unset _module _path

# == Parsing des arguments ======================================================

QUIET=0
ARGS=()

for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    *)       ARGS+=("$arg") ;;
  esac
done

MODE="${ARGS[0]:-}"
ARG2="${ARGS[1]:-}"
ARG3="${ARGS[2]:-}"

# == Configuration ==============================================================

# Dossier racine des résultats. Peut être surchargé par variable d'environnement.
# runner.sh surcharge cette valeur via export pour isoler les runs de pipeline.
RESULTATS_DIR="${RESULTATS_DIR:-${HOME}/integrity_resultats}"

# == Handlers des modes =========================================================

_run_compute() {
  local target="$ARG2"
  local hashfile="$ARG3"

  [ -n "$target"   ] || die "compute : dossier cible manquant.\nUsage : $0 compute <dossier> <base.b3>"
  [ -n "$hashfile" ] || die "compute : fichier de sortie .b3 manquant.\nUsage : $0 compute <dossier> <base.b3>"
  [ ! -d "$hashfile" ] || die "compute : '$hashfile' est un dossier. Le fichier .b3 de sortie doit être un chemin de fichier."

  core_assert_target_valid "$target"

  # Utilise ui_progress_callback uniquement si QUIET == 0
  local callback=""
  (( QUIET )) || callback="ui_progress_callback"

  core_compute "$target" "$hashfile" "$callback"
  ui_progress_clear

  say "Base enregistrée : $hashfile ($(wc -l < "$hashfile") fichiers)"
}

_run_verify() {
  local b3file="$ARG2"
  local workdir="${ARG3:-}"

  [ -n "$b3file" ] || die "verify : fichier .b3 manquant.\nUsage : $0 verify <base.b3> [dossier]"

  core_assert_b3_valid "$b3file" "base"

  # Résolution du chemin absolu AVANT le cd : un chemin relatif deviendrait
  # invalide après changement de répertoire
  local hashfile_abs
  hashfile_abs="$(cd "$(dirname "$b3file")" && pwd)/$(basename "$b3file")"

  if [ -n "$workdir" ]; then
    [ -d "$workdir" ] || die "verify : '$workdir' n'est pas un dossier valide."
    cd "$workdir"
  fi

  local outdir
  outdir=$(core_make_result_dir "$hashfile_abs" "$RESULTATS_DIR")

  # core_verify positionne les variables CORE_VERIFY_* dans le scope courant
  local exit_code=0
  core_verify "$hashfile_abs" || exit_code=$?

  results_write_verify \
    "$outdir" "$hashfile_abs" \
    "$CORE_VERIFY_STATUS" "$CORE_VERIFY_NB_OK" "$CORE_VERIFY_NB_FAIL" \
    "$CORE_VERIFY_LINES_FAIL" "$CORE_VERIFY_LINES_ERR"

  ui_show_verify_result \
    "$CORE_VERIFY_STATUS" "$CORE_VERIFY_NB_OK" "$CORE_VERIFY_NB_FAIL" \
    "$CORE_VERIFY_LINES_FAIL" "$CORE_VERIFY_LINES_ERR" \
    "$outdir"

  return $exit_code
}

_run_compare() {
  local old="$ARG2"
  local new="$ARG3"

  [ -n "$old" ] || die "compare : fichier ancienne base manquant.\nUsage : $0 compare <ancienne.b3> <nouvelle.b3>"
  [ -n "$new" ] || die "compare : fichier nouvelle base manquant.\nUsage : $0 compare <ancienne.b3> <nouvelle.b3>"

  core_assert_b3_valid "$old" "ancienne base"
  core_assert_b3_valid "$new" "nouvelle base"

  local outdir
  outdir=$(core_make_result_dir "$old" "$RESULTATS_DIR")

  # core_compare positionne CORE_COMPARE_NB_* dans le scope courant
  core_compare "$old" "$new" "$outdir"

  results_write_compare \
    "$outdir" "$old" "$new" \
    "$CORE_COMPARE_NB_MOD" "$CORE_COMPARE_NB_DIS" "$CORE_COMPARE_NB_NOU"

  generate_compare_html \
    "$old" "$new" \
    "$CORE_COMPARE_NB_MOD" "$CORE_COMPARE_NB_DIS" "$CORE_COMPARE_NB_NOU" \
    "${outdir}/modifies.b3" "${outdir}/disparus.txt" "${outdir}/nouveaux.txt" \
    "${outdir}/report.html"

  ui_show_compare_result \
    "$CORE_COMPARE_NB_MOD" "$CORE_COMPARE_NB_DIS" "$CORE_COMPARE_NB_NOU" \
    "$outdir"
}

# == Dispatch ===================================================================

case "$MODE" in
  compute) _run_compute ;;
  verify)  _run_verify  ;;
  compare) _run_compare ;;
  *)
    echo "Usage:"
    echo "  $0 [--quiet] compute <dossier> <base.b3>"
    echo "  $0 [--quiet] verify  <base.b3> [dossier]"
    echo "  $0 [--quiet] compare <ancienne.b3> <nouvelle.b3>"
    echo ""
    echo "Options:"
    echo "  --quiet   Silencieux : écrit uniquement dans les fichiers de résultats."
    exit 1
    ;;
esac
