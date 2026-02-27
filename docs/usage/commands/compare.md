# compare

## Syntaxe
```
hash-tool compare -old <ancienne.b3> -new <nouvelle.b3> [-save <dossier>] [-quiet]
```
Tableau des options. `-old` est la référence, `-new` est l'état à comparer.

## Comportement
Lecture et affichage des sidecars des deux bases si présents. Diff entre les
deux ensembles de hashes : fichiers modifiés (présents dans les deux, hash
différent), disparus (dans `-old`, absents de `-new`), nouveaux (absents de
`-old`, présents dans `-new`). Production des 5 fichiers de résultats.

## Fichiers produits
Description de chacun des 5 fichiers dans le dossier de résultats :
`disparus.txt`, `modifies.b3`, `nouveaux.txt`, `recap.txt`, `report.html`.
Format de chaque fichier et contenu typique.

## Codes de sortie
`0` : bases identiques, aucune différence. `1` : différences détectées
ou erreur d'exécution. Exploitable en script pour déclencher une alerte.

## Exemples
Comparaison avant/après migration, avec `-save` horodaté, résultat zéro
différence (migration parfaite).
