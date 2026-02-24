# Guide - NAS Synology

Déploiement et usage de hash_tool sur NAS Synology avec Docker.

---

## Prérequis

- DSM 7.x
- **Container Manager** (anciennement Docker Manager) installé depuis le Centre de paquets
- Accès SSH au NAS (`ssh admin@192.168.1.x`)

---

## Déterminer l'architecture

```bash
# Via SSH
uname -m
# amd64 → DS920+, DS923+, DS1621+, ...
# aarch64 (arm64) → DS220+, DS420+, DS720+, DS923+ avec CPU AMD
```

| Modèle (exemples) | Architecture |
|---|---|
| DS920+, DS1621+, RS1221+ | amd64 |
| DS220+, DS420+, DS720+ | arm64 (aarch64) |
| DS923+ | amd64 (Ryzen R1600) |

---

## Installation

### Via SSH

```bash
# Se connecter au NAS
ssh admin@192.168.1.x

# Cloner ou copier hash_tool
cd /volume1/docker
git clone https://github.com/hash_tool/hash_tool.git
cd hash_tool

# Build de l'image (adapter la plateforme)
# amd64
docker build -t hash_tool .

# arm64 (DS220+, DS420+...)
docker build --platform linux/arm64 -t hash_tool:arm64 .
```

### Vérifier l'image

```bash
docker run --rm hash_tool version
# hash_tool
#   b3sum : b3sum 1.x.x
#   jq    : jq-1.x
#   bash  : 5.x.x
```

---

## Structure recommandée sur le NAS

```
/volume1/
├== docker/
│   └== hash_tool/          ← scripts et Dockerfile
├== data/                   ← données à surveiller (ou sous-dossiers par partage)
│   ├== photos/
│   ├== documents/
│   └== backups/
├== bases/                  ← fichiers .b3 (séparés des données)
│   ├== hashes_photos.b3
│   ├== hashes_documents.b3
│   └== hashes_backups.b3
└== rapports/               ← résultats verify/compare
    └== ...
```

---

## Utilisation via SSH

### Compute

```bash
docker run --rm \
  -v /volume1/data/photos:/data:ro \
  -v /volume1/bases:/bases \
  hash_tool compute /data /bases/hashes_photos_$(date +%Y-%m-%d).b3
```

### Verify

```bash
docker run --rm \
  -v /volume1/data/photos:/data:ro \
  -v /volume1/bases:/bases:ro \
  -v /volume1/rapports:/resultats \
  hash_tool verify /bases/hashes_photos.b3 /data
```

### Pipeline complet

```bash
docker run --rm \
  -v /volume1/data:/data:ro \
  -v /volume1/bases:/bases \
  -v /volume1/rapports:/resultats \
  -v /volume1/docker/hash_tool/pipelines/pipeline.json:/pipelines/pipeline.json:ro \
  hash_tool runner
```

---

## Automatisation via le planificateur de tâches DSM

DSM dispose d'un planificateur de tâches intégré (Panneau de configuration → Planificateur de tâches).

### Créer une tâche planifiée

1. **Panneau de configuration** → **Planificateur de tâches** → **Créer** → **Tâche planifiée** → **Script défini par l'utilisateur**
2. Onglet **Général** : nommer la tâche, sélectionner l'utilisateur `root`
3. Onglet **Calendrier** : configurer la fréquence (ex : hebdomadaire, dimanche 03h00)
4. Onglet **Paramètres de la tâche** : coller le script ci-dessous

### Script de tâche planifiée

```bash
#!/bin/bash

LOG="/volume1/rapports/hash-integrity.log"
MAILTO="admin@example.com"

echo "$(date) - Démarrage vérification intégrité" >> "$LOG"

docker run --rm \
  -v /volume1/data:/data:ro \
  -v /volume1/bases:/bases:ro \
  -v /volume1/rapports:/resultats \
  hash_tool --quiet verify /bases/hashes.b3 /data \
  >> "$LOG" 2>&1

EXIT=$?

if [ $EXIT -ne 0 ]; then
    echo "$(date) - ALERTE : vérification échouée (exit $EXIT)" >> "$LOG"
    # Notification email DSM - nécessite la configuration SMTP dans le Panneau de configuration
    # synonotify -e "hash_tool : corruption détectée sur $(hostname)"
fi

echo "$(date) - Fin (exit $EXIT)" >> "$LOG"
exit $EXIT
```

### Notifications DSM natives

Pour utiliser le système de notification DSM :

```bash
# Envoyer une notification DSM (email, push, SMS selon config)
synodsmnotify @administrators "hash_tool" "Corruption détectée sur $(/bin/hostname)"
```

---

## Docker Compose sur Synology

Adapter `docker-compose.yml` avec les chemins Synology :

```yaml
x-volumes:
  data:      &vol-data      /volume1/data
  bases:     &vol-bases     /volume1/bases
  pipelines: &vol-pipelines /volume1/docker/hash_tool/pipelines
  resultats: &vol-resultats /volume1/rapports
```

Puis via Container Manager (interface graphique DSM) ou SSH :

```bash
cd /volume1/docker/hash_tool
docker compose run --rm integrity verify /bases/hashes.b3 /data
```

---

## Dépannage

### L'image ne se build pas sur ARM64

```bash
# Vérifier l'architecture
uname -m   # doit afficher aarch64

# Builder avec la plateforme explicite
docker build --platform linux/arm64 -t hash_tool:arm64 .

# Tagger pour utiliser sans suffixe
docker tag hash_tool:arm64 hash_tool
```

### Permission denied sur /volume1

```bash
# Les conteneurs Docker tournent en root par défaut
# Vérifier que les dossiers sont accessibles
ls -la /volume1/data
ls -la /volume1/bases

# Adapter les permissions si nécessaire
chmod 755 /volume1/bases
```

### Container Manager ne trouve pas l'image

Après build via SSH, l'image apparaît dans Container Manager → Images. Si elle n'apparaît pas, rafraîchir ou relancer le service Docker :

```bash
sudo synoservicectl --restart pkgctl-ContainerManager
```
