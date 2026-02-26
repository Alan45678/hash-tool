Aucun des deux n'est pertinent ici — ce sont des fichiers Python (`pip`/`conda`).

**hash_tool est un projet bash pur.** Les dépendances sont des binaires système, pas des packages Python. Le fichier équivalent existe déjà dans le projet : `requirements-docs.txt` qui gère uniquement MkDocs (la doc), pas le code.

**Pour les dépendances runtime du projet lui-même**, les conventions bash sont :

Le plus courant et le plus adapté à votre cas est de documenter dans un script de vérification ou directement dans `check-env`. Vous avez déjà `hash-tool check-env` qui joue exactement ce rôle. C'est la solution idiomatique pour un projet shell.

Si vous voulez quand même un fichier déclaratif formel pour l'intégration CI ou les contributeurs, la convention bash est un fichier texte simple à la racine :

```
# dependencies — hash_tool
# Binaires système requis (installables via apt / brew / apk)

bash>=4
b3sum
jq
find        # GNU coreutils
sort        # GNU coreutils
awk         # GNU coreutils
comm        # GNU coreutils
join        # GNU coreutils
stat        # GNU coreutils
du          # GNU coreutils
mktemp      # GNU coreutils

# Documentation uniquement (pip)
# pip install -r requirements-docs.txt
```

Nommé `DEPENDENCIES` ou `dependencies.txt`. Pas de standard universel — c'est purement informatif.

**Verdict : non, ce n'est pas grave.** `hash-tool check-env` est la vraie source de vérité. Un `DEPENDENCIES` textuel est un plus pour les contributeurs, pas une nécessité opérationnelle.