# Troubleshooting — Pipeline

## Erreur jq générique au lancement du runner
**Symptôme** : `parse error` ou `null` retourné par jq.
**Cause** : JSON malformé dans le fichier pipeline.
**Diagnostic** : `jq . pipeline.json` — valide la syntaxe et affiche l'erreur
avec numéro de ligne.
**Erreurs fréquentes** : virgule après le dernier élément d'un tableau (`},` avant `]`),
guillemets manquants sur les clés, accolades non fermées.

## Champ `op` non reconnu
**Symptôme** : runner signale une opération inconnue.
**Cause** : deux formats de pipeline coexistent dans le projet — `op` (format
historique de `pipeline.json`) et `type` (format amélioré de `pipeline-amelioree.json`).
Ils ne sont pas interchangeables selon la version du runner.
**Solution** : rester cohérent sur un seul format dans un même fichier. Vérifier
quel format est attendu par la version de `runner.sh` utilisée.

## Pipeline s'arrête à mi-exécution
**Comportement attendu** : `runner.sh` utilise `set -euo pipefail` — toute
commande en erreur arrête immédiatement le pipeline. Ce n'est pas un bug.
**Si l'arrêt est non désiré** : identifier l'étape qui échoue (message d'erreur
dans la sortie), corriger le problème sous-jacent. Pas de mode
`--continue-on-error` natif.

## Chemins relatifs dans le pipeline non résolus
**Symptôme** : "dossier introuvable" malgré un chemin qui semble correct.
**Cause** : les chemins relatifs dans le JSON sont résolus depuis le répertoire
du script `runner.sh`, pas depuis le CWD de l'utilisateur.
**Solution** : utiliser exclusivement des chemins absolus dans les fichiers
pipeline destinés à la production.
