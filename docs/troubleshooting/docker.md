# Troubleshooting - Docker

## Volumes montés mais fichiers non trouvés dans le conteneur
**Symptôme** : `compute` ou `verify` retourne "dossier introuvable".
**Cause** : chemin hôte relatif passé à `-v` - Docker exige des chemins absolus.
**Diagnostic** : `docker run --rm -v <chemin>:/data hash_tool shell` puis `ls /data`.
**Solution** : `docker run -v $(pwd)/mon_dossier:/data ...` ou chemin absolu explicite.

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
