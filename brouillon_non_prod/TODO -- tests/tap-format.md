# Format TAP — Spécification et implémentation

---

## Qu'est-ce que TAP ?

TAP (Test Anything Protocol) est un format texte standard pour les résultats de tests. Créé en 1987 pour Perl, il est aujourd'hui supporté par la quasi-totalité des systèmes CI et des outils de test multi-langages.

**Avantage principal :** TAP est lisible par un humain ET parseable par une machine sans configuration supplémentaire. GitHub Actions, GitLab CI, Jenkins et des dizaines d'autres outils savent afficher des rapports visuels à partir de TAP.

---

## Format TAP 14 — Syntaxe

```
TAP version 14
1..N
ok 1 - description du test
not ok 2 - description du test échoué
# commentaire ou diagnostic (ignoré par les parseurs)
ok 3 - description
not ok 4 - test avec diagnostic
  ---
  message: valeur attendue
  found: valeur obtenue
  ...
```

### Règles

| Élément | Syntaxe | Obligatoire |
|---|---|---|
| Déclaration de version | `TAP version 14` | Recommandé, première ligne |
| Plan | `1..N` (N = nombre total de tests) | Oui — doit apparaître avant ou après les tests |
| Test réussi | `ok N - description` | — |
| Test échoué | `not ok N - description` | — |
| Diagnostic | `# texte libre` | Non |
| YAML block (détail d'échec) | `  ---\n  clé: valeur\n  ...` | Non |
| Test ignoré | `ok N - description # SKIP raison` | Non |
| Test attendu en échec | `not ok N - description # TODO raison` | Non |

---

## Implémentation dans les suites bash

### Helpers à inclure dans chaque suite

```bash
#!/usr/bin/env bash
# helpers-tap.sh — à sourcer dans chaque suite de tests
# Usage : source helpers-tap.sh

TAP_TOTAL=0
TAP_PASS=0
TAP_FAIL=0
TAP_TESTS=()   # tableau des résultats pour le plan final

# Déclare le plan en tête (si le nombre est connu à l'avance)
# Usage : tap_plan 42
tap_plan() {
    echo "TAP version 14"
    echo "1..$1"
}

# Enregistre un succès
# Usage : tap_ok "description du test"
tap_ok() {
    TAP_TOTAL=$(( TAP_TOTAL + 1 ))
    TAP_PASS=$(( TAP_PASS + 1 ))
    printf "ok %d - %s\n" "$TAP_TOTAL" "$1"
}

# Enregistre un échec avec diagnostic optionnel
# Usage : tap_not_ok "description" ["message de diagnostic"]
tap_not_ok() {
    TAP_TOTAL=$(( TAP_TOTAL + 1 ))
    TAP_FAIL=$(( TAP_FAIL + 1 ))
    printf "not ok %d - %s\n" "$TAP_TOTAL" "$1"
    if [ -n "${2:-}" ]; then
        printf "  ---\n  message: %s\n  ...\n" "$2"
    fi
}

# Skip un test avec raison
# Usage : tap_skip "description" "raison du skip"
tap_skip() {
    TAP_TOTAL=$(( TAP_TOTAL + 1 ))
    printf "ok %d - %s # SKIP %s\n" "$TAP_TOTAL" "$1" "$2"
}

# Affiche le résumé final (quand le plan n'est pas connu à l'avance)
tap_summary() {
    echo "1..$TAP_TOTAL"
    echo "# Tests : $TAP_TOTAL | Passés : $TAP_PASS | Échecs : $TAP_FAIL"
}

# Assertions de haut niveau construites sur tap_ok/tap_not_ok

# assert_exit_zero <label> <commande...>
assert_exit_zero() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        tap_ok "$label"
    else
        tap_not_ok "$label" "commande a retourné exit non-zéro : $*"
    fi
}

# assert_exit_nonzero <label> <commande...>
assert_exit_nonzero() {
    local label="$1"; shift
    if ! "$@" >/dev/null 2>&1; then
        tap_ok "$label"
    else
        tap_not_ok "$label" "commande aurait dû échouer : $*"
    fi
}

# assert_contains <label> <pattern> <chaine>
assert_contains() {
    local label="$1" pattern="$2" string="$3"
    if echo "$string" | grep -q "$pattern"; then
        tap_ok "$label"
    else
        tap_not_ok "$label" "pattern '$pattern' absent dans : $(echo "$string" | head -3)"
    fi
}

# assert_not_contains <label> <pattern> <chaine>
assert_not_contains() {
    local label="$1" pattern="$2" string="$3"
    if ! echo "$string" | grep -q "$pattern"; then
        tap_ok "$label"
    else
        tap_not_ok "$label" "pattern '$pattern' présent à tort dans : $(echo "$string" | head -3)"
    fi
}

# assert_file_exists <label> <fichier>
assert_file_exists() {
    local label="$1" file="$2"
    if [ -f "$file" ]; then
        tap_ok "$label"
    else
        tap_not_ok "$label" "fichier absent : $file"
    fi
}

# assert_file_absent <label> <fichier>
assert_file_absent() {
    local label="$1" file="$2"
    if [ ! -f "$file" ]; then
        tap_ok "$label"
    else
        tap_not_ok "$label" "fichier présent à tort : $file"
    fi
}

# assert_line_count <label> <expected> <fichier>
assert_line_count() {
    local label="$1" expected="$2" file="$3"
    local actual
    actual=$(wc -l < "$file")
    if [ "$actual" -eq "$expected" ]; then
        tap_ok "$label"
    else
        tap_not_ok "$label" "attendu $expected lignes, obtenu $actual"
    fi
}

# assert_eq <label> <expected> <actual>
assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        tap_ok "$label"
    else
        tap_not_ok "$label" "attendu '$expected', obtenu '$actual'"
    fi
}
```

---

## Exemple de sortie TAP pour `run_tests_core.sh`

```
TAP version 14
1..53
ok 1 - CU01 fichier absent → exit 1
ok 2 - CU02 chemin est un dossier → exit 1
ok 3 - CU03 fichier vide → exit 1
ok 4 - CU04 format invalide → exit 1
ok 5 - CU05 hash trop court → exit 1
ok 6 - CU06 hash trop long → exit 1
ok 7 - CU07 hash avec majuscules → exit 1
ok 8 - CU08 ligne valide unique → exit 0
ok 9 - CU09 plusieurs lignes valides → exit 0
not ok 10 - CU10 mélange valide/invalide → exit 1
  ---
  message: attendu exit 1, obtenu 0
  ...
ok 11 - CU11 label dans message d'erreur
# T_CORE02 - core_assert_target_valid
ok 12 - CU12 dossier absent → exit 1
...
```

---

## Intégration avec GitHub Actions

GitHub Actions ne parse pas TAP nativement, mais plusieurs actions le font :

### Option 1 — `dorny/test-reporter`

```yaml
- name: Run tests (TAP output)
  run: cd tests && ./run_tests_core.sh > /tmp/core-results.tap || true

- name: Publish test results
  uses: dorny/test-reporter@v1
  if: always()
  with:
    name: Unit Tests
    path: /tmp/core-results.tap
    reporter: tap
```

### Option 2 — Conversion TAP → JUnit XML (plus universelle)

```bash
# Installer tap-junit
npm install -g tap-junit

# Dans la CI
cd tests && ./run_tests_core.sh | tap-junit --name "core" > /tmp/core-junit.xml
```

```yaml
- uses: mikepenz/action-junit-report@v4
  with:
    report_paths: /tmp/*-junit.xml
```

### Option 3 — Sortie colorée en terminal, TAP en CI

Détecter si on est en CI et adapter le format :

```bash
# En tête de chaque suite
if [ -n "${CI:-}" ]; then
    # Format TAP pour la CI
    tap_ok()     { printf "ok %d - %s\n"     "$((++TAP_TOTAL))" "$1"; }
    tap_not_ok() { printf "not ok %d - %s\n" "$((++TAP_TOTAL))" "$1"; TAP_FAIL=$((TAP_FAIL+1)); }
else
    # Format coloré pour le terminal local
    GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
    tap_ok()     { echo -e "${GREEN}  PASS${NC} - $1"; }
    tap_not_ok() { echo -e "${RED}  FAIL${NC} - $1"; TAP_FAIL=$((TAP_FAIL+1)); }
fi
```

---

## Stratégie de migration des suites existantes

Les suites `run_tests.sh` et `run_tests_pipeline.sh` utilisent actuellement des helpers `pass()`/`fail()` avec sortie colorée. La migration vers TAP se fait en deux étapes :

### Étape 1 — Compatibilité ascendante

Remplacer les helpers existants par les helpers TAP tout en conservant la sortie colorée en mode terminal. Seul le format change en CI (`CI` est défini automatiquement dans GitHub Actions).

Avant :
```bash
PASS=0; FAIL=0; TOTAL=0
pass() { echo -e "${GREEN}  PASS${NC} - $1"; ((PASS++)); ((TOTAL++)); }
fail() { echo -e "${RED}  FAIL${NC} - $1"; ((FAIL++)); ((TOTAL++)); }
```

Après (compatible backward + TAP en CI) :
```bash
source "$(dirname "$0")/helpers-tap.sh"
```

### Étape 2 — Extraction dans `tests/helpers-tap.sh`

Extraire les helpers dans un fichier commun sourcé par toutes les suites. Avantage : un seul endroit à maintenir.

```
tests/
├── helpers-tap.sh             ← helpers communs (nouveau)
├── run_tests.sh               ← source helpers-tap.sh
├── run_tests_pipeline.sh      ← source helpers-tap.sh
├── run_tests_core.sh          ← source helpers-tap.sh
└── run_tests_docker.sh        ← source helpers-tap.sh
```

---

## Plan pour `run_tests_core.sh`

Si le nombre total de tests est connu à l'avance (53 cas dans la spécification `unit-tests.md`), utiliser un plan en tête :

```bash
echo "TAP version 14"
echo "1..53"
```

Si le nombre évolue fréquemment (développement actif), utiliser un plan en queue :

```bash
# ... tous les tests ...
tap_summary   # affiche "1..N" en fin de fichier
```

TAP 14 supporte les deux positions pour le plan.
