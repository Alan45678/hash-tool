# integrity.sh — Vérification d'intégrité BLAKE3

Détection de corruption silencieuse et d'erreurs de transfert sur disque, par hachage BLAKE3.

**Dépendances :** `b3sum`, `bash >= 4`, `find`, `sort`, `awk`, `comm`, `join`, `stat`, `du`

---

## Usage

```bash
# Créer une base de hachage pour un dossier
./src/integrity.sh compute ./mon_dossier hashes_2024-01-15.b3

# Vérifier l'intégrité — lancer depuis le répertoire où le compute a été fait
./src/integrity.sh verify hashes_2024-01-15.b3

# Idem depuis un répertoire différent — passer le répertoire de travail d'origine
./src/integrity.sh verify /data/hashes_2024-01-15.b3 /data

# Comparer deux bases → résultats dans $RESULTATS_DIR/
./src/integrity.sh compare hashes_2024-01-15.b3 hashes_2024-02-01.b3

# Mode silencieux pour CI/cron
./src/integrity.sh --quiet verify hashes_2024-01-15.b3
```

---

## Pipeline batch — runner.sh + pipeline.json

Pour lancer plusieurs opérations en une seule commande. Dépendance supplémentaire : `jq`.

```bash
./runner.sh                              # lit pipelines/pipeline.json
./runner.sh /chemin/vers/pipeline.json   # config explicite
```

**Dépendance :** `jq` (`apt install jq`)

### pipelines/pipeline.json

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
            "op":       "compare",
            "base_a":   "/mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_1.b3",
            "base_b":   "/mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_2.b3",
            "resultats": "/mnt/c/Users/TonNom/Desktop/rapports/compare_1_vs_2"
        }

    ]
}
```

Champs par opération :

| `op` | Champs requis | Champs optionnels |
|---|---|---|
| `compute` | `source`, `bases`, `nom` | — |
| `verify` | `source`, `base` | — |
| `compare` | `base_a`, `base_b` | `resultats` — dossier de destination des résultats |

Le champ `resultats` sur `compare` surcharge `RESULTATS_DIR` pour ce seul bloc. Sans ce champ, les résultats sont créés dans `RESULTATS_DIR` (défaut : `~/integrity_resultats`).

### Lancement depuis Windows (double-clic)

```bat
@echo off
wsl bash /mnt/c/Users/TonNom/Desktop/hash_tool/runner.sh
pause
```

---

## Mode `--quiet`

Supprime toute sortie terminal, écrit uniquement dans les fichiers de résultats. Exit code propagé.

```bash
# Hook pre-commit git
./src/integrity.sh --quiet verify base.b3 || { echo "Corruption détectée"; exit 1; }

# Monitoring cron
0 3 * * * /opt/hash_tool/src/integrity.sh --quiet verify /data/base.b3 || mail -s "ALERT" admin@example.com
```

---

## Configuration

`RESULTATS_DIR` dans `src/integrity.sh` définit le dossier racine des résultats (défaut : `~/integrity_resultats`). Peut être surchargé par variable d'environnement, ou par le champ `resultats` dans `pipeline.json` pour un bloc `compare` spécifique.

Chaque exécution `verify` ou `compare` crée un sous-dossier horodaté si le dossier existe déjà :

```
<resultats>/
└── resultats_hashes_2024-01-15/
    ├── recap.txt
    ├── failed.txt        ← verify uniquement, absent si 0 échec
    ├── modifies.b3       ← compare uniquement
    ├── disparus.txt      ← compare uniquement
    ├── nouveaux.txt      ← compare uniquement
    └── report.html       ← compare uniquement, rapport visuel
```

---

## Structure du projet

```
hash_tool/
├── runner.sh                      ← point d'entrée pipeline
├── README.md
├── CHANGELOG.md
├── src/
│   ├── integrity.sh               ← script principal (compute / verify / compare)
│   └── lib/
│       └── report.sh              ← génération rapports (HTML)
├── pipelines/
│   ├── pipeline.json              ← pipeline de test local
│   └── pipeline-full.json         ← pipeline VeraCrypt multi-disques
├── reports/
│   └── template.html              ← barebone HTML de référence
├── docs/
│   ├── manuel.md
│   ├── progression-eta.md
│   └── explication-run-tests.md
└── tests/
    ├── run_tests.sh               ← tests integrity.sh (T00–T14)
    ├── run_tests_pipeline.sh      ← tests runner.sh (TP01–TP12b)
    └── validation.md
```

---

## Règles d'utilisation critiques

- **Chemins relatifs** dans les bases `.b3`. `runner.sh` gère le `cd` automatiquement.
- **Répertoire de travail** : lancer `verify` depuis le même répertoire qu'au `compute`, ou passer ce répertoire en second argument.
- **Stockage séparé** : stocker les `.b3` sur un support distinct des données — sur VeraCrypt, stocker sur `C:`.
- **Nommage daté** : `hashes_2024-01-15.b3`, jamais `hashes_latest.b3`.

---

## Docker

Aucune dépendance à installer sur l'hôte. Fonctionne sur Windows, NAS Synology, serveur Debian.

```bash
# Build
docker build -t hash_tool .

# Compute
docker run --rm -v /mes/donnees:/data:ro -v /mes/bases:/bases \
  hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3

# Verify
docker run --rm -v /mes/donnees:/data:ro -v /mes/bases:/bases:ro \
  -v /mes/resultats:/resultats \
  hash_tool verify /bases/hashes.b3 /data

# Compare
docker run --rm -v /mes/bases:/bases:ro -v /mes/resultats:/resultats \
  hash_tool compare /bases/old.b3 /bases/new.b3

# Pipeline complet
docker run --rm \
  -v /mes/donnees:/data:ro -v /mes/bases:/bases \
  -v /mes/resultats:/resultats \
  -v /chemin/pipeline.json:/pipelines/pipeline.json:ro \
  hash_tool runner
```

Voir `docs/docker.md` pour la documentation complète (NAS, cron, ARM64, Compose).

---

## Tests

```bash
# Tests integrity.sh
cd tests && ./run_tests.sh

# Tests runner.sh + pipeline.json
cd tests && ./run_tests_pipeline.sh

# Avec ShellCheck (recommandé)
apt install shellcheck && ./run_tests.sh
```

- `run_tests.sh` : 15 cas T00–T14
- `run_tests_pipeline.sh` : 13 cas TP01–TP12b (dont TP10b : champ `resultats` personnalisé)

---

## Arbre de décision

| Situation | Commande |
|---|---|
| Première indexation | `compute` |
| Vérifier après transfert / stockage | `verify` |
| Comparer deux snapshots | `compare` |
| Pipeline multi-dossiers / VeraCrypt | `runner.sh` + `pipeline.json` |
| Contrôle ad hoc d'un fichier unique | `b3sum fichier.bin` |
| Intégration CI/cron | `--quiet verify` |
