# list

## Syntaxe
```
hash-tool list [-data <dossier>]
```
Option `-data` : dossier à parcourir. Défaut : répertoire courant.
Profondeur de recherche : 2 niveaux maximum.

## Affichage
Pour chaque base `.b3` trouvée : nom du fichier, nombre de fichiers indexés,
taille du fichier `.b3`, indicateur `[+meta]` si sidecar présent.
Si sidecar présent : commentaire et date de création affichés en dessous.
Résultats triés par nom.

## Utilité
Inventaire rapide des bases disponibles avant de lancer un `verify` ou `compare`.
Permet de vérifier qu'une base existe et contient le bon nombre de fichiers
sans l'ouvrir.

## Exemples
Listage dans le dossier courant, avec `-data` explicite sur un dossier de bases.
Sortie commentée avec et sans sidecars.
