# Changelog - hash_tool / integrity.sh

## [0.18] - debug 

### Ajoutée 

- dans "brouillon_non_prod" j'ai ajouté des documents .md décrivant les prochains travaux à effectuer pour avoir une architecture de test ainsi qu'une CLI améliorée. 


## [0.17] - debug 

### Ajoutée 

- ajout de "autre" ou "brouillon_non_prod" au git, c'est des documents de travail qui n'a pas à être dans le délivrable mais qui est intéressant de mettre dans le git parce qu'ils sont importants.

## [0.16] - debug 

### Ajoutée 

- dossier "troubleshooting" et le fichier "troubleshooting_1" 
- dossier qu'il faudra compléter avec les bugs courants. 

## [0.15] - Documentation restructurée

maj de la doc 

## [0.14] - Documentation restructurée

### Ajouté
- `docs/` : documentation complète au format MkDocs Material.
  - `index.md` : page d'accueil, vue d'ensemble, structure du projet.
  - `getting-started.md` : installation, prérequis, premier usage pas à pas.
  - `reference/integrity-sh.md` : référence exhaustive - modes, arguments, variables, exit codes, limites.
  - `reference/runner-sh.md` : schéma complet pipeline.json, comportements, messages d'erreur.
  - `reference/docker.md` : build, volumes, Compose, cron, Synology, ARM64.
  - `guides/veracrypt.md` : workflow multi-disques, lanceur Windows `.bat`.
  - `guides/cron-ci.md` : cron Linux, GitHub Actions, GitLab CI, hooks Git, patterns de notification.
  - `guides/nas-synology.md` : DSM 7, Container Manager, planificateur de tâches.
  - `development/architecture.md` : décisions techniques documentées (BLAKE3, chemins relatifs, ETA, CSS inline, etc.).
  - `development/contributing.md` : couverture tests, conventions, processus de release.
  - `development/changelog.md` : historique reformaté Keep a Changelog.
- `mkdocs.yml` : configuration MkDocs Material, navigation, extensions pymdownx, thème sombre/clair.
- `CONTRIBUTING.md` : guide de contribution à la racine du projet.
- README-docker.md : readme juste pour docker. 
- README-docs.md : readme juste pour la documentation. 
- README-tests.md : readme juste pour les tests. 

### Supprimé
- `docs/*.docx`, `docs/*.pdf` : binaires non diffables retirés du repo. Générer depuis le markdown via `pandoc` si nécessaire.
- `temp.txt` : ajouté au `.gitignore`.

### Modifié
- `pipelines/pipeline full.json` → `pipelines/pipeline-full.json` : suppression de l'espace dans le nom de fichier.

## [0.13] - Débug de la dockerisation et documentation 

### Ajouté

- `hash_tool-positionnement-open-source.docx` : positionnement du projet dans l'environnement open source actuel, preuve de valeur du projet.
- `hash_tool-presentation.docx` : présentation macro du projet, sans rentrer dans les details de l'implémentation. 

### Modifié

- Modification du `Dockerfile` pour debug : Installer b3sum depuis Alpine community. b3sum est disponible dans les packages Alpine Linux Alpine Linux, ce qui est plus propre et évite le wget GitHub. Plus de multi-stage, plus de wget, plus de problème de nom. La version fournie par Alpine 3.19 est stable et maintenue. C'est la solution la plus robuste.


## [0.12] - Dockerisation

### Ajouté

- `Dockerfile` : image multi-stage basée sur Alpine 3.19.
  - Stage `fetcher` : télécharge le binaire officiel `b3sum` musl depuis GitHub Releases, le vérifie (auto-vérification via `b3sum --check`). Supporte `amd64`, `arm64`, `armv7`.
  - Stage final : Alpine + `bash` + `jq` + `coreutils` + `findutils` + binaire `b3sum` copié. Image finale ~14 Mo sans toolchain Rust.
  - `ARG B3SUM_VERSION` : version b3sum paramétrable au build.

