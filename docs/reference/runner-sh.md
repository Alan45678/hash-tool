# Référence - runner.sh & pipeline.json

Orchestrateur de pipeline pour exécuter plusieurs opérations `integrity.sh` en séquence.

**Emplacement :** `runner.sh`  
**Dépendance supplémentaire :** `jq`

---

## Synopsis

```
runner.sh [pipeline.json]
```

| Argument | Défaut | Description |
|---|---|---|
| `pipeline.json` | `pipelines/pipeline.json` | Chemin vers le fichier de configuration du pipeline. |

---

## Pourquoi runner.sh

Lancer `integrity.sh` manuellement sur plusieurs dossiers est error-prone :

- Oublier le `cd` avant `compute` → chemins absolus dans la base
- Mauvais répertoire de travail pour `verify` → faux positifs massifs
- Ordre d'exécution non garanti sur des appels séparés

`runner.sh` élimine ces risques : il gère automatiquement les `cd`, valide les chemins avant exécution, et s'arrête immédiatement sur toute erreur (`set -euo pipefail`).

---

## Format pipeline.json

### Structure générale

```json
{
    "pipeline": [
        { "op": "compute", ... },
        { "op": "verify",  ... },
        { "op": "compare", ... }
    ]
}
```

Le tableau `pipeline` est exécuté séquentiellement. En cas d'erreur sur un bloc, l'exécution s'arrête immédiatement.

### Opération `compute`

Calcule les hashes d'un dossier et produit un fichier `.b3`.

```json
{
    "op":     "compute",
    "source": "/chemin/vers/dossier",
    "bases":  "/chemin/vers/dossier_bases",
    "nom":    "hashes.b3"
}
```

| Champ | Requis | Description |
|---|---|---|
| `op` | Oui | `"compute"` |
| `source` | Oui | Dossier à indexer. `runner.sh` fait `cd` dans ce dossier avant le compute - les chemins dans la base seront relatifs. |
| `bases` | Oui | Dossier où enregistrer le fichier `.b3`. Créé automatiquement si inexistant. |
| `nom` | Oui | Nom du fichier `.b3` à créer dans `bases`. |

**Comportement interne :** `cd "$source"` puis `integrity.sh compute . "$bases/$nom"`. Le `.` garantit des chemins relatifs dans la base.

### Opération `verify`

Vérifie l'intégrité d'un dossier contre une base `.b3`.

```json
{
    "op":     "verify",
    "source": "/chemin/vers/dossier",
    "base":   "/chemin/vers/hashes.b3"
}
```

| Champ | Requis | Description |
|---|---|---|
| `op` | Oui | `"verify"` |
| `source` | Oui | Répertoire de travail d'origine (celui depuis lequel le `compute` a été fait). |
| `base` | Oui | Chemin complet du fichier `.b3`. |

**Comportement interne :** résolution du chemin absolu de `base`, puis `cd "$source"`, puis `integrity.sh verify "$base_abs"`.

### Opération `compare`

Compare deux bases `.b3`.

```json
{
    "op":        "compare",
    "base_a":    "/chemin/vers/ancienne.b3",
    "base_b":    "/chemin/vers/nouvelle.b3",
    "resultats": "/chemin/vers/dossier_resultats"
}
```

| Champ | Requis | Description |
|---|---|---|
| `op` | Oui | `"compare"` |
| `base_a` | Oui | Ancienne base (référence). |
| `base_b` | Oui | Nouvelle base (à comparer). |
| `resultats` | Non | Dossier de destination des résultats. Surcharge `RESULTATS_DIR` pour ce seul bloc. Créé automatiquement si inexistant. |

**Champ `resultats` :** l'isolation est garantie par un sous-shell - `RESULTATS_DIR` du processus parent n'est pas modifié. Les autres blocs du pipeline continuent d'utiliser la valeur globale de `RESULTATS_DIR`.

---

## Exemple complet - VeraCrypt multi-disques

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

## Validation et messages d'erreur

`runner.sh` valide la configuration avant d'exécuter quoi que ce soit :

| Problème | Message |
|---|---|
| JSON invalide | `ERREUR : JSON invalide : /chemin/pipeline.json` |
| Clé `.pipeline` absente | `ERREUR : tableau .pipeline vide ou absent` |
| Champ requis manquant | `ERREUR : Bloc #2 : champ 'nom' manquant ou vide.` |
| Opération inconnue | `ERREUR : Bloc #3 : opération inconnue : 'migrate'` |
| Dossier source introuvable | `ERREUR : Bloc #1 compute : dossier source introuvable : /mnt/a/...` |
| Base `.b3` introuvable | `ERREUR : Bloc #2 verify : base .b3 introuvable : /mnt/c/...` |

Tous les messages d'erreur incluent le numéro de bloc pour faciliter le débogage.

---

## Variables d'environnement

### `RESULTATS_DIR`

Dossier de résultats global pour tous les blocs `verify` et `compare` sans champ `resultats` explicite.

```bash
export RESULTATS_DIR=/srv/rapports
./runner.sh
```

Défaut : `~/integrity_resultats` (hérité de `integrity.sh`).

---

## Exit codes

| Code | Signification |
|---|---|
| `0` | Pipeline exécuté entièrement sans erreur |
| `1` | Erreur sur un bloc (bloc suivant non exécuté) |

---

## Lancement depuis Windows

Créer un fichier `.bat` sur le bureau :

```bat
@echo off
wsl bash /mnt/c/Users/TonNom/Desktop/hash_tool/runner.sh
pause
```

Double-clic pour exécuter. La fenêtre reste ouverte après exécution grâce à `pause`.

Pour un pipeline explicite :

```bat
@echo off
wsl bash /mnt/c/Users/TonNom/Desktop/hash_tool/runner.sh ^
    /mnt/c/Users/TonNom/Desktop/mon-pipeline.json
pause
```

---

## Isolation des sous-shells

`runner.sh` utilise des sous-shells `( )` pour isoler les `cd` :

```bash
# Le cd ne fuite pas vers les blocs suivants
( cd "$source" && integrity.sh compute . "$bases/$nom" )
```

Chaque bloc `compute` et `verify` démarre dans le répertoire courant du processus principal, quels que soient les `cd` des blocs précédents. La variable `RESULTATS_DIR` est de même isolée pour les blocs `compare` avec un champ `resultats` explicite.
