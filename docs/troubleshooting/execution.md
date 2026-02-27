# Troubleshooting - Exécution

## `verify` échoue sur tous les fichiers alors que rien n'a changé
**Symptôme** : 100% des fichiers en FAIL, pourtant les données sont intactes.
**Cause principale** : la base a été calculée depuis un répertoire de travail
différent de celui utilisé pour `verify`. Les chemins relatifs dans le `.b3`
ne correspondent plus.
**Diagnostic** : `head -3 <fichier.b3>` - inspecter le préfixe des chemins.
S'il commence par `./sous-dossier/` mais que vous êtes dans un autre répertoire,
c'est la cause.
**Solution** : toujours lancer `compute` et `verify` depuis le même répertoire
parent, ou utiliser `-data` avec le chemin absolu explicite.

## `compute` produit un `.b3` vide
**Symptôme** : fichier `.b3` créé mais vide (0 ligne).
**Cause** : dossier vide, permissions insuffisantes en lecture, ou tous les
fichiers sont des répertoires (b3sum ne hache que les fichiers réguliers).
**Diagnostic** : `find <dossier> -type f | wc -l` - doit retourner > 0.
`ls -la <dossier>` - vérifier les permissions.

## `compare` retourne des milliers de "modifiés" inattendus
**Symptôme** : `modifies.b3` contient des fichiers non modifiés.
**Cause** : les deux bases ont été calculées depuis des répertoires de travail
différents - les préfixes de chemins diffèrent, donc aucun fichier ne matche.
**Diagnostic** : `head -1 ancienne.b3` vs `head -1 nouvelle.b3` - comparer
les préfixes.
**Solution** : recalculer les deux bases de façon cohérente depuis le même
répertoire parent.

## Codes de sortie
| Code | Signification |
|------|---------------|
| `0`  | Succès - intégrité confirmée ou bases identiques |
| `1`  | Anomalie détectée (fichiers modifiés/disparus) **ou** erreur d'exécution |

Le code `1` sur anomalie détectée est **intentionnel** - exploitable en script
pour déclencher une alerte. Ne pas confondre avec une erreur de l'outil.

## Espaces ou caractères spéciaux dans les chemins
b3sum gère les espaces dans les noms de fichiers. Utiliser des guillemets
autour des chemins passés à `-data` et `-base`. Chemins avec `$` ou
backticks : utiliser des guillemets simples.
