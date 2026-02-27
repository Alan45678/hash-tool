# Interface CLI

## Interface `hash-tool`
Rôle du wrapper : point d'entrée unique abstrayant la couche d'exécution.
Syntaxe générale : `hash-tool <commande> [options]`. Liste complète des
commandes disponibles avec description en une ligne. Comportement de `help`
et `help <commande>`.

## Options globales
Tableau des options communes à toutes les commandes :
`-quiet` (mode silencieux), `-verbose` (mode verbeux), `-readonly`
(flag sidecar), `-meta <texte>` (commentaire sidecar), `-save <dossier>`
(dossier de sortie, surcharge `RESULTATS_DIR`).

## Dispatch et détection d'environnement
Logique de sélection du mode d'exécution : `_native_available()` vérifie
b3sum + jq + integrity.sh, `_docker_available()` vérifie docker + image locale.
Priorité : natif -> Docker -> erreur bloquante. Variable d'environnement
`HASH_TOOL_DOCKER_IMAGE` pour surcharger le nom de l'image.

## Variables d'environnement
Tableau des variables reconnues : `RESULTATS_DIR` (dossier de sortie par défaut),
`HASH_TOOL_DOCKER_IMAGE` (nom de l'image Docker). Priorité des valeurs :
argument CLI > variable d'environnement > valeur par défaut.
