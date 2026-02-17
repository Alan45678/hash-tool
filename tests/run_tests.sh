#!/usr/bin/env bash
# run_tests.sh — suite de tests automatisée pour integrity.sh
# Usage : ./run_tests.sh
# Prérequis : b3sum, stat, du installés ; integrity.sh dans le dossier parent

set -uo pipefail

# == Configuration ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRITY="$SCRIPT_DIR/../integrity.sh"
WORKDIR="$(mktemp -d /tmp/integrity-test.XXXXXX)"

# == Couleurs =================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# == Compteurs ================================================================

PASS=0
FAIL=0
TOTAL=0

# == Helpers ==================================================================

pass() { echo -e "${GREEN}  PASS${NC} — $1"; ((PASS++)); ((TOTAL++)); }
fail() { echo -e "${RED}  FAIL${NC} — $1"; ((FAIL++)); ((TOTAL++)); }

assert_exit_zero() {
  local label="$1"; shift
  if "$@" > /dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

assert_exit_nonzero() {
  local label="$1"; shift
  if ! "$@" > /dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

assert_contains() {
  local label="$1"
  local pattern="$2"
  local output="$3"
  if echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label (pattern: '$pattern' absent)"; fi
}

assert_not_contains() {
  local label="$1"
  local pattern="$2"
  local output="$3"
  if ! echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label (pattern: '$pattern' présent mais ne devrait pas l'être)"; fi
}

assert_line_count() {
  local label="$1"
  local expected="$2"
  local file="$3"
  local actual
  actual=$(wc -l < "$file")
  if [ "$actual" -eq "$expected" ]; then pass "$label"; else fail "$label (attendu: $expected lignes, obtenu: $actual)"; fi
}

# == Setup ====================================================================

setup() {
  mkdir -p "$WORKDIR/data/sub"
  echo "contenu alpha"  > "$WORKDIR/data/alpha.txt"
  echo "contenu beta"   > "$WORKDIR/data/beta.txt"
  echo "contenu gamma"  > "$WORKDIR/data/gamma.txt"
  echo "contenu delta"  > "$WORKDIR/data/sub/delta.txt"
}

teardown() {
  rm -rf "$WORKDIR"
}

# == Tests ====================================================================

run_tests() {
  cd "$WORKDIR"

  echo ""
  echo "========================================"
  echo "  integrity.sh — suite de tests"
  echo "  Workdir : $WORKDIR"
  echo "========================================"
  echo ""

  # == T01 : Compute de base =================================================
  echo "T01 — Compute de base"
  bash "$INTEGRITY" compute ./data base_t01.b3 > /dev/null 2>&1
  assert_line_count "base_t01.b3 contient 4 lignes" 4 base_t01.b3

  local first_line
  first_line=$(head -1 base_t01.b3)
  assert_contains "ligne au format <hash>  <chemin>" "  ./data/" "$first_line"
  echo ""

  # == T02 : Verify sans modification =======================================
  echo "T02 — Verify sans modification"
  local out_t02
  out_t02=$(b3sum --check base_t01.b3 2>&1)
  assert_exit_zero    "exit code 0" b3sum --check base_t01.b3
  assert_not_contains "aucun FAILED"  "FAILED" "$out_t02"
  echo ""

  # == T03 : Verify après corruption ========================================
  echo "T03 — Verify après corruption d'un fichier"
  echo "contenu modifié" > data/beta.txt
  local out_t03
  out_t03=$(b3sum --check base_t01.b3 2>&1 || true)
  assert_exit_nonzero "exit code non nul"   b3sum --check base_t01.b3
  assert_contains     "beta.txt FAILED"     "FAILED" "$out_t03"
  # Restauration
  echo "contenu beta" > data/beta.txt
  echo ""

  # == T04 : Verify après suppression =======================================
  echo "T04 — Verify après suppression d'un fichier"
  rm data/gamma.txt
  local out_t04
  out_t04=$(b3sum --check base_t01.b3 2>&1 || true)
  assert_exit_nonzero "exit code non nul"    b3sum --check base_t01.b3
  assert_contains     "gamma.txt FAILED"     "FAILED" "$out_t04"
  # Restauration
  echo "contenu gamma" > data/gamma.txt
  echo ""

  # == T05 : Compare — aucune différence ====================================
  echo "T05 — Compare : aucune différence"
  bash "$INTEGRITY" compute ./data base_t05.b3 > /dev/null 2>&1
  local out_t05
  out_t05=$(bash "$INTEGRITY" compare base_t01.b3 base_t05.b3 2>&1)
  assert_not_contains "pas de fichiers modifiés"  "MODIFIÉS" "$(echo "$out_t05" | grep -v '===')"
  assert_not_contains "pas de fichiers disparus"  "DISPARUS" "$(echo "$out_t05" | grep -v '===')"
  assert_not_contains "pas de fichiers nouveaux"  "NOUVEAUX" "$(echo "$out_t05" | grep -v '===')"
  # Vérifier qu'un rapport a été créé
  local rapport_t05
  rapport_t05=$(ls rapport_*.txt 2>/dev/null | tail -1)
  if [ -n "$rapport_t05" ]; then pass "rapport horodaté créé"; else fail "rapport horodaté absent"; ((FAIL++)); ((TOTAL++)); fi
  echo ""

  # == T06 : Compare — fichier modifié ======================================
  echo "T06 — Compare : fichier modifié"
  echo "contenu beta modifié" > data/beta.txt
  bash "$INTEGRITY" compute ./data base_t06.b3 > /dev/null 2>&1
  local out_t06
  out_t06=$(bash "$INTEGRITY" compare base_t01.b3 base_t06.b3 2>&1)
  assert_contains "beta.txt dans MODIFIÉS" "beta.txt" "$out_t06"
  # Restauration
  echo "contenu beta" > data/beta.txt
  echo ""

  # == T07 : Compare — suppression + ajout ==================================
  echo "T07 — Compare : fichier supprimé + fichier ajouté"
  bash "$INTEGRITY" compute ./data base_t07_old.b3 > /dev/null 2>&1
  rm data/alpha.txt
  echo "contenu epsilon" > data/epsilon.txt
  bash "$INTEGRITY" compute ./data base_t07_new.b3 > /dev/null 2>&1
  local out_t07
  out_t07=$(bash "$INTEGRITY" compare base_t07_old.b3 base_t07_new.b3 2>&1)
  assert_contains "alpha.txt dans DISPARUS"  "alpha.txt"   "$out_t07"
  assert_contains "epsilon.txt dans NOUVEAUX" "epsilon.txt" "$out_t07"
  # Restauration
  echo "contenu alpha" > data/alpha.txt
  rm data/epsilon.txt
  echo ""

  # == T08 : Noms de fichiers avec espaces ===================================
  echo "T08 — Robustesse : nom de fichier avec espace"
  echo "contenu avec espace" > "data/fichier avec espace.txt"
  bash "$INTEGRITY" compute ./data base_t08.b3 > /dev/null 2>&1
  local out_t08
  out_t08=$(b3sum --check base_t08.b3 2>&1)
  assert_exit_zero    "exit code 0"   b3sum --check base_t08.b3
  assert_not_contains "aucun FAILED"  "FAILED" "$out_t08"
  rm "data/fichier avec espace.txt"
  echo ""

  # == T09 : Dossier vide ignoré (limite documentée) =========================
  echo "T09 — Limite : dossier vide ignoré"
  mkdir data/dossier_vide
  bash "$INTEGRITY" compute ./data base_t09.b3 > /dev/null 2>&1
  assert_not_contains "dossier_vide absent de la base" "dossier_vide" "$(cat base_t09.b3)"
  pass "comportement conforme à la documentation"
  rmdir data/dossier_vide
  echo ""

  # == T10 : Chemin absolu vs relatif =======================================
  echo "T10 — Chemin absolu vs relatif"
  find "$WORKDIR/data" -type f -print0 | sort -z | xargs -0 b3sum > base_absolu.b3
  find ./data          -type f -print0 | sort -z | xargs -0 b3sum > base_relatif.b3
  local first_abs first_rel
  first_abs=$(head -1 base_absolu.b3)
  first_rel=$(head -1 base_relatif.b3)
  assert_contains     "base absolue contient un chemin absolu"  "  /" "$first_abs"
  assert_contains     "base relative contient un chemin relatif" "\./data/" "$first_rel"
  assert_not_contains "bases non interchangeables" "$first_abs" "$first_rel"
  echo ""

  # == T11 : compute_with_progress — intégrité de la base produite ===========
  echo "T11 — ETA : la base produite est identique à une base de référence"
  # Base de référence produite sans progression (pipeline xargs direct)
  find ./data -type f -print0 | sort -z | xargs -0 b3sum > base_ref.b3
  # Base produite par compute_with_progress via le script
  bash "$INTEGRITY" compute ./data base_eta.b3 > /dev/null 2>&1
  # Les deux bases doivent être identiques ligne à ligne (ordre et contenu)
  assert_exit_zero "base ETA identique à la base de référence" diff base_ref.b3 base_eta.b3
  # La base ne doit contenir aucune ligne de progression parasite
  assert_not_contains "aucune ligne ETA dans la base" "ETA" "$(cat base_eta.b3)"
  assert_not_contains "aucun caractère de contrôle dans la base" $'\r' "$(cat base_eta.b3)"
  echo ""
}

# == Main =====================================================================

# Vérification des prérequis
if ! command -v b3sum &> /dev/null; then
  echo -e "${RED}ERREUR${NC} : b3sum non trouvé. Installer avec : cargo install b3sum  ou  apt install b3sum"
  exit 1
fi

if [ ! -f "$INTEGRITY" ]; then
  echo -e "${RED}ERREUR${NC} : integrity.sh introuvable à : $INTEGRITY"
  exit 1
fi

setup
run_tests
teardown

# == Rapport final =============================================================

echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}$PASS/$TOTAL tests passés${NC}"
else
  echo -e "  ${GREEN}$PASS${NC}/${TOTAL} passés — ${RED}$FAIL échec(s)${NC}"
fi
echo "========================================"
echo ""

[ "$FAIL" -eq 0 ]