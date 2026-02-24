Non, pas vraiment. Voici ce qui existe et ce qui manque :

**Ce qui existe :** zéro test Docker dans les suites actuelles. `entrypoint.sh` n'est jamais testé automatiquement. Le Dockerfile n'est jamais buildé en CI. La seule "vérification" Docker est manuelle : `docker run --rm hash_tool version` que l'utilisateur peut faire à la main.

**Ce qui manque concrètement :**

*Tests de build :*
- Que le `docker build` réussit (pas d'erreur de syntaxe Dockerfile, pas de package Alpine introuvable, `b3sum` bien installé)
- Que l'image produite fait bien ~14 Mo et pas 500 Mo (régression de taille)
- Que le build fonctionne en `--platform linux/arm64` (les NAS Synology)

*Tests de l'entrypoint :*
- `docker run hash_tool help` → exit 0, affiche de l'aide
- `docker run hash_tool commande_inconnue` → exit 1, message d'erreur propre
- `docker run hash_tool version` → affiche les versions de b3sum, jq, bash
- `docker run hash_tool compute /data /bases/test.b3` avec volumes montés → produit le fichier .b3
- `docker run hash_tool --quiet verify ...` → le flag `--quiet` est bien transmis à `integrity.sh`
- `docker run hash_tool runner /pipelines/pipeline.json` → pipeline exécuté

*Tests d'environnement (que les outils dans l'image sont bien ceux attendus) :*
```bash
# Vérifier que b3sum est la bonne version et fonctionne
docker run --rm hash_tool b3sum --version
# Vérifier que jq est présent
docker run --rm hash_tool jq --version
# Vérifier que bash >= 4
docker run --rm hash_tool bash -c 'echo $BASH_VERSION'
```

*Test de régression de l'image :*
```bash
# Taille de l'image — détecter une régression (ex: on ajoute python par erreur)
SIZE=$(docker image inspect hash_tool --format='{{.Size}}')
[ $SIZE -lt 20000000 ] || echo "FAIL : image trop lourde ($SIZE octets)"
```

*Tests multi-plateforme :*
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t hash_tool:multiarch .
# Vérifier que les deux architectures produisent les mêmes résultats sur un même jeu de fichiers
```

Ce serait un fichier `tests/run_tests_docker.sh` séparé, conditionné à la présence de Docker (`command -v docker`), et un job distinct dans la CI GitHub Actions — parce que le build Docker est lent (~2-3 min) et ne doit pas bloquer les tests unitaires rapides.