- `docker/entrypoint.sh` : dispatcher des commandes.
  - `compute`, `verify`, `compare` → délégués à `src/integrity.sh`.
  - `runner [pipeline.json]` → délégué à `runner.sh` (défaut : `/pipelines/pipeline.json`).
  - `shell` / `bash` → shell interactif debug.
  - `help`, `version` → affichage inline.
  - `--quiet` supporté en premier argument.

- `docker-compose.yml` : trois services.
  - `integrity` : commandes ponctuelles (compute/verify/compare).
  - `pipeline` : exécution de `runner.sh` avec `pipeline.json` monté.
  - `cron` : profil optionnel (`--profile cron`) pour vérification périodique.
  - Section `x-volumes` : chemins à adapter en un seul endroit.

- `.dockerignore` : exclut données, résultats, tests, docs du contexte de build.

- `docs/docker.md` : guide complet - build, commandes, volumes, NAS Synology, cron Debian, taille image, mise à jour b3sum.

### Volumes conventionnels

| Volume conteneur | Usage |
|---|---|
| `/data` | Données à hacher (`:ro` recommandé) |
| `/bases` | Fichiers `.b3` |
| `/pipelines` | Fichiers `pipeline.json` |
| `/resultats` | Résultats compare/verify |

`RESULTATS_DIR=/resultats` est défini par défaut dans l'image.

---

 - Restructuration + rapport HTML compare

### Restructuration du projet

```
hash_tool/
├== runner.sh                  ← inchangé (point d'entrée)
├== src/
│   ├== integrity.sh           ← déplacé depuis la racine
│   └== lib/
│       └== report.sh          ← nouveau, extrait de integrity.sh
├== pipelines/
│   ├== pipeline.json          ← déplacé depuis la racine
│   └== pipeline-full.json     ← renommé depuis "pipeline full.json"
└== reports/
    └== template.html          ← nouveau, barebone HTML de référence
```

Motivations :
- `src/` isole le code des fichiers de configuration et de données.
- `src/lib/` prépare l'extension à d'autres modules (ex. `notify.sh`, `export.sh`).
- `pipelines/` centralise les configurations de pipeline, évite la pollution de la racine.
- `reports/` documente la structure HTML attendue, sert de référence pour la personnalisation.

### Modifié

- `runner.sh`
  - Chemin `INTEGRITY` mis à jour : `$SCRIPT_DIR/src/integrity.sh`.
  - Chemin `CONFIG` par défaut mis à jour : `$SCRIPT_DIR/pipelines/pipeline.json`.
  - `run_compare()` : lecture du champ optionnel `resultats` dans le bloc JSON. Si présent, exporte `RESULTATS_DIR` avec cette valeur pour le seul appel à `integrity.sh compare`. Isolation par sous-shell : le `RESULTATS_DIR` global du processus parent n'est pas modifié.
  - `run_compute()` et `run_verify()` : isolation du `cd` dans un sous-shell `( )` - le répertoire courant ne fuite plus vers les blocs suivants du pipeline.

- `src/integrity.sh`
  - Chargement de `src/lib/report.sh` via `source` au démarrage.
  - `run_compare()` : délègue la génération HTML à `generate_compare_html()` (définie dans `lib/report.sh`).

### Ajouté

- `src/lib/report.sh` : bibliothèque de génération de rapports.
  - `generate_compare_html()` : produit `report.html` autonome (CSS inline, sans dépendance externe) à partir des fichiers `modifies.b3`, `disparus.txt`, `nouveaux.txt`. Thème sombre, police monospace, compteurs par catégorie, badge statut IDENTIQUES / DIFFÉRENCES DÉTECTÉES.

- `reports/template.html` : barebone HTML statique de référence. Documente les placeholders injectés par `generate_compare_html()` et la structure attendue du dossier de résultats.

- `pipeline.json` (et `pipeline-full.json`) : champ optionnel `"resultats"` sur les blocs `compare`.

  ```json
  {
      "op":       "compare",
      "base_a":   "/chemin/hashes_1.b3",
      "base_b":   "/chemin/hashes_2.b3",
      "resultats": "/chemin/vers/dossier_resultats"
  }
  ```

  Sans ce champ, comportement inchangé : résultats dans `RESULTATS_DIR` (défaut `~/integrity_resultats`).

