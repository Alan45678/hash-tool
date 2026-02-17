# Explication du code — run_tests.sh

---

## Vue d'ensemble

`run_tests.sh` est une suite de tests automatisée pour `integrity.sh`. Elle n'utilise aucun framework externe — uniquement du bash pur. Elle crée un environnement isolé, exécute 10 cas de test, restaure l'état entre chaque cas, puis nettoie.

```
run_tests.sh
├── Vérification des prérequis   (b3sum, integrity.sh)
├── setup()                      création de l'environnement de test
├── run_tests()                  exécution des 11 cas T01–T11
├── teardown()                   suppression de l'environnement
└── Rapport final                compteurs PASS/FAIL + exit code
```

---

## 1. Configuration et chemins

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRITY="$SCRIPT_DIR/../integrity.sh"
WORKDIR="$(mktemp -d /tmp/integrity-test.XXXXXX)"
```

- `SCRIPT_DIR` : répertoire absolu du script lui-même, indépendant du répertoire depuis lequel on l'appelle.
- `INTEGRITY` : chemin vers `integrity.sh` calculé relativement à `run_tests.sh` — les deux scripts peuvent être déplacés ensemble sans modifier les chemins en dur.
- `WORKDIR` : répertoire temporaire unique créé par `mktemp`. Le suffixe `XXXXXX` est remplacé par 6 caractères aléatoires — garantit l'isolation entre deux exécutions simultanées.

---

## 2. Système de comptage

```bash
PASS=0
FAIL=0
TOTAL=0

pass() { echo -e "${GREEN}  PASS${NC} — $1"; ((PASS++)); ((TOTAL++)); }
fail() { echo -e "${RED}  FAIL${NC} — $1"; ((FAIL++)); ((TOTAL++)); }
```

Deux compteurs indépendants `PASS` et `FAIL`, incrémentés par les fonctions `pass()` et `fail()`. Chaque assertion appelle l'une ou l'autre — jamais les deux. `TOTAL` permet de vérifier qu'aucun test n'a été sauté silencieusement.

---

## 3. Fonctions d'assertion

Chaque assertion encapsule un test élémentaire et appelle `pass()` ou `fail()` selon le résultat.

### `assert_exit_zero` / `assert_exit_nonzero`

```bash
assert_exit_zero() {
  local label="$1"; shift
  if "$@" > /dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}
```

Exécute une commande et vérifie son code de retour. `> /dev/null 2>&1` supprime stdout et stderr — seul le code de retour importe ici. `shift` consomme le premier argument (`label`) pour que `"$@"` ne contienne que la commande à exécuter.

`assert_exit_nonzero` fait l'inverse : il attend un échec (code ≠ 0). Utilisé pour vérifier que `b3sum --check` détecte bien une corruption.

### `assert_contains` / `assert_not_contains`

```bash
assert_contains() {
  local label="$1"
  local pattern="$2"
  local output="$3"
  if echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label"; fi
}
```

Cherche un pattern dans une chaîne déjà capturée (pas dans un fichier). Le résultat de la commande est capturé avant l'appel via `local out=$(commande)` — ce qui permet de l'inspecter plusieurs fois sans relancer la commande.

### `assert_line_count`

```bash
assert_line_count() {
  local expected="$2"
  local actual; actual=$(wc -l < "$3")
  if [ "$actual" -eq "$expected" ]; then pass "$label"; else fail "$label"; fi
}
```

Compte les lignes d'un fichier avec `wc -l`. La redirection `< fichier` (sans passer le nom à `wc`) évite que `wc` affiche le nom du fichier dans sa sortie.

---

## 4. Setup et teardown

```bash
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
```

`setup()` crée 4 fichiers avec contenu connu et déterministe — leurs hashes sont donc reproductibles d'une exécution à l'autre. `sub/delta.txt` teste la récursivité de `find` dans les sous-dossiers.

`teardown()` supprime le `WORKDIR` entier. Appelé en fin de script, même en cas d'échec partiel (voir section 6).

---

## 5. Structure d'un cas de test

Chaque cas suit le même schéma :

```bash
echo "T0X — Description"

# 1. Préparer l'état (modifier fichiers, créer bases...)
# 2. Exécuter la commande testée, capturer la sortie
local out; out=$(commande 2>&1 || true)
# 3. Lancer les assertions
assert_xxx "label" "pattern" "$out"
# 4. Restaurer l'état pour les tests suivants
echo "contenu original" > data/fichier.txt
echo ""
```

Le `|| true` après la commande capturée est critique : sans lui, si la commande retourne un code non nul (ex: `b3sum --check` sur un fichier corrompu), le mode `-e` du script parent interromprait l'exécution avant que l'assertion puisse enregistrer le résultat.

### T11 — Intégrité de la base produite par `compute_with_progress`

C'est le test critique post-intégration ETA. Il vérifie trois choses indépendantes :

1. La base produite par `compute_with_progress` est **bit-à-bit identique** à une base de référence produite par `find | sort | xargs b3sum` — via `diff`. Si un fichier est manquant, dupliqué, ou dans le mauvais ordre, `diff` le détecte.
2. La base ne contient **aucune ligne "ETA"** parasite — le `printf "\r..."` écrit sur le terminal (stderr implicite via `/dev/tty`), pas dans le fichier.
3. La base ne contient **aucun caractère `\r`** — garantit que la progression n'a pas pollué le flux d'écriture.

```bash
assert_exit_zero "base ETA identique à la base de référence" diff base_ref.b3 base_eta.b3
assert_not_contains "aucune ligne ETA dans la base" "ETA" "$(cat base_eta.b3)"
assert_not_contains "aucun caractère de contrôle dans la base" $'\r' "$(cat base_eta.b3)"
```

---

## 6. Vérification des prérequis

```bash
if ! command -v b3sum &> /dev/null; then
  echo -e "${RED}ERREUR${NC} : b3sum non trouvé."
  exit 1
fi

if [ ! -f "$INTEGRITY" ]; then
  echo -e "${RED}ERREUR${NC} : integrity.sh introuvable à : $INTEGRITY"
  exit 1
fi
```

Vérifié avant `setup()` — inutile de créer l'environnement de test si les outils sont absents. `command -v` est la méthode portable pour tester la présence d'un exécutable (préférable à `which`).

---

## 7. Exit code et intégration CI

```bash
[ "$FAIL" -eq 0 ]
```

Dernière ligne du script. Si `FAIL` vaut 0, l'expression est vraie → exit code 0. Si au moins un test a échoué → exit code 1. Ce comportement est exploitable directement dans un pipeline :

```bash
# Hook pre-commit git
./tests/run_tests.sh || exit 1

# Crontab — alerte si régression
0 3 * * * /opt/integrity/tests/run_tests.sh >> /var/log/integrity-tests.log 2>&1
```