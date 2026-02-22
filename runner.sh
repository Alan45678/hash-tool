#!/usr/bin/env bash
# runner.sh — Exécuteur de pipeline integrity.sh depuis pipeline.json
#
# Usage :
#   ./runner.sh                   # lit pipeline.json dans le même dossier
#   ./runner.sh /chemin/pipeline.json
#
# Dépendances : bash >= 4, jq, integrity.sh (même dossier)

set -euo pipefail

# ── Chemins ───────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRITY="$SCRIPT_DIR/integrity.sh"
CONFIG="${1:-$SCRIPT_DIR/pipeline.json}"

# ── Prérequis ─────────────────────────────────────────────────────────────────

(( BASH_VERSINFO[0] >= 4 )) || { echo "ERREUR : bash >= 4 requis" >&2; exit 1; }

command -v jq &>/dev/null    || { echo "ERREUR : jq non trouvé (apt install jq)" >&2; exit 1; }
[ -f "$INTEGRITY" ]          || { echo "ERREUR : integrity.sh introuvable : $INTEGRITY" >&2; exit 1; }
[ -f "$CONFIG" ]             || { echo "ERREUR : pipeline.json introuvable : $CONFIG" >&2; exit 1; }

# ── Validation JSON ───────────────────────────────────────────────────────────

jq empty "$CONFIG" 2>/dev/null || { echo "ERREUR : JSON invalide : $CONFIG" >&2; exit 1; }

# Vérifier que .pipeline est un tableau non vide
nb_ops=$(jq '.pipeline | length' "$CONFIG")
(( nb_ops > 0 )) || { echo "ERREUR : pipeline.json — tableau .pipeline vide ou absent" >&2; exit 1; }

# ── Fonctions ─────────────────────────────────────────────────────────────────

die() { echo "ERREUR : $*" >&2; exit 1; }

require_field() {
    local op_index="$1"
    local field="$2"
    local val
    val=$(jq -r --argjson i "$op_index" '.pipeline[$i].'"$field" "$CONFIG")
    [ "$val" != "null" ] && [ -n "$val" ] || die "Bloc #$((op_index+1)) : champ '$field' manquant ou vide."
    echo "$val"
}

run_compute() {
    local i="$1"
    local source bases nom
    source=$(require_field "$i" "source")
    bases=$(require_field "$i" "bases")
    nom=$(require_field "$i" "nom")

    echo "=== COMPUTE : $source ==="
    [ -d "$source" ] || die "Bloc #$((i+1)) compute : dossier source introuvable : $source"

    mkdir -p "$bases"
    # Résoudre bases en absolu AVANT le cd — un chemin relatif devient invalide après cd
    local bases_abs
    bases_abs="$(cd "$bases" && pwd)"
    # Sous-shell : le cd ne fuite pas vers les opérations suivantes
    ( cd "$source" && "$INTEGRITY" compute . "$bases_abs/$nom" )
}

run_verify() {
    local i="$1"
    local source base
    source=$(require_field "$i" "source")
    base=$(require_field "$i" "base")

    echo "=== VERIFY : $source ==="
    [ -d "$source" ] || die "Bloc #$((i+1)) verify : dossier source introuvable : $source"
    [ -f "$base" ]   || die "Bloc #$((i+1)) verify : base .b3 introuvable : $base"

    # Résoudre base en absolu AVANT le cd
    local base_abs
    base_abs="$(cd "$(dirname "$base")" && pwd)/$(basename "$base")"
    # Sous-shell : le cd ne fuite pas vers les opérations suivantes
    ( cd "$source" && "$INTEGRITY" verify "$base_abs" )
}

run_compare() {
    local i="$1"
    local base_a base_b
    base_a=$(require_field "$i" "base_a")
    base_b=$(require_field "$i" "base_b")

    echo "=== COMPARE : $(basename "$base_a") vs $(basename "$base_b") ==="
    [ -f "$base_a" ] || die "Bloc #$((i+1)) compare : base_a introuvable : $base_a"
    [ -f "$base_b" ] || die "Bloc #$((i+1)) compare : base_b introuvable : $base_b"

    "$INTEGRITY" compare "$base_a" "$base_b"
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo "=== PIPELINE DÉMARRÉ : $(date) ==="
echo "=== Config : $CONFIG ($nb_ops opération(s)) ==="
echo ""

for (( i=0; i<nb_ops; i++ )); do
    op=$(jq -r --argjson i "$i" '.pipeline[$i].op' "$CONFIG")
    [ "$op" != "null" ] && [ -n "$op" ] || die "Bloc #$((i+1)) : champ 'op' manquant."

    case "$op" in
        compute) run_compute "$i" ;;
        verify)  run_verify  "$i" ;;
        compare) run_compare "$i" ;;
        *)       die "Bloc #$((i+1)) : opération inconnue : '$op'" ;;
    esac

    echo ""
done

echo "=== PIPELINE TERMINÉ : $(date) ==="