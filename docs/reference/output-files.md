# Fichiers de résultats

Produits dans `RESULTATS_DIR` par les commandes `verify` et `compare`.

## `recap.txt`
Synthèse chiffrée de l'opération : nombre de fichiers OK, modifiés, disparus,
nouveaux. Date et heure d'exécution. Chemin de la base utilisée. Format texte
brut, lisible par un script. Toujours produit, même si tout est OK.

## `modifies.b3`
Fichiers présents dans les deux bases avec un hash différent. Format identique
au `.b3` standard — peut être relu par b3sum. Contient les deux lignes
(ancienne et nouvelle) pour chaque fichier modifié, permettant de voir les
deux hashes. Absent ou vide si aucun fichier modifié.

## `disparus.txt`
Liste des fichiers présents dans la base de référence (ou au moment du `compute`)
et introuvables lors de la vérification. Un chemin par ligne. Absent ou vide
si aucun fichier disparu.

## `nouveaux.txt`
Liste des fichiers présents sur disque mais absents de la base de référence.
Un chemin par ligne. Absent ou vide si aucun nouveau fichier.

## `report.html`
Rapport visuel généré depuis `reports/template.html`. Sections : résumé
statistique, liste des fichiers modifiés avec les deux hashes, liste des
disparus, liste des nouveaux. Ouvrir dans un navigateur. Toujours produit
par `compare`, produit par `verify` uniquement si des anomalies sont détectées.

## `failed.txt`
Produit par `verify` uniquement. Liste des fichiers en erreur : hash différent
ou fichier inaccessible. Format : chemin + statut (FAIL ou ERROR).
