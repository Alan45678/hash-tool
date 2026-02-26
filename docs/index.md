# hash_tool

hash_tool détecte la corruption silencieuse de fichiers en comparant des empreintes BLAKE3 prises à des instants différents. Il fonctionne depuis une interface CLI unique, ne requiert aucune installation complexe, et produit un rapport HTML lisible sans outil supplémentaire.

---

## Principe

`hash-tool` est l'interface CLI unique. Il détecte automatiquement si l'exécution native est possible (`b3sum` disponible), sinon délègue à Docker — sans que l'utilisateur ait à s'en préoccuper. En interne, `src/integrity.sh` calcule les empreintes et `runner.sh` orchestre les pipelines.

```
┌=============┐    compute     ┌==============┐    ┌==================┐
│  Dossier    │ =============► │  base.b3     │    │  base.b3         │
│  de données │                │  (hashes)    │    │  .meta.json      │ ← sidecar
└=============┘                └==============┘    └==================┘
                                      │
                     verify / compare │
                                      ▼
                               ┌==============┐
                               │  recap.txt   │
                               │  failed.txt  │
                               │  report.html │
                               └==============┘
```

---

## Cas d'usage

- **Archivage long terme** — vérifier qu'un disque n'a pas développé de secteurs défectueux
- **Transfert de données** — confirmer qu'une copie est bit-à-bit identique à la source
- **VeraCrypt** — indexer des partitions chiffrées avant démontage, vérifier après remontage
- **Monitoring périodique** — cron hebdomadaire sur un NAS ou serveur
- **Automatisation CI/CD** — mode `--quiet`, exit code propagé, image Docker légère

---

## Démarrage rapide

=== "CLI unique (recommandé)"

    ```bash
    # 1. Indexer un dossier
    hash-tool compute -data ./mon_dossier -save ./bases -meta "Snapshot initial"

    # 2. Vérifier l'intégrité
    hash-tool verify -base ./bases/hashes_mon_dossier.b3

    # 3. Comparer deux snapshots
    hash-tool compare -old snap1.b3 -new snap2.b3 -save ./rapports

    # 4. Vérifier l'environnement
    hash-tool check-env
    ```

=== "Pipeline JSON"

    ```bash
    # Éditer pipelines/pipeline-amelioree.json, puis :
    hash-tool runner -pipeline ./pipelines/pipeline-amelioree.json
    ```

=== "Docker"

    ```bash
    docker run --rm \
      -v /mes/donnees:/data:ro \
      -v /mes/bases:/bases \
      hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3
    ```

=== "Mode --quiet (CI/cron)"

    ```bash
    # Hook pre-commit git
    hash-tool verify -base base.b3 -quiet || { echo "Corruption détectée"; exit 1; }

    # Monitoring cron
    0 3 * * * hash-tool verify -base /data/base.b3 -quiet || mail -s "ALERT" admin@example.com
    ```

---

## Arbre de décision

| Situation | Commande |
|---|---|
| Première indexation | `hash-tool compute` |
| Vérifier après transfert / stockage | `hash-tool verify` |
| Comparer deux snapshots | `hash-tool compare` |
| Lister les bases disponibles | `hash-tool list` |
| Voir les fichiers nouveaux/disparus sans recalculer | `hash-tool diff` |
| Statistiques sur une base | `hash-tool stats` |
| Pipeline multi-étapes / VeraCrypt | `hash-tool runner` |
| Diagnostic de l'environnement | `hash-tool check-env` |
| Contrôle ad hoc d'un fichier unique | `b3sum fichier.bin` |

---

## Configuration

`RESULTATS_DIR` définit le dossier racine des résultats (défaut : `~/integrity_resultats`).
Peut être surchargé par variable d'environnement ou via l'option `-save`.

---

## Règles d'utilisation critiques

- **Chemins relatifs** dans les bases `.b3`. `runner.sh` gère le `cd` automatiquement.
- **Répertoire de travail** : lancer `verify` depuis le même répertoire qu'au `compute`, ou passer `-data <dossier>`.
- **Stockage séparé** : stocker les `.b3` sur un support distinct des données.
- **Nommage daté** : `hashes_2024-01-15.b3`, jamais `hashes_latest.b3`.
- **Sidecar** : le fichier `.meta.json` associé à chaque `.b3` est optionnel mais recommandé pour la traçabilité.

---

## Docker

Aucune dépendance à installer sur l'hôte. Fonctionne sur Windows, NAS Synology, serveur Debian.

```bash
# Build
docker build -t hash_tool .

# Compute
docker run --rm -v /mes/donnees:/data:ro -v /mes/bases:/bases \
  hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3

# Verify
docker run --rm -v /mes/donnees:/data:ro -v /mes/bases:/bases:ro \
  -v /mes/resultats:/resultats \
  hash_tool verify /bases/hashes.b3 /data

# Pipeline complet
docker run --rm \
  -v /mes/donnees:/data:ro -v /mes/bases:/bases \
  -v /mes/resultats:/resultats \
  -v /chemin/pipeline.json:/pipelines/pipeline.json:ro \
  hash_tool runner
```

Voir [docs/reference/docker.md](reference/docker.md) pour la documentation complète.

---

## Tests

```bash
# Tests integrity.sh (T00–T14)
cd tests && ./run_tests.sh

# Tests runner.sh + pipeline.json (TP01–TP12b)
cd tests && ./run_tests_pipeline.sh

# ShellCheck (inclus dans T00, requiert installation séparée)
apt install shellcheck
```

---

## Structure du projet

```
hash_tool/
├── hash-tool                  ← CLI unique (point d'entrée utilisateur)
├── src/
│   ├── integrity.sh           ← dispatcher CLI (compute, verify, compare)
│   └── lib/
│       ├── core.sh            ← logique métier (hachage, vérification, comparaison)
│       ├── ui.sh              ← interface terminal (affichage, ETA, progression)
│       ├── results.sh         ← écriture fichiers de résultats
│       └── report.sh          ← génération HTML
├── runner.sh                  ← orchestrateur pipeline (formats legacy + étendu)
├── pipelines/
│   ├── pipeline.json              ← pipeline legacy simple
│   ├── pipeline-amelioree.json    ← pipeline format étendu (toutes les commandes)
│   ├── pipeline-veracrypt.json    ← pipeline VeraCrypt multi-disques
│   └── pipeline-debug.json        ← pipeline de test local
├── reports/
│   └── template.html          ← template HTML de référence
├── docs/
│   ├── spec/                  ← spécifications formelles
│   ├── reference/             ← référence des commandes
│   ├── guides/                ← guides utilisateur
│   └── development/           ← documentation développeur
└── tests/
    ├── run_tests.sh           ← T00–T14
    └── run_tests_pipeline.sh  ← TP01–TP12b
```

---

## Dépendances

| Outil | Requis par | Installation |
|---|---|---|
| `bash >= 4` | `hash-tool`, `integrity.sh`, `runner.sh` | Natif Linux ; macOS via `brew install bash` |
| `b3sum` | `integrity.sh` | `apt install b3sum` / `brew install b3sum` |
| `jq` | `hash-tool`, `runner.sh` | `apt install jq` / `brew install jq` |
| `find`, `sort`, `awk`, `comm`, `join`, `stat`, `du` | `integrity.sh` | GNU coreutils (natifs) |
| `docker` (optionnel) | `hash-tool` (fallback) | Uniquement si b3sum non disponible |

!!! note "macOS"
    `bash` est en version 3.x par défaut sur macOS. Installer bash 5 via Homebrew : `brew install bash`.