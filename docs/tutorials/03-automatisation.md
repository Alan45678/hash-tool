# Tutoriel 3 - Automatiser avec un pipeline JSON

## Situation de départ
Le workflow T2 (compute + compute + compare) est répétitif. Objectif : définir
une fois les chemins et opérations dans un fichier JSON, lancer tout en une
seule commande, résultats reproductibles sans erreur de saisie.

## Étape 1 - Anatomie d'un pipeline JSON
Déconstruction de `pipelines/pipeline.json` champ par champ. Tableau :
clé -> rôle -> valeur exemple -> obligatoire/optionnel. Distinction entre
les trois opérations : `compute`, `verify`, `compare` et leurs champs spécifiques.

## Étape 2 - Écrire votre premier pipeline
Construction pas à pas d'un pipeline à 3 opérations sur les données de
`examples/`. Fichier JSON complet montré en fin de section.
Validation préalable : `jq . pipeline.json` pour détecter les erreurs de syntaxe.

## Étape 3 - Lancer le pipeline
Commande `hash-tool runner` avec `-pipeline` et `-save`. Sortie terminal
complète : chaque étape loggée séquentiellement, résumé final.

## Étape 4 - Analyser les résultats produits
Même lecture que T2 mais en soulignant que les 3 opérations ont été exécutées
en une seule invocation. Dossier de résultats produit automatiquement.

## Étape 5 - Pipelines fournis en exemple
Tableau des 4 pipelines livrés avec le projet :
`pipeline.json` (base, chemins relatifs), `pipeline-debug.json` (debug local),
`pipeline-debug-deux-adresses.json` (chemins absolus mixtes),
`pipeline-veracrypt.json` (volumes chiffrés Windows/WSL).
Ce qui différencie chacun et quand l'utiliser.

## Étape 6 - Lancer via Docker
Même pipeline, exécution via Docker. Commande `docker run` complète avec
montages `-v` pour chaque volume. Mapping chemin hôte -> chemin conteneur
expliqué pour chaque opération du pipeline.

## Aller plus loin - Planifier l'exécution
Extrait cron Linux pour exécution nocturne. Référence au service `cron`
dans `docker-compose.yml` (profil). Lien vers `guides/automation.md`
pour le setup complet.

## Ce que vous savez maintenant faire
Récapitulatif des 3 tutoriels enchaînés. L'utilisateur maîtrise le workflow
complet : audit unitaire, vérification de migration, automatisation par pipeline.
