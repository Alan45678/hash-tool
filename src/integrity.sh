#!/usr/bin/env bash
# integrity.sh — vérification d'intégrité par hachage BLAKE3
#
# Usage :
#   ./integrity.sh compute <dossier> <base.b3>
#   ./integrity.sh verify  <base.b3> [dossier]
#   ./integrity.sh compare <ancienne.b3> <nouvelle.b3>
#
# Options :
#   --quiet   Supprime toute sortie terminal ; écrit uniquement dans les
#             fichiers de résultats (recap.txt, failed.txt, report.html, etc.).
#             Utile pour usage en CI/cron/script parent.
#
# Dépendances : b3sum, find, sort, awk, comm, join, stat, du

set -euo pipefail

# ── Vérification version bash ──────────────────────────────────────────────────

(( BASH_VERSINFO[0] >= 4 )) || {
  echo "ERREUR : bash >= 4 requis (actuel : $BASH_VERSION)" >&2
  exit 1
}

# ── Résolution du répertoire du script ────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Chargement de la bibliothèque de rapports ─────────────────────────────────

LIB_REPORT="$SCRIPT_DIR/lib/report.sh"
[ -f "$LIB_REPORT" ] || {
  echo "ERREUR : lib/report.sh introuvable : $LIB_REPORT" >&2
  exit 1
}
# shellcheck source=lib/report.sh
source "$LIB_REPORT"

# ── Parsing des arguments ──────────────────────────────────────────────────────

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

# ── Configuration ──────────────────────────────────────────────────────────────

# Dossier racine où seront créés les sous-dossiers de résultats.
# Peut être surchargé par l'environnement (ex : runner.sh via export RESULTATS_DIR).
RESULTATS_DIR="${RESULTATS_DIR:-${HOME}/integrity_resultats}"

# ── Fonctions utilitaires ──────────────────────────────────────────────────────

die() {
  echo "ERREUR : $*" >&2
  exit 1
}

say() {
  (( QUIET )) || echo "$@"
}

assert_b3_valid() {
  local file="$1"
  local label="${2:-$file}"

  [ -e "$file" ] || die "$label : fichier introuvable."
  [ -f "$file" ] || die "$label : est un dossier, pas un fichier .b3."
  [ -s "$file" ] || die "$label : fichier vide — aucun hash à traiter."

  local first_valid
  first_valid=$(grep -m1 -E '^[0-9a-f]{64}  .+' "$file" || true)
  [ -n "$first_valid" ] || die "$label : format invalide — aucune ligne au format b3sum détectée."
}

assert_target_valid() {
  local dir="$1"

  [ -e "$dir" ] || die "Dossier cible introuvable : $dir"
  [ -d "$dir" ] || die "Le chemin cible n'est pas un dossier : $dir"

  local nb_files
  nb_files=$(find "$dir" -type f -print0 | grep -zc '' || echo 0)
  (( nb_files > 0 )) || die "Le dossier $dir ne contient aucun fichier — rien à hacher."
}

file_size() {
  local f="$1"
  if stat -c%s "$f" 2>/dev/null; then
    return
  fi
  stat -f%z "$f"
}

# ── Fonctions principales ──────────────────────────────────────────────────────