- `tests/run_tests_pipeline.sh` : cas TP10b - vérifie que le champ `resultats` redirige bien les résultats dans le dossier personnalisé et n'écrit rien dans `RESULTATS_DIR` par défaut.

### Couverture tests mise à jour

| Suite | Cas | Description |
|---|---|---|
| `run_tests.sh` | T00–T14 | Inchangée - `INTEGRITY` mis à jour vers `../src/integrity.sh` |
| `run_tests_pipeline.sh` | TP01–TP12 | Inchangée dans la logique |
| `run_tests_pipeline.sh` | **TP10b** | Nouveau - champ `resultats` personnalisé et isolation |

---















## [0.11] - Restructuration + rapport HTML compare

### Restructuration du projet

```
hash_tool/
├== runner.sh                  ← inchangé (point d'entrée)
├== src/
│   ├== integrity.sh           ← déplacé depuis la racine
│   └== lib/
│       └== report.sh          ← nouveau, extrait de integrity.sh
├== pipelines/
│   ├== pipeline.json          ← déplacé depuis la racine
│   └== pipeline-full.json     ← renommé depuis "pipeline full.json"
└== reports/
    └== template.html          ← nouveau, barebone HTML de référence
```

Motivations :
- `src/` isole le code des fichiers de configuration et de données.
- `src/lib/` prépare l'extension à d'autres modules (ex. `notify.sh`, `export.sh`).
- `pipelines/` centralise les configurations de pipeline, évite la pollution de la racine.
- `reports/` documente la structure HTML attendue, sert de référence pour la personnalisation.

### Modifié

- `runner.sh`
  - Chemin `INTEGRITY` mis à jour : `$SCRIPT_DIR/src/integrity.sh`.
  - Chemin `CONFIG` par défaut mis à jour : `$SCRIPT_DIR/pipelines/pipeline.json`.
  - `run_compare()` : lecture du champ optionnel `resultats` dans le bloc JSON. Si présent, exporte `RESULTATS_DIR` avec cette valeur pour le seul appel à `integrity.sh compare`. Isolation par sous-shell : le `RESULTATS_DIR` global du processus parent n'est pas modifié.
  - `run_compute()` et `run_verify()` : isolation du `cd` dans un sous-shell `( )` - le répertoire courant ne fuite plus vers les blocs suivants du pipeline.

- `src/integrity.sh`
  - Chargement de `src/lib/report.sh` via `source` au démarrage.
  - `run_compare()` : délègue la génération HTML à `generate_compare_html()` (définie dans `lib/report.sh`).

### Ajouté

- `src/lib/report.sh` : bibliothèque de génération de rapports.
  - `generate_compare_html()` : produit `report.html` autonome (CSS inline, sans dépendance externe) à partir des fichiers `modifies.b3`, `disparus.txt`, `nouveaux.txt`. Thème sombre, police monospace, compteurs par catégorie, badge statut IDENTIQUES / DIFFÉRENCES DÉTECTÉES.

- `reports/template.html` : barebone HTML statique de référence. Documente les placeholders injectés par `generate_compare_html()` et la structure attendue du dossier de résultats.

- `pipeline.json` (et `pipeline-full.json`) : champ optionnel `"resultats"` sur les blocs `compare`.

  ```json
  {
      "op":       "compare",
      "base_a":   "/chemin/hashes_1.b3",
      "base_b":   "/chemin/hashes_2.b3",
      "resultats": "/chemin/vers/dossier_resultats"
  }
  ```

  Sans ce champ, comportement inchangé : résultats dans `RESULTATS_DIR` (défaut `~/integrity_resultats`).

- `tests/run_tests_pipeline.sh` : cas TP10b - vérifie que le champ `resultats` redirige bien les résultats dans le dossier personnalisé et n'écrit rien dans `RESULTATS_DIR` par défaut.

### Couverture tests mise à jour

