# PLAN D'ACTION - MIGRATION HASH TOOL

## ÉTAPE 1 : SUPPRESSION (5 min)

### Supprimer ces fichiers

```bash
cd hash_tool

# Scripts shell obsolètes
rm src/collect.sh
rm src/compare.sh
rm src/compute.sh
rm src/hash_tool.sh
rm src/verify.sh
rm src/setup.sh
rm src/run_on_windows.bat

# Anciens scripts Python
rm src/compute_baseline.py
rm src/report_gen.py
rm src/hash_tool_gui.py

# Documentation obsolète
rm -rf documentation/

# Environnement de test
rm -rf test/

# Config
rm config.json
```

## ÉTAPE 2 : INSTALLATION (2 min)

### Copier les nouveaux fichiers dans `src/`

1. **hash_tool_gui_v2.py** -> `src/hash_tool_gui.py`
2. **compute_baseline_v2.py** -> `src/compute_baseline.py`
3. **compare_hashes.py** -> `src/compare_hashes.py`
4. **README.md** -> `README.md` (racine du projet)

Structure finale :

```
hash_tool/
|-- src/
│   |-- hash_tool_gui.py       # Nouveau
│   |-- compute_baseline.py    # Nouveau
│   |-- compare_hashes.py      # Nouveau
|-- README.md
```

## ÉTAPE 3 : VÉRIFICATION WSL (5 min)

### Installer les dépendances dans WSL

```bash
# Ouvrir WSL Ubuntu
wsl

# Installer b3sum et sqlite3
sudo apt update
sudo apt install b3sum sqlite3 python3

# Vérifier installations
b3sum --version
sqlite3 --version
python3 --version
```

## ÉTAPE 4 : TEST (5 min)

### Lancer l'interface

```bash
cd hash_tool
python src/hash_tool_gui.py
```

### Test complet

1. **Onglet 1 - Calculer Hash**
   - Sélectionner un petit dossier (quelques fichiers)
   - Choisir destination (ex: Bureau)
   - Lancer calcul
   - Vérifier que le fichier `.db` est créé

2. **Onglet 2 - Comparer**
   - Sélectionner deux bases (ou la même 2x pour test)
   - Choisir destination rapport
   - Lancer comparaison
   - Ouvrir le rapport HTML

## ÉTAPE 5 : UTILISATION RÉELLE

### Workflow recommandé

#### Cas 1 : Vérification d'intégrité mensuelle

```
1. Calculer hash -> dossier_janvier2026.db
2. Attendre 1 mois
3. Calculer hash -> dossier_fevrier2026.db
4. Comparer -> rapport détecte corruption
```

#### Cas 2 : Validation de sauvegarde

```
1. Calculer hash source -> source.db
2. Copier les fichiers vers backup
3. Calculer hash backup -> backup.db
4. Comparer -> rapport confirme copie parfaite
```

## RÉSULTAT FINAL

### Avant (22 fichiers)
```
hash_tool/
|-- config.json
|-- documentation/ (3 fichiers)
|-- src/ (10 fichiers)
|-- test/ (8 fichiers + structure)
```

### Après (4 fichiers)
```
hash_tool/
|-- src/
│   |-- hash_tool_gui.py
│   |-- compute_baseline.py
│   |-- compare_hashes.py
|-- README.md
```

**Réduction : 82% de fichiers en moins**

## AVANTAGES

✅ Interface moderne style Windows 11
✅ Aucune configuration manuelle
✅ Noms de fichiers automatiques
✅ Deux onglets clairs
✅ Rapports HTML élégants
✅ Console temps réel
✅ Utilise WSL (natif)
✅ Architecture simple
✅ Maintenance facile

## DÉSAVANTAGES SUPPRIMÉS

❌ Plus de scripts shell complexes
❌ Plus de config.json à maintenir
❌ Plus de dossier test/
❌ Plus de documentation obsolète
❌ Plus de bat Windows hacky
❌ Plus d'UI Linux moche

## NOTES IMPORTANTES

1. **WSL obligatoire** : b3sum tourne dans WSL
2. **Python 3.8+** : Avec tkinter
3. **Simplicité** : 3 fichiers Python, point final
4. **Pas de dépendances pip** : Uniquement stdlib

## TEMPS TOTAL

- Suppression : 5 min
- Installation : 2 min
- Vérification : 5 min
- Test : 5 min

**Total : 17 minutes**
