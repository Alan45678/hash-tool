#!/usr/bin/env bash
# integrity.sh — vérification d'intégrité par hachage BLAKE3
#
# Usage :
#   ./integrity.sh compute <dossier> <base.b3>
#   ./integrity.sh verify  <base.b3> [dossier]
#   ./integrity.sh compare <ancienne.b3> <nouvelle.b3>
#
# Dépendances : b3sum, find, sort, awk, comm, join, stat, du

set -euo pipefail

MODE=${1:-}
ARG2=${2:-}
ARG3=${3:-}

# ── Configuration ─────────────────────────────────────────────────────────────

# Dossier racine où seront créés les sous-dossiers de résultats.
# Modifier ce chemin selon l'environnement.
RESULTATS_DIR="${RESULTATS_DIR:-${HOME}/integrity_resultats}"

# ── Fonctions utilitaires ─────────────────────────────────────────────────────

# Affiche un message d'erreur sur stderr et quitte.
die() {
  echo "ERREUR : $*" >&2
  exit 1
}

# Vérifie qu'un fichier .b3 est valide : existe, est un fichier, non vide,
# contient au moins une ligne au format b3sum (<hash>  <chemin>).
assert_b3_valid() {
  local file="$1"
  local label="${2:-$file}"

  [ -e "$file" ]  || die "$label : fichier introuvable."
  [ -f "$file" ]  || die "$label : est un dossier, pas un fichier .b3."
  [ -s "$file" ]  || die "$label : fichier vide — aucun hash à traiter."

  # Vérifier le format : au moins une ligne avec deux champs (hash + chemin)
  local first_valid
  first_valid=$(grep -m1 -E '^[0-9a-f]{64}  .+' "$file" || true)
  [ -n "$first_valid" ] || die "$label : format invalide — aucune ligne au format b3sum détectée."
}

# Vérifie qu'un dossier cible est valide et contient au moins un fichier.
assert_target_valid() {
  local dir="$1"

  [ -e "$dir" ] || die "Dossier cible introuvable : $dir"
  [ -d "$dir" ] || die "Le chemin cible n'est pas un dossier : $dir"

  local nb_files
  nb_files=$(find "$dir" -type f | wc -l)
  (( nb_files > 0 )) || die "Le dossier $dir ne contient aucun fichier — rien à hacher."
}

# ── Fonctions principales ─────────────────────────────────────────────────────

# Calcule le hash BLAKE3 de chaque fichier du dossier cible, fichier par fichier,
# en affichant la progression et une estimation du temps restant (ETA).
# Usage : compute_with_progress <dossier> <hashfile>
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

    bytes_done=$(( bytes_done + $(stat -c%s "$file") ))
    i=$(( i + 1 ))

    local t_now elapsed
    t_now=$(date +%s)
    elapsed=$(( t_now - t_start ))

    if (( bytes_done > 0 && elapsed > 0 )); then
      local speed remaining
      speed=$(( bytes_done / elapsed ))
      remaining=$(( (total_bytes - bytes_done) / speed ))
      printf "\r[%d/%d] ETA : %dm %02ds   " \
        "$i" "$total_files" $(( remaining / 60 )) $(( remaining % 60 ))
    fi
  done

  printf "\r%*s\r" 40 ""  # effacer la ligne de progression
}

# Crée le dossier de résultats nommé d'après le fichier .b3 fourni.
# Usage : outdir=$(make_result_dir <fichier.b3>)
make_result_dir() {
  local b3file="$1"
  local basename
  basename=$(basename "$b3file" .b3)
  local outdir="${RESULTATS_DIR}/resultats_${basename}"
  mkdir -p "$outdir"
  echo "$outdir"
}

