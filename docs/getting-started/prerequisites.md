# Prérequis

## Dépendances natives
Liste des dépendances requises pour l'exécution native : bash >= 4, b3sum, jq.
Version minimale de chaque outil. Commandes de vérification (`bash --version`,
`b3sum --version`, `jq --version`). Liens d'installation par OS (Alpine,
Debian/Ubuntu, macOS).

## Dépendances Docker
Docker Engine version minimale requise. Commande de vérification (`docker --version`).
L'image `hash_tool` doit être buildée localement - elle n'est pas publiée sur
Docker Hub. Lien vers `docker/setup.md`.

## Compatibilité OS
Tableau des environnements testés et supportés : Linux (Debian, Ubuntu, Alpine),
macOS (bash via brew requis), Windows via WSL2, NAS Synology (ARM64 via Docker).
Notes spécifiques par plateforme (bash système macOS = 3.x, incompatible).
