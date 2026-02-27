# Guide — Vérification d'une migration

## Cas d'usage
Copie de disque, migration serveur, transfert NAS, duplication d'archive.
Objectif : certifier que chaque fichier de la source est présent et identique
dans la destination après l'opération.

## Workflow complet
1. `compute` sur la source avant migration (avec `-meta` documentant la date)
2. Exécuter la migration
3. `compute` sur la destination après migration
4. `compare` entre les deux bases
5. Lecture du rapport : 0 modifié + 0 disparu + 0 nouveau = migration validée

## Interpréter les écarts
Fichiers modifiés : erreur de copie, corruption en transit — à recopier.
Fichiers disparus : non transférés — à identifier et recopier.
Fichiers nouveaux : ajoutés côté destination pendant la migration (fichiers
système, logs) — à qualifier et décider de leur légitimité.

## Pipeline recommandé
Référence à `pipeline-amelioree.json` qui enchaîne compute source, verify
immédiat, compute destination, compare — en une seule exécution.
Avantage : le verify intermédiaire détecte un problème de compute avant
de lancer la migration.

## Cas particulier — deux chemins non relatifs
Quand source et destination sont sur des disques ou machines différentes,
utiliser `pipeline-debug-deux-adresses.json` comme base avec chemins absolus.
