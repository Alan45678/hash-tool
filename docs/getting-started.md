# Démarrage rapide

---

## Prérequis

| Dépendance | Usage | Installation |
|---|---|---|
| `bash >= 4` | Interpréteur shell | Linux natif ; macOS via `brew install bash` ; WSL |
| `b3sum` | Calcul des empreintes BLAKE3 | `apt install b3sum` / `brew install b3sum` |
| `jq` | Pipelines JSON + sidecar | `apt install jq` / `brew install jq` |
| `find`, `sort`, `awk`, `comm`, `join`, `stat`, `du` | Outils internes | GNU coreutils (natifs sur toute distribution) |

!!! note "macOS"
    `bash` est en version 3.x par défaut sur macOS. hash_tool requiert bash >= 4.
    ```bash
    brew install bash b3sum jq
    # Vérifier : /usr/local/bin/bash --version
    ```

!!! note "Docker (alternative)"
    Si les dépendances ne peuvent pas être installées sur l'hôte, `hash-tool` bascule automatiquement sur Docker. Voir [Démarrage rapide Docker](#docker-démarrage-rapide).

---

## Installation

```bash
git clone https://github.com/hash_tool/hash_tool.git
cd hash_tool
chmod +x hash-tool src/integrity.sh runner.sh
```

Aucune compilation, aucune dépendance système au-delà des outils listés ci-dessus.

### Rendre `hash-tool` accessible globalement (optionnel)

```bash
sudo ln -s "$(pwd)/hash-tool" /usr/local/bin/hash-tool
# Ou : ajouter le dossier hash_tool/ au PATH
```

---

## Environnements supportés

| Environnement | Méthode | Notes |
|---|---|---|
| Linux (Debian, Ubuntu, Alpine, Arch…) | Natif | Environnement de référence |
| macOS | Natif avec bash 4+ via Homebrew | `brew install bash b3sum jq` |
| Windows | Via WSL2 | Distributions Ubuntu ou Debian recommandées |
| NAS Synology | Via Docker (image arm64) | Voir [guide NAS](guides/nas-synology.md) |
| Serveur headless | Mode `-quiet` + cron | Voir [guide CI/Cron](guides/cron-ci.md) |

---

## Vérifier l'environnement

Avant toute utilisation, diagnostiquer l'environnement :

```bash
hash-tool check-env
```

Sortie attendue :

```
=== check-env : Analyse de l'environnement ===

  [OK] b3sum disponible : b3sum 1.5.4
  [OK] jq disponible : jq-1.7
  [OK] bash 5.2.15(1)-release
  [OK] integrity.sh présent et exécutable : /opt/hash_tool/src/integrity.sh
  [OK] runner.sh présent et exécutable : /opt/hash_tool/runner.sh
  [--] Docker non disponible (optionnel)

  Mode d'exécution sélectionné : native
  → Exécution native active
```

---

## Workflow typique

| Étape | Commande | Moment |
|---|---|---|
| 1. Indexer | `hash-tool compute -data ./dossier -save ./bases -meta "..."` | Données saines connues |
| 2. Vérifier | `hash-tool verify -base ./bases/hashes_dossier.b3` | Après transfert / stockage |
| 3. Comparer | `hash-tool compare -old avant.b3 -new apres.b3` | Entre deux états |
| 4. Inspecter | `hash-tool diff -base ./bases/hashes_dossier.b3 -data ./dossier` | Contrôle rapide (sans recalcul) |
| 5. Pipeline | `hash-tool runner -pipeline ./pipelines/pipeline-amelioree.json` | Automatisation multi-étapes |

### Exemple concret — archivage sur disque externe

```bash
# Disque monté sur /mnt/archive

# 1. Première indexation — données saines à J0
hash-tool compute \
  -data /mnt/archive \
  -save /mnt/c/bases \
  -meta "Snapshot initial archive 2024-01-15"

# 2. Vérification après chaque session — J+30, J+90, etc.
hash-tool verify \
  -base /mnt/c/bases/hashes_archive.b3 \
  -data /mnt/archive

# 3. Après ajout de fichiers — voir ce qui a changé sans recalculer
hash-tool diff \
  -base /mnt/c/bases/hashes_archive.b3 \
  -data /mnt/archive

# 4. Nouveau snapshot puis comparaison
hash-tool compute \
  -data /mnt/archive \
  -save /mnt/c/bases \
  -meta "Snapshot après ajout collection 2024-02-15"

hash-tool compare \
  -old /mnt/c/bases/hashes_archive_avant.b3 \
  -new /mnt/c/bases/hashes_archive_apres.b3 \
  -save /mnt/c/rapports
```

---

## Sidecar file — métadonnées associées aux bases

Chaque `compute` génère automatiquement un fichier `.meta.json` à côté du `.b3` :

```bash
hash-tool compute -data ./donnees -save ./bases -meta "Snapshot initial"
```

Produit :

```
./bases/
├── hashes_donnees.b3           ← empreintes BLAKE3
└── hashes_donnees.b3.meta.json ← métadonnées (date, commentaire, paramètres)
```

Contenu du sidecar :

```json
{
  "created_by": "hash-tool v2.0.0",
  "date": "2026-02-26T14:30:00Z",
  "comment": "Snapshot initial",
  "parameters": {
    "directory": "./donnees",
    "hash_algo": "blake3",
    "readonly": false,
    "nb_files": 1247
  }
}
```

Les commandes `verify`, `compare` et `stats` affichent automatiquement les métadonnées sidecar si le fichier est présent.

---

## Lire les résultats

Chaque opération `verify` ou `compare` produit un dossier horodaté dans `~/integrity_resultats/` :

```
~/integrity_resultats/
└── resultats_hashes_archive/
    ├── recap.txt      ← statut global, compteurs
    ├── failed.txt     ← fichiers en échec (si applicable)
    ├── modifies.b3    ← fichiers modifiés (compare uniquement)
    ├── disparus.txt   ← fichiers disparus (compare uniquement)
    ├── nouveaux.txt   ← nouveaux fichiers (compare uniquement)
    └── report.html    ← rapport visuel autonome
```

Ouvrir `report.html` directement dans un navigateur — aucune connexion requise, aucun serveur.

---

## Docker — démarrage rapide

Si les dépendances ne peuvent pas être installées sur l'hôte, `hash-tool` détecte Docker automatiquement et l'utilise en fallback :

```bash
# Build une fois
docker build -t hash_tool .

# Ensuite, hash-tool fonctionne identiquement
# (le mode d'exécution est sélectionné automatiquement)
hash-tool check-env   # affichera : Mode d'exécution : docker
```

Ou directement via Docker :

```bash
docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases \
  hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3
```

Voir la [référence Docker complète](reference/docker.md) pour les volumes, les environnements Synology, et les options Compose.

---

## Commandes disponibles

```
hash-tool compute     Calcule les empreintes d'un dossier.
hash-tool verify      Vérifie l'intégrité d'un dossier à partir d'une base.
hash-tool compare     Compare deux bases d'empreintes.
hash-tool runner      Exécute un pipeline JSON.
hash-tool list        Liste les bases d'empreintes disponibles.
hash-tool diff        Affiche les différences entre une base et un dossier.
hash-tool stats       Affiche des statistiques sur une base.
hash-tool check-env   Analyse l'environnement d'exécution.
hash-tool version     Affiche la version.
hash-tool help        Affiche l'aide (ou 'help <commande>' pour le détail).
```

Aide détaillée par commande :

```bash
hash-tool help compute
hash-tool help verify
hash-tool help runner
# etc.
```