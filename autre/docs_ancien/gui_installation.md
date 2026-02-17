# Guide d'Installation - Interface Graphique Hash Tool

## Installation

### 

```bash
# Rendre exécutable
chmod +x hash_tool_gui.py
```

### 2. Vérifier les dépendances

```bash
# Python 3 (requis)
python3 --version

# Tkinter (généralement inclus avec Python)
python3 -c "import tkinter"

# Si erreur tkinter, installer :
# Ubuntu/Debian
sudo apt-get install python3-tk

# Fedora
sudo dnf install python3-tkinter

# macOS (via Homebrew)
brew install python-tk
```

### 3. Lancer l'interface

```bash
cd /path/to/hash_tool/src
python3 hash_tool_gui.py
```

**OU** double-cliquer sur le fichier dans l'explorateur de fichiers.

---

## Fonctionnalités de l'Interface

### Onglet 1️⃣ : Créer Baseline

**Utilisation** :
1. Cliquer sur "Parcourir..." pour sélectionner un dossier
2. Entrer un nom pour la base (suggestions disponibles)
3. Cliquer sur "🚀 Créer la Baseline"
4. Suivre la progression dans la console

**Quand utiliser** :
- Première fois que vous voulez surveiller un dossier
- Avant une copie pour avoir une référence
- Pour créer un snapshot daté

---

### Onglet 2️⃣ : Vérifier Intégrité

**Utilisation** :
1. Sélectionner le dossier à vérifier
2. Choisir la baseline de référence dans la liste
3. Cliquer sur "🔍 Vérifier l'Intégrité"
4. Consulter les résultats dans la console
5. Cliquer sur "📄 Ouvrir le Rapport HTML" pour voir les détails

**Quand utiliser** :
- Détection de bit rot mensuelle/hebdomadaire
- Après une panne de courant
- Vérification périodique de l'intégrité des archives

**Résultats possibles** :
- ✅ Aucune corruption : Tout est OK
- ⚠️ Fichiers corrompus : BIT ROT DÉTECTÉ
- 📁 Fichiers manquants : Fichiers supprimés depuis baseline
- 📄 Nouveaux fichiers : Fichiers ajoutés depuis baseline

---

### Onglet 3️⃣ : Comparer Bases

**Utilisation** :
1. Sélectionner la Base 1 (ex: disk1_baseline)
2. Sélectionner la Base 2 (ex: disk2_baseline)
3. Cliquer sur "⚖️ Comparer les Bases"
4. Consulter les différences
5. Ouvrir le rapport HTML pour détails

**Quand utiliser** :
- Vérifier qu'une copie est identique à la source
- Comparer deux snapshots temporels
- Audit de synchronisation

**Cas d'usage** :
```
Workflow typique:
1. Créer baseline de /source -> disk1_baseline
2. Copier /source vers /backup
3. Créer baseline de /backup -> backup_baseline
4. Comparer disk1_baseline vs backup_baseline
   -> Si différences = copie échouée
   -> Si identique = copie OK
```

---

### Onglet 4️⃣ : Gestion Bases

**Fonctionnalités** :
- **Liste complète** : Voir toutes les bases avec détails
- **🔄 Actualiser** : Rafraîchir la liste
- **🗑️ Supprimer** : Effacer une base (avec confirmation)
- **📊 Voir Détails** : Info complète (nombre fichiers, taille, date)
- **📂 Ouvrir Dossier** : Accéder au dossier hashdb/

**Informations affichées** :
- Nom de la base
- Nombre de fichiers
- Date de création
- Taille de la base

---

## Workflows avec l'Interface

### Workflow 1 : Détection Bit Rot

**Étapes** :

1. **Jour 0 - Créer la référence**
   - Onglet "Créer Baseline"
   - Dossier: `/mnt/y/photos`
   - Nom: `photos_baseline`
   - Créer

2. **Jour 30 - Vérifier**
   - Onglet "Vérifier Intégrité"
   - Dossier: `/mnt/y/photos`
   - Baseline: `photos_baseline`
   - Vérifier
   - Si corruption -> Ouvrir rapport -> Restaurer fichiers

3. **Jour 60 - Re-vérifier**
   - Répéter l'étape 2

---

### Workflow 2 : Vérification de Copie

**Étapes** :

1. **Hasher la source**
   - Onglet "Créer Baseline"
   - Dossier: `/mnt/y/data`
   - Nom: `source_data`
   - Créer

2. **Copier les fichiers**
   - Utiliser rsync ou cp dans un terminal
   - `rsync -av /mnt/y/data/ /mnt/z/backup/`

3. **Hasher la destination**
   - Onglet "Créer Baseline"
   - Dossier: `/mnt/z/backup`
   - Nom: `backup_data`
   - Créer

4. **Comparer**
   - Onglet "Comparer Bases"
   - Base 1: `source_data`
   - Base 2: `backup_data`
   - Comparer
   - Vérifier qu'il n'y a aucune différence

---

### Workflow 3 : Snapshot Temporel

**Étapes** :

1. **Snapshot quotidien automatisé**
   - Onglet "Créer Baseline"
   - Dossier: `/data/project`
   - Nom: `project_20260206` (avec date du jour)
   - Créer

2. **Le lendemain**
   - Nom: `project_20260207`
   - Créer

