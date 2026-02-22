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
./integrity.sh verify /data/hashes_2024-01-15.b3 /data

# Comparer deux bases (états historiques) → résultats dans $RESULTATS_DIR/
./integrity.sh compare hashes_2024-01-15.b3 hashes_2024-02-01.b3

# Mode silencieux pour CI/cron
./integrity.sh --quiet verify hashes_2024-01-15.b3
```

---

## Pipeline batch — runner.sh + pipeline.json

Pour lancer plusieurs opérations en une seule commande. Dépendance supplémentaire : `jq`.

**Dépendance :** `jq` (`apt install jq`)

### pipeline.json

```json
{
    "pipeline": [

        {
            "op":     "compute",
            "source": "/mnt/a/dossier_disque_1",
            "bases":  "/mnt/c/Users/TonNom/Desktop/bases",
            "nom":    "hashes_dossier_1.b3"
        },

        {
            "op":     "verify",
            "source": "/mnt/a/dossier_disque_1",
            "base":   "/mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_1.b3"
        },

        {
            "op":     "compare",
            "base_a": "/mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_1.b3",
            "base_b": "/mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_2.b3"
        }

    ]
}
```

Champs par opération :

| `op` | Champs requis |
|---|---|
| `compute` | `source`, `bases`, `nom` |
| `verify` | `source`, `base` |
| `compare` | `base_a`, `base_b` |

### Lancement depuis Windows (double-clic)

```bat
@echo off
wsl bash /mnt/c/Users/TonNom/Desktop/runner.sh
pause
```

`runner.sh`, `pipeline.json` et `integrity.sh` doivent être dans le même dossier.

---

## Mode `--quiet`

Supprime toute sortie terminal et écrit uniquement dans les fichiers de résultats (`recap.txt`, `failed.txt`). Exit code propagé : 0 si OK, non-nul en cas d'échec.

```bash
# Hook pre-commit git
./integrity.sh --quiet verify base.b3 || { echo "Corruption détectée"; exit 1; }

# Monitoring cron
0 3 * * * /opt/integrity.sh --quiet verify /data/base.b3 || mail -s "ALERT" admin@example.com
```

Compatible avec `compute`, `verify`, et `compare`.

---

## Configuration

`RESULTATS_DIR` dans `integrity.sh` définit où sont créés les dossiers de résultats (défaut : `~/integrity_resultats`).

```bash
RESULTATS_DIR="/mon/chemin/resultats"
```

Chaque exécution de `verify` ou `compare` crée un sous-dossier horodaté si le dossier existe déjà :

```
~/integrity_resultats/
├── resultats_hashes_2024-01-15/
│   ├── recap.txt
│   ├── failed.txt
│   ├── modifies.b3
│   ├── disparus.txt
│   └── nouveaux.txt
└── resultats_hashes_2024-01-15_20250215-143022/
    └── ...
```

---

| Situation | Commande |
|---|---|
| Première indexation | `compute` |
| Vérifier après transfert / stockage | `verify` |
| Comparer deux snapshots | `compare` |
| Pipeline multi-dossiers | `runner.sh` + `pipeline.json` |
| Contrôle ad hoc d'un fichier unique | `b3sum fichier.bin` |
| Intégration CI/cron | `--quiet verify` |

---

## Structure du projet

```
hash_tool/
├── README.md
├── integrity.sh           ← script principal
├── runner.sh              ← exécuteur de pipeline
├── pipeline.json          ← déclaration du pipeline
├── docs/
│   ├── manuel.md
│   ├── progression-eta.md
│   └── explication-run-tests.md
└── tests/
    ├── run_tests.sh               ← tests integrity.sh (T00–T14)
    ├── run_tests_pipeline.sh      ← tests runner.sh (TP01–TP12)
    └── validation.md
```

---

## Règles d'utilisation critiques

- Toujours des **chemins relatifs** dans les bases `.b3`. `runner.sh` gère le `cd` automatiquement.
- Lancer `verify` depuis le **même répertoire de travail** qu'au `compute`, ou passer ce répertoire en second argument.
- Stocker les `.b3` sur un **support distinct** des données — sur VeraCrypt, stocker sur `C:` ou un support tiers.
- Nommer les bases avec une **date explicite** : `hashes_2024-01-15.b3`, jamais `hashes_latest.b3`.

---

## Tests

```bash
# Tests integrity.sh (bash >= 4, b3sum requis)
cd tests
./run_tests.sh

# Tests runner.sh + pipeline.json (jq requis en plus)
./run_tests_pipeline.sh

# Avec ShellCheck (recommandé)
apt install shellcheck
./run_tests.sh
```

- `run_tests.sh` : 15 cas T00–T14 — compute, verify, compare, `--quiet`, horodatage, robustesse.
- `run_tests_pipeline.sh` : 12 cas TP01–TP12 — parsing JSON, exécution des 3 modes, erreurs.