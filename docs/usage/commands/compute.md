# compute

## Syntaxe
```
hash-tool compute -data <dossier> [-save <dossier>] [-meta <texte>] [-readonly] [-quiet]
```
Tableau des options avec description, caractère obligatoire/optionnel et valeur par défaut.

## Comportement
Calcul BLAKE3 récursif sur tous les fichiers du dossier via b3sum. Les chemins
dans le `.b3` sont relatifs au dossier analysé. Nommage automatique du fichier
de sortie : `hashes_<nom_dossier>.b3`. Création du dossier `-save` si absent.

## Sidecar généré
Contenu complet du `.meta.json` produit : `created_by`, `date` (ISO 8601 UTC),
`comment` (valeur de `-meta`), `parameters.directory`, `parameters.hash_algo`,
`parameters.readonly`, `parameters.nb_files`. Le sidecar est toujours créé,
même si `-meta` est vide.

## Codes de sortie
`0` : succès. `1` : erreur (dossier introuvable, permission refusée, b3sum absent).

## Exemples
Cas nominal, avec métadonnée, en lecture seule, avec dossier de sauvegarde explicite.
