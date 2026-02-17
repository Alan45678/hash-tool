# Tests et validation - integrity.sh

**Niveau d'exigence :** production, admin système. Chaque cas doit être exécuté et son résultat vérifié explicitement.

---

## Environnement de test

```bash
# Créer un environnement de test isolé
mkdir -p /tmp/integrity-test/{data,output}
cd /tmp/integrity-test

# Créer des fichiers de test avec contenu connu
echo "contenu alpha" > data/alpha.txt
echo "contenu beta"  > data/beta.txt
echo "contenu gamma" > data/gamma.txt
mkdir -p data/sub
echo "contenu delta" > data/sub/delta.txt
```

---

## Cas de test

### T01 - Compute de base

```bash
./integrity.sh compute ./data base_t01.b3
```

**Résultat attendu :**

- Fichier `base_t01.b3` créé avec 4 lignes (une par fichier).
- Message `Base enregistrée : base_t01.b3 (4 fichiers)`.
- Chaque ligne au format `<hash64chars>  ./data/<chemin>`.

```bash
# Vérification
wc -l base_t01.b3           # → 4
head -1 base_t01.b3         # → hash + chemin lisibles
```

---

### T02 - Verify sans modification

```bash
b3sum --check base_t01.b3
```

**Résultat attendu :** 4 lignes `OK`, aucun `FAILED`, exit code 0.

```bash
echo $?   # → 0
```

---

### T03 - Verify après corruption d'un fichier

```bash
echo "contenu modifié" > data/beta.txt
b3sum --check base_t01.b3
```

**Résultat attendu :**

- `./data/beta.txt: FAILED`
- `b3sum: WARNING: 1 computed checksum did NOT match`
- Exit code non nul.

```bash
echo $?   # → 1
b3sum --check base_t01.b3 2>&1 | grep FAILED   # → ./data/beta.txt: FAILED
```

---

### T04 - Verify après suppression d'un fichier

```bash
# Restaurer l'état T01 d'abord
echo "contenu beta" > data/beta.txt

# Supprimer un fichier
rm data/gamma.txt
b3sum --check base_t01.b3
```

**Résultat attendu :**

- `./data/gamma.txt: FAILED` (No such file or directory)
- Exit code non nul.

---

### T05 - Compare : aucune différence

```bash
# Restaurer l'état T01
echo "contenu gamma" > data/gamma.txt

# Créer une seconde base identique
./integrity.sh compute ./data base_t05.b3
./integrity.sh compare base_t01.b3 base_t05.b3
```

**Résultat attendu :** sections `MODIFIÉS`, `DISPARUS`, `NOUVEAUX` toutes vides. Rapport sauvegardé.

---

### T06 - Compare : fichier modifié

```bash
echo "contenu beta modifié" > data/beta.txt
./integrity.sh compute ./data base_t06.b3
./integrity.sh compare base_t01.b3 base_t06.b3
```

**Résultat attendu :**

- Section `FICHIERS MODIFIÉS` contient `./data/beta.txt` avec ancien et nouveau hash.
- Sections `DISPARUS` et `NOUVEAUX` vides.

---

### T07 - Compare : fichier supprimé + fichier ajouté

```bash
# Repartir d'une base propre
echo "contenu beta" > data/beta.txt
./integrity.sh compute ./data base_t07_old.b3

# Modifier l'état
rm data/alpha.txt
echo "contenu epsilon" > data/epsilon.txt
./integrity.sh compute ./data base_t07_new.b3

./integrity.sh compare base_t07_old.b3 base_t07_new.b3
```

**Résultat attendu :**

- `DISPARUS` : `./data/alpha.txt`
- `NOUVEAUX` : `./data/epsilon.txt`
- `MODIFIÉS` : vide

---

### T08 - Robustesse : fichier avec espace dans le nom

```bash
echo "contenu avec espace" > "data/fichier avec espace.txt"
./integrity.sh compute ./data base_t08.b3
b3sum --check base_t08.b3
```

**Résultat attendu :** tous les fichiers `OK`, y compris `fichier avec espace.txt`.

---

### T09 - Robustesse : dossier vide (limite connue)

```bash
mkdir data/dossier_vide
./integrity.sh compute ./data base_t09.b3
```

**Résultat attendu :** `dossier_vide` absent de `base_t09.b3`. Comportement normal et documenté - `find -type f` n'indexe pas les dossiers vides.

---

### T10 - Chemin absolu vs relatif (piège critique)

```bash
# Calculer avec chemin absolu - mauvaise pratique
b3sum $(find /tmp/integrity-test/data -type f) > base_absolu.b3
head -1 base_absolu.b3   # → chemin absolu /tmp/integrity-test/data/...

# Calculer avec chemin relatif - bonne pratique
cd /tmp/integrity-test
find ./data -type f -print0 | sort -z | xargs -0 b3sum > base_relatif.b3
head -1 base_relatif.b3  # → chemin relatif ./data/...
```

**Résultat attendu :** les deux bases sont incompatibles entre elles. Confirme que les chemins absolus cassent la portabilité.

---

## Nettoyage

```bash
rm -rf /tmp/integrity-test
```

---

## Critères de qualité globaux

| Critère | Exigence |
|---|---|
| Détection corruption | 100 % des fichiers modifiés détectés (T03) |
| Détection suppression | 100 % des fichiers manquants détectés (T04) |
| Faux positifs | Zéro - verify sur base intacte = 100 % OK (T02) |
| Noms avec espaces | Traités sans erreur (T08) |
| Rapport compare | Sauvegardé sur disque, horodaté (T05–T07) |
| Exit code | Non nul si au moins un FAILED (T03, T04) |
| Mode strict `-euo pipefail` | Le script s'arrête sur toute erreur non gérée |
