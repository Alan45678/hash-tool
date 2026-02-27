# hash_tool

## Vue d'ensemble
Présentation du projet : outil CLI de vérification d'intégrité par hachage BLAKE3.
Cas d'usage principaux : audit avant archivage, contrôle après migration, surveillance
périodique de volumes chiffrés. Principe de fonctionnement en une phrase.

## Fonctionnalités clés
Tableau synthétique des 7 commandes disponibles (compute, verify, compare, list,
diff, stats, runner) avec description en une ligne et cas d'usage principal de chacune.

## Modes d'exécution
Explication de la dualité natif / Docker. Logique de détection automatique :
b3sum + jq disponibles -> natif, sinon -> Docker en fallback. L'interface CLI
reste identique dans les deux cas. Lien vers `getting-started/installation.md`.

## Navigation rapide
Orientation selon le profil : premier usage -> Getting Started, apprentissage
par la pratique -> Tutorials, référence d'une commande -> Usage, problème -> Troubleshooting.