| Suite | Cas | Description |
|---|---|---|
| `run_tests.sh` | T00–T14 | Inchangée - `INTEGRITY` mis à jour vers `../src/integrity.sh` |
| `run_tests_pipeline.sh` | TP01–TP12 | Inchangée dans la logique |
| `run_tests_pipeline.sh` | **TP10b** | Nouveau - champ `resultats` personnalisé et isolation |

---



## [0.10] - Pipeline JSON + tests pipeline

### Modifié

- `pipeline.json` (ex `config.txt`) : format migré de la syntaxe custom vers JSON standard. Champ `op` remplace les noms de blocs. Parsé par `jq` - validation syntaxique native, interopérable avec tout outil JSON.
- `runner.sh` : réécriture du parser. Suppression du parser bash custom (`IFS`, regex, `local -n`). Remplacement par `jq` pour l'extraction des champs. Validation JSON en entrée (`jq empty`), détection des champs manquants et des opérations inconnues avec messages d'erreur explicites incluant le numéro de bloc.

### Ajouté

- `tests/run_tests_pipeline.sh` : suite de tests dédiée au pipeline. 12 cas TP01–TP12.

### Format pipeline.json

```json
{
    "pipeline": [
        {
            "op":     "compute",
            "source": "/mnt/a/dossier",
            "bases":  "/mnt/c/bases",
            "nom":    "hashes.b3"
        },
        {
            "op":     "verify",
            "source": "/mnt/a/dossier",
            "base":   "/mnt/c/bases/hashes.b3"
        },
        {
            "op":     "compare",
            "base_a": "/mnt/c/bases/hashes_1.b3",
            "base_b": "/mnt/c/bases/hashes_2.b3"
        }
    ]
}
```

### Couverture run_tests_pipeline.sh

| Cas | Description |
|---|---|
| TP01 | JSON invalide - erreur propre sans stacktrace jq |
| TP02 | Clé `.pipeline` absente |
| TP03 | Champ manquant dans un bloc (`nom`) |
| TP04 | Opération inconnue |
| TP05 | Compute - cd correct, chemins relatifs dans la base, comptage fichiers |
| TP06 | Compute - dossier source absent |
| TP07 | Verify - bon répertoire de travail, OK détecté |
| TP08 | Verify - corruption détectée |
| TP09 | Verify - base .b3 absente |
| TP10 | Compare - fichiers de résultats produits |
| TP11 | Compare - base_a absente |
| TP12 | Pipeline complet compute + verify + compare |

---


## [0.9] - Pipeline batch : runner.sh + config.txt

### Ajouté

- `runner.sh` : exécuteur de pipeline batch. Lit `config.txt`, parse les blocs `compute`, `verify`, `compare` et appelle `integrity.sh` avec les arguments corrects. Gère le `cd` automatique avant chaque `compute` et `verify` pour garantir des chemins relatifs dans les bases `.b3`.
- `config.txt` : déclaration du pipeline au format structuré `pipeline = { ... }`. Chaque opération est un bloc nommé avec des champs `clé = "valeur"`. Supporte les commentaires `#` et les lignes vides.
- `runner.bat` : lanceur Windows pour double-clic depuis le bureau. Appelle `runner.sh` via WSL. Paramètre `pause` final pour garder la fenêtre ouverte.

### Format config.txt

```
pipeline = {

    compute {
        source = "/mnt/a/dossier",
        bases  = "/mnt/c/bases",
        nom    = "hashes.b3"
    }

    verify {
        source = "/mnt/a/dossier",
        base   = "/mnt/c/bases/hashes.b3"
    }

    compare {
        base_a = "/mnt/c/bases/hashes_1.b3",
        base_b = "/mnt/c/bases/hashes_2.b3"
    }

}
```

### Comportement runner.sh

- `compute` : `cd` dans `source`, puis `integrity.sh compute . bases/nom` - chemin relatif garanti.
- `verify` : `cd` dans `source`, puis `integrity.sh verify base` - répertoire de travail correct.
- `compare` : appel direct `integrity.sh compare base_a base_b`.
- Crée `bases/` automatiquement si inexistant (`mkdir -p`).
- `set -e` : arrêt immédiat sur toute erreur.

---

