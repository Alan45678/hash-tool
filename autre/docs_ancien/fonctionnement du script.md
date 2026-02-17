

# Architecture du Système

Le système a été simplifié pour utiliser un orchestrateur unique (`main.sh`) qui pilote les étapes suivantes :

### Étapes Automatisées

* 
**Initialisation** : Correction automatique des scripts et installation de l'outil de hachage `b3sum` si manquant.


* 
**Hachage Parallèle** : Calcul ultra-rapide des empreintes numériques en utilisant tous les cœurs du processeur via BLAKE3.


* 
**Normalisation** : Nettoyage des chemins de fichiers pour permettre une comparaison basée uniquement sur les noms relatifs.


* 
**Comparaison** : Détection des fichiers modifiés, manquants ou ajoutés via l'outil `diff`.


* 
**Reporting** : Transformation des données brutes en un rapport HTML lisible.



### Pourquoi BLAKE3 ?

Nous utilisons BLAKE3 car il est 10 à 20 fois plus rapide que le SHA-256. Sur un SSD, il peut traiter plusieurs gigaoctets par seconde.






