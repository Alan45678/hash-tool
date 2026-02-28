# Troubleshooting - Docker

## Exécution Docker lente sur WSL2

**Symptôme** : `compute` sur quelques fichiers prend plusieurs secondes, 
sur 1000+ fichiers c'est inutilisable.

**Cause** : trois facteurs cumulés :
- Overhead de démarrage du conteneur (~1-2s par appel)
- `b3sum` appelé une fois par fichier (pas en batch)
- Accès aux volumes WSL2 via un pont réseau lent

**Solution recommandée** : installer les dépendances nativement dans WSL2.
`hash-tool` bascule automatiquement en mode natif si `b3sum` et `jq` sont disponibles.

\`\`\`bash
sudo apt-get install -y jq
sudo wget https://github.com/BLAKE3-team/BLAKE3/releases/latest/download/b3sum_linux_x64_musl \
  -O /usr/local/bin/b3sum
sudo chmod +x /usr/local/bin/b3sum
\`\`\`

## Volumes montés mais fichiers non trouvés dans le conteneur
**Symptôme** : `compute` ou `verify` retourne "dossier introuvable".
**Cause** : chemin hôte relatif passé à `-v` - Docker exige des chemins absolus.
**Diagnostic** : `docker run --rm -v <chemin>:/data hash_tool shell` puis `ls /data`.
**Solution** : `docker run -v $(pwd)/examples:/data ...` ou chemin absolu explicite.

## Permission denied sur `/bases` ou `/resultats`
**Symptôme** : erreur d'écriture lors du `compute` ou `compare`.
**Cause** : UID du processus Alpine dans le conteneur (root = UID 0) différent
du propriétaire des fichiers hôte, ou dossier hôte créé avec des permissions restrictives.
**Solution** : `docker run --user $(id -u):$(id -g) ...` ou `chmod 777` sur le
dossier hôte (moins recommandé).

## `/data` monté en `:ro` mais `compute` échoue à écrire la base
**Symptôme** : `Permission denied` sur l'écriture du `.b3`.
**Cause** : tentative d'écrire la base dans `/data` monté en lecture seule.
**Solution** : séparer les volumes - données dans `-v .../data:/data:ro`,
bases dans `-v .../bases:/bases` (lecture/écriture). La base s'écrit dans `/bases`.

## Fallback Docker non déclenché alors que b3sum est absent
**Symptôme** : `check-env` signale `EXEC_MODE=none` alors que Docker est installé.
**Cause** : `_docker_available()` vérifie `docker image inspect hash_tool` -
si l'image n'est pas buildée localement, le fallback ne s'active pas.
**Solution** : `docker build -t hash_tool .`

## ARM64 / NAS Synology : image incompatible
**Symptôme** : `exec format error` au lancement du conteneur.
**Cause** : image buildée pour amd64, conteneur exécuté sur ARM64.
**Solution** : `docker build --platform linux/arm64 -t hash_tool:arm64 .`
Vérification de l'architecture cible : `uname -m` sur le NAS.
