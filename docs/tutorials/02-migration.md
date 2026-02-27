# Tutoriel 2 - Vérifier une migration de données

## Situation de départ
Contexte : `_data-source/` copié vers `_data-destination/`. La copie est-elle
parfaite ? `lorem-ipsum-01-modif.txt` diffère intentionnellement entre les deux
dossiers - c'est le défaut à détecter. Aucune modification manuelle requise,
les données de test sont déjà dans cet état.

## Étape 1 - Calculer les empreintes de la source
Commande `compute` sur `_data-source/` avec `-meta "Source - avant migration"`.
Résultat : `hashes__data-source.b3` produit.

## Étape 2 - Calculer les empreintes de la destination
Commande `compute` sur `_data-destination/` avec `-meta "Destination - après migration"`.
Résultat : `hashes__data-destination.b3` produit. Importance de sauvegarder
les deux bases dans le même dossier `bases/`.

## Étape 3 - Comparer les deux bases
Commande `compare` avec `-old`, `-new`, `-save`. Sortie terminal complète
montrée avec les compteurs : 1 modifié, 0 disparu, 0 nouveau.

## Étape 4 - Lire les résultats
Parcours de chaque fichier produit dans le dossier de résultats :
`recap.txt` (synthèse chiffrée), `modifies.b3` (`lorem-ipsum-01-modif.txt`
apparaît ici avec les deux hashes), `disparus.txt` (vide - explication),
`nouveaux.txt` (vide - explication), `report.html` (description des sections).

## Étape 5 - Interpréter et décider
Arbre de décision : modifiés -> erreur de copie à corriger / disparus -> fichier
non transféré / nouveaux -> fichier parasite à identifier. Critères de validation
d'une migration : 0 modifié, 0 disparu, 0 nouveau.

## Variante - Deux machines ou deux disques
Référence à `pipeline-debug-deux-adresses.json` : chemins absolus mixtes,
adaptation quand source et destination sont sur des montages différents
(disques, WSL, NAS).

## Ce que vous savez maintenant faire
Récapitulatif : cycle compute -> compute -> compare. Lien vers Tutoriel 3
pour automatiser ce workflow en pipeline.