## [0.8] - Fonctionnalité batch_compute.sh

### Ajouté

- `batch_compute.sh` : permet de lancer plusieurs commandes `compute` avec un seul script. Remplacé par `runner.sh` + `config.txt` dans la version 0.9.


---

## [0.7] - Robustesse compare : chemins avec espaces

### Corrigé
- `integrity.sh`
  - Bug critique dans `run_compare()` : `sort -k2,2`, `join -1 2 -2 2` et `awk '{print $2}'` utilisent le blanc comme séparateur de champ. Un chemin contenant des espaces est fragmenté en plusieurs champs, ce qui corrompt le tri, le join et l'extraction - produisant des faux positifs massifs (ex. 26569 modifiés pour 163 fichiers dont 1 seul a changé).
  - Correction : conversion préalable de chaque ligne en `chemin\thash` via `awk '{ print substr($0,67) "\t" substr($0,1,64) }'` - le hash b3sum étant toujours exactement 64 caractères, l'offset 67 est garanti par le format. Toutes les opérations suivantes utilisent `-t $'\t'` comme séparateur explicite : `sort -t $'\t' -k1,1`, `join -t $'\t' -1 1 -2 1`, `cut -f1`.
  - `modifies.b3` : format de sortie préservé (`hash  chemin`) via `awk -F $'\t' '$2 != $3 { print $3 "  " $1 }'`.

## [0.6] - Robustesse et mode silencieux

### Ajouté
- `integrity.sh`
  - Flag `--quiet` : supprime toute sortie terminal, écrit uniquement dans les fichiers de résultats (`recap.txt`, `failed.txt`). Exit code propagé pour usage CI/cron.
  - Fonction `say()` : point d'entrée unique pour toute sortie terminal, désactivée si `--quiet`.
  - Fonction `file_size()` : abstraction portable `stat -c%s` (GNU/Linux) / `stat -f%z` (BSD/macOS).
  - Vérification version bash en tête de script : `bash >= 4` requis, exit explicite avec message si non respecté.
  - `make_result_dir()` : horodatage automatique des dossiers de résultats en cas de collision (`_YYYYMMDD-HHMMSS`), plus d'écrasement silencieux.
  - `trap EXIT` dans `run_compare()` : nettoyage garanti des fichiers temporaires même en cas d'erreur intermédiaire.
  - Redirection ETA sur `/dev/tty` dans `compute_with_progress()` : garantit que la progression n'est jamais écrite dans le fichier `.b3`.
- `tests/run_tests.sh`
  - `set -euo pipefail` : mode strict complet activé (ajout de `-e`).
  - Fonction `assert_file_absent()` : helper dédié pour les assertions d'absence de fichier.
  - T00 : ShellCheck sur `integrity.sh` et `run_tests.sh` (SKIP propre si non installé).
  - T12 : couverture exhaustive du mode `--quiet` (stdout vide, fichiers produits, exit code propagé).
  - T13 : vérifie l'horodatage automatique des dossiers de résultats sur collision.
  - T14 : détection d'un argument `[dossier]` invalide pour `verify`.
- `README.md`
  - Section `--quiet` avec exemples CI/cron.
  - Section Tests avec instructions d'exécution et comptage des cas (14 tests).
  - Mention horodatage automatique dans l'arborescence des résultats.

### Modifié
- `integrity.sh`
  - `assert_target_valid()` : `find -print0 | grep -zc ''` au lieu de `find | wc -l` - robuste aux noms de fichiers contenant des newlines.
  - `run_verify()` : comptage de lignes via `grep -c '^'` au lieu de `grep -c '.'` - correction du bug de comptage sur flux vide.
  - `run_compare()` : `sort -k2,2` au lieu de `sort -k2` - clé de tri limitée strictement au champ chemin, sans déborder sur le hash.
  - `run_verify()` : propagation de l'exit code de `b3sum --check` via `return $exit_code` - utilisable en scripting avec `|| alert`.
  - `failed.txt` : suppression explicite via `rm -f` si `nb_failed == 0` après une vérification OK suivant un échec précédent.
