# stats

## Syntaxe
```
hash-tool stats -base <fichier.b3>
```
`-base` : fichier `.b3` à analyser (obligatoire).

## Affichage
Chemin absolu du fichier base, taille du fichier `.b3`, nombre total de
fichiers indexés. Top 10 des extensions les plus fréquentes avec leur
compteur. Contenu complet du sidecar `.meta.json` si présent.

## Usage typique
Audit rapide d'une base avant de lancer un `verify` ou `compare` : s'assurer
que la base contient le bon nombre de fichiers et correspond au bon dossier
(via les métadonnées sidecar). Détection immédiate d'une base vide ou tronquée.

## Exemples
Sortie complète sur une base avec sidecar. Sortie sur une base sans sidecar.
