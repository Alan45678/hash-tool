#!/usr/bin/env bash
# run_tests.sh — suite de tests automatisée pour integrity.sh
# Usage : ./run_tests.sh
# Prérequis : b3sum, stat, du installés ; integrity.sh dans le dossier parent

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRITY="$SCRIPT_DIR/../integrity.sh"
WORKDIR="$(mktemp -d /tmp/integrity-test.XXXXXX)"

# Rediriger les résultats dans le WORKDIR pour les tests
export RESULTATS_DIR="$WORKDIR/resultats"

# ── Couleurs ──────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ── Compteurs ─────────────────────────────────────────────────────────────────

PASS=0
FAIL=0
TOTAL=0

# ── Helpers ───────────────────────────────────────────────────────────────────

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

assert_file_exists() {
  local label="$1"
  local file="$2"
  if [ -f "$file" ]; then pass "$label"; else fail "$label (fichier absent : $file)"; fi
}

assert_file_absent() {
  local label="$1"
  local file="$2"
  if [ ! -f "$file" ]; then pass "$label"; else fail "$label (fichier présent à tort : $file)"; fi
}

# ── Setup ─────────────────────────────────────────────────────────────────────

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

# ── Tests ─────────────────────────────────────────────────────────────────────

run_tests() {
  cd "$WORKDIR"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  integrity.sh — suite de tests"
  echo "  Workdir : $WORKDIR"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # ── T00 : ShellCheck ──────────────────────────────────────────────────────
  echo "T00 — ShellCheck"
  if command -v shellcheck &> /dev/null; then
    assert_exit_zero "ShellCheck integrity.sh" shellcheck "$INTEGRITY"
    assert_exit_zero "ShellCheck run_tests.sh" shellcheck "$0"
  else
    echo "  SKIP — shellcheck non installé (apt install shellcheck)"
  fi
  echo ""

  # ── T01 : Compute de base ─────────────────────────────────────────────────
  echo "T01 — Compute de base"
  bash "$INTEGRITY" compute ./data base_t01.b3 > /dev/null 2>&1
  assert_line_count "base_t01.b3 contient 4 lignes" 4 base_t01.b3

  local first_line
  first_line=$(head -1 base_t01.b3)
  assert_contains "ligne au format <hash>  <chemin>" "  ./data/" "$first_line"
  echo ""

  # ── T02 : Verify sans modification ───────────────────────────────────────
  echo "T02 — Verify sans modification"
  local out_t02
  out_t02=$(bash "$INTEGRITY" verify base_t01.b3 2>&1 || true)
  assert_not_contains "aucun FAILED dans terminal" "FAILED" "$out_t02"
  assert_contains     "terminal indique OK"        "OK"     "$out_t02"

  local outdir_t02
  outdir_t02=$(ls -d "${RESULTATS_DIR}/resultats_base_t01"* 2>/dev/null | tail -1)
  assert_file_exists "recap.txt créé"   "${outdir_t02}/recap.txt"
  assert_contains    "recap contient OK" "OK" "$(cat "${outdir_t02}/recap.txt")"
  assert_file_absent "failed.txt absent si 0 échec" "${outdir_t02}/failed.txt"
  echo ""

  # ── T03 : Verify après corruption ────────────────────────────────────────
  echo "T03 — Verify après corruption d'un fichier"
  echo "contenu modifié" > data/beta.txt
  local out_t03
  out_t03=$(bash "$INTEGRITY" verify base_t01.b3 2>&1 || true)
  assert_contains "terminal affiche bloc ECHEC"    "ECHEC"   "$out_t03"
  assert_contains "terminal liste beta.txt FAILED" "FAILED"  "$out_t03"

  local outdir_t03
  outdir_t03=$(ls -d "${RESULTATS_DIR}/resultats_base_t01"* 2>/dev/null | tail -1)
  assert_file_exists "failed.txt créé"              "${outdir_t03}/failed.txt"
  assert_contains    "failed.txt contient beta.txt" "beta.txt" "$(cat "${outdir_t03}/failed.txt")"
  assert_contains    "recap indique FAILED > 0"     "FAILED"   "$(cat "${outdir_t03}/recap.txt")"
  # Restauration
  echo "contenu beta" > data/beta.txt
  echo ""

  # ── T04 : Verify après suppression ───────────────────────────────────────
  echo "T04 — Verify après suppression d'un fichier"
  rm data/gamma.txt
  local out_t04
  out_t04=$(bash "$INTEGRITY" verify base_t01.b3 2>&1 || true)
  assert_contains "gamma.txt FAILED" "FAILED" "$out_t04"
  # Restauration
  echo "contenu gamma" > data/gamma.txt
  echo ""

  # ── T05 : Compare — aucune différence ────────────────────────────────────
  echo "T05 — Compare : aucune différence"
  bash "$INTEGRITY" compute ./data base_t05.b3 > /dev/null 2>&1
  bash "$INTEGRITY" compare base_t01.b3 base_t05.b3 > /dev/null 2>&1

  local outdir_t05
  outdir_t05=$(ls -d "${RESULTATS_DIR}/resultats_base_t01"* 2>/dev/null | tail -1)
  assert_file_exists "recap.txt créé"    "${outdir_t05}/recap.txt"
  assert_file_exists "modifies.b3 créé"  "${outdir_t05}/modifies.b3"
  assert_file_exists "disparus.txt créé" "${outdir_t05}/disparus.txt"
  assert_file_exists "nouveaux.txt créé" "${outdir_t05}/nouveaux.txt"
  assert_line_count  "modifies.b3 vide"  0 "${outdir_t05}/modifies.b3"
  assert_line_count  "disparus.txt vide" 0 "${outdir_t05}/disparus.txt"
  assert_line_count  "nouveaux.txt vide" 0 "${outdir_t05}/nouveaux.txt"
  echo ""

  # ── T06 : Compare — fichier modifié ──────────────────────────────────────
  echo "T06 — Compare : fichier modifié"
  echo "contenu beta modifié" > data/beta.txt
  bash "$INTEGRITY" compute ./data base_t06.b3 > /dev/null 2>&1
  bash "$INTEGRITY" compare base_t01.b3 base_t06.b3 > /dev/null 2>&1

  local outdir_t06
  outdir_t06=$(ls -d "${RESULTATS_DIR}/resultats_base_t01"* 2>/dev/null | tail -1)
  assert_contains "modifies.b3 contient beta.txt" "beta.txt" "$(cat "${outdir_t06}/modifies.b3")"
  # Restauration
  echo "contenu beta" > data/beta.txt
  echo ""

  # ── T07 : Compare — suppression + ajout ──────────────────────────────────
  echo "T07 — Compare : fichier supprimé + fichier ajouté"
  bash "$INTEGRITY" compute ./data base_t07_old.b3 > /dev/null 2>&1
  rm data/alpha.txt
  echo "contenu epsilon" > data/epsilon.txt
  bash "$INTEGRITY" compute ./data base_t07_new.b3 > /dev/null 2>&1
  bash "$INTEGRITY" compare base_t07_old.b3 base_t07_new.b3 > /dev/null 2>&1

  local outdir_t07
  outdir_t07=$(ls -d "${RESULTATS_DIR}/resultats_base_t07_old"* 2>/dev/null | tail -1)
  assert_contains "disparus.txt contient alpha.txt"   "alpha.txt"   "$(cat "${outdir_t07}/disparus.txt")"
  assert_contains "nouveaux.txt contient epsilon.txt" "epsilon.txt" "$(cat "${outdir_t07}/nouveaux.txt")"
  # Restauration
  echo "contenu alpha" > data/alpha.txt
  rm data/epsilon.txt
  echo ""

  # ── T08 : Noms de fichiers avec espaces ───────────────────────────────────
  echo "T08 — Robustesse : nom de fichier avec espace"
  echo "contenu avec espace" > "data/fichier avec espace.txt"
  bash "$INTEGRITY" compute ./data base_t08.b3 > /dev/null 2>&1
  local out_t08
  out_t08=$(bash "$INTEGRITY" verify base_t08.b3 2>&1 || true)
  assert_not_contains "aucun FAILED" "FAILED" "$out_t08"
  rm "data/fichier avec espace.txt"
  echo ""

  # ── T09 : Dossier vide ignoré (limite documentée) ─────────────────────────
  echo "T09 — Limite : dossier vide ignoré"
  mkdir data/dossier_vide
  bash "$INTEGRITY" compute ./data base_t09.b3 > /dev/null 2>&1
  assert_not_contains "dossier_vide absent de la base" "dossier_vide" "$(cat base_t09.b3)"
  pass "comportement conforme à la documentation"
  rmdir data/dossier_vide
  echo ""

  # ── T10 : Chemin absolu vs relatif ───────────────────────────────────────
  echo "T10 — Chemin absolu vs relatif"
  find "$WORKDIR/data" -type f -print0 | sort -z | xargs -0 b3sum > base_absolu.b3
  find ./data          -type f -print0 | sort -z | xargs -0 b3sum > base_relatif.b3
  local first_abs first_rel
  first_abs=$(head -1 base_absolu.b3)
  first_rel=$(head -1 base_relatif.b3)
  assert_contains     "base absolue contient un chemin absolu"   "  /" "$first_abs"
  assert_contains     "base relative contient un chemin relatif" "\./data/" "$first_rel"
  assert_not_contains "bases non interchangeables" "$first_abs" "$first_rel"
  echo ""

  # ── T11 : compute_with_progress — intégrité de la base produite ───────────
  echo "T11 — ETA : la base produite est identique à une base de référence"
  find ./data -type f -print0 | sort -z | xargs -0 b3sum > base_ref.b3
  bash "$INTEGRITY" compute ./data base_eta.b3 > /dev/null 2>&1
  assert_exit_zero    "base ETA identique à la base de référence" diff base_ref.b3 base_eta.b3
  assert_not_contains "aucune ligne ETA dans la base"             "ETA"  "$(cat base_eta.b3)"
  assert_not_contains "aucun caractère de contrôle dans la base"  $'\r'  "$(cat base_eta.b3)"
  echo ""

  # ── T12 : Mode --quiet ────────────────────────────────────────────────────
  echo "T12 — Mode --quiet : aucune sortie terminal"
  bash "$INTEGRITY" compute ./data base_t12.b3 > /dev/null 2>&1

  local out_quiet_ok
  out_quiet_ok=$(bash "$INTEGRITY" --quiet verify base_t12.b3 2>&1 || true)
  assert_not_contains "--quiet verify OK : stdout vide" "OK"   "$out_quiet_ok"
  assert_not_contains "--quiet verify OK : stdout vide" "Résultats" "$out_quiet_ok"

  # Vérifier que les fichiers de résultats sont bien produits malgré --quiet
  local outdir_t12
  outdir_t12=$(ls -d "${RESULTATS_DIR}/resultats_base_t12"* 2>/dev/null | tail -1)
  assert_file_exists "recap.txt produit en mode --quiet" "${outdir_t12}/recap.txt"

  # --quiet avec échec : stdout toujours vide, fichiers produits, exit code non nul
  echo "contenu corrompu" > data/beta.txt
  local out_quiet_fail exit_quiet
  out_quiet_fail=$(bash "$INTEGRITY" --quiet verify base_t12.b3 2>&1 || true)
  bash "$INTEGRITY" --quiet verify base_t12.b3 > /dev/null 2>&1 && exit_quiet=0 || exit_quiet=$?
  assert_not_contains "--quiet verify ECHEC : stdout vide" "ECHEC"  "$out_quiet_fail"
  assert_not_contains "--quiet verify ECHEC : stdout vide" "FAILED" "$out_quiet_fail"

  local outdir_t12b
  outdir_t12b=$(ls -d "${RESULTATS_DIR}/resultats_base_t12"* 2>/dev/null | tail -1)
  assert_file_exists "failed.txt produit en mode --quiet" "${outdir_t12b}/failed.txt"

  if (( exit_quiet != 0 )); then
    pass "--quiet propage l'exit code non nul sur échec"
  else
    fail "--quiet propage l'exit code non nul sur échec (exit_quiet=$exit_quiet)"
  fi

  # Restauration
  echo "contenu beta" > data/beta.txt

  # --quiet compute : pas de sortie progression
  local out_quiet_compute
  out_quiet_compute=$(bash "$INTEGRITY" --quiet compute ./data base_t12c.b3 2>&1 || true)
  assert_not_contains "--quiet compute : stdout vide" "Base enregistrée" "$out_quiet_compute"
  assert_not_contains "--quiet compute : pas d'ETA"   "ETA"              "$out_quiet_compute"
  echo ""

  # ── T13 : Horodatage make_result_dir — pas d'écrasement ──────────────────
  echo "T13 — Horodatage : deux exécutions successives sur la même base"
  bash "$INTEGRITY" compute ./data base_t13.b3 > /dev/null 2>&1
  bash "$INTEGRITY" verify base_t13.b3 > /dev/null 2>&1 || true
  sleep 1
  bash "$INTEGRITY" verify base_t13.b3 > /dev/null 2>&1 || true
  local nb_resultats
  nb_resultats=$(ls -d "${RESULTATS_DIR}/resultats_base_t13"* 2>/dev/null | wc -l)
  if (( nb_resultats >= 2 )); then
    pass "deux dossiers distincts créés (pas d'écrasement)"
  else
    fail "écrasement détecté : $nb_resultats dossier(s) au lieu de >= 2"
  fi
  echo ""

  # ── T14 : verify avec [dossier] incorrect ────────────────────────────────
  echo "T14 — verify : dossier argument invalide détecté"
  local out_t14
  out_t14=$(bash "$INTEGRITY" verify base_t01.b3 /chemin/inexistant 2>&1 || true)
  assert_contains "erreur si dossier invalide" "ERREUR" "$out_t14"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

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

# ── Rapport final ──────────────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}$PASS/$TOTAL tests passés${NC}"
else
  echo -e "  ${GREEN}$PASS${NC}/${TOTAL} passés — ${RED}$FAIL échec(s)${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

[ "$FAIL" -eq 0 ]