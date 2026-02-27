# Tutoriel 1 — Premier audit d'intégrité

## Situation de départ
Description du contexte : dossier de données à protéger, objectif de détecter
toute altération future. Présentation de `mon_dossier/_data-source/` utilisé
comme support : 4 fichiers lorem-ipsum, état initial connu.

## Étape 1 — Calculer les empreintes
Commande complète avec `-data`, `-save`, `-meta`. Sortie terminal attendue
montrée ligne par ligne. Explication des deux fichiers produits :
`hashes__data-source.b3` et `hashes__data-source.b3.meta.json`.

## Étape 2 — Inspecter la base produite
Commande `hash-tool stats` sur la base créée. Sortie commentée : nombre de
fichiers, distribution des extensions, contenu du sidecar avec le commentaire
saisi à l'étape précédente.

## Étape 3 — Vérifier l'intégrité (cas nominal)
Commande `verify` sur le même dossier sans modification. Sortie attendue :
tous les fichiers OK. Signification du code de sortie `0`.

## Étape 4 — Simuler une altération
Instruction explicite : ajouter un caractère dans `lorem-ipsum-01-modif.txt`.
Relancer `verify`. Sortie d'erreur complète montrée. Explication de chaque
ligne : fichier incriminé, hash attendu vs hash calculé.

## Étape 5 — Lire les fichiers de résultats
Contenu réel de `recap.txt` et `failed.txt` produits dans `RESULTATS_DIR`.
Chaque champ annoté. Distinction erreur d'exécution vs fichier corrompu.

## Ce que vous savez maintenant faire
Récapitulatif des commandes maîtrisées : `compute`, `stats`, `verify`.
Lien vers Tutoriel 2 pour le cas migration.
