




# Rapport de Performance : Vérification d'Intégrité (BLAKE3)

**Configuration** : HDD et SSD connectés en USB.

dossier : annees (= 200 go)

temps de calcul de hash pour le ssd : 1h 
sur le hdd : 4h 






## Analyse Comparative : Script BLAKE3 vs FreeFileSync (FFS)

La force de cette méthode réside dans l'utilisation de fichiers d'empreintes persistants (`.b3`).

### 1. Avantage Structurel

Contrairement à FreeFileSync qui nécessite la présence simultanée des deux dossiers pour comparer le contenu octet par octet, l'approche par hash permet :

* De comparer un dossier vivant par rapport à une "empreinte" pré-enregistrée.
* De vérifier l'intégrité sans avoir besoin d'une deuxième copie physique des fichiers sur un autre disque.


### 2. Efficacité Temporelle (Algorithmique)


**Note** : En enregistrant vos hash une seule fois, vous divisez par deux la charge de travail de vos disques lors des vérifications ultérieures, tout en utilisant BLAKE3 qui est 10 à 20 fois plus rapide que les algorithmes standards comme SHA-256.



