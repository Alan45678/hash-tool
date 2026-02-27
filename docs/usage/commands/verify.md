# verify

## Syntaxe
```
hash-tool verify -base <fichier.b3> [-data <dossier>] [-save <dossier>] [-quiet]
```
Tableau des options avec description, obligatoire/optionnel et valeur par défaut.

## Comportement
Lecture et affichage du sidecar `.meta.json` si présent. Comparaison hash par hash
entre la base et l'état actuel du dossier. Les chemins dans la base sont utilisés
tels quels — le répertoire de travail au moment du `verify` doit être cohérent
avec celui du `compute`. Fichiers de résultats écrits dans `RESULTATS_DIR`.

## Interprétation des résultats
Trois catégories de fichiers dans le rapport : OK (hash identique), modifiés
(hash différent), disparus (présents dans la base, absents sur disque). Fichiers
`recap.txt` et `failed.txt` produits en cas d'anomalie.

## Codes de sortie
`0` : intégrité confirmée, tous les fichiers OK. `1` : anomalie détectée
(fichiers modifiés ou disparus) ou erreur d'exécution. Distinction importante
pour l'intégration en script ou CI.

## Exemples
Vérification nominale, avec `-data` explicite, avec `-save` pour archiver
les résultats, en mode `-quiet` pour usage en cron.
