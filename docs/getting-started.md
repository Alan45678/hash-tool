# Démarrage rapide

---

## Prérequis

| Dépendance | Usage | Installation |
|---|---|---|
| `bash >= 4` | Interpréteur shell | Linux natif ; macOS via `brew install bash` ; WSL |
| `b3sum` | Calcul des empreintes BLAKE3 | `apt install b3sum` / `brew install b3sum` |
| `jq` | Parsing `pipeline.json` (runner uniquement) | `apt install jq` / `brew install jq` |
| `find`, `sort`, `awk`, `comm`, `join`, `stat`, `du` | Outils internes | GNU coreutils (natifs sur toute distribution) |

!!! note "macOS"
    `bash` est en version 3.x par défaut sur macOS. hash_tool requiert bash >= 4.
    ```bash
    brew install bash
    # Vérifier : /usr/local/bin/bash --version
    ```

---

## Installation

```bash
git clone https://github.com/hash_tool/hash_tool.git
cd hash_tool
chmod +x src/integrity.sh runner.sh
```

Aucune compilation, aucune dépendance système au-delà des outils listés ci-dessus.

---

## Environnements supportés

| Environnement | Méthode | Notes |
|---|---|---|
| Linux (Debian, Ubuntu, Alpine, Arch…) | Natif | Environnement de référence |
| macOS | Natif avec bash 4+ via Homebrew | `brew install bash b3sum jq` |
| Windows | Via WSL2 | Distributions Ubuntu ou Debian recommandées |
| NAS Synology | Via Docker (image arm64) | Voir [guide NAS](guides/nas-synology.md) |
| Serveur headless | Mode `--quiet` + cron | Voir [guide CI/Cron](guides/cron-ci.md) |

---

## Workflow typique

| Étape | Commande | Moment |
|---|---|---|
| 1. Indexer | `./src/integrity.sh compute ./dossier bases/hashes_2024-01-15.b3` | Données saines connues |
| 2. Vérifier | `./src/integrity.sh verify bases/hashes_2024-01-15.b3` | Après transfert / stockage |
| 3. Comparer | `./src/integrity.sh compare bases/avant.b3 bases/apres.b3` | Entre deux états |
| 4. Pipeline | `./runner.sh pipelines/pipeline.json` | Automatisation multi-étapes |

### Exemple concret - archivage sur disque externe

```bash
# Brancher le disque externe, VeraCrypt le monte sur /mnt/archive

# 1. Première indexation - données saines à J0
cd /mnt/archive
../hash_tool/src/integrity.sh compute . /mnt/c/bases/archive_2024-01-15.b3

# 2. Vérification après chaque session - J+30, J+90, etc.
cd /mnt/archive
../hash_tool/src/integrity.sh verify /mnt/c/bases/archive_2024-01-15.b3

# 3. Après ajout de fichiers - comparer les deux états
cd /mnt/archive
../hash_tool/src/integrity.sh compute . /mnt/c/bases/archive_2024-02-15.b3
../hash_tool/src/integrity.sh compare \
  /mnt/c/bases/archive_2024-01-15.b3 \
  /mnt/c/bases/archive_2024-02-15.b3
```

---

## Lire les résultats

Chaque opération `verify` ou `compare` produit un dossier horodaté dans `~/integrity_resultats/` :

```
~/integrity_resultats/
└== resultats_archive_2024-01-15/
    ├== recap.txt      ← statut global, compteurs
    ├== failed.txt     ← fichiers en échec (si applicable)
    └== report.html    ← rapport visuel autonome (ouvrir dans un navigateur)
```

Ouvrir `report.html` directement dans un navigateur - aucune connexion requise, aucun serveur.

---

## Docker - démarrage rapide

Si les dépendances ne peuvent pas être installées sur l'hôte :

```bash
docker build -t hash_tool .

docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases \
  hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3
```

Voir la [référence Docker complète](reference/docker.md) pour les volumes, les environnements Synology, et les options Compose.
