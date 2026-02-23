# Contribuer & Tests

---

## Environnement de développement

### Prérequis

```bash
# Debian / Ubuntu
sudo apt install bash b3sum jq shellcheck

# macOS
brew install bash b3sum jq shellcheck
```

`shellcheck` est optionnel mais recommandé — le test T00 le lance sur tous les scripts.

### Structure des tests

```
tests/
├── run_tests.sh            ← integrity.sh — 15 cas T00–T14
└── run_tests_pipeline.sh   ← runner.sh + pipeline.json — 13 cas TP01–TP12
```

Chaque suite est indépendante, s'isole via `mktemp`, et retourne un exit code CI-compatible.

---

## Lancer les tests

```bash
# Tests integrity.sh
cd tests && ./run_tests.sh

# Tests runner.sh + pipeline.json
cd tests && ./run_tests_pipeline.sh

# Les deux
cd tests && ./run_tests.sh && ./run_tests_pipeline.sh
```

Sortie attendue (tous passants) :

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  15/15 tests passés
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Couverture — run_tests.sh (T00–T14)

| Cas | Description |
|---|---|
| T00 | ShellCheck sur `integrity.sh` et `run_tests.sh` |
| T01 | Compute de base — format et comptage lignes |
| T02 | Verify sans modification — OK, `failed.txt` absent |
| T03 | Verify après corruption — ECHEC, `failed.txt` présent |
| T04 | Verify après suppression de fichier |
| T05 | Compare sans différence — fichiers de résultats produits, tous vides |
| T06 | Compare avec fichier modifié — `modifies.b3` et `report.html` |
| T07 | Compare avec suppression + ajout — `disparus.txt` et `nouveaux.txt` |
| T08 | Robustesse — fichier avec espace dans le nom |
| T09 | Limite — dossier vide ignoré par `find -type f` |
| T10 | Chemin absolu vs relatif — bases non interchangeables |
| T11 | Intégrité base ETA — bit-à-bit identique à `xargs b3sum`, sans artefact `\r` |
| T12 | Mode `--quiet` — stdout vide, fichiers produits, exit code propagé |
| T13 | Horodatage anti-écrasement — deux dossiers distincts sur deux appels successifs |
| T14 | Argument invalide pour `verify` — message ERREUR explicite |

## Couverture — run_tests_pipeline.sh (TP01–TP12)

| Cas | Description |
|---|---|
| TP01 | JSON invalide — message ERREUR sans stacktrace `jq` |
| TP02 | Clé `.pipeline` absente |
| TP03 | Champ `nom` manquant dans un bloc `compute` |
| TP04 | Opération inconnue |
| TP05 | Compute — `cd` correct, chemins relatifs dans la base, comptage fichiers |
| TP06 | Compute — dossier `source` absent |
| TP07 | Verify — bon répertoire de travail, vérification OK, `recap.txt` produit |
| TP08 | Verify — corruption détectée |
| TP09 | Verify — base `.b3` absente |
| TP10 | Compare — cinq fichiers de résultats produits |
| TP10b | Compare — champ `resultats` personnalisé, `RESULTATS_DIR` global non pollué |
| TP11 | Compare — `base_a` absente |
| TP12 | Pipeline complet : `compute × 2` + `verify` + `compare` |

---

## Écrire un nouveau test

### Anatomie d'un cas dans run_tests.sh

```bash
echo "T15 — Description du cas"
# Setup spécifique au cas
local out
out=$(bash "$INTEGRITY" <commande> 2>&1 || true)   # || true : ne pas arrêter sur exit non-nul
assert_contains     "label"          "pattern"   "$out"
assert_not_contains "label négatif"  "absent"    "$out"
assert_file_exists  "fichier créé"   "$OUTDIR/fichier.txt"
echo ""
```

### Règles

- Toujours capturer la sortie avec `local out; out=$(... 2>&1 || true)` avant d'inspecter
- `|| true` est obligatoire pour les commandes qui peuvent retourner un exit code non-nul sans que ce soit une erreur de test
- Nettoyer les effets de bord en fin de cas (restaurer les fichiers modifiés, supprimer les fichiers créés)
- Utiliser `WORKDIR` pour tous les chemins — jamais de chemins absolus en dur

### Helpers disponibles

```bash
pass "label"                           # incrémente PASS, affiche vert
fail "label"                           # incrémente FAIL, affiche rouge

assert_exit_zero    "label" cmd args   # vérifie exit code 0
assert_exit_nonzero "label" cmd args   # vérifie exit code non-nul
assert_contains     "label" "pattern" "$output"
assert_not_contains "label" "pattern" "$output"
assert_line_count   "label" N  "$file"
assert_file_exists  "label" "$file"
assert_file_absent  "label" "$file"
```

---

## Conventions de code

### Bash

- `set -euo pipefail` en tête de chaque script
- `(( BASH_VERSINFO[0] >= 4 ))` vérifié à l'entrée
- Guillemets doubles systématiques sur toutes les variables (`"$var"`, `"$@"`)
- `local` pour toutes les variables de fonctions
- `die()` comme unique point de sortie sur erreur — message sur stderr
- `say()` comme unique point de sortie terminal — désactivé en mode `--quiet`

### Nommage

- Fonctions : `snake_case`
- Variables locales : `snake_case`
- Constantes globales : `UPPER_SNAKE_CASE`
- Fichiers : `kebab-case.sh` ou `snake_case.sh` (existant)

### ShellCheck

Zéro warning ShellCheck requis. Lancer avant tout commit :

```bash
shellcheck src/integrity.sh runner.sh src/lib/report.sh docker/entrypoint.sh
```

---

## Ajouter un nouveau mode à integrity.sh

1. Ajouter le cas dans le `case "$MODE" in` de `src/integrity.sh`
2. Écrire la fonction `run_<mode>()` dans `src/integrity.sh`
3. Mettre à jour le `case "$CMD" in` de `docker/entrypoint.sh`
4. Ajouter les blocs dans `runner.sh` si le mode est orchestrable
5. Écrire les tests dans `run_tests.sh` et/ou `run_tests_pipeline.sh`
6. Mettre à jour la documentation : `docs/reference/integrity-sh.md`, `README.md`

## Ajouter un module à src/lib/

1. Créer `src/lib/<module>.sh` avec `#!/usr/bin/env bash` et un commentaire d'en-tête
2. Le sourcer dans `src/integrity.sh` :
   ```bash
   source "$SCRIPT_DIR/lib/<module>.sh"
   ```
3. L'ajouter dans le `Dockerfile` :
   ```dockerfile
   COPY src/lib/<module>.sh  ./src/lib/<module>.sh
   RUN chmod +x src/lib/<module>.sh
   ```

---

## Processus de release

1. Mettre à jour `CHANGELOG.md` avec la nouvelle version et les changements
2. Vérifier que tous les tests passent
3. Vérifier ShellCheck sur tous les scripts
4. Tagger le commit : `git tag v0.14`
5. Rebuilder l'image Docker : `docker build -t hash_tool:v0.14 -t hash_tool:latest .`
