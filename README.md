# integrity.sh — Vérification d'intégrité BLAKE3

Détection de corruption silencieuse et d'erreurs de transfert sur disque, par hachage BLAKE3.

**Dépendances :** `b3sum`, `bash >= 4`, `find`, `sort`, `awk`, `comm`, `join`, `stat`, `du`

---

## Usage

```bash
# Créer une base de hachage pour un dossier
./integrity.sh compute ./mon_dossier hashes_2024-01-15.b3

# Vérifier l'intégrité — lancer depuis le répertoire où le compute a été fait
./integrity.sh verify hashes_2024-01-15.b3

# Idem depuis un répertoire différent — passer le répertoire de travail d'origine
# Exemple : le compute a été lancé depuis /data, on est ailleurs
./integrity.sh verify /data/hashes_2024-01-15.b3 /data

# Comparer deux bases (états historiques) → résultats dans $RESULTATS_DIR/
./integrity.sh compare hashes_2024-01-15.b3 hashes_2024-02-01.b3

# Mode silencieux pour CI/cron — écrit uniquement dans les fichiers de résultats
./integrity.sh --quiet verify hashes_2024-01-15.b3
```

---

## Mode `--quiet`

Supprime toute sortie terminal (stdout/stderr) et écrit uniquement dans les fichiers de résultats (`recap.txt`, `failed.txt`). L'exit code est propagé : 0 si OK, non-nul en cas d'échec.

**Usage typique en CI/cron :**

```bash
# Hook pre-commit git
./integrity.sh --quiet verify base.b3 || { echo "Corruption détectée"; exit 1; }

# Monitoring cron
0 3 * * * /opt/integrity.sh --quiet verify /data/base.b3 || mail -s "ALERT" admin@example.com
```

Compatible avec `compute`, `verify`, et `compare`.

---

## Configuration

`RESULTATS_DIR` dans `integrity.sh` définit où sont créés les dossiers de résultats (valeur par défaut : `~/integrity_resultats`).

```bash
# Modifier dans integrity.sh, ligne RESULTATS_DIR=
RESULTATS_DIR="/mon/chemin/resultats"
```

Chaque exécution de `verify` ou `compare` crée un sous-dossier horodaté si le dossier existe déjà (pas d'écrasement silencieux) :

```
~/integrity_resultats/
├── resultats_hashes_2024-01-15/
│   ├── recap.txt       ← commande, date, compteurs
│   ├── failed.txt      ← fichiers en échec (verify)
│   ├── modifies.b3     ← fichiers dont le hash a changé (compare)
│   ├── disparus.txt    ← fichiers dans A absents de B (compare)
│   └── nouveaux.txt    ← fichiers dans B absents de A (compare)
└── resultats_hashes_2024-01-15_20250215-143022/  ← horodatage si collision
    └── ...
```

---

| Situation | Commande |
|---|---|
| Première indexation | `compute` |
| Vérifier après transfert / stockage | `verify` |
| Comparer deux snapshots | `compare` |
| Contrôle ad hoc d'un fichier unique | `b3sum fichier.bin` |
| Intégration CI/cron | `--quiet verify` |

---

## Structure du projet

```
integrity/
├── README.md              ← ce fichier
├── integrity.sh           ← script principal
├── docs/
│   ├── manuel.md          ← référence technique complète
│   └── progression-eta.md ← progression temps réel et estimation ETA
└── tests/
    ├── run_tests.sh       ← suite de tests automatisée
    └── validation.md      ← protocole de test et critères qualité
```

---

## Règles d'utilisation critiques

- Toujours utiliser des **chemins relatifs** (`find ./dossier`, jamais `/chemin/absolu`). Un chemin absolu rend la base inutilisable après déplacement ou remontage.
- Lancer `verify` depuis le **même répertoire de travail** qu'au moment du `compute`. Si ce n'est pas possible, passer ce répertoire en second argument : `verify hashes.b3 /chemin/origine` — c'est le répertoire d'où le compute a été lancé, **pas** le dossier qui a été haché.
- Stocker la base `.b3` sur un **support distinct** des données à vérifier.
- Nommer les bases avec une **date explicite** : `hashes_2024-01-15.b3`, jamais `hashes_latest.b3`.

---

## Tests

```bash
# Exécuter la suite de tests automatisée (bash >= 4, b3sum requis)
cd tests
./run_tests.sh

# Avec ShellCheck (recommandé)
apt install shellcheck
./run_tests.sh
```

14 cas de test couvrent : compute, verify, compare, noms avec espaces, chemins absolus vs relatifs, mode `--quiet`, horodatage des résultats, robustesse des assertions.