# Produit les fichiers de résultats pour le mode verify.
# Usage : run_verify <hashfile_absolu>
run_verify() {
  local hashfile="$1"
  local outdir
  outdir=$(make_result_dir "$hashfile")

  local raw exit_code
  raw=$(b3sum --check "$hashfile" 2>&1) && exit_code=0 || exit_code=$?

  # Séparer les lignes OK, FAILED, et les erreurs b3sum (ni OK ni FAILED)
  local lines_ok lines_failed lines_error
  lines_ok=$(echo "$raw"    | grep ': OK$'    || true)
  lines_failed=$(echo "$raw" | grep ': FAILED' || true)
  lines_error=$(echo "$raw"  | grep -Ev ': (OK|FAILED)' | grep -v '^$' || true)

  local nb_ok nb_failed
  nb_ok=$(echo "$lines_ok"     | grep -c '.' || true)
  nb_failed=$(echo "$lines_failed" | grep -c '.' || true)
  [ -n "$lines_ok" ]     || nb_ok=0
  [ -n "$lines_failed" ] || nb_failed=0

  local statut
  if [ -n "$lines_error" ]; then
    statut="ERREUR"
  elif (( nb_failed > 0 )); then
    statut="ECHEC"
  else
    statut="OK"
  fi

  # ── recap.txt ──────────────────────────────────────────────────────────────
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

  # ── failed.txt — créé uniquement si des échecs existent ───────────────────
  if (( nb_failed > 0 )) || [ -n "$lines_error" ]; then
    {
      echo "════════════════════════════════════════"
      echo "  FICHIERS EN ECHEC"
      echo "════════════════════════════════════════"
      echo ""
      if (( nb_failed > 0 )); then
        echo "$lines_failed"
      fi
      if [ -n "$lines_error" ]; then
        echo ""
        echo "── Erreurs ────────────────────────────"
        echo "$lines_error"
      fi
    } > "${outdir}/failed.txt"
  fi

  # ── Affichage terminal ─────────────────────────────────────────────────────
  if [ "$statut" = "OK" ]; then
    echo "Vérification OK — $nb_ok fichiers intègres."
  else
    echo ""
    echo "████████████████████████████████████████"
    if [ "$statut" = "ERREUR" ]; then
      echo "  ERREUR lors de la vérification"
    else
      echo "  ECHEC : $nb_failed fichier(s) corrompu(s) ou manquant(s)"
    fi
    echo "████████████████████████████████████████"
    echo ""
    if (( nb_failed > 0 )); then echo "$lines_failed"; fi
    if [ -n "$lines_error" ]; then echo "$lines_error"; fi
    echo ""
  fi

  echo "Résultats dans : $outdir"
  echo "  recap.txt"
  if (( nb_failed > 0 )) || [ -n "$lines_error" ]; then
    echo "  failed.txt"
  fi
}

# Produit les fichiers de résultats pour le mode compare.
# Usage : run_compare <ancienne.b3> <nouvelle.b3>
run_compare() {
  local old="$1"
  local new="$2"
  local outdir
  outdir=$(make_result_dir "$old")

  local tmp_old tmp_new
  tmp_old=$(mktemp)
  tmp_new=$(mktemp)
  sort -k2 "$old" > "$tmp_old"
  sort -k2 "$new" > "$tmp_new"

  # modifies.b3
  join -1 2 -2 2 "$tmp_old" "$tmp_new" \
    | awk '$2 != $3 {print $3, $1}' \
    > "${outdir}/modifies.b3"

  # disparus.txt
  comm -23 <(awk '{print $2}' "$tmp_old") \
           <(awk '{print $2}' "$tmp_new") \
    > "${outdir}/disparus.txt"

  # nouveaux.txt
  comm -13 <(awk '{print $2}' "$tmp_old") \
           <(awk '{print $2}' "$tmp_new") \
    > "${outdir}/nouveaux.txt"

  local nb_modifies nb_disparus nb_nouveaux
  nb_modifies=$(wc -l < "${outdir}/modifies.b3")
  nb_disparus=$(wc -l < "${outdir}/disparus.txt")
  nb_nouveaux=$(wc -l < "${outdir}/nouveaux.txt")

  # recap.txt
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

  rm "$tmp_old" "$tmp_new"

  # Affichage terminal
  echo "Résultats enregistrés dans : $outdir"
  echo "  recap.txt     — modifiés: $nb_modifies, disparus: $nb_disparus, nouveaux: $nb_nouveaux"
  echo "  modifies.b3   — $nb_modifies fichiers"
  echo "  disparus.txt  — $nb_disparus fichiers"
  echo "  nouveaux.txt  — $nb_nouveaux fichiers"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "$MODE" in
  compute)
    [ -n "$ARG2" ] || die "compute : dossier cible manquant.\nUsage : $0 compute <dossier> <base.b3>"
    [ -n "$ARG3" ] || die "compute : fichier de sortie .b3 manquant.\nUsage : $0 compute <dossier> <base.b3>"
    [ ! -d "$ARG3" ] || die "compute : '$ARG3' est un dossier. Le fichier .b3 de sortie doit être un chemin de fichier."
    assert_target_valid "$ARG2"
    compute_with_progress "$ARG2" "$ARG3"
    echo "Base enregistrée : $ARG3 ($(wc -l < "$ARG3") fichiers)"
    ;;

  verify)
    [ -n "$ARG2" ] || die "verify : fichier .b3 manquant.\nUsage : $0 verify <base.b3> [dossier]"
    assert_b3_valid "$ARG2" "base"
    # Résoudre le chemin absolu du .b3 AVANT tout cd
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
    echo "  $0 compute <dossier> <base.b3>"
    echo "  $0 verify  <base.b3> [dossier]"
    echo "  $0 compare <ancienne.b3> <nouvelle.b3>"
    exit 1
    ;;
esac