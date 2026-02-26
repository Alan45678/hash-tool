


### Note — Feature « Sidecar File » pour `hash-tool`

**Objet :** ajout de la possibilité de stocker des métadonnées et commentaires associés aux fichiers `.b3` générés par `hash-tool`.

---

#### 1. Contexte

Les fichiers `.b3` générés par `hash-tool` contiennent uniquement les hash Blake3 des fichiers d’un dossier. Actuellement, il n’existe aucun espace prévu pour des commentaires ou des informations complémentaires (ex. date de snapshot, paramètres utilisés, version de l’outil).

Pour enrichir l’information sans modifier le format `.b3` natif ni perdre la compatibilité avec d’autres outils Blake3, l’introduction d’un **sidecar file** est proposée.

---

#### 2. Principe

Un **sidecar file** est un fichier annexe, créé à côté du fichier `.b3` correspondant, contenant des métadonnées structurées.

* Extension suggérée : `.meta.json` ou `.b3.json` (ex. `hashes_exemple.b3.meta.json`).
* Format : JSON, pour lisibilité et compatibilité avec les pipelines existants.
* Contenu typique : informations descriptives, date de création, paramètres d’exécution, version de `hash-tool`.

---

#### 3. Structure du sidecar

Exemple minimal de fichier sidecar :

```json
{
  "created_by": "hash-tool v1.2",
  "date": "2026-02-24T14:30:00Z",
  "comment": "Snapshot avant migration",
  "parameters": {
    "readonly": true,
    "directory": "/mnt/data/dossier_exemple",
    "hash_algo": "blake3"
  }
}
```

**Champs principaux :**

| Champ        | Description                                                                   |
| ------------ | ----------------------------------------------------------------------------- |
| `created_by` | Version de l’outil ayant généré le snapshot.                                  |
| `date`       | Date et heure du calcul des hash.                                             |
| `comment`    | Texte libre pour des informations contextuelles.                              |
| `parameters` | Paramètres utilisés pour le calcul des hash (répertoires, flags, algorithme). |

---

#### 4. Avantages

1. **Compatibilité** : le fichier `.b3` reste inchangé, donc compatible avec Blake3 standard.
2. **Extensible** : possibilité d’ajouter de nouveaux champs sans modifier le moteur de hash.
3. **Synchronisation** : le sidecar est lié au fichier `.b3` correspondant et peut être automatiquement créé par `hash-tool`.
4. **Automatisation** : les pipelines (`runner`) peuvent lire et utiliser les métadonnées pour documentation ou suivi.

---

#### 5. Intégration dans `hash-tool`

* **Création automatique** : lors de `hash-tool compute`, un sidecar peut être généré dans le même répertoire que le `.b3`.
* **Lecture et affichage** : les commandes `verify`, `compare`, `stats` peuvent afficher ou exploiter les métadonnées.
* **Mise à jour optionnelle** : possibilité d’ajouter un commentaire postérieur au snapshot sans toucher au `.b3`.

* `params.meta` dans le pipeline JSON peut être utilisé pour remplir le sidecar automatiquement.

**Exemple d’usage :**

```bash
hash-tool compute -data ./donnees -save ./bases -meta "Snapshot initial"
```

Cette commande générerait :

* `hashes_donnees.b3` → hash des fichiers
* `hashes_donnees.b3.meta.json` → métadonnées contenant la note “Snapshot initial” et autres informations automatiques (date, version, paramètres).

---

#### 6. Conclusion

Le sidecar file est une solution simple et robuste pour enrichir les fichiers `.b3` avec des métadonnées :

* Aucun impact sur le format binaire existant.
* Permet la documentation, l’automatisation et le suivi des snapshots.
* Compatible avec les pipelines et l’interface CLI unique de `hash-tool`.



















