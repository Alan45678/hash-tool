



# Guide d'Exécution

### 1. Préparation dans Windows
Avant de lancer le script, assurez-vous que vos disques externes sont bien branchés et reconnus par Windows. 

### 2. Configuration (setup.sh)
Ouvrez `src/setup.sh` et vérifiez les chemins. [cite_start]**Attention à la casse** (minuscules pour /mnt/y et /mnt/z)[cite: 4]:
* [cite_start]**SOURCE_DIR** : `/mnt/test/source/annees` [cite: 4]
* [cite_start]**DESTINATION_DIR** : `/mnt/test/destination/annees` [cite: 4]

### 3. Lancement dans WSL
[cite_start]Ouvrez votre terminal WSL, rendez-vous dans le dossier `src` et lancez le script[cite: 5, 10]:

```bash
cd "/mnt/a/main_interne/divers/config ordinateur/2 en cours -- 2025-00-00 -- backup/d15 exécution/vérification_hash/src"
./main.sh

```

### 4. Lecture du Rapport

Le résultat final est un fichier HTML interactif.
Vous pouvez le consulter ici :
`C:\Users\CM\Desktop\result_hash\hash\rapport.html` 


