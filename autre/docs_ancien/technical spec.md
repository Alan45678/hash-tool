# Technical Specifications - Hash Tool

## Architecture Technique

### Composants Principaux

#### 1. Algorithme de Hachage
- **BLAKE3** (via `b3sum`)
- Performance : Plusieurs Go/s (limité par le hardware)
- Optimisé pour processeurs modernes
- Choix justifié : vitesse maximale pour minimiser le temps de scan

#### 2. Stockage des Données
- **SQLite3** pour persistance structurée
- Stockage : empreintes, dates de scan, métadonnées
- Avantages : 
  - Protection contre corruption lors d'arrêts brutaux
  - Requêtes SQL pour analyse
  - Mise à jour < 10s pour 50k fichiers

#### 3. Interface Utilisateur
- **Python 3 + Tkinter** pour GUI
- Scripts Bash pour CLI
- Double mode d'utilisation (GUI/CLI)

### Structure de Données

#### Base de Données SQLite
```sql
Table: file_hashes
- path (TEXT) : chemin relatif du fichier
- hash_blake3 (TEXT) : empreinte BLAKE3
- scan_date (TIMESTAMP) : date du dernier scan
- file_size (INTEGER) : taille du fichier
```

#### Configuration JSON
```json
{
  "hashdb_dir": "/chemin/hashdb",
  "reports_dir": "/chemin/reports",
  "last_source_dir": "/dernier/source",
  "last_destination_dir": "/dernier/destination"
}
```

## Modules Fonctionnels

### 1. collect.sh
- Fonction : Création baseline (empreinte de référence)
- Input : Nom de référence, dossier cible
- Output : Fichier `.db` dans `hashdb/`
- Process : Scan récursif + calcul BLAKE3 + insertion SQLite

### 2. verify.sh
- Fonction : Vérification d'intégrité
- Input : Dossier cible, baseline de référence
- Output : Rapport HTML d'anomalies
- Détections :
  - Fichiers corrompus (hash différent)
  - Fichiers manquants (suppression)
  - Nouveaux fichiers (ajouts)

### 3. compare.sh
- Fonction : Comparaison source/destination
- Input : Deux baselines (source + destination)
- Output : Rapport HTML de divergences
- Use case : Validation de sauvegarde

### 4. compute.sh / compute_baseline.py
- Fonction : Calcul de hachage parallélisé
- Optimisation : Utilisation multi-thread
- Output : Fichiers intermédiaires `.b3`

### 5. report_gen.py
- Fonction : Génération rapports HTML
- Types : verify, compare
- Input : Fichiers temporaires de résultats
- Output : Rapport HTML formaté avec statistiques

### 6. hash_tool_gui.py
- Fonction : Interface graphique Tkinter
- Actions disponibles :
  - Scanner dossier (création baseline)
  - Vérifier intégrité
  - Comparer deux bases
  - Visualiser rapports

### 7. setup.sh
- Fonction : Initialisation environnement
- Actions :
  - Création arborescence (hashdb/, reports/)
  - Attribution droits d'exécution
  - Export variables d'environnement

## Performances Mesurées

### Benchmarks Réels

#### Configuration SSD (SATA/NVMe)
- Volume : 200 Go (photos/vidéos)
- Temps : 5-12 minutes
- Facteur limitant : Vitesse SSD

#### Configuration HDD (USB 3.0)
- Volume : 200 Go
- Temps : 45 min - 1h15
- Facteur limitant : Vitesse mécanique

#### Traitement Base de Données
- Volume : 50 000 fichiers
- Temps mise à jour : < 10 secondes
- Overhead SQLite : négligeable

## Environnement de Test

### Structure test/
```
test/
|-- source/          # Fichiers originaux
|-- destination/     # Copie (potentiellement altérée)
|-- hashdb/          # Bases de données SQLite
|-- reports/         # Rapports HTML générés
```

### Protocole de Test
1. Création baseline : `./src/collect.sh "ref_source"`
2. Simulation corruption : `echo "data" >> test/source/fichier.txt`
3. Vérification : Détection automatique des modifications
4. Output : Rapport HTML dans `reports/`

## Dépendances Système

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install b3sum sqlite3 python3 python3-tk
```

### Windows
- Python 3 (avec PATH)
- Script wrapper : `run_on_windows.bat`
- Vérification Python avant lancement GUI

## Format de Sortie

### Rapports HTML
- Fichiers corrompus : path | baseline_hash | current_hash
- Fichiers manquants : path
- Nouveaux fichiers : path
- Statistiques globales
- Timestamp de génération

### Codes de Retour
- `0` : Aucune anomalie détectée
- `1` : Corruption(s) détectée(s)

## Flux de Données

```
Scanner Dossier -> b3sum (BLAKE3) -> SQLite DB
                                      ↓
Vérification ← Comparaison Hash ← SQLite DB
       ↓
Détection Anomalies -> Fichiers Temp -> report_gen.py -> HTML
```

## Choix d'Implémentation

### Pourquoi Bash + Python ?
- Bash : Performance maximale pour I/O et appels système
- Python : GUI, génération rapports, manipulation SQLite

### Pourquoi BLAKE3 vs SHA256/MD5 ?
- BLAKE3 : ~10x plus rapide que SHA256
- Sécurité cryptographique équivalente
- Parallélisation native

### Pourquoi SQLite vs Fichiers Texte ?
- Intégrité transactionnelle (ACID)
- Requêtes SQL pour analyses complexes
- Résistance corruption
- Performance indexation automatique

## Isolation Données

- **Principe** : Séparation stricte projet/données
- **Racine projet** : Code source uniquement
- **Dossier test/** : Toutes les données générées
  - hashdb/ : Bases SQLite
  - reports/ : Rapports HTML
  - hash/hashbase/ : Fichiers `.b3` intermédiaires

## Portabilité

### Linux/WSL
- Natif, utilisation standard scripts `.sh`

### Windows
- Wrapper `run_on_windows.bat`
- Vérification Python dans PATH
- Lancement GUI sans WSL

## Sécurité

- Hash non-cryptographique (intégrité, pas authentification)
- Pas de transmission réseau
- Stockage local uniquement
- Aucune élévation privilèges requise