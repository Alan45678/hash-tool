# Explication du code — run_tests.sh + run_tests_pipeline.sh

---

## Vue d'ensemble

Deux suites de tests indépendantes, bash pur, sans framework externe.

```
tests/
├── run_tests.sh            ← integrity.sh — 15 cas T00–T14
└── run_tests_pipeline.sh   ← runner.sh + pipeline.json — 12 cas TP01–TP12
```

Chaque suite : prérequis → setup → tests → teardown → rapport + exit code CI.

---

## PARTIE 1 — run_tests.sh (integrity.sh)

### 1.1 Configuration et chemins

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRITY="$SCRIPT_DIR/../integrity.sh"
WORKDIR="$(mktemp -d /tmp/integrity-test.XXXXXX)"
```

- `SCRIPT_DIR` : répertoire absolu du script, indépendant du `pwd` appelant.
- `INTEGRITY` : chemin relatif à `run_tests.sh` — déplaçables ensemble sans modifier les chemins.
- `WORKDIR` : répertoire temporaire isolé par `mktemp`, suffix aléatoire 6 chars.

### 1.2 Système de comptage

```bash
PASS=0; FAIL=0; TOTAL=0
pass() { echo -e "${GREEN}  PASS${NC} — $1"; (( PASS++ )); (( TOTAL++ )); }
fail() { echo -e "${RED}  FAIL${NC} — $1"; (( FAIL++ )); (( TOTAL++ )); }
```

`TOTAL` permet de détecter un test sauté silencieusement.

### 1.3 Fonctions d'assertion

**`assert_exit_zero` / `assert_exit_nonzero`** : exécute une commande, vérifie le code de retour. `> /dev/null 2>&1` supprime toute sortie. `shift` consomme le label pour que `"$@"` ne contienne que la commande.

**`assert_contains` / `assert_not_contains`** : cherche un pattern dans une chaîne capturée. La capture via `local out=$(commande)` avant l'assertion permet plusieurs inspections sans relancer la commande.

**`assert_line_count`** : `wc -l < fichier` (sans le nom) — pas d'affichage du nom par `wc`.

**`assert_file_exists` / `assert_file_absent`** : présence ou absence d'un fichier régulier.

### 1.4 Setup / Teardown

4 fichiers déterministes (contenu connu → hashes reproductibles). `sub/delta.txt` valide la récursivité de `find`. `teardown()` supprime `WORKDIR` entier.

### 1.5 Pattern || true

```bash
local out
out=$(commande 2>&1 || true)
```

Critique : sans `|| true`, un code de retour non nul sous `-euo pipefail` interrompt le script avant que l'assertion enregistre l'échec.

### 1.6 Cas de test spécifiques

**T00 — ShellCheck** : analyse statique sur `integrity.sh` et `run_tests.sh`. `SKIP` propre si non installé.

**T11 — Intégrité base avec ETA** : vérifie que `compute_with_progress` produit une base bit-à-bit identique à `find | sort | xargs b3sum`, sans artefact `ETA` ni `\r`.

**T12 — Mode `--quiet`** : stdout vide sur verify OK, verify ECHEC, et compute. Exit code non nul propagé. Fichiers de résultats produits malgré `--quiet`.

**T13 — Horodatage** : deux `verify` successifs sur la même base → deux dossiers distincts (pas d'écrasement). `sleep 1` garantit des timestamps différents.

**T14 — Argument invalide** : `verify base.b3 /chemin/inexistant` → `ERREUR` explicite.

### 1.7 Tableau des cas

| Cas | Description |
|---|---|
| T00 | ShellCheck (analyse statique) |
| T01 | Compute de base |
| T02 | Verify sans modification |
| T03 | Verify après corruption |
| T04 | Verify après suppression |
| T05 | Compare sans différence |
| T06 | Compare avec fichier modifié |
| T07 | Compare avec fichier supprimé + ajouté |
| T08 | Noms de fichiers avec espaces |
| T09 | Dossiers vides ignorés |
| T10 | Chemins absolus vs relatifs |
| T11 | Intégrité base avec ETA |
| T12 | Mode `--quiet` |
| T13 | Horodatage anti-écrasement |
| T14 | Argument invalide pour verify |

---

## PARTIE 2 — run_tests_pipeline.sh (runner.sh + pipeline.json)

### 2.1 Configuration et chemins

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/../runner.sh"
INTEGRITY="$SCRIPT_DIR/../integrity.sh"
WORKDIR="$(mktemp -d /tmp/integrity-pipeline-test.XXXXXX)"
export RESULTATS_DIR="$WORKDIR/resultats"
```