- `tests/run_tests.sh`
  - Résolution dynamique des `outdir` via `ls -d ... | tail -1` : compatible avec l'horodatage des dossiers de résultats.
  - T02, T03, T05, T06, T07 : assertions adaptées à la résolution dynamique des dossiers.
- `README.md`
  - Dépendances : mention explicite de `bash >= 4`.
  - Usage : exemple `--quiet` ajouté.

### Corrigé
- `integrity.sh`
  - Bug comptage lignes dans `run_verify()` : `grep -c '.'` sur flux vide retournait 0 mais ne capturait pas correctement les lignes non vides. Remplacé par `grep -c '^'`.
  - Bug tri ambigü dans `run_compare()` : `sort -k2` triait du champ 2 à la fin de ligne, incluant potentiellement le hash. `sort -k2,2` limite la clé au seul champ 2.
  - Bug nettoyage tmpfiles : `run_compare()` laissait des fichiers temporaires en cas d'erreur intermédiaire. Ajout de `trap 'rm -f ...' EXIT`.
  - Bug portabilité `stat` : `stat -c%s` est GNU-only. Ajout de `file_size()` avec fallback BSD `stat -f%z`.
  - Bug comptage fichiers avec newlines : `assert_target_valid()` utilisait `find | wc -l`. Corrigé avec `find -print0 | grep -zc ''`.
- `tests/run_tests.sh`
  - T10 : pattern `"^/"` remplacé par `"  /"` - `grep` opérait sur une chaîne, l'ancre `^` ne matchait pas la deuxième colonne.

---

## [0.5] - Documentation

### Modifié
- `README.md` - règle répertoire de travail pour `verify` précisée : l'argument `[dossier]` est le répertoire d'origine du compute, pas le dossier haché. Exemples correct/incorrect ajoutés.
- `docs/manuel.md` - section `verify` mise à jour avec le même avertissement et les exemples.

---

## [0.4] - Gardes-fous et signalisation des erreurs

### Modifié
- `integrity.sh`
  - Ajout de `die()` : point de sortie unique pour toutes les erreurs, message sur stderr.
  - Ajout de `assert_b3_valid()` : vérifie existence, type fichier, non-vide, format b3sum valide.
  - Ajout de `assert_target_valid()` : vérifie existence du dossier cible et présence d'au moins un fichier.
  - Validation explicite des arguments dans chaque branche du `case` avant tout traitement.
  - `verify` accepte un argument optionnel `[dossier]` : fait `cd` avant `b3sum --check`.
  - Résolution du chemin absolu du `.b3` avant `cd` (correction bug : chemin relatif invalide après changement de répertoire).
  - `RESULTATS_DIR` : `${RESULTATS_DIR:-...}` au lieu d'assignation inconditionnelle - respecte la valeur exportée par l'environnement (fix tests).
  - Suppression de `local hashfile_abs` hors fonction (illégal en bash hors contexte fonction).
  - `run_verify()` : refonte de la signalisation.
    - Trois états distincts : `OK`, `ECHEC`, `ERREUR`.
    - Terminal : affichage sobre si OK, bloc `████` visible si échec ou erreur.
    - `recap.txt` : compteur `FAILED` affiché uniquement si > 0 ; section erreurs b3sum séparée.
    - `failed.txt` : créé uniquement si `nb_failed > 0` ou erreurs b3sum présentes. Supprimé si tout est OK.
