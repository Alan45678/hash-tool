# Fichier sidecar `.meta.json`

## Rôle
Fichier JSON accolé à chaque base `.b3` (`<base>.b3.meta.json`). Stocke les
métadonnées de contexte au moment du `compute` : qui a créé la base, quand,
sur quel dossier, avec quels paramètres. Affiché automatiquement par `verify`,
`compare`, `stats` et `list`.

## Schéma complet
```json
{
  "created_by": "hash-tool v2.0.0",
  "date": "2024-01-01T03:00:00Z",
  "comment": "Snapshot initial - avant archivage",
  "parameters": {
    "directory": "/chemin/absolu/vers/dossier",
    "hash_algo": "blake3",
    "readonly": false,
    "nb_files": 1234
  }
}
```
Description de chaque champ : type, format, source de la valeur.

## Lecture automatique
`verify` et `compare` affichent le sidecar en tête d'exécution avec délimiteurs
visuels. `stats` affiche le sidecar en fin de sortie. `list` affiche le
commentaire et la date sur une ligne dédiée.

## Absence de sidecar
Comportement si le sidecar est absent : les commandes fonctionnent normalement,
le sidecar est simplement ignoré. Pas d'erreur. Les bases créées avec la v1.x
(sans sidecar) restent pleinement utilisables.
