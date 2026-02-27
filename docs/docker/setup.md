# Setup Docker

## Build de l'image
Commande standard : `docker build -t hash_tool .`. Build multi-arch ARM64 :
`docker build --platform linux/arm64 -t hash_tool:arm64 .`. Le build doit
être lancé depuis la racine du dépôt (présence du `Dockerfile`).
Taille de l'image produite : ~15 Mo (base Alpine 3.19).

## Dépendances installées
Liste des packages Alpine installés : bash, jq, b3sum (depuis community),
coreutils, findutils. Aucun binaire téléchargé depuis GitHub - tout depuis
`apk`. Justification de ce choix (fiabilité, reproductibilité).

## Entrypoint
Rôle de `docker/entrypoint.sh` : dispatch des commandes vers `integrity.sh`
ou `runner.sh`. Commandes supportées : `compute`, `verify`, `compare`,
`runner`, `shell` (debug interactif), `help`. Commande inconnue -> exit non-zéro.

## Variables d'environnement
`RESULTATS_DIR` : dossier de sortie dans le conteneur (défaut : `/resultats`).
Doit correspondre à un volume monté. `HASH_TOOL_DOCKER_IMAGE` : non applicable
dans le conteneur, utilisée par `hash-tool` côté hôte.