3. **Comparer l'évolution**
   - Onglet "Comparer Bases"
   - Base 1: `project_20260206`
   - Base 2: `project_20260207`
   - Comparer
   - Voir ce qui a changé en 24h

---

## Interprétation des Rapports HTML

### Rapport de Vérification

**Section "Fichiers Corrompus"** :
```
Fichier          | Hash Baseline  | Hash Actuel
photo.jpg        | abc123...      | xyz789...
```
-> **BIT ROT DÉTECTÉ** : Restaurer depuis backup

**Section "Fichiers Manquants"** :
```
- document.pdf
- video.mp4
```
-> Fichiers supprimés depuis baseline

**Section "Nouveaux Fichiers"** :
```
- nouveau.txt
- rapport.docx
```
-> Fichiers ajoutés depuis baseline

---

### Rapport de Comparaison

**Section "Fichiers avec Hash Différents"** :
```
Fichier      | Hash Base 1  | Hash Base 2
data.bin     | aaa111...    | bbb222...
```
-> Contenu différent entre les deux bases

**Section "Présents uniquement dans Base 1"** :
```
- fichier_unique_source.txt
```
-> Fichier pas copié

**Section "Présents uniquement dans Base 2"** :
```
- fichier_extra_destination.txt
```
-> Fichier ajouté dans destination

---

## Raccourcis et Astuces

### Nommage des Bases

**Bonnes pratiques** :
```
disk1_baseline       # Référence immuable
disk1_20260206       # Snapshot daté
photos_backup        # Backup de photos
source_project       # Source d'un projet
```

**Éviter** :
```
test1, test2         # Pas descriptif
baseline             # Trop générique
xyz                  # Incompréhensible
```

---

### Automatisation

**Script de vérification automatique** :

Créer `auto_verify.sh` :
```bash
#!/bin/bash
python3 /path/to/hash_tool/src/hash_tool_gui.py &
# OU lancer en ligne de commande :
cd /path/to/hash_tool/src
./hash_tool.sh verify --dir /data --baseline data_baseline
```

**Cron job** :
```bash
# Tous les lundis à 2h du matin
0 2 * * 1 /path/to/auto_verify.sh
```

---

## Dépannage

### Problème : Interface ne se lance pas

**Erreur** : `ModuleNotFoundError: No module named 'tkinter'`

**Solution** :
```bash
# Ubuntu/Debian
sudo apt-get install python3-tk

# Vérifier
python3 -c "import tkinter; print('OK')"
```

---

### Problème : Bouton "Parcourir" ne fonctionne pas

**Cause** : Permissions insuffisantes

**Solution** :
```bash
# Lancer avec sudo si nécessaire
sudo python3 hash_tool_gui.py
```

---

### Problème : Console ne s'actualise pas

**Cause** : Les scripts bash ne sont pas exécutables

**Solution** :
```bash
cd /path/to/hash_tool/src
chmod +x hash_tool.sh compute.sh verify.sh compare.sh
```

---

### Problème : Rapport HTML ne s'ouvre pas

**Vérifier** :
```bash
ls -la /path/to/hash_tool/reports/
```

Si vide :
- Relancer l'opération
- Vérifier les permissions du dossier reports/

---

## Fonctionnalités Avancées

### Console en Temps Réel

- La console affiche la progression en direct
- Nombre de fichiers traités
- Erreurs éventuelles
- Code de retour final

### Multi-threading

- Les opérations longues s'exécutent dans un thread séparé
- L'interface reste réactive
- Possibilité de fermer la fenêtre (le traitement continue)

### Persistance

- Les chemins de dossiers sont suggérés automatiquement
- Les dernières bases utilisées sont pré-sélectionnées
- Les rapports sont accessibles même après fermeture

---

## Exemples avec le Dossier Test

### Exemple 1 : Créer Baseline du Dossier Source

1. Lancer l'interface : `python3 hash_tool_gui.py`
2. Onglet "Créer Baseline"
3. Parcourir : `../test/source`
4. Nom : `test_source_baseline`
5. Créer
6. Vérifier dans "Gestion Bases" : 4 fichiers

---

### Exemple 2 : Comparer Source vs Destination

1. Créer baseline source (ci-dessus)
2. Créer baseline destination :
   - Dossier : `../test/destination`
   - Nom : `test_destination_baseline`
3. Onglet "Comparer Bases"
4. Base 1 : `test_source_baseline`
5. Base 2 : `test_destination_baseline`
6. Comparer
7. Résultat : 1 fichier différent (fichier (1).txt)

---

### Exemple 3 : Simuler et Détecter Corruption

1. Créer baseline : `test_source_baseline`
2. Dans un terminal, modifier un fichier :
   ```bash
   echo "CORRUPTION" >> ../test/source/fichier\ \(2\).txt
   ```
3. Onglet "Vérifier Intégrité"
4. Dossier : `../test/source`
5. Baseline : `test_source_baseline`
6. Vérifier
7. Résultat : 1 fichier corrompu détecté
8. Ouvrir rapport HTML pour voir les détails

---

## Support

Pour toute question ou problème :

1. Vérifier ce guide
2. Consulter les logs dans la console
3. Vérifier les permissions des scripts
4. Vérifier que b3sum est installé : `b3sum --version`

---

**Interface créée pour simplifier la gestion des hash et la détection de bit rot.**
