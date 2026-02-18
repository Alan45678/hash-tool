# Explication du code — run_tests.sh

---

## Vue d'ensemble

`run_tests.sh` est une suite de tests automatisée pour `integrity.sh`. Elle n'utilise aucun framework externe — uniquement du bash pur. Elle crée un environnement isolé, exécute 14 cas de test (T00–T14), restaure l'état entre chaque cas, puis nettoie.

```
run_tests.sh
├── Vérification des prérequis   (b3sum, integrity.sh)
├── setup()                      création de l'environnement de test
├── run_tests()                  exécution des 14 cas T00–T14
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

### `assert_file_exists` / `assert_file_absent`

```bash
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
```

Vérifient la présence ou l'absence d'un fichier. `assert_file_absent` est utilisé pour confirmer qu'un fichier comme `failed.txt` n'est pas créé inutilement après une vérification réussie.

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

`teardown()` supprime le `WORKDIR` entier. Appelé en fin de script, même en cas d'échec partiel (voir section 7).

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

Le `|| true` après la commande capturée est critique : sans lui, si la commande retourne un code non nul (ex: `b3sum --check` sur un fichier corrompu), le mode `-euo pipefail` du script parent interromprait l'exécution avant que l'assertion puisse enregistrer le résultat.

---

## 6. Cas de test spécifiques

### T00 — ShellCheck (analyse statique)

Premier test exécuté. Invoque ShellCheck sur `integrity.sh` et `run_tests.sh` pour détecter les bugs bash courants (variables non quotées, globbing non contrôlé, problèmes de portabilité).

Si ShellCheck n'est pas installé, le test affiche `SKIP` sans bloquer l'exécution — c'est une vérification additionnelle, pas une dépendance stricte.

```bash
if command -v shellcheck &> /dev/null; then
  assert_exit_zero "ShellCheck integrity.sh" shellcheck "$INTEGRITY"
  assert_exit_zero "ShellCheck run_tests.sh" shellcheck "$0"
else
  echo "  SKIP — shellcheck non installé"
fi
```

### T11 — Intégrité de la base produite par `compute_with_progress`

Test critique post-intégration ETA. Vérifie trois choses indépendantes :

1. La base produite par `compute_with_progress` est **bit-à-bit identique** à une base de référence produite par `find | sort | xargs b3sum` — via `diff`. Si un fichier est manquant, dupliqué, ou dans le mauvais ordre, `diff` le détecte.
2. La base ne contient **aucune ligne "ETA"** parasite — le `printf "\r..."` écrit sur le terminal (stderr implicite via `/dev/tty`), pas dans le fichier.
3. La base ne contient **aucun caractère `\r`** — garantit que la progression n'a pas pollué le flux d'écriture.

```bash
assert_exit_zero    "base ETA identique à la base de référence" diff base_ref.b3 base_eta.b3
assert_not_contains "aucune ligne ETA dans la base"             "ETA"  "$(cat base_eta.b3)"
assert_not_contains "aucun caractère de contrôle dans la base"  $'\r'  "$(cat base_eta.b3)"
```

### T12 — Mode `--quiet`

Couverture exhaustive du flag `--quiet` :

- **Verify OK en mode `--quiet`** : stdout vide, fichiers de résultats produits (`recap.txt`).
- **Verify ECHEC en mode `--quiet`** : stdout vide, `failed.txt` créé, exit code non nul propagé.
- **Compute en mode `--quiet`** : pas de ligne "Base enregistrée", pas d'ETA dans la sortie.

La résolution des dossiers de résultats (`outdir`) utilise `ls -d ... | tail -1` pour récupérer le dernier dossier créé, compatible avec l'horodatage automatique introduit dans cette version.

### T13 — Horodatage des dossiers de résultats

Vérifie qu'exécuter deux fois `verify` sur la même base `.b3` ne produit pas un écrasement silencieux des résultats. Deux dossiers distincts doivent être créés :

- `resultats_base_t13/`
- `resultats_base_t13_YYYYMMDD-HHMMSS/`

Un `sleep 1` entre les deux appels garantit un timestamp différent.

### T14 — Détection d'argument invalide pour `verify [dossier]`

Confirme que `verify` détecte et rejette un argument `[dossier]` invalide (chemin inexistant ou non-dossier) avec un message d'erreur explicite.

---

## 7. Vérification des prérequis

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

## 8. Exit code et intégration CI

```bash
[ "$FAIL" -eq 0 ]
```

Dernière ligne du script. Si `FAIL` vaut 0, l'expression est vraie → exit code 0. Si au moins un test a échoué → exit code 1. Ce comportement est exploitable directement dans un pipeline :

```bash
# Hook pre-commit git
./tests/run_tests.sh || exit 1

# CI/CD pipeline
./tests/run_tests.sh && deploy_artifacts

# Crontab — alerte si régression
0 3 * * * /opt/integrity/tests/run_tests.sh >> /var/log/integrity-tests.log 2>&1 || mail -s "Tests failed" admin@example.com
```

---

## 9. Couverture de test

Les 14 cas couvrent :

| Cas | Périmètre |
|---|---|
| T00 | Analyse statique ShellCheck |
| T01 | Compute de base, format de sortie |
| T02 | Verify sans modification, absence de `failed.txt` |
| T03 | Verify après corruption, présence de `failed.txt` |
| T04 | Verify après suppression de fichier |
| T05 | Compare sans différence |
| T06 | Compare avec fichier modifié |
| T07 | Compare avec fichier supprimé + ajouté |
| T08 | Noms de fichiers avec espaces |
| T09 | Dossiers vides ignorés (limite documentée) |
| T10 | Chemins absolus vs relatifs |
| T11 | Intégrité de la base avec ETA |
| T12 | Mode `--quiet` (stdout vide, exit code) |
| T13 | Horodatage anti-écrasement |
| T14 | Détection argument invalide |

**Aucun mocking.** Tous les tests exécutent réellement `b3sum` et `integrity.sh` sur des fichiers réels dans un environnement isolé.