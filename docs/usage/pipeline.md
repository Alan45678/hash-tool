# Pipelines JSON

## Format pipeline.json
Schéma JSON complet : objet racine `pipeline` contenant un tableau d'opérations.
Champs obligatoires par type d'opération. Champs optionnels (`options`, `meta`,
`description`). Deux formats coexistants : champ `op` (format historique)
vs champ `type` (format amélioré) - ne pas mélanger dans un même fichier.

## Opérations supportées
Description de chaque opération avec ses champs spécifiques :
`compute` (source, bases, nom), `verify` (source, base), `compare`
(base_a, base_b, resultats). Correspondance exacte avec les commandes CLI.

## Exécution
Commande : `hash-tool runner -pipeline <fichier.json> [-save <dossier>]`.
Comportement séquentiel : les opérations s'exécutent dans l'ordre du tableau.
Arrêt immédiat en cas d'échec d'une étape (`set -euo pipefail`).

## Chemins dans le pipeline
Les chemins relatifs sont résolus depuis le répertoire du script `runner.sh`,
pas depuis le CWD de l'utilisateur. Règle pratique : toujours utiliser des
chemins absolus dans les pipelines en production.

## Pipelines d'exemple fournis
Description et cas d'usage de chacun des 4 pipelines livrés :
`pipeline.json`, `pipeline-debug.json`, `pipeline-debug-deux-adresses.json`,
`pipeline-veracrypt.json`. Lien vers `guides/veracrypt.md` pour le détail
du cas VeraCrypt.