- `tests/run_tests.sh`
  - T02 : assertion `failed.txt absent si 0 échec` (logique inversée par rapport à l'ancienne version).
  - T03 : patterns mis à jour (`ECHEC`, `FAILED`) alignés sur le nouveau format de sortie.

---

## [0.3] - Dossiers de résultats (verify et compare)

### Modifié
- `integrity.sh`
  - Ajout de `RESULTATS_DIR` (configurable, défaut `~/integrity_resultats`).
  - Ajout de `make_result_dir()` : crée `resultats_<nom_base>/` sous `RESULTATS_DIR`.
  - `verify` : délègue à `run_verify()` - produit `recap.txt` et `failed.txt`.
  - `compare` : délègue à `run_compare()` - produit `recap.txt`, `modifies.b3`, `disparus.txt`, `nouveaux.txt`.
  - Fichiers temporaires de `compare` passent par `mktemp` (plus de `/tmp/_old.b3` en dur).
  - Signature `verify` simplifiée : `<base.b3>` uniquement (le dossier n'était pas utilisé par `b3sum --check`).
- `README.md` - usage `verify` et `compare` mis à jour ; section Configuration ajoutée avec arbre des fichiers produits.
- `docs/manuel.md` - sections `verify` et `compare` mises à jour ; arbre de décision et référence rapide alignés.
- `tests/run_tests.sh`
  - `RESULTATS_DIR` exporté vers `WORKDIR` pour isoler les résultats des tests.
  - Ajout de `assert_file_exists()`.
  - T02–T07 : assertions sur la présence et le contenu des fichiers de résultats.

---

## [0.2] - Intégration ETA et tests automatisés

### Modifié
- `integrity.sh`
  - Suppression de `detect_parallelism()` et de la logique SSD/parallélisme (hors périmètre HDD gros volumes).
  - Mode `compute` : délègue à `compute_with_progress()`.
  - Ajout de `compute_with_progress()` : boucle fichier par fichier avec affichage progression et ETA.
    - `mapfile -d ''` remplace `FILES=($(find ...))` - gestion correcte des noms avec espaces.
    - `printf "\r%*s\r"` efface proprement la ligne de progression avant le message final.
  - `df` retiré des dépendances.
- `README.md` - dépendances mises à jour (`df` supprimé, `stat` et `du` ajoutés).
- `docs/manuel.md`
  - Section `detect_parallelism` supprimée.
  - Section `compute` réécrite autour de `compute_with_progress`.
  - Section performances : stratégie SSD/NVMe retirée, focus HDD séquentiel.
- `docs/progression-eta.md` - implémentation finale documentée ; note `mapfile -d ''` vs substitution de commande.
- `tests/run_tests.sh` - T11 ajouté : vérifie que la base produite par `compute_with_progress` est bit-à-bit identique à une base de référence, sans artefact ETA ni `\r`.
- `docs/explication-run-tests.md` - comptage corrigé (10 → 11 cas) ; section T11 ajoutée.

### Corrigé
- `tests/run_tests.sh` T10 : pattern `"^/"` remplacé par `"  /"` - `grep` opère sur une chaîne, pas un fichier, l'ancre `^` ne matchait pas la deuxième colonne.

---

## [0.1] - Structure initiale du projet

### Ajouté
- `integrity.sh` - script principal BLAKE3 avec trois modes : `compute`, `verify`, `compare`.
  - `set -euo pipefail` - mode strict.
  - `detect_parallelism()` - détection SSD/HDD via `/sys/block/.../queue/rotational`.
  - Mode `compute` : pipeline `find | sort -z | xargs b3sum`, parallélisme `-P 4` sur SSD.
  - Mode `verify` : délègue à `b3sum --check`.
  - Mode `compare` : tri sur colonne 2, `join` pour les modifiés, `comm` pour disparus/nouveaux, rapport `tee`.
- `README.md` - point d'entrée : dépendances, usage en 3 commandes, arbre de décision, règles critiques.
- `docs/manuel.md` - référence technique complète : algorithmes, structure `.b3`, workflow, explication du script, performances, limites, référence rapide, annexe FIM.
- `docs/progression-eta.md` - analyse du problème ETA sur pipeline `xargs`, deux approches (`pv` invalide, boucle bash), mécanique de l'estimation, tableau de comparaison des performances.
- `docs/explication-run-tests.md` - documentation du code `run_tests.sh` : chemins, compteurs, assertions, setup/teardown, structure d'un cas de test, prérequis, exit code CI.
- `tests/run_tests.sh` - suite de tests automatisée bash pur, 11 cas T01–T11, isolation via `mktemp`, teardown systématique, exit code CI-compatible.
- `tests/validation.md` - protocole de test manuel : 10 cas T01–T10 avec commandes exactes et résultats attendus, critères de qualité globaux.
