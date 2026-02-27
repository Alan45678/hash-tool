# Troubleshooting — Résultats

## `report.html` vide ou non généré
**Symptôme** : fichier `report.html` absent ou de taille 0.
**Cause** : `reports/template.html` introuvable au moment de la génération.
`report.sh` cherche le template relativement à `SCRIPT_DIR`.
**Diagnostic** : vérifier que `reports/template.html` est présent à la racine
du dépôt. En mode Docker, le template n'est pas copié dans l'image —
à vérifier dans le Dockerfile si une version personnalisée est utilisée.

## `modifies.b3` contient des fichiers visiblement non modifiés
**Cause** : problème de préfixes de chemins entre les deux bases comparées —
même cause que le faux positif massif dans `compare`.
**Lien** : voir `troubleshooting/execution.md` — section "compare retourne
des milliers de modifiés inattendus".

## `RESULTATS_DIR` non respecté — résultats écrits ailleurs
**Symptôme** : les résultats apparaissent dans un dossier inattendu.
**Priorité de la variable** : argument `-save` CLI > variable d'environnement
`RESULTATS_DIR` > valeur par défaut du script.
**Diagnostic** : `echo $RESULTATS_DIR` avant lancement. En Docker, vérifier
que `-e RESULTATS_DIR=/resultats` est bien passé à `docker run`.

## Dossier de résultats écrasé à chaque exécution
**Comportement attendu** : le dossier est recréé à chaque exécution — les
résultats précédents sont écrasés. C'est intentionnel.
**Pour conserver l'historique** : utiliser `-save` avec un chemin horodaté :
```bash
hash-tool verify -base ./bases/hashes.b3 -save ./resultats/$(date +%Y%m%d_%H%M%S)
```
