# Référence - `hash-tool runner` & pipeline JSON

Orchestrateur de pipeline pour exécuter plusieurs opérations en séquence.

**Scripts :** `hash-tool runner` (CLI unique) → `runner.sh` (implémentation)  
**Dépendance :** `jq`

---

## Synopsis

```bash
hash-tool runner [-pipeline <fichier.json>] [-save <dossier>]

# Ou directement :
./runner.sh [pipeline.json]
```

| Argument | Défaut | Description |
|---|---|---|
| `-pipeline` | `pipelines/pipeline.json` | Chemin vers le fichier de configuration du pipeline. |
| `-save` | `RESULTATS_DIR` | Dossier de résultats global (surcharge `RESULTATS_DIR`). |

---

## Pourquoi un runner

Lancer `integrity.sh` manuellement sur plusieurs dossiers est error-prone :

- Oublier le `cd` avant `compute` → chemins absolus dans la base
- Mauvais répertoire de travail pour `verify` → faux positifs massifs
- Ordre d'exécution non garanti sur des appels séparés

`runner.sh` élimine ces risques : il gère automatiquement les `cd`, valide les chemins avant exécution, et s'arrête immédiatement sur toute erreur (`set -euo pipefail`).

---

## Deux formats de pipeline

`runner.sh` supporte deux formats, **rétrocompatibles** et détectés automatiquement :

### Format legacy

Format d'origine, basé sur le champ `"op"`. Toujours fonctionnel.

```json
{
    "pipeline": [
        { "op": "compute", "source": "...", "bases": "...", "nom": "..." },
        { "op": "verify",  "source": "...", "base":  "..." },
        { "op": "compare", "base_a": "...", "base_b": "...", "resultats": "..." }
    ]
}
```

### Format étendu (recommandé)

Structure uniforme `type / params / options / meta / description`. Supporte toutes les commandes et le sidecar.

```json
{
    "pipeline": [
        {
            "type":        "compute",
            "params":      { "input": "...", "output_dir": "...", "filename": "..." },
            "options":     { "quiet": false, "verbose": false, "readonly": true },
            "meta":        { "comment": "Snapshot initial" },
            "description": "Texte explicatif de l'étape"
        }
    ]
}
```

Le format est détecté automatiquement par la présence de `"op"` (legacy) ou `"type"` (étendu).

---

## Opérations - Format legacy

### `compute`

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
| `source` | Oui | Dossier à indexer. `runner.sh` fait `cd` dans ce dossier - chemins relatifs garantis dans la base. |
| `bases` | Oui | Dossier de destination pour le fichier `.b3`. Créé automatiquement si inexistant. |
| `nom` | Oui | Nom du fichier `.b3` à créer dans `bases`. |

### `verify`

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

### `compare`

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
| `resultats` | Non | Dossier de destination des résultats. Surcharge `RESULTATS_DIR` pour ce seul bloc. |

---

## Opérations - Format étendu

### `compute`

```json
{
    "type": "compute",
    "params": {
        "input":      "/chemin/vers/dossier",
        "output_dir": "/chemin/vers/bases",
        "filename":   "hashes.b3"
    },
    "options": { "quiet": false, "readonly": true },
    "meta":    { "comment": "Snapshot avant migration" },
    "description": "Indexation du dossier source"
}
```

| Champ | Requis | Description |
|---|---|---|
| `params.input` | Oui | Dossier à indexer. |
| `params.output_dir` | Oui | Dossier de destination pour le `.b3`. Créé automatiquement. |
| `params.filename` | Oui | Nom du fichier `.b3`. |
| `options.quiet` | Non | Supprime la sortie terminal. Défaut : `false`. |
| `options.readonly` | Non | Documenté dans le sidecar. Défaut : `false`. |
| `meta.comment` | Non | Commentaire stocké dans le sidecar `.meta.json`. |
| `description` | Non | Documentation lisible dans le JSON. |

**Sidecar :** si `meta.comment` est fourni, un fichier `<filename>.meta.json` est généré à côté du `.b3`.

### `verify`

```json
{
    "type": "verify",
    "params": {
        "input": "/chemin/vers/dossier",
        "base":  "/chemin/vers/hashes.b3"
    },
    "options": { "quiet": false },
    "description": "Vérification d'intégrité"
}
```

