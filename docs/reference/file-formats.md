# Formats de fichiers

## Format `.b3`
Structure d'une ligne : hash BLAKE3 (64 caractères hexadécimaux) + deux espaces
+ chemin relatif du fichier. Compatible avec la sortie native de `b3sum`.
Encodage : UTF-8. Un fichier par ligne. Pas d'en-tête. Exemple de ligne réelle.

## Chemins relatifs dans la base
Les chemins sont relatifs au répertoire de travail au moment du `compute`.
Convention de préfixe `./` ou préfixe de sous-dossier selon la commande
utilisée. Impact direct sur `verify` : le répertoire de travail au moment
du `verify` doit être cohérent avec celui du `compute`. C'est la source
d'erreur la plus fréquente - lien vers `troubleshooting/execution.md`.

## `.gitignore` et `.dockerignore`
Ce qui est exclu et pourquoi :
`.gitignore` exclut `*.b3`, `resultats/`, `integrity_resultats/`, `site/`
(doc générée), fichiers temporaires, OS, éditeurs.
`.dockerignore` exclut `examples/`, `tests/`, `docs/`, `*.md` (sauf README).
Rationalité : les données utilisateur et résultats ne vont jamais dans l'image.