`RESULTATS_DIR` est exporté pour que `integrity.sh` (appelé par `runner.sh`) redirige ses résultats dans le `WORKDIR` isolé — pas dans `~/integrity_resultats`.

### 2.2 Helper write_config

```bash
write_config() {
    local path="$WORKDIR/pipeline.json"
    cat > "$path"
    echo "$path"
}
```

Lit le JSON depuis stdin (heredoc), l'écrit dans `WORKDIR/pipeline.json`, retourne le chemin. Permet de générer un `pipeline.json` différent par test sans fichiers temporaires nommés à la main.

Usage :

```bash
local cfg
cfg=$(write_config <<EOF
{ "pipeline": [ { "op": "compute", ... } ] }
EOF
)
bash "$RUNNER" "$cfg"
```

### 2.3 Stratégie de test par cas

**TP01–TP04 (parsing)** : tests négatifs — chaque test passe un JSON ou une config invalide et vérifie que `runner.sh` échoue avec un message `ERREUR` explicite, sans stacktrace `jq` brute ni crash silencieux.

**TP05–TP06 (compute)** : TP05 vérifie trois invariants sur la base produite — existence, chemins relatifs (`./ `en début de chemin), comptage exact de fichiers. TP06 vérifie l'échec propre sur source absente.

**TP07–TP09 (verify)** : TP07 vérifie le bon répertoire de travail (vérification OK, `recap.txt` produit). TP08 vérifie la détection de corruption. TP09 vérifie l'échec propre sur base absente.

**TP10–TP11 (compare)** : TP10 vérifie les quatre fichiers de résultats produits. TP11 vérifie l'échec propre sur `base_a` absente.

**TP12 (pipeline complet)** : test d'intégration — compute × 2 + verify + compare dans un seul `pipeline.json`. Vérifie les labels dans la sortie, les bases créées, et l'absence d'erreur.

### 2.4 Résolution des dossiers de résultats

```bash
outdir_tp07=$(ls -d "${RESULTATS_DIR}/resultats_hashes_a"* 2>/dev/null | tail -1)
```

`tail -1` récupère le dossier le plus récent — compatible avec l'horodatage automatique de `make_result_dir()`. Sans `tail -1`, si un dossier `resultats_hashes_a` existe déjà d'un test précédent, `ls` retourne plusieurs lignes et l'assertion porte sur la mauvaise.

### 2.5 Prérequis et exécution

```bash
cd tests
./run_tests_pipeline.sh
```

Prérequis : `jq`, `b3sum`, `bash >= 4`, `runner.sh` et `integrity.sh` dans le répertoire parent. Exit code CI-compatible : 0 si tous passent, 1 si au moins un échec.

### 2.6 Tableau des cas

| Cas | Description |
|---|---|
| TP01 | JSON invalide — erreur propre sans stacktrace jq |
| TP02 | Clé `.pipeline` absente |
| TP03 | Champ `nom` manquant dans compute |
| TP04 | Opération inconnue |
| TP05 | Compute — cd correct, chemins relatifs, comptage |
| TP06 | Compute — dossier source absent |
| TP07 | Verify — bon répertoire de travail, OK |
| TP08 | Verify — corruption détectée |
| TP09 | Verify — base .b3 absente |
| TP10 | Compare — fichiers de résultats produits |
| TP11 | Compare — base_a absente |
| TP12 | Pipeline complet compute + verify + compare |

---

## Prérequis globaux

```bash
# run_tests.sh
apt install b3sum shellcheck   # shellcheck optionnel

# run_tests_pipeline.sh
apt install b3sum jq
```

Les deux suites sont indépendantes et peuvent être lancées séparément.