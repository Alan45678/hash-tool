# Référence — Docker

Utilisation de hash_tool via Docker. Aucune dépendance (`b3sum`, `jq`, `bash`) à installer sur l'hôte.

**Image :** Alpine 3.19, ~14 Mo. Supporte `linux/amd64` et `linux/arm64`.

---

## Build

```bash
# Standard (amd64)
docker build -t hash_tool .

# ARM64 — NAS Synology, Raspberry Pi, Apple Silicon
docker build --platform linux/arm64 -t hash_tool:arm64 .
```

---

## Commandes disponibles

```
docker run [--rm] [-v ...] hash_tool [--quiet] <commande> [args]

  compute <dossier> <base.b3>             Calcule les hashes
  verify  <base.b3> [dossier]             Vérifie l'intégrité
  compare <ancienne.b3> <nouvelle.b3>     Compare deux bases
  runner  [pipeline.json]                 Exécute un pipeline JSON
  shell                                   Shell bash interactif (debug)
  help                                    Aide
  version                                 Versions des outils embarqués
```

---

## Volumes

| Volume conteneur | Usage | Flag recommandé |
|---|---|---|
| `/data` | Données à hacher | `:ro` (lecture seule) |
| `/bases` | Fichiers `.b3` | Lecture/écriture |
| `/pipelines` | Fichiers `pipeline.json` | `:ro` |
| `/resultats` | Résultats `verify`/`compare` | Lecture/écriture |

`RESULTATS_DIR=/resultats` est défini par défaut dans l'image.

---

## Exemples

### Compute

```bash
docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases \
  hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3
```

### Verify

```bash
docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases:ro \
  -v /mes/resultats:/resultats \
  hash_tool verify /bases/hashes.b3 /data
```

### Compare

```bash
docker run --rm \
  -v /mes/bases:/bases:ro \
  -v /mes/resultats:/resultats \
  hash_tool compare /bases/old.b3 /bases/new.b3
```

### Pipeline complet

```bash
docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases \
  -v /mes/resultats:/resultats \
  -v /chemin/pipeline.json:/pipelines/pipeline.json:ro \
  hash_tool runner
```

### Mode silencieux — CI/cron

```bash
docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases:ro \
  -v /mes/resultats:/resultats \
  hash_tool --quiet verify /bases/hashes.b3 /data \
  || echo "ALERTE : corruption détectée"
```

### Debug interactif

```bash
docker run --rm -it \
  -v /mes/donnees:/data \
  -v /mes/bases:/bases \
  hash_tool shell
```

---

## Docker Compose

Adapter les chemins dans la section `x-volumes` de `docker-compose.yml` :

```yaml
x-volumes:
  data:      &vol-data      /chemin/vers/donnees
  bases:     &vol-bases     /chemin/vers/bases
  pipelines: &vol-pipelines /chemin/vers/pipelines
  resultats: &vol-resultats /chemin/vers/resultats
```

Puis :

```bash
# Commande ponctuelle
docker compose run --rm integrity verify /bases/hashes.b3 /data
docker compose run --rm integrity compute /data /bases/hashes.b3

# Pipeline complet
docker compose run --rm pipeline

# Build puis run
docker compose build && docker compose run --rm pipeline
```

---

## Variable d'environnement

### `RESULTATS_DIR`

Surcharger le dossier de résultats dans le conteneur :

```bash
docker run --rm \
  -v /mes/resultats:/mon_dossier_custom \
  -e RESULTATS_DIR=/mon_dossier_custom \
  hash_tool verify /bases/hashes.b3
```

---

## NAS Synology

Sur DSM 7.x avec Docker Manager ou Portainer :

```bash
docker run --rm \
  -v /volume1/data:/data:ro \
  -v /volume1/bases:/bases \
  -v /volume1/resultats:/resultats \
  hash_tool verify /bases/hashes.b3 /data
```

Pour ARM64 (DS220+, DS923+, etc.) : builder avec `--platform linux/arm64`.

Voir le [guide NAS Synology](../guides/nas-synology.md) pour la configuration complète.

---

## Cron sur Debian/Ubuntu

```bash
# /etc/cron.d/hash-integrity
0 3 * * * root \
  docker run --rm \
    -v /srv/data:/data:ro \
    -v /srv/bases:/bases:ro \
    -v /srv/resultats:/resultats \
    hash_tool --quiet verify /bases/hashes.b3 /data \
  >> /var/log/hash-integrity.log 2>&1 \
  || mail -s "ALERTE intégrité $(hostname)" admin@example.com
```

Voir le [guide CI/Cron](../guides/cron-ci.md) pour les patterns d'intégration avancés.

---

## Taille de l'image

| Couche | Taille approximative |
|---|---|
| Alpine 3.19 | ~7 Mo |
| bash + jq + coreutils + findutils | ~5 Mo |
| b3sum (depuis Alpine community) | ~2 Mo |
| Scripts hash_tool | < 100 Ko |
| **Total** | **~14 Mo** |

---

## Mise à jour de b3sum

`b3sum` est installé depuis les packages Alpine — mise à jour via rebuild de l'image :

```bash
docker build --no-cache -t hash_tool .
```

Pour vérifier la version embarquée :

```bash
docker run --rm hash_tool version
```
