#!/usr/bin/env bash
# integrity.sh - vérification d'intégrité par hachage BLAKE3
#
# Usage :
#   ./integrity.sh compute <dossier> <base.b3>
#   ./integrity.sh verify  <dossier> <base.b3>
#   ./integrity.sh compare <ancienne.b3> <nouvelle.b3>
#
# Dépendances : b3sum, find, sort, awk, comm, join, stat, du

set -euo pipefail

MODE=${1:-}
ARG2=${2:-}
ARG3=${3:-}

# == Fonctions =================================================================

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

# == Dispatch ==================================================================

case "$MODE" in
  compute)
    TARGET=$ARG2
    HASHFILE=$ARG3
    compute_with_progress "$TARGET" "$HASHFILE"
    echo "Base enregistrée : $HASHFILE ($(wc -l < "$HASHFILE") fichiers)"
    ;;

  verify)
    HASHFILE=$ARG3
    b3sum --check "$HASHFILE"
    ;;

  compare)
    OLD=$ARG2
    NEW=$ARG3
    RAPPORT="rapport_$(date +%Y-%m-%d_%H%M%S).txt"
    {
      echo "Rapport de comparaison - $(date)"
      echo "Ancienne base : $OLD"
      echo "Nouvelle base : $NEW"
      echo ""
      sort -k2 "$OLD" > /tmp/_old.b3
      sort -k2 "$NEW" > /tmp/_new.b3

      echo "=== FICHIERS MODIFIÉS ==="
      join -1 2 -2 2 /tmp/_old.b3 /tmp/_new.b3 \
        | awk '$2 != $3 {print $1, "\n  ancien:", $3, "\n  nouveau:", $2}'

      echo ""
      echo "=== FICHIERS DISPARUS ==="
      comm -23 <(awk '{print $2}' /tmp/_old.b3) \
               <(awk '{print $2}' /tmp/_new.b3)

      echo ""
      echo "=== FICHIERS NOUVEAUX ==="
      comm -13 <(awk '{print $2}' /tmp/_old.b3) \
               <(awk '{print $2}' /tmp/_new.b3)

      rm /tmp/_old.b3 /tmp/_new.b3
    } | tee "$RAPPORT"
    echo "Rapport sauvegardé : $RAPPORT"
    ;;

  *)
    echo "Usage: $0 {compute|verify|compare} <args>"
    exit 1
    ;;
esac
