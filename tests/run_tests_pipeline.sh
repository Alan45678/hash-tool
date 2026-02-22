#!/usr/bin/env bash
# run_tests_pipeline.sh — Tests automatisés pour runner.sh + pipeline.json
#
# Couvre : parsing JSON, compute, verify, compare, erreurs (dossier absent, JSON invalide)
#
# Prérequis : bash >= 4, jq, b3sum, integrity.sh et runner.sh dans le répertoire parent
# Usage     : cd tests && ./run_tests_pipeline.sh

set -euo pipefail

# ── Chemins ───────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/../runner.sh"
INTEGRITY="$SCRIPT_DIR/../integrity.sh"
WORKDIR="$(mktemp -d /tmp/integrity-pipeline-test.XXXXXX)"
export RESULTATS_DIR="$WORKDIR/resultats"

# ── Couleurs ──────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ── Compteurs ─────────────────────────────────────────────────────────────────

PASS=0
FAIL=0
TOTAL=0

pass() { echo -e "${GREEN}  PASS${NC} — $1"; (( PASS++ )); (( TOTAL++ )); }
fail() { echo -e "${RED}  FAIL${NC} — $1"; (( FAIL++ )); (( TOTAL++ )); }

# ── Assertions ────────────────────────────────────────────────────────────────

assert_exit_zero() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

