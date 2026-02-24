# hash_tool

hash_tool détecte la corruption silencieuse de fichiers en comparant des empreintes BLAKE3 prises à des instants différents. Il fonctionne depuis la ligne de commande, ne requiert aucune installation complexe, et produit un rapport HTML lisible sans outil supplémentaire.




## Principe

`integrity.sh` calcule une empreinte cryptographique de chaque fichier d'un dossier, stocke ces empreintes dans un fichier `.b3`, puis permet de vérifier ultérieurement que rien n'a changé. `runner.sh` orchestre plusieurs opérations via un fichier `pipeline.json`.

```
┌=============┐    compute     ┌==============┐
│  Dossier    │ =============► │  base.b3     │
│  de données │                │  (hashes)    │
└=============┘                └==============┘
                                      │
                     verify / compare │
                                      ▼
                               ┌==============┐
                               │  Rapport     │
                               │  recap.txt   │
                               │  report.html │
                               └==============┘
```

---

## Cas d'usage

- **Archivage long terme** - vérifier qu'un disque n'a pas développé de secteurs défectueux
- **Transfert de données** - confirmer qu'une copie est bit-à-bit identique à la source
- **VeraCrypt** - indexer des partitions chiffrées avant démontage, vérifier après remontage
- **Monitoring périodique** - cron hebdomadaire sur un NAS ou serveur

---

## Démarrage rapide

=== "Script direct"

    ```bash
    # 1. Indexer un dossier
    ./src/integrity.sh compute ./mon_dossier hashes_$(date +%Y-%m-%d).b3

    # 2. Vérifier l'intégrité
    ./src/integrity.sh verify hashes_$(date +%Y-%m-%d).b3

    # 3. Comparer deux snapshots
    ./src/integrity.sh compare ancien.b3 nouveau.b3
    ```

=== "Pipeline JSON"

    ```bash
    # Éditer pipelines/pipeline.json, puis :
    ./runner.sh                              # lit pipelines/pipeline.json
    ./runner.sh /chemin/vers/pipeline.json   # config explicite
    ```

=== "Docker"

    ```bash
    docker run --rm \
      -v /mes/donnees:/data:ro \
      -v /mes/bases:/bases \
      hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3
    ```

=== Mode `--quiet`

Supprime toute sortie terminal, écrit uniquement dans les fichiers de résultats. Exit code propagé.

    ```bash
    # Hook pre-commit git
    ./src/integrity.sh --quiet verify base.b3 || { echo "Corruption détectée"; exit 1; }

    # Monitoring cron
    0 3 * * * /opt/hash_tool/src/integrity.sh --quiet verify /data/base.b3 || mail -s "ALERT" admin@example.com
    ```

---

## Arbre de décision

| Situation | Commande |
|---|---|
| Première indexation | `compute` |
| Vérifier après transfert / stockage | `verify` |
| Comparer deux snapshots | `compare` |
| Pipeline multi-dossiers / VeraCrypt | `runner.sh` + `pipeline.json` |
| Contrôle ad hoc d'un fichier unique | `b3sum fichier.bin` |
| Intégration CI/cron | `--quiet verify` |

























## Configuration

`RESULTATS_DIR` définit le dossier racine des résultats (défaut : `~/integrity_resultats`).
Peut être surchargé par variable d'environnement, ou par le champ `resultats` dans `pipeline.json`.

---

## Règles d'utilisation critiques

- **Chemins relatifs** dans les bases `.b3`. `runner.sh` gère le `cd` automatiquement.
- **Répertoire de travail** : lancer `verify` depuis le même répertoire qu'au `compute`, ou passer ce répertoire en second argument.
- **Stockage séparé** : stocker les `.b3` sur un support distinct des données.
- **Nommage daté** : `hashes_2024-01-15.b3`, jamais `hashes_latest.b3`.

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

Voir [docs/reference/docker.md](docs/reference/docker.md) pour la documentation complète (NAS, cron, ARM64, Compose).

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

## Documentation

```bash
# Installer les dépendances
pip install mkdocs mkdocs-material

# Prévisualiser en local
mkdocs serve    # http://localhost:8000

# Générer le site statique
mkdocs build    # → site/
```

---



---

## Structure de la documentation

La documentation est organisée en trois niveaux :

### Documentation utilisateur
Pour installer, configurer et utiliser hash_tool sans connaître son implémentation interne.

- [Démarrage rapide](getting-started.md) - installation et premier usage
- [Guide VeraCrypt](guides/veracrypt.md) - workflow multi-disques
- [Guide CI/Cron](guides/cron-ci.md) - automatisation
- [Guide NAS Synology](guides/nas-synology.md) - déploiement NAS

### Documentation développeur
Pour comprendre l'architecture, contribuer au code ou intégrer les modules.

- [Architecture](development/architecture.md) - décisions techniques et rationale
- [Contribuer](development/contributing.md) - conventions, tests, processus de release
- [Changelog](development/changelog.md) - historique des versions
- [API interne](spec/api-interne.md) - contrats des modules

### Documentation de référence
Spécifications formelles et référence exhaustive des commandes.

- [Spécification format `.b3`](spec/b3-format.md) - grammaire, invariants, exemples
- [Référence integrity.sh](reference/integrity-sh.md) - modes, arguments, exit codes, limites
- [Référence runner.sh](reference/runner-sh.md) - format pipeline.json, comportements
- [Référence Docker](reference/docker.md) - build, volumes, Compose, cron, ARM64

---

## Dépendances

| Outil | Requis par | Installation |
|---|---|---|
| `bash >= 4` | `integrity.sh`, `runner.sh` | Natif Linux/macOS |
| `b3sum` | `integrity.sh` | `apt install b3sum` |
| `jq` | `runner.sh` | `apt install jq` |
| `find`, `sort`, `awk`, `comm`, `join`, `stat`, `du` | `integrity.sh` | GNU coreutils (natifs) |

!!! note "macOS"
    `bash` est en version 3.x par défaut sur macOS. Installer bash 5 via Homebrew : `brew install bash`.

---

## Structure du projet

```
hash_tool/
├== src/
│   ├== integrity.sh           ← dispatcher CLI
│   └== lib/
│       ├== core.sh            ← logique métier (hachage, vérification, comparaison)
│       ├== ui.sh              ← interface terminal (affichage, ETA, progression)
│       ├== results.sh         ← écriture fichiers de résultats
│       └== report.sh          ← génération HTML
├== runner.sh                  ← orchestrateur pipeline
├== pipelines/
│   ├== pipeline.json          ← pipeline de test local
│   └== pipeline-full.json     ← pipeline VeraCrypt multi-disques
├== reports/
│   └== template.html          ← template HTML de référence
├== docs/
│   ├== spec/                  ← spécifications formelles
│   │   ├== b3-format.md       ← format .b3
│   │   └== api-interne.md     ← contrats des modules
│   ├== reference/             ← référence des commandes
│   ├== guides/                ← guides utilisateur
│   └== development/           ← documentation développeur
└== tests/
    ├== run_tests.sh           ← T00–T14
    └== run_tests_pipeline.sh  ← TP01–TP12b
```
