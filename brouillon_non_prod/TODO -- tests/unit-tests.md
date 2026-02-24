# Tests unitaires — Spécification `run_tests_core.sh`

---

## Principe

`run_tests_core.sh` source directement `src/lib/core.sh` (et `src/lib/ui.sh` pour `die()`) sans passer par `integrity.sh`. Chaque fonction de `core.sh` est testée en isolation.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(mktemp -d /tmp/integrity-core-test.XXXXXX)"
export RESULTATS_DIR="$WORKDIR/resultats"
QUIET=0

# Sourcing direct — pas d'appel à integrity.sh
source "$SCRIPT_DIR/../src/lib/ui.sh"
source "$SCRIPT_DIR/../src/lib/core.sh"

teardown() { rm -rf "$WORKDIR"; }
trap teardown EXIT
```

---

## Fonctions à tester

### `core_assert_b3_valid`

**Signature :** `core_assert_b3_valid <fichier> [label]`

| ID | Cas | Input | Résultat attendu |
|---|---|---|---|
| CU01 | Fichier absent | `/tmp/inexistant_xyz.b3` | exit 1, message "introuvable" sur stderr |
| CU02 | Chemin est un dossier | `mkdir /tmp/un_dossier` | exit 1, message "est un dossier" |
| CU03 | Fichier vide | `touch /tmp/vide.b3` | exit 1, message "fichier vide" |
| CU04 | Ligne au format invalide | `echo "pas_un_hash  chemin"` | exit 1, message "format invalide" |
| CU05 | Hash trop court (63 chars) | `echo "abc...63chars  ./f.txt"` | exit 1 |
| CU06 | Hash trop long (65 chars) | `echo "abc...65chars  ./f.txt"` | exit 1 |
| CU07 | Hash avec majuscules | `echo "ABC...64chars  ./f.txt"` | exit 1 — format b3sum est minuscule |
| CU08 | Ligne valide unique | `echo "aaa...64zeros  ./f.txt"` | exit 0 |
| CU09 | Plusieurs lignes valides | 4 lignes correctes | exit 0 |
| CU10 | Mélange valide + invalide | 3 valides + 1 invalide | exit 1, message "ligne(s) ne respectent pas" |
| CU11 | Label personnalisé dans message d'erreur | `core_assert_b3_valid /tmp/vide.b3 "ma base"` | stderr contient "ma base" |

```bash
# Exemple d'implémentation — CU04
test_cu04_format_invalide() {
    local f="$WORKDIR/bad.b3"
    echo "pas_un_hash  ./fichier.txt" > "$f"
    local out
    out=$(core_assert_b3_valid "$f" 2>&1) && fail "CU04 doit exit 1" || {
        assert_contains "CU04 message format invalide" "format invalide" "$out"
    }
}
```

---

### `core_assert_target_valid`

**Signature :** `core_assert_target_valid <dossier>`

| ID | Cas | Input | Résultat attendu |
|---|---|---|---|
| CU12 | Dossier absent | `/tmp/inexistant_xyz/` | exit 1, message "introuvable" |
| CU13 | Chemin est un fichier | `touch /tmp/unfichier` | exit 1, message "n'est pas un dossier" |
| CU14 | Dossier vide | `mkdir /tmp/vide` | exit 1, message "aucun fichier régulier" |
| CU15 | Dossier avec un fichier | `echo "x" > /tmp/d/f.txt` | exit 0 |
| CU16 | Dossier avec sous-dossiers uniquement vides | `mkdir /tmp/d/sub` | exit 1 — aucun fichier régulier |
| CU17 | Dossier avec fichiers dans sous-dossiers | `echo "x" > /tmp/d/sub/f.txt` | exit 0 |

---

### `core_compute`

**Signature :** `core_compute <dossier> <fichier_sortie> [callback]`

| ID | Cas | Condition | Résultat attendu |
|---|---|---|---|
| CU18 | Cas nominal sans callback | 3 fichiers, callback="" | hashfile produit, 3 lignes, format correct |
| CU19 | Format des lignes | 1 fichier connu | ligne = `[0-9a-f]{64}  <chemin>` |
| CU20 | Tri des chemins | 3 fichiers désordonnés | lignes triées par chemin (ordre lexicographique) |
| CU21 | Chemin relatif préservé | `compute ./data base.b3` depuis `/tmp` | chemins commencent par `./data/` |
| CU22 | Fichier avec espace dans le nom | `"fichier test.txt"` | une seule ligne, chemin correct |
| CU23 | Fichier de taille zéro | `touch zero.bin` | ligne présente, bytes_done non affecté |
| CU24 | Callback appelé N fois | 5 fichiers, callback compteur | callback appelé exactement 5 fois |
| CU25 | Callback reçoit les bons arguments | 1 fichier, callback loggeur | args (i, total, bytes_done, total_bytes, eta) cohérents |
| CU26 | Aucune ligne ETA dans hashfile | compute avec callback actif | hashfile ne contient pas "ETA" ni `\r` |
| CU27 | Idempotence | compute 2× sur même dossier | les deux hashfiles sont identiques |

```bash
# Exemple — CU24 : callback appelé N fois
test_cu24_callback_count() {
    local dir="$WORKDIR/data_cu24"
    mkdir -p "$dir"
    for i in 1 2 3 4 5; do echo "contenu $i" > "$dir/f$i.txt"; done

    local count=0
    _counter_callback() { count=$((count + 1)); }

    core_compute "$dir" "$WORKDIR/base_cu24.b3" "_counter_callback"
    [ "$count" -eq 5 ] && pass "CU24 callback appelé 5 fois" || fail "CU24 callback appelé $count fois (attendu 5)"
}
```

---

### `core_verify`

**Signature :** `core_verify <fichier_b3_absolu>`

Le répertoire courant doit être celui d'origine du compute avant l'appel.

| ID | Cas | Condition | Résultat attendu |
|---|---|---|---|
| CU28 | Tous les fichiers intègres | base correcte, fichiers inchangés | exit 0, CORE_VERIFY_STATUS="OK" |
| CU29 | Un fichier corrompu | contenu modifié après compute | exit 1, STATUS="ECHEC", NB_FAIL=1 |
| CU30 | Plusieurs fichiers corrompus | 2 fichiers modifiés | exit 1, NB_FAIL=2 |
| CU31 | Un fichier supprimé | rm après compute | exit 1, LINES_FAIL contient le chemin |
| CU32 | Variables CORE_VERIFY_* positionnées | cas nominal | toutes les variables sont non nulles et cohérentes |
| CU33 | CORE_VERIFY_NB_OK correct | 4 fichiers intègres | NB_OK=4 |
| CU34 | CORE_VERIFY_LINES_FAIL contient les bons chemins | 1 corruption sur beta.txt | LINES_FAIL contient "beta.txt" |
| CU35 | STATUS="ERREUR" si b3sum rapporte une erreur | fichier illisible (chmod 000) | STATUS="ERREUR" |

```bash
# Exemple — CU29
test_cu29_corruption_detectee() {
    local dir="$WORKDIR/data_cu29"
    mkdir -p "$dir"
    echo "contenu original" > "$dir/alpha.txt"
    local base="$WORKDIR/base_cu29.b3"

    ( cd "$dir" && core_compute . "$base" "" )

    echo "contenu corrompu" > "$dir/alpha.txt"

    local exit_code=0
    ( cd "$dir" && core_verify "$(cd "$WORKDIR" && pwd)/base_cu29.b3" ) || exit_code=$?

    [ "$exit_code" -ne 0 ] && pass "CU29 exit code non-zéro" || fail "CU29 doit détecter la corruption"
    [ "$CORE_VERIFY_STATUS" = "ECHEC" ] && pass "CU29 STATUS=ECHEC" || fail "CU29 STATUS=$CORE_VERIFY_STATUS"
}
```

---

### `core_compare`

**Signature :** `core_compare <old> <new> <outdir>`

C'est la fonction la plus critique — un bug ici produit de faux positifs massifs (cf. v0.7).

| ID | Cas | Condition | Résultat attendu |
|---|---|---|---|
| CU36 | Bases identiques | même contenu | modifies.b3 vide, disparus.txt vide, nouveaux.txt vide |
| CU37 | Un fichier modifié | beta.txt changé | modifies.b3 contient beta.txt, NB_MOD=1 |
| CU38 | Plusieurs fichiers modifiés | 3 fichiers changés | NB_MOD=3, les 3 chemins dans modifies.b3 |
| CU39 | Un fichier disparu | alpha.txt supprimé dans new | disparus.txt contient alpha.txt, NB_DIS=1 |
| CU40 | Un fichier nouveau | epsilon.txt ajouté dans new | nouveaux.txt contient epsilon.txt, NB_NOU=1 |
| CU41 | Combinaison modifié + disparu + nouveau | — | les 3 fichiers dans les 3 listes correctes |
| CU42 | Chemin avec espace | `"fichier test.txt"` modifié | modifies.b3 contient le chemin complet avec espace |
| CU43 | Chemin avec `&` | `"a&b.txt"` modifié | chemin correct dans modifies.b3 |
| CU44 | Chemin avec `<` et `>` | `"<script>.txt"` modifié | chemin correct (pas d'échappement HTML dans .b3) |
| CU45 | Format de modifies.b3 | 1 fichier modifié | ligne = `nouveau_hash  chemin` (format b3sum) |
| CU46 | Variables CORE_COMPARE_NB_* | — | NB_MOD, NB_DIS, NB_NOU corrects |
| CU47 | Fichiers tmp nettoyés | après appel | aucun fichier dans /tmp commençant par le pattern mktemp |
| CU48 | outdir doit exister avant l'appel | outdir absent | comportement défini (mkdir requis par l'appelant) |

```bash
# Exemple — CU42 : chemin avec espace
test_cu42_chemin_avec_espace() {
    local dir_old="$WORKDIR/old_cu42"
    local dir_new="$WORKDIR/new_cu42"
    mkdir -p "$dir_old" "$dir_new"

    echo "contenu v1" > "$dir_old/fichier avec espace.txt"
    echo "contenu v2" > "$dir_new/fichier avec espace.txt"

    ( cd "$dir_old" && core_compute . "$WORKDIR/old_cu42.b3" "" )
    ( cd "$dir_new" && core_compute . "$WORKDIR/new_cu42.b3" "" )

    local outdir="$WORKDIR/result_cu42"
    mkdir -p "$outdir"
    core_compare "$WORKDIR/old_cu42.b3" "$WORKDIR/new_cu42.b3" "$outdir"

    assert_contains "CU42 chemin avec espace dans modifies.b3" \
        "fichier avec espace.txt" \
        "$(cat "$outdir/modifies.b3")"
    [ "$CORE_COMPARE_NB_MOD" -eq 1 ] && pass "CU42 NB_MOD=1" || fail "CU42 NB_MOD=$CORE_COMPARE_NB_MOD"
}
```

---

### `core_make_result_dir`

**Signature :** `core_make_result_dir <fichier_b3> <resultats_dir>`

| ID | Cas | Condition | Résultat attendu |
|---|---|---|---|
| CU49 | Création normale | dossier parent existe, pas de collision | dossier `resultats_<nom>` créé, chemin retourné sur stdout |
| CU50 | Anti-collision — dossier existant | `resultats_<nom>` déjà présent | nouveau dossier `resultats_<nom>_YYYYMMDD-HHMMSS` créé |
| CU51 | Deux appels successifs | sleep 1 entre les deux | deux dossiers distincts |
| CU52 | Nom sans extension .b3 | fichier nommé `base` (sans .b3) | dossier `resultats_base` |
| CU53 | Nom avec chemin imbriqué | `/chemin/vers/hashes.b3` | dossier `resultats_hashes` (basename only) |

---

## Structure du fichier `run_tests_core.sh`

```bash
#!/usr/bin/env bash
# run_tests_core.sh - Tests unitaires de src/lib/core.sh
# Usage : cd tests && ./run_tests_core.sh
# Prérequis : bash >= 4, b3sum

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(mktemp -d /tmp/integrity-core-test.XXXXXX)"
export RESULTATS_DIR="$WORKDIR/resultats"
QUIET=0

