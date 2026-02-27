# Installation

## Installation native
Étapes : clonage du dépôt, application des permissions (`chmod +x` sur `hash-tool`,
`runner.sh`, `src/integrity.sh`), vérification avec `hash-tool check-env`.
Sortie attendue de `check-env` ligne par ligne commentée.

## Build Docker
Commande de build standard : `docker build -t hash_tool .`. Build multi-arch
pour ARM64 : `docker build --platform linux/arm64 -t hash_tool:arm64 .`.
Vérification que l'image est disponible : `docker image inspect hash_tool`.

## Vérification de l'installation
Commande de validation finale : `hash-tool version` puis `hash-tool check-env`.
Sortie complète attendue dans les deux cas. Indicateurs visuels OK/KO expliqués.
Mode d'exécution sélectionné affiché en fin de `check-env`.
