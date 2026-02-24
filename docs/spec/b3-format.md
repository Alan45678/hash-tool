# Spécification formelle du format `.b3`

**Version :** 1.0  
**Statut :** Référence normative  
**Scope :** tout code lisant ou écrivant des fichiers `.b3` dans hash_tool

---

## 1. Définition

Un fichier `.b3` est un fichier texte encodé en UTF-8 contenant une empreinte BLAKE3 par fichier indexé. Son format est celui natif produit par `b3sum` version ≥ 1.3.

---

## 2. Grammaire formelle

```
b3file     ::= line* EOF
line       ::= hash SEP path LF
hash       ::= [0-9a-f]{64}
SEP        ::= "  "          (deux espaces U+0020)
path       ::= <chemin de fichier>
LF         ::= U+000A
EOF        ::= fin de fichier
```

### 2.1 Contraintes sur `hash`

- Exactement 64 caractères hexadécimaux minuscules (`[0-9a-f]`)
- Représentation de l'empreinte BLAKE3 256 bits en notation hexadécimale

### 2.2 Contraintes sur `SEP`

- Exactement deux espaces ASCII (U+0020)
- Aucun autre séparateur n'est valide (tabulation, espace unique, etc.)
- Ce format est identique à celui de `sha256sum`, `sha512sum` et `md5sum` - interopérabilité outil garantie

### 2.3 Contraintes sur `path`

- Chemin **relatif** obligatoire - voir section 3
- Encodé en UTF-8 ; les noms non UTF-8 sont traités comme des séquences d'octets opaques
- Un chemin contenant des espaces est valide (les espaces font partie du chemin, pas du séparateur)
- Le chemin inclut le préfixe `./` si `b3sum` a été appelé avec un argument commençant par `./`

### 2.4 Contraintes sur le fichier

- Trié par chemin (ordre lexicographique binaire, LC_ALL=C) - requis pour que `diff`, `join` et `comm` produisent des résultats déterministes
- Une ligne par fichier régulier - les dossiers vides ne génèrent pas de ligne
- Pas de ligne vide, pas de commentaire, pas de ligne d'en-tête
- Pas de retour chariot (U+000D) - fichier au format Unix uniquement

---

## 3. Invariant des chemins relatifs

**Règle absolue : les chemins dans un fichier `.b3` sont toujours relatifs.**

### Rationale

Un chemin absolu `/mnt/veracrypt1/photos/img.jpg` devient invalide si la partition est remontée sur `/mnt/veracrypt2/` ou déplacée. Un chemin relatif `./photos/img.jpg` reste valide quel que soit le point de montage, à condition de lancer `verify` depuis le même répertoire de travail qu'au `compute`.

### Conséquence opérationnelle

- `b3sum --check base.b3` doit être exécuté depuis le répertoire où `compute` a été lancé
- `runner.sh` gère ce `cd` automatiquement via des sous-shells isolés

### Cas de non-conformité

Un fichier `.b3` contenant des chemins absolus est techniquement lisible par `b3sum --check` mais est considéré **non conforme** au sens de cette spécification. `integrity.sh verify` refusera un tel fichier avec un avertissement.

---

## 4. Exemple conforme

```
a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2  ./dossier/fichier.txt
e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6  ./dossier/sous/autre.bin
f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1  ./fichier avec espaces.pdf
```

---

## 5. Règles de nommage des fichiers `.b3`

Ces règles ne sont pas normatives mais fortement recommandées :

- Nom daté : `hashes_YYYY-MM-DD.b3` ou `hashes_<label>_YYYY-MM-DD.b3`
- Ne jamais utiliser `hashes_latest.b3` - un nom non daté ne permet pas de situer la base dans le temps
- Stocker sur un support distinct des données vérifiées (voir guide VeraCrypt)

---

## 6. Taille indicative

| Nombre de fichiers | Taille approximative |
|---|---|
| 1 000 | ~200 Ko |
| 10 000 | ~2 Mo |
| 100 000 | ~20 Mo |
| 1 000 000 | ~200 Mo |

Calcul : 64 (hash) + 2 (séparateur) + longueur_moyenne_chemin + 1 (LF) ≈ 80–100 octets par ligne.

---

## 7. Validation programmatique

Expression régulière de validation d'une ligne :

```
^[0-9a-f]{64}  .+$
```

Validation utilisée par `core_assert_b3_valid()` dans `src/lib/core.sh` :

```bash
valid_lines=$(grep -c -E '^[0-9a-f]{64}  .+' "$file" || true)
total_lines=$(wc -l < "$file")
# Un fichier est valide si valid_lines == total_lines && valid_lines > 0
```

---

## 8. Interopérabilité

Le format est directement compatible avec les outils suivants sans conversion :

| Outil | Commande |
|---|---|
| `b3sum` | `b3sum --check base.b3` |
| `grep` | `grep FAILED < <(b3sum --check base.b3)` |
| `sort` | `sort base.b3` (tri stable, déterministe) |
| `diff` | `diff base_a.b3 base_b.b3` |
| `wc` | `wc -l base.b3` → nombre de fichiers indexés |
