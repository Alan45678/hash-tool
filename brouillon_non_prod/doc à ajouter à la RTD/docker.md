# Docker — hash_tool

Utilisation de hash_tool via Docker — aucune dépendance à installer sur l'hôte.

---

## Prérequis

- Docker >= 20.10 (support multi-platform)
- Optionnel : Docker Compose v2

---

## Build

```bash
# Build standard (amd64)
docker build -t hash_tool .

# Build pour ARM64 (NAS Synology DS923+, Raspberry Pi, Apple Silicon)
docker build --platform linux/arm64 -t hash_tool:arm64 .

# Build avec version b3sum spécifique
docker build --build-arg B3SUM_VERSION=1.5.4 -t hash_tool .
```

---

## Commandes disponibles

```
docker run [--rm] [-v ...] hash_tool <commande> [args]

  compute <dossier> <base.b3>           Calcule les hashes
  verify  <base.b3> [dossier]           Vérifie l'intégrité
  compare <ancienne.b3> <nouvelle.b3>   Compare deux bases
  runner  [pipeline.json]               Exécute un pipeline JSON
  shell                                 Shell bash interactif (debug)
  help                                  Aide
  version                               Versions des outils
```

---

## Exemples d'utilisation

### Compute — indexer un dossier

```bash
docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases \
  hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3
```

### Verify — vérifier l'intégrité

```bash
# Depuis le répertoire d'origine (même montage /data qu'au compute)
docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases:ro \
  -v /mes/resultats:/resultats \
  hash_tool verify /bases/hashes_2024-01-15.b3 /data
```

Le résultat (`recap.txt`, `failed.txt` si échec) est écrit dans `/resultats` sur l'hôte.

### Compare — deux snapshots

```bash
docker run --rm \
  -v /mes/bases:/bases:ro \
  -v /mes/resultats:/resultats \
  hash_tool compare /bases/hashes_2024-01-15.b3 /bases/hashes_2024-02-01.b3
```

Produit `recap.txt`, `modifies.b3`, `disparus.txt`, `nouveaux.txt`, `report.html`.

### Pipeline JSON complet

```bash
docker run --rm \
  -v /mes/donnees:/data:ro \
  -v /mes/bases:/bases \
  -v /mes/resultats:/resultats \
  -v /chemin/vers/pipeline.json:/pipelines/pipeline.json:ro \
  hash_tool runner
```

### Mode silencieux — CI/cron

```bash
# Exit code 0 si OK, non-nul si FAILED
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

## Volumes

| Volume | Usage | Recommandation |
|---|---|---|
| `/data` | Données à hacher | `:ro` (lecture seule) |
| `/bases` | Fichiers `.b3` | Lecture/écriture pour `compute` |
| `/pipelines` | Fichiers `pipeline.json` | `:ro` |
| `/resultats` | Résultats `verify`/`compare` | Lecture/écriture |

---

## Variable d'environnement

`RESULTATS_DIR` — dossier de résultats dans le conteneur (défaut : `/resultats`).

```bash
docker run --rm \
  -v /mes/resultats:/mon_dossier_custom \
  -e RESULTATS_DIR=/mon_dossier_custom \
  hash_tool verify /bases/hashes.b3
```

---

## Docker Compose

Adapter les chemins dans `docker-compose.yml` (section `x-volumes`), puis :

```bash
# Commande ponctuelle
docker compose run --rm integrity verify /bases/hashes.b3 /data
docker compose run --rm integrity compute /data /bases/hashes.b3

# Pipeline complet
docker compose run --rm pipeline

# Build et run pipeline
docker compose build && docker compose run --rm pipeline
```

---

## NAS Synology

Sur DSM 7.x avec Docker Manager ou Portainer :

```bash
# Chemin type sur Synology
docker run --rm \
  -v /volume1/data:/data:ro \
  -v /volume1/bases:/bases \
  -v /volume1/resultats:/resultats \
  hash_tool verify /bases/hashes.b3 /data
```

Pour ARM64 (DS220+, DS923+) : builder avec `--platform linux/arm64` ou utiliser une image pré-buildée.

---

## Cron sur serveur Debian

```bash
# /etc/cron.d/hash-integrity
0 3 * * * root docker run --rm \
  -v /srv/data:/data:ro \
  -v /srv/bases:/bases:ro \
  -v /srv/resultats:/resultats \
  hash_tool --quiet verify /bases/hashes.b3 /data \
  >> /var/log/hash-integrity.log 2>&1 \
  || mail -s "ALERTE intégrité $(hostname)" admin@example.com
```

---

## Taille de l'image

| Couche | Taille approx. |
|---|---|
| Alpine 3.19 base | ~7 Mo |
| bash + jq + coreutils + findutils | ~5 Mo |
| b3sum binaire musl | ~2 Mo |
| Scripts hash_tool | <100 Ko |
| **Total** | **~14 Mo** |

L'utilisation d'un binaire musl pré-compilé (stage `fetcher`) évite d'embarquer la toolchain Rust (~700 Mo) dans l'image finale.

---

## Mise à jour de b3sum

Modifier `ARG B3SUM_VERSION` dans le `Dockerfile` et rebuilder :

```bash
docker build --build-arg B3SUM_VERSION=1.6.0 -t hash_tool .
```

Les URLs de release suivent le pattern :
```
https://github.com/BLAKE3-team/BLAKE3/releases/download/<version>/b3sum_linux_amd64_musl
https://github.com/BLAKE3-team/BLAKE3/releases/download/<version>/b3sum_linux_aarch64_musl
```

La signature `.b3` est vérifiée automatiquement au build (le binaire se vérifie lui-même).
