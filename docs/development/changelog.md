# Changelog — hash_tool




### [1.1.0] — 2026-02-26

#### Corrigé

-Isolation des chemins relatifs** : Correction d'un bug où l'entrée dans un sous-shell via `cd "$OPT_DATA"` empêchait l'écriture de la base dans le dossier `-save` si celui-ci était renseigné en chemin relatif.

-Résolution absolue des cibles** : Le script transforme désormais systématiquement le chemin `-save` en chemin absolu avant de changer de répertoire de travail. Cela garantit que la base `.b3` est enregistrée exactement là où l'utilisateur l'a demandé, même après un `cd` dans le dossier source.

-Robustesse aux espaces** : Ajout de guillemets doubles manquants dans les fonctions `_run_integrity` et `_sidecar_write` pour supporter les chemins Windows/WSL complexes comportant des espaces et des caractères spéciaux.

#### Ajouté

-Contrôle de conformité** : La commande `verify` émet désormais un avertissement si elle détecte des chemins absolus dans un fichier `.b3`, car cela brise l'invariant de portabilité du logiciel.

-Mode Read-only explicite** : Support de l'option `-readonly` lors du `compute` pour marquer l'état de la source dans le fichier de métadonnées sidecar.

#### Modifié

-Priorité des résultats** : L'option `-save` surcharge désormais systématiquement la variable d'environnement `RESULTATS_DIR` pour toutes les commandes (`compute`, `verify`, `compare`, `runner`).


## [1.0] — CLI unique, nouvelles commandes, sidecar, pipeline étendu

### Ajouté

**`hash-tool` — CLI unique (nouveau fichier à la racine)**

- Interface CLI unifiée. L'utilisateur invoque toujours `hash-tool <commande>`, indépendamment du mode d'exécution réel.
- Détection automatique du mode d'exécution : natif (`b3sum` + `jq` disponibles) ou Docker (`hash_tool` image disponible). Aucune intervention utilisateur requise.
- Parser d'arguments uniforme : `-data`, `-base`, `-old`, `-new`, `-pipeline`, `-save`, `-meta`, `-quiet`, `-verbose`, `-readonly`.
- Nouvelles commandes : `list`, `diff`, `stats`, `check-env`, `version`, `help` (global + par sous-commande).
- Variable d'environnement `HASH_TOOL_DOCKER_IMAGE` pour spécifier l'image Docker à utiliser (défaut : `hash_tool`).

**Sidecar file (`.meta.json`)**

- `compute` génère automatiquement `<base.b3>.meta.json` à côté du fichier `.b3`.
- Champs : `created_by`, `date` (ISO 8601 UTC), `comment` (depuis `-meta`), `parameters` (répertoire, algorithme, nb_fichiers, readonly).
- `verify`, `compare`, `stats` affichent le sidecar si présent.
- Le runner (format étendu) génère également le sidecar via `meta.comment` dans le pipeline JSON.

**Commande `list`**

- `hash-tool list -data <dossier>` : parcourt le dossier sur 2 niveaux, liste toutes les bases `.b3` avec leur nombre de fichiers, taille, et commentaire sidecar si présent.
- Indicateur `[+meta]` si un sidecar est associé.

**Commande `diff`**

- `hash-tool diff -base <fichier.b3> [-data <dossier>]` : compare les chemins de la base avec l'état actuel du dossier.
- Ne recalcule pas les hashes — uniquement comparaison des chemins.
- Affiche les fichiers disparus et les nouveaux fichiers non indexés.

**Commande `stats`**

- `hash-tool stats -base <fichier.b3>` : affiche le chemin absolu, la taille du fichier `.b3`, le nombre de fichiers indexés, la distribution des extensions (top 10), et le sidecar si présent.

**Commande `check-env`**

- `hash-tool check-env` : vérifie la disponibilité de `b3sum`, `jq`, `bash >= 4`, `integrity.sh`, `runner.sh`, Docker et l'image Docker.
- Indique le mode d'exécution sélectionné : `native`, `docker`, ou `none`.

**Commande `version`**

- `hash-tool version` : affiche la version `hash-tool` et la version `b3sum`.

**Commande `help`**