assert_exit_nonzero() {
    local label="$1"; shift
    if ! "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

assert_contains() {
    local label="$1" pattern="$2" output="$3"
    if echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label"; fi
}

assert_not_contains() {
    local label="$1" pattern="$2" output="$3"
    if ! echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label"; fi
}

assert_file_exists() {
    local label="$1" file="$2"
    if [ -f "$file" ]; then pass "$label"; else fail "$label (absent : $file)"; fi
}

assert_file_absent() {
    local label="$1" file="$2"
    if [ ! -f "$file" ]; then pass "$label"; else fail "$label (présent à tort : $file)"; fi
}

assert_line_count() {
    local label="$1" expected="$2" file="$3"
    local actual
    actual=$(wc -l < "$file")
    if [ "$actual" -eq "$expected" ]; then pass "$label"; else fail "$label (attendu $expected, obtenu $actual)"; fi
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Écrit un pipeline.json dans WORKDIR et retourne son chemin
write_config() {
    local path="$WORKDIR/pipeline.json"
    cat > "$path"
    echo "$path"
}

# ── Setup / Teardown ──────────────────────────────────────────────────────────

setup() {
    mkdir -p "$WORKDIR"/{src_a,src_b,src_absent,bases,resultats}

    echo "alpha content" > "$WORKDIR/src_a/alpha.txt"
    echo "beta content"  > "$WORKDIR/src_a/beta.txt"
    mkdir -p "$WORKDIR/src_a/sub"
    echo "delta content" > "$WORKDIR/src_a/sub/delta.txt"

    echo "gamma content" > "$WORKDIR/src_b/gamma.txt"
    echo "delta content" > "$WORKDIR/src_b/delta.txt"
}

teardown() {
    rm -rf "$WORKDIR"
}

# ── Tests ─────────────────────────────────────────────────────────────────────

run_tests() {
    cd "$WORKDIR"

    # ── TP01 : JSON invalide — runner doit échouer proprement ────────────────
    echo "TP01 — JSON invalide : runner échoue avec message explicite"
    local cfg_invalid="$WORKDIR/invalid.json"
    echo "{ pipeline: [ BROKEN" > "$cfg_invalid"
    local out_tp01
    out_tp01=$(bash "$RUNNER" "$cfg_invalid" 2>&1 || true)
    assert_contains    "exit non nul sur JSON invalide"    "ERREUR"  "$out_tp01"
    assert_not_contains "pas de stacktrace jq brute"       "parse error" "$out_tp01"
    echo ""

    # ── TP02 : tableau .pipeline absent ──────────────────────────────────────
    echo "TP02 — .pipeline absent : runner échoue"
    local cfg_no_pipeline
    cfg_no_pipeline=$(write_config <<'EOF'
{ "config": [] }
EOF
)
    local out_tp02
    out_tp02=$(bash "$RUNNER" "$cfg_no_pipeline" 2>&1 || true)
    assert_contains "erreur si .pipeline absent" "ERREUR" "$out_tp02"
    echo ""

    # ── TP03 : champ manquant dans un bloc compute ────────────────────────────
    echo "TP03 — Champ 'nom' manquant dans compute : erreur explicite"
    local cfg_missing_field
    cfg_missing_field=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "compute",
            "source": "$WORKDIR/src_a",
            "bases":  "$WORKDIR/bases"
        }
    ]
}
EOF
)
    local out_tp03
    out_tp03=$(bash "$RUNNER" "$cfg_missing_field" 2>&1 || true)
    assert_contains "erreur si champ 'nom' absent" "ERREUR" "$out_tp03"
    assert_contains "mention du champ manquant"    "nom"    "$out_tp03"
    echo ""

    # ── TP04 : opération inconnue ─────────────────────────────────────────────
    echo "TP04 — Opération inconnue : erreur explicite"
    local cfg_unknown_op
    cfg_unknown_op=$(write_config <<'EOF'
{
    "pipeline": [
        { "op": "migrate", "source": "/tmp" }
    ]
}
EOF
)
    local out_tp04
    out_tp04=$(bash "$RUNNER" "$cfg_unknown_op" 2>&1 || true)
    assert_contains "erreur si op inconnue" "ERREUR"   "$out_tp04"
    assert_contains "nom de l'op dans l'erreur" "migrate" "$out_tp04"
    echo ""

    # ── TP05 : compute — cd correct, chemin relatif dans la base ─────────────
    echo "TP05 — Compute : cd correct, chemins relatifs dans la base"
    local cfg_compute
    cfg_compute=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "compute",
            "source": "$WORKDIR/src_a",
            "bases":  "$WORKDIR/bases",
            "nom":    "hashes_a.b3"
        }
    ]
}
EOF
)
    bash "$RUNNER" "$cfg_compute" >/dev/null 2>&1
    assert_file_exists "base hashes_a.b3 créée" "$WORKDIR/bases/hashes_a.b3"

    # Vérifier que les chemins dans la base sont relatifs (commencent par ./)
    local first_path
    first_path=$(awk '{print $2}' "$WORKDIR/bases/hashes_a.b3" | head -1)
    assert_contains    "chemin relatif dans la base (./))" "./" "$first_path"
    assert_not_contains "pas de chemin absolu dans la base" "$WORKDIR" "$first_path"

    # 3 fichiers indexés (alpha.txt, beta.txt, sub/delta.txt)
    assert_line_count "3 fichiers indexés" 3 "$WORKDIR/bases/hashes_a.b3"
    echo ""

    # ── TP06 : compute — dossier source absent ────────────────────────────────
    echo "TP06 — Compute : dossier source absent → erreur explicite"
    local cfg_absent
    cfg_absent=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "compute",
            "source": "$WORKDIR/src_absent_inexistant",
            "bases":  "$WORKDIR/bases",
            "nom":    "hashes_absent.b3"
        }
    ]
}
EOF
)
    local out_tp06
    out_tp06=$(bash "$RUNNER" "$cfg_absent" 2>&1 || true)
    assert_contains     "erreur si source absente"       "ERREUR"  "$out_tp06"
    assert_file_absent  "pas de base créée si source KO" "$WORKDIR/bases/hashes_absent.b3"
    echo ""

    # ── TP07 : verify — bon répertoire de travail ─────────────────────────────
    echo "TP07 — Verify : répertoire de travail correct, vérification OK"
    # Prérequis : base hashes_a.b3 créée en TP05
    local cfg_verify
    cfg_verify=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "verify",
            "source": "$WORKDIR/src_a",
            "base":   "$WORKDIR/bases/hashes_a.b3"
        }
    ]
}
EOF
)
    local out_tp07
    out_tp07=$(bash "$RUNNER" "$cfg_verify" 2>&1 || true)
    assert_contains     "verify retourne OK"     "OK"     "$out_tp07"
    assert_not_contains "aucun FAILED"           "FAILED" "$out_tp07"

    # recap.txt produit
    local outdir_tp07
    outdir_tp07=$(ls -d "${RESULTATS_DIR}/resultats_hashes_a"* 2>/dev/null | tail -1)
    assert_file_exists "recap.txt produit par verify" "${outdir_tp07}/recap.txt"
    echo ""

    # ── TP08 : verify — détection de corruption ───────────────────────────────
    echo "TP08 — Verify : détection de corruption"
    echo "contenu corrompu" > "$WORKDIR/src_a/alpha.txt"
    local out_tp08
    out_tp08=$(bash "$RUNNER" "$cfg_verify" 2>&1 || true)
    assert_contains "corruption détectée" "ECHEC" "$out_tp08"
    # Restauration
    echo "alpha content" > "$WORKDIR/src_a/alpha.txt"
    echo ""

    # ── TP09 : verify — base .b3 absente ─────────────────────────────────────
    echo "TP09 — Verify : base .b3 absente → erreur explicite"
    local cfg_verify_bad_base
    cfg_verify_bad_base=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "verify",
            "source": "$WORKDIR/src_a",
            "base":   "$WORKDIR/bases/inexistante.b3"
        }
    ]
}
EOF
)
    local out_tp09
    out_tp09=$(bash "$RUNNER" "$cfg_verify_bad_base" 2>&1 || true)
    assert_contains "erreur si base absente" "ERREUR" "$out_tp09"
    echo ""

    # ── TP10 : compare — appel correct, résultats produits ───────────────────
    echo "TP10 — Compare : appel correct, fichiers de résultats produits"
    # Créer une seconde base (src_b)
    local cfg_compute_b
    cfg_compute_b=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "compute",
            "source": "$WORKDIR/src_b",
            "bases":  "$WORKDIR/bases",
            "nom":    "hashes_b.b3"
        }
    ]
}
EOF
)
    bash "$RUNNER" "$cfg_compute_b" >/dev/null 2>&1

    local cfg_compare
    cfg_compare=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "compare",
            "base_a": "$WORKDIR/bases/hashes_a.b3",
            "base_b": "$WORKDIR/bases/hashes_b.b3"
        }
    ]
}
EOF
)
    bash "$RUNNER" "$cfg_compare" >/dev/null 2>&1

    local outdir_tp10
    outdir_tp10=$(ls -d "${RESULTATS_DIR}/resultats_hashes_a"* 2>/dev/null | tail -1)
    assert_file_exists "recap.txt produit"     "${outdir_tp10}/recap.txt"
    assert_file_exists "modifies.b3 produit"   "${outdir_tp10}/modifies.b3"
    assert_file_exists "disparus.txt produit"  "${outdir_tp10}/disparus.txt"
    assert_file_exists "nouveaux.txt produit"  "${outdir_tp10}/nouveaux.txt"
    echo ""

    # ── TP11 : compare — base_a absente ──────────────────────────────────────
    echo "TP11 — Compare : base_a absente → erreur explicite"
    local cfg_compare_bad
    cfg_compare_bad=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "compare",
            "base_a": "$WORKDIR/bases/fantome.b3",
            "base_b": "$WORKDIR/bases/hashes_b.b3"
        }
    ]
}
EOF
)
    local out_tp11
    out_tp11=$(bash "$RUNNER" "$cfg_compare_bad" 2>&1 || true)
    assert_contains "erreur si base_a absente" "ERREUR" "$out_tp11"
    echo ""

    # ── TP12 : pipeline multi-opérations — exécution séquentielle complète ───
    echo "TP12 — Pipeline complet : compute + verify + compare"
    # Recalcul propre
    rm -f "$WORKDIR/bases/hashes_a.b3" "$WORKDIR/bases/hashes_b.b3"

    local cfg_full
    cfg_full=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":     "compute",
            "source": "$WORKDIR/src_a",
            "bases":  "$WORKDIR/bases",
            "nom":    "hashes_a.b3"
        },
        {
            "op":     "compute",
            "source": "$WORKDIR/src_b",
            "bases":  "$WORKDIR/bases",
            "nom":    "hashes_b.b3"
        },
        {
            "op":     "verify",
            "source": "$WORKDIR/src_a",
            "base":   "$WORKDIR/bases/hashes_a.b3"
        },
        {
            "op":     "compare",
            "base_a": "$WORKDIR/bases/hashes_a.b3",
            "base_b": "$WORKDIR/bases/hashes_b.b3"
        }
    ]
}
EOF
)
    local out_tp12
    out_tp12=$(bash "$RUNNER" "$cfg_full" 2>&1 || true)
    assert_contains     "COMPUTE src_a mentionné" "COMPUTE" "$out_tp12"
    assert_contains     "VERIFY mentionné"        "VERIFY"  "$out_tp12"
    assert_contains     "COMPARE mentionné"       "COMPARE" "$out_tp12"
    assert_file_exists  "hashes_a.b3 créée"       "$WORKDIR/bases/hashes_a.b3"
    assert_file_exists  "hashes_b.b3 créée"       "$WORKDIR/bases/hashes_b.b3"
    assert_not_contains "pas d'ERREUR dans pipeline complet" "ERREUR" "$out_tp12"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

for dep in jq b3sum; do
    command -v "$dep" &>/dev/null || {
        echo -e "${RED}ERREUR${NC} : $dep non trouvé."
        exit 1
    }
done

[ -f "$RUNNER" ]    || { echo -e "${RED}ERREUR${NC} : runner.sh introuvable : $RUNNER";    exit 1; }
[ -f "$INTEGRITY" ] || { echo -e "${RED}ERREUR${NC} : integrity.sh introuvable : $INTEGRITY"; exit 1; }

setup
run_tests
teardown

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}$PASS/$TOTAL tests passés${NC}"
else
    echo -e "  ${GREEN}$PASS${NC}/${TOTAL} passés — ${RED}$FAIL échec(s)${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

[ "$FAIL" -eq 0 ]