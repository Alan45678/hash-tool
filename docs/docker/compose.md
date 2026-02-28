# Docker Compose

`docker-compose.yml` définit trois services préconfigurés pour les cas d'usage
courants. L'objectif est d'éviter de retaper les options `-v` et `-e` à chaque commande.

---

## Configuration initiale

Avant tout usage, adapter la section `x-volumes` en tête du fichier :

```yaml
x-volumes:
  data:      &vol-data      /chemin/vers/donnees     # données à hacher (lecture seule)
  bases:     &vol-bases     /chemin/vers/bases        # fichiers .b3
  pipelines: &vol-pipelines /chemin/vers/pipelines   # fichiers pipeline.json
  resultats: &vol-resultats /chemin/vers/resultats   # résultats compare/verify
```

C'est le **seul endroit à modifier** — tous les services référencent ces chemins
via les ancres YAML (`*vol-data`, `*vol-bases`, etc.).

### Exemples de chemins selon l'environnement

| Environnement | Exemple |
|---|---|
| Linux / serveur | `/srv/hash-tool/données` |
| macOS | `/Users/moi/Documents/données` |
| WSL2 | `/home/wsl-acer/données` (pas `/mnt/c/...`) |
| NAS Synology | `/volume1/données` |

!!! warning "WSL2"
    Ne pas utiliser les chemins `/mnt/c/...` — Docker Desktop ne monte pas
    correctement les chemins Windows comme volumes. Utiliser le filesystem Linux
    natif (`/home/...`).

---

## Services

### `integrity` — commandes unitaires

Service principal pour `compute`, `verify` et `compare`.

```bash
# Calculer les empreintes
docker compose run --rm integrity compute /data /bases/hashes.b3

# Vérifier l'intégrité
docker compose run --rm integrity verify /bases/hashes.b3 /data

# Comparer deux bases
docker compose run --rm integrity compare /bases/old.b3 /bases/new.b3
```

Volumes montés : `/data` (`:ro`), `/bases`, `/resultats`.

### `pipeline` — exécution runner.sh

Service dédié à l'exécution d'un pipeline JSON complet.

```bash
docker compose run --rm pipeline
```

Lance `runner.sh /pipelines/pipeline.json` automatiquement.
Le fichier `pipeline.json` doit être placé dans le dossier mappé sur `/pipelines`.

Volumes montés : `/data` (`:ro`), `/bases`, `/pipelines`, `/resultats`.

### `cron` — vérification périodique

Service optionnel, désactivé par défaut (profil `cron`).

```bash
# Démarrer le service cron en arrière-plan
docker compose --profile cron up -d cron

# Arrêter
docker compose --profile cron down
```

Variables de configuration :

| Variable | Défaut | Description |
|---|---|---|
| `CRON_SCHEDULE` | `0 3 * * *` | Expression cron (03h00 chaque nuit) |
| `CRON_BASE` | `/bases/hashes.b3` | Base à vérifier |

!!! warning "Image étendue requise"
    Le service `cron` utilise l'image `hash_tool` standard qui ne contient pas `crond`.
    Pour un usage en production, créer une image dérivée avec `crond` installé.
    Voir [Automatisation](../guides/automation.md) pour le setup complet.

---

## Build de l'image

Si l'image n'est pas encore buildée :

```bash
docker compose build
# ou
docker build -t hash_tool .
```

Les deux sont équivalents — `docker-compose.yml` référence le même `Dockerfile`.

---

## Comparaison `docker compose run` vs `docker run`

| | `docker compose run` | `docker run` |
|---|---|---|
| Volumes | Préconfigurés dans `docker-compose.yml` | À spécifier à chaque commande |
| Image | Référencée dans `docker-compose.yml` | À spécifier à chaque commande |
| Cas d'usage | Usage régulier sur un poste fixe | Usage ponctuel, CI, scripts |

En CI, `docker run` avec les volumes explicites est préférable — pas de dépendance
à `docker-compose.yml` ni aux chemins locaux.

---

## Exemple complet — workflow audit

```bash
# 1. Configurer les chemins dans docker-compose.yml (une seule fois)
# data:      /srv/archives
# bases:     /srv/bases
# resultats: /srv/resultats

# 2. Calculer les empreintes initiales
docker compose run --rm integrity compute /data /bases/hashes_archives.b3

# 3. Plus tard, vérifier l'intégrité
docker compose run --rm integrity verify /bases/hashes_archives.b3 /data

# 4. Après une migration, comparer deux états
docker compose run --rm integrity compare \
  /bases/hashes_avant.b3 \
  /bases/hashes_apres.b3
```