- `hash-tool help` : aide globale avec toutes les commandes et options.
- `hash-tool help <commande>` : aide détaillée par sous-commande.

**`runner.sh` — format pipeline étendu**

- Nouveau format `type / params / options / meta / description` — rétrocompatible avec le format legacy `op / source / bases / nom`.
- Détection automatique du format par la présence de `"op"` (legacy) ou `"type"` (étendu).
- Support des nouvelles opérations dans le pipeline : `list`, `diff`, `stats`, `check-env`, `version`.
- Génération du sidecar dans les blocs `compute` (format étendu) si `meta.comment` est fourni.
- Champ `options` par bloc : `quiet`, `verbose`, `readonly`.
- Champ `description` : documentation lisible directement dans le JSON.

**`pipelines/pipeline-amelioree.json`**

- Nouveau fichier pipeline de référence au format étendu, couvrant toutes les commandes disponibles.

### Modifié

- `runner.sh` : ajout de la fonction `dispatch_bloc()` qui détecte le format (legacy/étendu) et route vers la bonne implémentation. Fonctions `run_*_legacy()` et `run_*_extended()` séparées pour chaque opération.

### Non modifié

- `src/integrity.sh` : inchangé — les nouvelles commandes sont intégralement gérées dans `hash-tool`.
- `src/lib/core.sh`, `src/lib/ui.sh`, `src/lib/results.sh`, `src/lib/report.sh` : inchangés.
- Tous les pipelines existants (format legacy) : rétrocompatibles sans modification.

### Installation

```bash
chmod +x hash-tool runner.sh src/integrity.sh
# Optionnel : accès global
sudo ln -s "$(pwd)/hash-tool" /usr/local/bin/hash-tool
```

---

## [0.18] — debug

### Ajouté

- Dans `brouillon_non_prod` : documents `.md` décrivant les prochains travaux (architecture de test, CLI améliorée).

---

## [0.17] — debug

### Ajouté

- Ajout de `brouillon_non_prod` au git : documents de travail non inclus dans le délivrable mais conservés dans le dépôt pour référence.

---

## [0.16] — debug

### Ajouté

- Dossier `troubleshooting/` et fichier `troubleshooting_1.md` : premier cas documenté (Permission non accordée sur `integrity.sh` — solution : `chmod +x`).

---

## [0.15] — Documentation restructurée

- Mise à jour de la documentation.

---

## [0.14] — Documentation complète MkDocs

### Ajouté

- `docs/` : documentation complète au format MkDocs Material.
  - `index.md` : vue d'ensemble, structure du projet.
  - `getting-started.md` : installation, prérequis, premier usage.
  - `reference/integrity-sh.md` : référence exhaustive.
  - `reference/runner-sh.md` : format pipeline.json, comportements, messages d'erreur.
  - `reference/docker.md` : build, volumes, Compose, cron, Synology, ARM64.
  - `guides/veracrypt.md` : workflow multi-disques, lanceur Windows `.bat`.
  - `guides/cron-ci.md` : cron Linux, GitHub Actions, GitLab CI, hooks Git.
  - `guides/nas-synology.md` : DSM 7, Container Manager.
  - `development/architecture.md` : décisions techniques documentées.
  - `development/contributing.md` : couverture tests, conventions, processus de release.
  - `development/changelog.md` : historique.
- `mkdocs.yml` : configuration MkDocs Material, navigation, thème sombre/clair.

### Supprimé

- `docs/*.docx`, `docs/*.pdf` : binaires non diffables retirés du repo.

### Modifié

- `pipelines/pipeline full.json` → `pipelines/pipeline-full.json` : suppression de l'espace.

---

## [0.13] — Débug dockerisation et documentation

### Ajouté

- `hash_tool-positionnement-open-source.docx` : positionnement dans l'écosystème open source.
- `hash_tool-presentation.docx` : présentation macro du projet.

### Modifié

- `Dockerfile` : `b3sum` installé depuis Alpine community (`apk add b3sum`) au lieu de `wget` GitHub. Plus propre, plus robuste, évite les erreurs de nom de binaire.

---

## [0.12] — Dockerisation

### Ajouté