compute_with_progress() {
  local target="$1"
  local hashfile="$2"

  local -a files
  mapfile -d '' files < <(find "$target" -type f -print0 | sort -z)

  local total_files=${#files[@]}
  local total_bytes
  total_bytes=$(du -sb "$target" | awk '{print $1}')

  local bytes_done=0
  local t_start
  t_start=$(date +%s)

  local i=0
  for file in "${files[@]}"; do
    b3sum "$file" >> "$hashfile"

    bytes_done=$(( bytes_done + $(file_size "$file") ))
    i=$(( i + 1 ))

    if (( ! QUIET )); then
      local t_now elapsed
      t_now=$(date +%s)
      elapsed=$(( t_now - t_start ))

      if (( bytes_done > 0 && elapsed > 0 )); then
        local speed remaining
        speed=$(( bytes_done / elapsed ))
        remaining=$(( (total_bytes - bytes_done) / speed ))
        printf "\r[%d/%d] ETA : %dm %02ds   " \
          "$i" "$total_files" $(( remaining / 60 )) $(( remaining % 60 )) > /dev/tty
      fi
    fi
  done

  if (( ! QUIET )); then
    printf "\r%*s\r" 40 "" > /dev/tty
  fi
}

make_result_dir() {
  local b3file="$1"
  local basename_noext
  basename_noext=$(basename "$b3file" .b3)
  local outdir="${RESULTATS_DIR}/resultats_${basename_noext}"

  if [ -d "$outdir" ]; then
    outdir="${outdir}_$(date +%Y%m%d-%H%M%S)"
  fi

  mkdir -p "$outdir"
  echo "$outdir"
}

run_verify() {
  local hashfile="$1"
  local outdir
  outdir=$(make_result_dir "$hashfile")

  local raw exit_code
  raw=$(b3sum --check "$hashfile" 2>&1) && exit_code=0 || exit_code=$?

  local lines_ok lines_failed lines_error
  lines_ok=$(echo    "$raw" | grep ': OK$'    || true)
  lines_failed=$(echo "$raw" | grep ': FAILED' || true)
  lines_error=$(echo  "$raw" | grep -Ev ': (OK|FAILED)' | grep -v '^$' || true)

  local nb_ok nb_failed
  if [ -n "$lines_ok" ];     then nb_ok=$(echo "$lines_ok"     | grep -c '^'); else nb_ok=0;     fi
  if [ -n "$lines_failed" ]; then nb_failed=$(echo "$lines_failed" | grep -c '^'); else nb_failed=0; fi

  local statut
  if [ -n "$lines_error" ];   then statut="ERREUR"
  elif (( nb_failed > 0 ));   then statut="ECHEC"
  else                              statut="OK"
  fi

  # ── recap.txt ─────────────────────────────────────────────────────────────
  {
    echo "════════════════════════════════════════"
    echo "  STATUT : $statut"
    echo "════════════════════════════════════════"
    echo ""
    echo "Commande  : integrity.sh verify $(basename "$hashfile")"
    echo "Date      : $(date)"
    echo "Base      : $hashfile"
    echo ""
    echo "OK        : $nb_ok"
    if (( nb_failed > 0 )); then
      echo "FAILED    : $nb_failed  ← voir failed.txt"
    fi
    if [ -n "$lines_error" ]; then
      echo ""
      echo "── Erreurs b3sum ──────────────────────"
      echo "$lines_error"
    fi
  } > "${outdir}/recap.txt"

  # ── failed.txt ────────────────────────────────────────────────────────────
  if (( nb_failed > 0 )) || [ -n "$lines_error" ]; then
    {
      echo "════════════════════════════════════════"
      echo "  FICHIERS EN ECHEC"
      echo "════════════════════════════════════════"
      echo ""
      if (( nb_failed > 0 )); then echo "$lines_failed"; fi
      if [ -n "$lines_error" ]; then
        echo ""
        echo "── Erreurs ────────────────────────────"
        echo "$lines_error"
      fi
    } > "${outdir}/failed.txt"
  else
    rm -f "${outdir}/failed.txt"
  fi

  # ── Affichage terminal ────────────────────────────────────────────────────
  if [ "$statut" = "OK" ]; then
    say "Vérification OK — $nb_ok fichiers intègres."
  else
    say ""
    say "████████████████████████████████████████"
    if [ "$statut" = "ERREUR" ]; then
      say "  ERREUR lors de la vérification"
    else
      say "  ECHEC : $nb_failed fichier(s) corrompu(s) ou manquant(s)"
    fi
    say "████████████████████████████████████████"
    say ""
    if (( nb_failed > 0 )); then say "$lines_failed"; fi
    if [ -n "$lines_error" ]; then say "$lines_error"; fi
    say ""
  fi

  say "Résultats dans : $outdir"
  say "  recap.txt"
  if (( nb_failed > 0 )) || [ -n "$lines_error" ]; then
    say "  failed.txt"
  fi

  return $exit_code
}

run_compare() {
  local old="$1"
  local new="$2"
  local outdir
  outdir=$(make_result_dir "$old")

  local tmp_old tmp_new
  tmp_old=$(mktemp)
  tmp_new=$(mktemp)

  trap 'rm -f "$tmp_old" "$tmp_new"' EXIT

  b3_to_path_hash() {
    awk '{ print substr($0,67) "\t" substr($0,1,64) }' "$1" | sort -t $'\t' -k1,1
  }

  b3_to_path_hash "$old" > "$tmp_old"
  b3_to_path_hash "$new" > "$tmp_new"

  join -t $'\t' -1 1 -2 1 "$tmp_old" "$tmp_new" \
    | awk -F $'\t' '$2 != $3 { print $3 "  " $1 }' \
    > "${outdir}/modifies.b3"

  comm -23 <(cut -f1 "$tmp_old") <(cut -f1 "$tmp_new") > "${outdir}/disparus.txt"
  comm -13 <(cut -f1 "$tmp_old") <(cut -f1 "$tmp_new") > "${outdir}/nouveaux.txt"

  local nb_modifies nb_disparus nb_nouveaux
  nb_modifies=$(wc -l < "${outdir}/modifies.b3")
  nb_disparus=$(wc -l < "${outdir}/disparus.txt")
  nb_nouveaux=$(wc -l < "${outdir}/nouveaux.txt")

  # ── recap.txt ─────────────────────────────────────────────────────────────
  {
    echo "Commande      : integrity.sh compare $(basename "$old") $(basename "$new")"
    echo "Date          : $(date)"
    echo "Ancienne base : $old"
    echo "Nouvelle base : $new"
    echo ""
    echo "Modifiés      : $nb_modifies"
    echo "Disparus      : $nb_disparus"
    echo "Nouveaux      : $nb_nouveaux"
  } > "${outdir}/recap.txt"

  # ── report.html — délégué à lib/report.sh ─────────────────────────────────
  generate_compare_html \
    "$old" "$new" \
    "$nb_modifies" "$nb_disparus" "$nb_nouveaux" \
    "${outdir}/modifies.b3" "${outdir}/disparus.txt" "${outdir}/nouveaux.txt" \
    "${outdir}/report.html"

  rm -f "$tmp_old" "$tmp_new"
  trap - EXIT

  say "Résultats enregistrés dans : $outdir"
  say "  recap.txt     — modifiés: $nb_modifies, disparus: $nb_disparus, nouveaux: $nb_nouveaux"
  say "  modifies.b3   — $nb_modifies fichiers"
  say "  disparus.txt  — $nb_disparus fichiers"
  say "  nouveaux.txt  — $nb_nouveaux fichiers"
  say "  report.html   — rapport visuel"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "$MODE" in
  compute)
    [ -n "$ARG2" ] || die "compute : dossier cible manquant.\nUsage : $0 compute <dossier> <base.b3>"
    [ -n "$ARG3" ] || die "compute : fichier de sortie .b3 manquant.\nUsage : $0 compute <dossier> <base.b3>"
    [ ! -d "$ARG3" ] || die "compute : '$ARG3' est un dossier. Le fichier .b3 de sortie doit être un chemin de fichier."
    assert_target_valid "$ARG2"
    compute_with_progress "$ARG2" "$ARG3"
    say "Base enregistrée : $ARG3 ($(wc -l < "$ARG3") fichiers)"
    ;;

  verify)
    [ -n "$ARG2" ] || die "verify : fichier .b3 manquant.\nUsage : $0 verify <base.b3> [dossier]"
    assert_b3_valid "$ARG2" "base"
    HASHFILE_ABS="$(cd "$(dirname "$ARG2")" && pwd)/$(basename "$ARG2")"
    if [ -n "$ARG3" ]; then
      [ -d "$ARG3" ] || die "verify : '$ARG3' n'est pas un dossier valide."
      cd "$ARG3"
    fi
    run_verify "$HASHFILE_ABS"
    ;;

  compare)
    [ -n "$ARG2" ] || die "compare : fichier ancienne base manquant.\nUsage : $0 compare <ancienne.b3> <nouvelle.b3>"
    [ -n "$ARG3" ] || die "compare : fichier nouvelle base manquant.\nUsage : $0 compare <ancienne.b3> <nouvelle.b3>"
    assert_b3_valid "$ARG2" "ancienne base"
    assert_b3_valid "$ARG3" "nouvelle base"
    run_compare "$ARG2" "$ARG3"
    ;;

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