source "$SCRIPT_DIR/../src/lib/ui.sh"
source "$SCRIPT_DIR/../src/lib/core.sh"

# Helpers identiques à run_tests.sh
PASS=0; FAIL=0; TOTAL=0
pass() { ... }
fail() { ... }
assert_contains() { ... }
assert_exit_nonzero() { ... }

teardown() { rm -rf "$WORKDIR"; }
trap teardown EXIT

# == Tests =====================================================================

echo "T_CORE01 - core_assert_b3_valid"
# ... cas CU01 à CU11

echo "T_CORE02 - core_assert_target_valid"
# ... cas CU12 à CU17

echo "T_CORE03 - core_compute"
# ... cas CU18 à CU27

echo "T_CORE04 - core_verify"
# ... cas CU28 à CU35

echo "T_CORE05 - core_compare"
# ... cas CU36 à CU48

echo "T_CORE06 - core_make_result_dir"
# ... cas CU49 à CU53

# == Résultats =================================================================
echo "========================================"
[ "$FAIL" -eq 0 ] \
    && echo "  $PASS/$TOTAL tests passés" \
    || echo "  $PASS/$TOTAL passés - $FAIL échec(s)"
echo "========================================"
[ "$FAIL" -eq 0 ]
```

---

## Précautions spécifiques au sourcing

Quand `core.sh` est sourcé directement, les fonctions internes `_b3_to_path_hash` et `_core_file_size` sont aussi accessibles. Elles peuvent être testées unitairement si nécessaire :

```bash
# Test de la fonction interne _b3_to_path_hash
test_b3_to_path_hash_format() {
    local f="$WORKDIR/sample.b3"
    printf '%0.s0' {1..64} > /tmp/hash64  # 64 zéros
    echo "$(cat /tmp/hash64)  ./dossier/fichier.txt" > "$f"

    local result
    result=$(_b3_to_path_hash "$f")
    # Attendu : "./dossier/fichier.txt\t0000...64zeros"
    echo "$result" | grep -q $'./dossier/fichier.txt\t' \
        && pass "_b3_to_path_hash format correct" \
        || fail "_b3_to_path_hash format incorrect : $result"
}
```