- `Dockerfile` : image Alpine 3.19 avec `bash`, `jq`, `b3sum`, `coreutils`, `findutils`. Image ~14 Mo.
- `docker/entrypoint.sh` : dispatcher des commandes (`compute`, `verify`, `compare`, `runner`, `shell`, `help`, `version`). `--quiet` supporté en premier argument.
- `docker-compose.yml` : trois services — `integrity`, `pipeline`, `cron` (profil optionnel).
- `.dockerignore` : exclut données, résultats, tests, docs du contexte de build.

### Volumes conventionnels

| Volume | Usage |
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
├── runner.sh                  ← inchangé
├── src/
│   ├── integrity.sh           ← déplacé depuis la racine
│   └── lib/
│       └── report.sh          ← nouveau, extrait de integrity.sh
├── pipelines/
│   ├── pipeline.json          ← déplacé depuis la racine
│   └── pipeline-full.json     ← renommé
└── reports/
    └── template.html          ← nouveau
```

### Ajouté

- `src/lib/report.sh` : `generate_compare_html()` — rapport HTML autonome (CSS inline, thème sombre, compteurs, badge statut).
- `reports/template.html` : template de référence.
- `pipeline.json` : champ optionnel `"resultats"` sur les blocs `compare`.
- `tests/run_tests_pipeline.sh` : cas **TP10b** — champ `resultats` personnalisé et isolation `RESULTATS_DIR`.

### Modifié

- `runner.sh` : isolation des `cd` dans des sous-shells `( )`. Champ `resultats` pour les blocs `compare`.
- `src/integrity.sh` : délègue la génération HTML à `generate_compare_html()`.

---

## [0.10] — Pipeline JSON + tests pipeline

### Modifié

- `pipeline.json` : migration du format custom vers JSON standard. Champ `op` au lieu des noms de blocs.
- `runner.sh` : réécriture du parser avec `jq`. Validation JSON native, messages d'erreur avec numéro de bloc.

### Ajouté

- `tests/run_tests_pipeline.sh` : 12 cas TP01–TP12.

---

## [0.9] — Pipeline batch : runner.sh + config.txt

### Ajouté

- `runner.sh` : exécuteur de pipeline. Lit `config.txt`, gère le `cd` automatique.
- `config.txt` : déclaration du pipeline au format structuré.
- `runner.bat` : lanceur Windows (WSL) avec `pause`.

---

## [0.8] — batch_compute.sh

### Ajouté

- `batch_compute.sh` : plusieurs `compute` en un seul script. Remplacé par `runner.sh` en 0.9.

---

## [0.7] — Séparation en modules (lib/)

### Ajouté

- `src/lib/core.sh` : logique métier pure extraite de `integrity.sh`.
- `src/lib/ui.sh` : logique d'interface (affichage, ETA, progression).
- `src/lib/results.sh` : écriture des fichiers de résultats.

---

## [0.6] — Mode `--quiet`

### Ajouté

- `--quiet` : supprime toute sortie terminal. Exit code propagé sans modification. Résultats écrits dans les fichiers de sortie normaux.

---

## [0.5] — Horodatage anti-écrasement

### Modifié

- `core_make_result_dir()` : suffixe `_YYYYMMDD-HHMMSS` si le dossier de résultats existe déjà.

---

## [0.4] — ETA et progression

### Ajouté

- Affichage de la progression fichier par fichier avec ETA calculée sur la vélocité réelle.
- Écriture sur `/dev/tty` pour isolation des pipes.

---

## [0.3] — Rapport HTML `compare`

### Ajouté

- `report.html` généré après chaque `compare`.

---

## [0.2] — Commande `compare`

### Ajouté

- `integrity.sh compare <ancienne.b3> <nouvelle.b3>` : comparaison de deux snapshots.
- Produit `modifies.b3`, `disparus.txt`, `nouveaux.txt`.

---

## [0.1] — Initial

### Ajouté

- `integrity.sh compute <dossier> <base.b3>` : calcul des empreintes BLAKE3.
- `integrity.sh verify <base.b3>` : vérification d'intégrité via `b3sum --check`.
- Chemins relatifs dans les bases `.b3`.