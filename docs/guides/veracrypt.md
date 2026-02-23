# Guide — VeraCrypt & disques multiples

Workflow complet pour archiver et vérifier des données sur partitions VeraCrypt avec `runner.sh`.

---

## Principe

Les partitions VeraCrypt sont montées comme des lettres de lecteur sous Windows / des points de montage sous Linux. Les données n'existent en clair que pendant la session de montage. Il faut donc :

1. **Indexer avant démontage** — calculer les hashes pendant que les données sont accessibles
2. **Stocker les `.b3` hors de la partition vérifiée** — sur `C:` ou une partition non chiffrée
3. **Vérifier après remontage** — au prochain accès, confirmer l'intégrité

---

## Correspondance chemins Windows / WSL

| Lecteur Windows | Chemin WSL |
|---|---|
| `A:\` | `/mnt/a/` |
| `C:\` | `/mnt/c/` |
| `H:\` | `/mnt/h/` |
| `I:\` | `/mnt/i/` |

Si VeraCrypt remonte une partition sur une lettre différente d'une session à l'autre, seul le champ `source` dans `pipeline.json` est à modifier. Les bases `.b3` restent valides car leurs chemins sont relatifs.

---

## Structure recommandée

```
C:\Users\TonNom\Desktop\
├── hash_tool\                  ← scripts (non chiffré)
│   ├── runner.sh
│   ├── src\integrity.sh
│   └── pipelines\
│       └── pipeline-veracrypt.json
├── bases\                      ← fichiers .b3 (non chiffré, hors VeraCrypt)
│   ├── hashes_disque_1.b3
│   ├── hashes_disque_2.b3
│   └── hashes_disque_3.b3
└── rapports\                   ← résultats compare/verify
    └── ...
```

!!! danger "Stocker les .b3 hors de la partition vérifiée"
    Si les `.b3` sont sur la même partition VeraCrypt que les données, une corruption du disque peut corrompre simultanément les données **et** leur empreinte — rendant la vérification inutile.

    Stocker les `.b3` sur `C:` (non chiffré) ou une partition séparée.

---

## Configuration pipeline

### Cas simple — un disque, compute + verify

```json
{
    "pipeline": [
        {
            "op":     "compute",
            "source": "/mnt/a/mes_archives",
            "bases":  "/mnt/c/Users/TonNom/Desktop/bases",
            "nom":    "hashes_disque_a.b3"
        },
        {
            "op":     "verify",
            "source": "/mnt/a/mes_archives",
            "base":   "/mnt/c/Users/TonNom/Desktop/bases/hashes_disque_a.b3"
        }
    ]
}
```

### Cas complet — trois disques avec comparaison

```json
{
    "pipeline": [

        {
            "op":     "compute",
            "source": "/mnt/a/dossier_disque_1",
            "bases":  "/mnt/c/Users/TonNom/Desktop/bases",
            "nom":    "hashes_disque_1.b3"
        },

        {
            "op":     "compute",
            "source": "/mnt/i/dossier_disque_2",
            "bases":  "/mnt/c/Users/TonNom/Desktop/bases",
            "nom":    "hashes_disque_2.b3"
        },

        {
            "op":     "compute",
            "source": "/mnt/h/dossier_disque_3",
            "bases":  "/mnt/c/Users/TonNom/Desktop/bases",
            "nom":    "hashes_disque_3.b3"
        },

        {
            "op":     "verify",
            "source": "/mnt/a/dossier_disque_1",
            "base":   "/mnt/c/Users/TonNom/Desktop/bases/hashes_disque_1.b3"
        },

        {
            "op":        "compare",
            "base_a":    "/mnt/c/Users/TonNom/Desktop/bases/hashes_disque_1.b3",
            "base_b":    "/mnt/c/Users/TonNom/Desktop/bases/hashes_disque_2.b3",
            "resultats": "/mnt/c/Users/TonNom/Desktop/rapports/compare_1_vs_2"
        }

    ]
}
```

---

## Lanceur Windows (double-clic)

Créer `lancer_integrity.bat` sur le bureau :

```bat
@echo off
echo Demarrage verification integrite...
wsl bash /mnt/c/Users/TonNom/Desktop/hash_tool/runner.sh ^
    /mnt/c/Users/TonNom/Desktop/hash_tool/pipelines/pipeline-veracrypt.json
if %errorlevel% neq 0 (
    echo.
    echo ERREUR : le pipeline a echoue. Consulter les resultats.
) else (
    echo.
    echo Pipeline termine avec succes.
)
pause
```

---

## Workflows types

### Workflow d'archivage initial

1. Monter les partitions VeraCrypt
2. Double-clic sur `lancer_integrity.bat`
3. Attendre la fin (progression affichée dans la console WSL)
4. Vérifier que `recap.txt` indique OK
5. Démonter les partitions

### Workflow de vérification périodique

1. Monter les partitions VeraCrypt
2. Modifier `pipeline.json` pour ne conserver que les blocs `verify` (supprimer les `compute`)
3. Double-clic sur `lancer_integrity.bat`
4. Consulter `recap.txt` et `failed.txt` si présent
5. Démonter les partitions

### Workflow de comparaison après copie

Après avoir copié des données d'un disque à un autre :

1. `compute` sur la source (`base_a`)
2. `compute` sur la destination (`base_b`)
3. `compare base_a base_b` → `disparus.txt` et `nouveaux.txt` doivent être vides, `modifies.b3` aussi

---

## Nommage des bases

Utiliser des noms datés pour conserver l'historique :

```
bases/
├── hashes_disque_1_2024-01-15.b3    ← baseline initiale
├── hashes_disque_1_2024-06-01.b3    ← après ajout de fichiers
└── hashes_disque_1_2024-12-01.b3    ← vérification annuelle
```

Ne jamais écraser une base existante — chaque `.b3` est une preuve datée de l'état du disque.

!!! tip
    Pour automatiser le nommage daté depuis Windows avec WSL :
    ```bat
    for /f %%i in ('wsl date +%%Y-%%m-%%d') do set DATE=%%i
    ```