| Champ | Requis | Description |
|---|---|---|
| `params.input` | Oui | Répertoire de travail d'origine. |
| `params.base` | Oui | Chemin du fichier `.b3`. |

### `compare`

```json
{
    "type": "compare",
    "params": {
        "reference":  "/chemin/vers/ancienne.b3",
        "input":      "/chemin/vers/nouvelle.b3",
        "output_dir": "/chemin/vers/dossier_resultats"
    },
    "options": { "quiet": false },
    "description": "Comparaison avant/après migration"
}
```

| Champ | Requis | Description |
|---|---|---|
| `params.reference` | Oui | Ancienne base (référence). |
| `params.input` | Oui | Nouvelle base (à comparer). |
| `params.output_dir` | Non | Dossier de résultats. Surcharge `RESULTATS_DIR` pour ce bloc. |

### `list`

```json
{
    "type": "list",
    "params": { "input_dir": "/chemin/vers/bases" },
    "description": "Lister les bases disponibles"
}
```

### `diff`

```json
{
    "type": "diff",
    "params": {
        "input":         "/chemin/vers/hashes.b3",
        "reference_dir": "/chemin/vers/dossier"
    },
    "description": "Différences entre base et dossier courant"
}
```

### `stats`

```json
{
    "type": "stats",
    "params": { "input": "/chemin/vers/hashes.b3" },
    "description": "Statistiques de la base"
}
```

### `check-env`

```json
{
    "type": "check-env",
    "params": {},
    "description": "Vérifier l'environnement d'exécution"
}
```

### `version`

```json
{
    "type": "version",
    "params": {},
    "description": "Afficher la version"
}
```

---

## Exemples complets

### Pipeline VeraCrypt multi-disques (format legacy)

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

### Pipeline complet avec sidecar (format étendu)

Voir `pipelines/pipeline-amelioree.json` pour un exemple complet couvrant toutes les commandes.

---

## Validation et messages d'erreur

`runner.sh` valide la configuration avant d'exécuter quoi que ce soit :

| Problème | Message |
|---|---|
| JSON invalide | `ERREUR : JSON invalide : /chemin/pipeline.json` |
| Clé `.pipeline` absente | `ERREUR : tableau .pipeline vide ou absent` |
| Champ requis manquant | `ERREUR : Bloc #2 : params.filename manquant ou vide.` |
| Type inconnu | `ERREUR : Bloc #3 : type inconnu : 'migrate'` |
| Dossier source introuvable | `ERREUR : Bloc #1 compute : dossier source introuvable : /mnt/a/...` |
| Base `.b3` introuvable | `ERREUR : Bloc #2 verify : base .b3 introuvable : /mnt/c/...` |
| `runner` imbriqué | `ERREUR : Bloc #1 : 'runner' imbriqué non supporté.` |

---

## Variables d'environnement

### `RESULTATS_DIR`

Dossier de résultats global pour tous les blocs `verify` et `compare` sans champ `output_dir` (format étendu) ou `resultats` (format legacy) explicite.

```bash
export RESULTATS_DIR=/srv/rapports
hash-tool runner -pipeline ./pipeline.json
```

Défaut : `~/integrity_resultats`.

---

## Exit codes

| Code | Signification |
|---|---|
| `0` | Pipeline exécuté entièrement sans erreur |
| `1` | Erreur sur un bloc (blocs suivants non exécutés) |

---

## Isolation des sous-shells

`runner.sh` utilise des sous-shells `( )` pour isoler les `cd` :

```bash
# Le cd ne fuite pas vers les blocs suivants
( cd "$source" && integrity.sh compute . "$bases/$nom" )
```

Chaque bloc `compute` et `verify` démarre dans le répertoire courant du processus principal, quels que soient les `cd` des blocs précédents. `RESULTATS_DIR` est de même isolé pour les blocs avec un champ `output_dir`/`resultats` explicite.

---

## Lancement depuis Windows (WSL)

```bat
@echo off
wsl bash /mnt/c/Users/TonNom/Desktop/hash_tool/runner.sh
pause
```

Avec pipeline explicite :

```bat
@echo off
wsl bash /mnt/c/Users/TonNom/Desktop/hash_tool/runner.sh ^
    /mnt/c/Users/TonNom/Desktop/mon-pipeline.json
pause
```