



# Guide d'Installation technique

Ce document détaille les composants nécessaires pour faire fonctionner l'outil de vérification d'intégrité.

## 1. Dépendances système

L'outil repose sur trois piliers pour garantir rapidité, fiabilité et portabilité :

* **BLAKE3 (b3sum)** : L'algorithme de hachage le plus rapide actuellement.
    * *Installation sur Ubuntu/Debian :*
        ```bash
        sudo apt-get update
        sudo apt-get install b3sum
        ```
* **SQLite3** : Utilisé pour stocker les empreintes, les dates de scan et les métadonnées de manière structurée.
    * *Installation sur Ubuntu/Debian :*
        ```bash
        sudo apt-get install sqlite3
        ```
* **Python 3 & Tkinter** : Nécessaires pour faire tourner l'interface graphique (GUI) et la génération des rapports HTML.
    * *Installation sur Ubuntu/Debian :*
        ```bash
        sudo apt-get install python3 python3-tk
        ```

## 2. Configuration du projet

Grâce au point d'entrée unique `src/main.sh`, l'installation logicielle est simplifiée. Lors de la première exécution, le script va :
1.  Attribuer les droits d'exécution (`chmod +x`) à tous les scripts `.sh` et `.py`.
2.  Créer l'arborescence nécessaire dans le dossier `test/` (notamment `hashdb` et `reports`).

## 3. Utilisation de l'Interface Graphique (GUI)

Bien que l'outil puisse être piloté via `main.sh`, une interface visuelle est disponible pour plus de confort.

Pour la lancer :
```bash
python3 src/hash_tool_gui.py

```

**L'interface permet de :**

* Scanner un dossier pour créer une base de référence.
* Vérifier l'intégrité d'un dossier par rapport à une base existante.
* Comparer deux bases (Source vs Destination) pour valider une sauvegarde.
* Visualiser les rapports d'erreurs directement.

## 4. Pourquoi ces choix techniques ?

* **Vitesse** : BLAKE3 est nativement optimisé pour les processeurs modernes, permettant de traiter plusieurs Go/s, limitant le temps de scan à la vitesse physique de vos disques.
* **Fiabilité** : Contrairement aux simples fichiers texte, SQLite garantit que vos bases de données ne seront pas corrompues en cas d'arrêt brutal du script.
* **Propreté** : Toutes les données de travail sont isolées dans le dossier `test/`, laissant les sources de votre projet intactes.



