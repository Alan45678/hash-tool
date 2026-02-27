# Volumes Docker

## Volumes définis
Quatre volumes utilisés par le conteneur :
`/data` (données à hacher), `/bases` (fichiers `.b3`),
`/pipelines` (fichiers `pipeline.json`), `/resultats` (sorties).

## Règles de montage
`/data` : monter en lecture seule (`:ro`) — le conteneur ne doit jamais
modifier les données source. `/bases` : lecture/écriture — les `.b3`
et sidecars sont écrits ici. `/resultats` : lecture/écriture — résultats
`verify` et `compare` écrits ici. `/pipelines` : lecture seule suffisante.

## Mapping par commande
Tableau : pour chaque commande (`compute`, `verify`, `compare`, `runner`),
quels volumes sont requis et avec quel mode d'accès.
Erreur fréquente : tenter d'écrire la base dans `/data` monté en `:ro`.

## Exemples de montage
Commandes `docker run` complètes avec tous les `-v` pour chaque cas d'usage.
Convention de nommage des chemins hôte selon l'OS :
Linux (`/srv/...`), macOS (`/Users/...`), WSL (`/mnt/c/...`), NAS (`/volume1/...`).
