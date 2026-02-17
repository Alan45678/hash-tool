



# Hash Tool

Outil Python permettant de :

1. Générer une base de hachages de fichiers (SQLite).
2. Comparer deux bases de hachages et produire un rapport HTML.
3. Utiliser une interface graphique simple (Tkinter).

## Prérequis

* Python 3.8+
* pip

Installation des dépendances :

```bash
pip install -r requirements.txt
```

ou bien 

```bash
conda env update -f environment.yml --prune
```


## Arborescence

```
hash_tool/
|-- src/
│   |-- compute_baseline.py    # Génération de la base de hash (SQLite)
│   |-- compare_hashes.py      # Comparaison de deux bases + rapport HTML
│   |-- hash_tool_gui.py       # Interface graphique
|-- test/                      # Données d’exemple (source/destination/rapport)
|-- requirements.txt
|-- README.md
```

## Fonctionnement


### 0. Lancer les tests 

Commande :

```bash
pytest -v tests/
```

### 1. Génération d’une base de hash

Calcule le hash SHA-256 de chaque fichier d’un dossier et stocke le résultat dans une base SQLite.

Commande :

```bash
python src/compute_baseline.py <dossier> <fichier.db>
```

python3 -m src.compute_baseline


Exemple :

```bash
python src/compute_baseline.py test/source hash_source.db
```

La base contient :

* Chemin relatif du fichier
* Hash SHA-256

### 2. Comparaison de deux bases

Compare deux bases SQLite et génère un rapport HTML.

Commande :

```bash
python src/compare_hashes.py --base1 <ref.db> --base2 <current.db> --output <rapport.html>
```

Exemple :

```bash
python src/compare_hashes.py --base1 hash_source.db --base2 hash_destination.db --output rapport.html
```

Le rapport indique :

* Nombre de fichiers identiques
* Fichiers corrompus (hash différent)
* Fichiers manquants
* Fichiers en trop

### 3. Interface graphique

Lancement :

```bash
python src/hash_tool_gui.py
```

Fonctionnalités :

* Onglet 1 : calcul d’une base de hash
* Onglet 2 : comparaison de deux bases
* Affichage des logs d’exécution
* Génération automatique du rapport HTML



## Dossier `fichier_test`

Contient un jeu de données d’exemple :

* `source/` : fichiers de référence
* `destination/` : fichiers comparés
* `rapport.html` : exemple de rapport généré

## Format de sortie

* Base de hash : fichier SQLite (`.db`)
* Rapport : fichier HTML lisible dans un navigateur




