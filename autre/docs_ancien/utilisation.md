


# Guide d'Utilisation - Hash Tool

L'outil `hash_tool` permet de surveiller l'intégrité de vos fichiers (détection de bit rot) et de vérifier la fidélité de vos copies de sauvegarde entre deux disques.

## 🚀 Lancement Rapide

Grâce à l'automatisation intégrée, il n'est plus nécessaire de rendre les fichiers exécutables manuellement. Utilisez simplement le point d'entrée principal :

```bash
cd src
./main.sh

```

## 🛠️ Configuration initiale

Avant de lancer un scan, vous devez configurer vos chemins dans le fichier `src/setup.sh`. Les variables clés sont :

* **SOURCE_DIR** : Le chemin de votre dossier principal.
* **DESTINATION_DIR** : Le chemin de votre dossier de sauvegarde.

Le script créera automatiquement les dossiers suivants pour organiser le travail :

* `test/hashdb/` : Stockage des bases de données SQLite contenant les empreintes.
* `test/reports/` : Stockage des rapports de comparaison au format HTML.

## 📈 Workflows Principaux

### 1. Détection de Bit Rot (Corruption de données)

La corruption silencieuse peut arriver avec le temps sur n'est n'importe quel support de stockage.

1. Générez une **Baseline** (état de référence) de votre dossier source.
2. Plus tard (par exemple, après 6 mois), relancez une **Vérification**.
3. Le système comparera l'état actuel aux données stockées dans la base SQLite située dans `test/hashdb/` et signalera tout changement.

### 2. Audit de Sauvegarde (Comparaison)

Pour s'assurer qu'une copie est 100% identique à l'original (après un rsync ou un copier/coller) :

1. Générez une base de hash pour le dossier **Source**.
2. Générez une base de hash pour le dossier **Destination**.
3. Lancez le script de comparaison pour générer un rapport dans `test/reports/`.

## 📁 Gestion des fichiers de sortie

Tous les fichiers générés par le programme sont désormais isolés dans le dossier `test/` pour ne pas polluer la racine du projet :

* **Bases SQLite** : `test/hashdb/*.db`
* **Rapports HTML** : `test/reports/*.html`
* **Fichiers temporaires** : `test/hash/hashbase/`

> **Note** : Si vous souhaitez réinitialiser vos données de test, il vous suffit de vider le contenu du dossier `test/hashdb/`.


