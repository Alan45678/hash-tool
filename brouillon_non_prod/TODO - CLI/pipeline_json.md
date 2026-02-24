


### Fichier : pipeline_json.md

**Rapport — Documentation du pipeline JSON pour `hash-tool`**

---

**1. Objectif**

Le pipeline JSON permet de définir une suite d’opérations à exécuter automatiquement avec `hash-tool runner`. Chaque étape correspond à une commande CLI (`compute`, `verify`, `compare`, etc.) et inclut les chemins, paramètres et options nécessaires.

Le fichier `pipeline-amelioree.json` fournit un exemple représentatif, suffisant pour couvrir toutes les commandes principales et illustrer la structure uniforme du pipeline.

---

**2. Structure générale**

Chaque étape du pipeline utilise une structure uniforme :

* `type` : commande à exécuter (`compute`, `verify`, `compare`, `runner`, `list`, `diff`, `stats`, `check-env`, `version`).
* `params` : arguments spécifiques à la commande (`input`, `reference`, `output_dir`, etc.).
* `options` : flags optionnels (`verbose`, `quiet`, `readonly`, etc.).
* `meta` : métadonnées optionnelles pour enrichir la documentation et suivi (ex. `comment`).
* `description` : texte explicatif décrivant l’étape.

Cette uniformité permet au runner de **parcourir toutes les étapes dans l’ordre** et d’exécuter automatiquement les commandes, tout en conservant un format homogène, clair et validable.

---

**3. Référence du fichier pipeline**

Le pipeline complet est disponible dans :

```
pipeline-amelioree.json
```

Ce fichier contient un exemple pertinent, couvrant toutes les commandes principales et utilisant la structure uniforme `type` / `params` / `options` / `meta` avec `description`.

---

**4. Description fonctionnelle**

* Chaque étape correspond à une commande CLI.
* `params` et `options` sont standardisés pour toutes les commandes, facilitant l’automatisation.
* `meta` permet d’associer des informations complémentaires à chaque étape, exploitables par les pipelines ou le sidecar file.
* Le champ `description` fournit une documentation lisible directement dans le JSON.
* Le runner exécute chaque étape dans l’ordre défini.

---

**5. Bonnes pratiques**

1. Toujours vérifier les chemins et permissions avant exécution.
2. Utiliser des noms explicites pour les fichiers de base (`filename`) et dossiers de sortie (`output_dir`).
3. Ajouter les options (`verbose`, `quiet`, `readonly`) au niveau de chaque étape si nécessaire.
4. Compléter le champ `description` pour documenter le rôle de chaque étape, facilitant la lecture et le suivi du pipeline.
5. Exploiter le champ `meta` pour des commentaires, version de snapshot ou paramètres spécifiques.
6. Utiliser le fichier `pipeline-amelioree.json` comme référence pour créer de nouveaux pipelines cohérents et homogènes.

---

**6. Avantages du format**

* Pertinent et compréhensible pour l’utilisateur.
* Suffisamment descriptif pour illustrer toutes les commandes principales.
* Uniforme, extensible et facile à valider avec JSON Schema.
* Permet l’automatisation et la documentation simultanément.
* Intégrable avec le sidecar file pour enrichir les métadonnées associées aux fichiers `.b3`.


