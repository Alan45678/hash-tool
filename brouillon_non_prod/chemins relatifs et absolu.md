


**Problématique : comparaison de dossiers sur différents volumes**

Lorsqu’on utilise `hash-tool` pour comparer des dossiers situés sur des volumes différents (ex. `A:/disque_1/musique` vs `Z:/disque_3/musique`), une limitation apparaît : les bases `.b3` actuelles stockent des chemins **absolus**. Ainsi, même si les fichiers ont un contenu identique, `compare` ou `verify` peut signaler des différences, car les chemins absolus diffèrent (`A:/…` ≠ `Z:/…`).

Ce comportement n’est pas un bug : l’outil compare en réalité des fonctions `chemin → hash`. Toute divergence dans les chemins rend la comparaison invalide.

---

**Feature proposée : support des chemins relatifs**

Pour résoudre ce problème, il est nécessaire d’introduire le concept de **chemins relatifs à une racine logique**.

* Lors de l’indexation (`compute`), le chemin enregistré dans la base `.b3` serait **relatif à la racine du dossier analysé** (ex. `musique/album1/piste1.flac`).
* Lors de la vérification ou de la comparaison (`verify` / `diff`), ces chemins relatifs seraient appliqués à la racine du dossier cible, quelle que soit sa localisation sur le système de fichiers.

**Avantages attendus :**

1. Comparer deux copies identiques de dossiers sur différents volumes sans générer de faux positifs liés aux chemins absolus.
2. Détecter précisément : fichiers modifiés, manquants ou ajoutés, indépendamment du point de montage ou de la lettre de disque.
3. Maintenir l’intégrité logique du workflow actuel, sans changer la méthode de calcul des hash.

**Exemple :**

* Base générée sur : `A:/disque_1/musique` → enregistre `album1/piste1.flac`
* Vérification sur : `Z:/disque_3/musique` → applique le même chemin relatif, détection correcte des écarts.

En résumé, le support des chemins relatifs permet une **comparaison robuste des contenus**, indépendamment des chemins physiques, tout en conservant la puissance et la granularité du modèle `chemin → hash`.


