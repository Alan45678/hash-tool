# diff

## Syntaxe
```
hash-tool diff -base <fichier.b3> [-data <dossier>]
```
`-base` : base de référence (obligatoire). `-data` : dossier courant à comparer
(défaut : répertoire courant).

## Comportement
Comparaison des chemins de fichiers uniquement - les hashes ne sont pas
recalculés. Détecte : fichiers disparus (présents dans la base, absents
sur disque) et nouveaux fichiers non indexés (présents sur disque, absents
de la base). Rapide car aucun calcul cryptographique.

## Différence avec `compare`
`diff` compare une base et un dossier sans recalcul : détecte les absences
et ajouts mais pas les modifications de contenu. `compare` compare deux bases
déjà calculées : détecte aussi les modifications. Utiliser `diff` pour un
diagnostic rapide, `compare` pour une vérification complète.

## Exemples
Diagnostic rapide après suspicion d'ajout/suppression de fichiers. Sortie
commentée : section "disparus", section "nouveaux".
