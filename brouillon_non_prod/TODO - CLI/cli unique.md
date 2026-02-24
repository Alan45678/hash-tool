
**Rapport — Spécification conceptuelle de l’interface CLI de `hash-tool` (version mise à jour)**

**1. Objectif général**

Le logiciel `hash-tool` propose une interface en ligne de commande unique, indépendante du mode d’exécution réel (natif ou conteneurisé). L’utilisateur interagit exclusivement avec une grammaire de commandes stable, sans référence explicite à l’environnement d’exécution. Le logiciel choisit automatiquement le mode d’exécution (natif ou conteneurisé) selon les capacités détectées.

Ce principe correspond à une abstraction de la couche d’exécution : la CLI constitue un contrat stable entre l’utilisateur et le logiciel, tandis que l’implémentation peut varier selon l’environnement.

---

**2. Principe d’interface de commande unique**

La propriété centrale reste l’« unicité de l’interface » :

– L’utilisateur invoque toujours `hash-tool` avec la même syntaxe,
– Le logiciel détecte en interne les capacités de l’environnement,
– Si l’exécution native est possible, elle est utilisée,
– Sinon, le programme délègue l’exécution à un conteneur (Docker), invisible pour l’utilisateur.

Docker ou tout autre conteneur devient un **détail d’implémentation**. La CLI reste stable et intuitive.

---

**3. Support des pipelines JSON (conceptuel)**

Le logiciel prend en charge un **fichier pipeline JSON** définissant une suite d’opérations à exécuter automatiquement. Chaque opération (`op`) correspond à une commande CLI (`compute`, `verify`, `compare`). Le runner (`hash-tool runner -pipeline <chemin>`) parcourt le JSON et exécute chaque étape dans l’ordre, en respectant la logique métier.

Exemple conceptuel :

```json
{
  "pipeline": [
    { "op": "compute", "source": "...", "bases": "...", "nom": "..." },
    { "op": "verify", "source": "...", "base": "..." },
    { "op": "compare", "base_a": "...", "base_b": "...", "resultats": "..." }
  ]
}
````

**Description fonctionnelle :**

– Les chemins et noms dans le JSON reflètent les arguments de la CLI.
– Les opérations sont cumulables et répétables sur plusieurs dossiers et bases sans intervention manuelle.
– Cette approche rend la CLI plus puissante et adaptée à l’automatisation tout en conservant l’interface unique et cohérente.

---

**4. Support des métadonnées avec Sidecar File (conceptuel)**

Le logiciel peut générer un fichier **sidecar** associé à chaque `.b3` produit, contenant des métadonnées et commentaires. Cela permet de conserver des informations supplémentaires sans altérer le fichier `.b3` natif.

Exemple d’usage conceptuel :

```bash
hash-tool compute -data ./donnees -save ./bases -meta "Snapshot initial"
```

Cette commande génère :

* `hashes_donnees.b3` → hash des fichiers
* `hashes_donnees.b3.meta.json` → sidecar avec métadonnées (date, version, paramètres, commentaire)

---

**5. Conclusion**

Le modèle CLI conceptuel final :

– Interface homogène et stable pour toutes les opérations
– Détection automatique du mode d’exécution (natif ou Docker)
– Support conceptuel des pipelines JSON pour automatisation
– Gestion des métadonnées via sidecar file
– Détail d’implémentation masqué à l’utilisateur
– Maximisation de lisibilité, portabilité et ergonomie


