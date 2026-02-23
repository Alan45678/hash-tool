# hash_tool

Détection de corruption silencieuse et d'erreurs de transfert sur disque, par hachage **BLAKE3**.

---

## Principe

`integrity.sh` calcule une empreinte cryptographique de chaque fichier d'un dossier, stocke ces empreintes dans un fichier `.b3`, puis permet de vérifier ultérieurement que rien n'a changé. `runner.sh` orchestre plusieurs opérations via un fichier `pipeline.json`.

```
┌─────────────┐    compute     ┌──────────────┐
│  Dossier    │ ─────────────► │  base.b3     │
│  de données │                │  (hashes)    │
└─────────────┘                └──────────────┘
                                      │
                     verify / compare │
                                      ▼
                               ┌──────────────┐
                               │  Rapport     │
                               │  recap.txt   │
                               │  report.html │
                               └──────────────┘
```

## Cas d'usage

- **Archivage long terme** — vérifier qu'un disque n'a pas développé de secteurs défectueux
- **Transfert de données** — confirmer qu'une copie est bit-à-bit identique à la source
- **VeraCrypt** — indexer des partitions chiffrées avant démontage, vérifier après remontage
- **Monitoring périodique** — cron hebdomadaire sur un NAS ou serveur

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
    ./runner.sh
    ```

=== "Docker"

    ```bash
    docker run --rm \
      -v /mes/donnees:/data:ro \
      -v /mes/bases:/bases \
      hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3
    ```

## Dépendances

| Outil | Requis par | Installation |
|---|---|---|
| `bash >= 4` | `integrity.sh`, `runner.sh` | Natif Linux/macOS |
| `b3sum` | `integrity.sh` | `apt install b3sum` |
| `jq` | `runner.sh` | `apt install jq` |
| `find`, `sort`, `awk`, `comm`, `join`, `stat`, `du` | `integrity.sh` | Natifs (GNU coreutils) |

!!! note "macOS"
    `bash` est en version 3.x par défaut sur macOS. Installer bash 5 via Homebrew : `brew install bash`.

## Structure du projet

```
hash_tool/
├── src/
│   ├── integrity.sh           ← script principal
│   └── lib/
│       └── report.sh          ← génération HTML
├── runner.sh                  ← orchestrateur pipeline
├── pipelines/
│   ├── pipeline.json          ← exemple/test local
│   └── pipeline-full.json     ← exemple multi-disques VeraCrypt
├── docker/
│   └── entrypoint.sh
├── tests/
│   ├── run_tests.sh           ← T00–T14
│   └── run_tests_pipeline.sh  ← TP01–TP12
├── docs/
├── Dockerfile
├── docker-compose.yml
└── CHANGELOG.md
```
