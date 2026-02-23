# Changelog

Toutes les modifications notables de hash_tool sont documentées ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

---

## [0.13] — Débug dockerisation et documentation

### Ajouté
- `hash_tool-positionnement-open-source.docx` : positionnement du projet dans l'environnement open source, preuve de valeur.
- `hash_tool-presentation.docx` : présentation macro du projet.

### Modifié
- `Dockerfile` : suppression du multi-stage et du téléchargement GitHub. `b3sum` installé depuis les packages Alpine community — plus propre, pas de `wget`, pas de problème de nom de binaire. La version Alpine 3.19 est stable et maintenue.

---

## [0.12] — Dockerisation

### Ajouté
- `Dockerfile` : image Alpine 3.19 avec `b3sum`, `jq`, `bash`, `coreutils`, `findutils`. Image finale ~14 Mo.
- `docker/entrypoint.sh` : dispatcher des commandes (`compute`, `verify`, `compare`, `runner`, `shell`, `help`, `version`). Support `--quiet` en premier argument.
- `docker-compose.yml` : services `integrity`, `pipeline`, `cron` (profil optionnel).
- `.dockerignore` : exclusion des données, résultats, tests et docs du contexte de build.
- `docs/docker.md` : guide complet (build, volumes, NAS Synology, cron Debian, ARM64, Compose).

### Volumes conventionnels

| Volume conteneur | Usage |
|---|---|
| `/data` | Données à hacher (`:ro` recommandé) |
| `/bases` | Fichiers `.b3` |
| `/pipelines` | Fichiers `pipeline.json` |
| `/resultats` | Résultats compare/verify |

---

## [0.11] — Restructuration + rapport HTML compare

### Restructuration

```
hash_tool/
├── runner.sh
├── src/
│   ├── integrity.sh
│   └── lib/
│       └── report.sh          ← nouveau, extrait de integrity.sh
├── pipelines/
│   ├── pipeline.json
│   └── pipeline-full.json
└── reports/
    └── template.html
```

### Ajouté
- `src/lib/report.sh` : génération HTML autonome (CSS inline). Thème sombre, police monospace, compteurs, badge statut.
- `reports/template.html` : barebone de référence documentant les placeholders.
- Champ optionnel `"resultats"` sur les blocs `compare` du pipeline.
- Test TP10b : champ `resultats` personnalisé et isolation de `RESULTATS_DIR`.

### Modifié
- `runner.sh` : chemin `INTEGRITY` et `CONFIG` mis à jour. Isolation des `cd` en sous-shells. Lecture du champ `resultats` optionnel.
- `src/integrity.sh` : délègue la génération HTML à `lib/report.sh`.

---

## [0.10] — Pipeline JSON + tests pipeline

### Modifié
- `pipeline.json` : migration de la syntaxe custom vers JSON standard. Champ `op` remplace les noms de blocs. Parsé par `jq`.
- `runner.sh` : suppression du parser bash custom. Remplacement par `jq`. Validation JSON en entrée. Messages d'erreur avec numéro de bloc.

### Ajouté
- `tests/run_tests_pipeline.sh` : 12 cas TP01–TP12.

---

## [0.9] — Pipeline batch : runner.sh + config.txt

### Ajouté
- `runner.sh` : exécuteur de pipeline batch. Gestion automatique du `cd` avant `compute` et `verify`.
- `config.txt` : format structuré `pipeline = { ... }` (remplacé par JSON en 0.10).
- `runner.bat` : lanceur Windows pour double-clic.

---

## [0.8] — batch_compute.sh

### Ajouté
- `batch_compute.sh` : lancer plusieurs `compute` en un script. Remplacé par `runner.sh` en 0.9.

---

## [0.7] — Robustesse compare : chemins avec espaces

### Corrigé
- `run_compare()` : bug critique — `sort -k2,2`, `join`, `awk` fragmentaient les chemins avec espaces. Correction par conversion préalable en `chemin\thash` via `awk` avec offset fixe (hash = 64 chars). Séparateur `$'\t'` explicite sur toutes les opérations.

---

## [0.6] — Robustesse et mode silencieux

### Ajouté
- Flag `--quiet` : supprime toute sortie terminal, exit code propagé.
- `say()` : point d'entrée unique pour la sortie terminal.
- `file_size()` : abstraction portable `stat -c%s` / `stat -f%z`.
- Vérification `bash >= 4` en tête de script.
- `make_result_dir()` : horodatage automatique en cas de collision.
- `trap EXIT` dans `run_compare()` : nettoyage garanti des fichiers temporaires.
- T12 : couverture `--quiet`. T13 : horodatage. T14 : argument invalide.

### Corrigé
- `grep -c '.'` → `grep -c '^'` pour le comptage de lignes sur flux vide.
- `sort -k2` → `sort -k2,2` pour limiter la clé de tri au seul champ chemin.
- `find | wc -l` → `find -print0 | grep -zc ''` pour les noms avec newlines.
- `stat -c%s` → `file_size()` pour la portabilité BSD/macOS.

---

## [0.5] — Documentation

### Modifié
- `README.md` et `docs/manuel.md` : règle répertoire de travail pour `verify` précisée avec exemples correct/incorrect.

---

## [0.4] — Gardes-fous et signalisation des erreurs

### Modifié
- Ajout `die()`, `assert_b3_valid()`, `assert_target_valid()`.
- `verify` accepte `[dossier]` optionnel.
- Résolution chemin absolu du `.b3` avant `cd`.
- `RESULTATS_DIR` : `${RESULTATS_DIR:-...}` au lieu d'assignation inconditionnelle.
- `run_verify()` : trois états (`OK`, `ECHEC`, `ERREUR`), `failed.txt` supprimé si zéro échec.

---

## [0.3] — Dossiers de résultats

### Modifié
- Ajout `RESULTATS_DIR` et `make_result_dir()`.
- `verify` produit `recap.txt` et `failed.txt`.
- `compare` produit `recap.txt`, `modifies.b3`, `disparus.txt`, `nouveaux.txt`.
- Fichiers temporaires `compare` via `mktemp`.

---

## [0.2] — Intégration ETA et tests automatisés

### Modifié
- Mode `compute` : délègue à `compute_with_progress()`.
- `mapfile -d ''` remplace `FILES=($(find ...))` — gestion correcte des espaces.
- Progression sur `/dev/tty` — jamais dans le `.b3`.
- T11 : base ETA bit-à-bit identique à la référence.

---

## [0.1] — Structure initiale

### Ajouté
- `integrity.sh` : trois modes `compute`, `verify`, `compare`. `set -euo pipefail`.
- `README.md`, `docs/manuel.md`, `docs/progression-eta.md`.
- `tests/run_tests.sh` : 11 cas T01–T11.
- `tests/validation.md` : protocole de test manuel.
