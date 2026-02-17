





jusque là mon outil utilisait des fichier .b3 pour stocker les bases de hash, c'est quoi ?



## Fichiers .b3 - Explication

Les fichiers `.b3` sont simplement des **fichiers texte** contenant les résultats de `b3sum`, sans format spécial.

### Contenu d'un fichier .b3

```
096fc1aadff334e739da7bde4bca5116735c85e097ec459c9765382656073b18  /chemin/fichier (1).txt
0f6591514285c2e48ce58e71cc34879e345b7414dba9201ba2c8c9bb812b7924  /chemin/fichier (2).txt
7bb238792d6ba450e3d9cb1b4bc2de6c8dc8210a6011282b7df2c3772b462df9  /chemin/fichier (3).txt
```

**Format** : `<hash_blake3>  <chemin_fichier>`

### C'est juste une convention de nommage

L'extension `.b3` n'est **pas un format officiel**. C'est une convention personnelle pour :
- Indiquer visuellement "ce fichier contient des hash BLAKE3"
- Différencier des hash MD5 (`.md5`) ou SHA256 (`.sha256`)

**Équivalents** :
```bash
b3sum fichier.txt > hash.b3      # Votre convention
b3sum fichier.txt > hash.txt     # Exactement pareil
b3sum fichier.txt > hash.blake3  # Aussi valable
```

### Avantages vs SQLite

**Fichier .b3 (texte)** :
- ✅ Simple, lisible humainement
- ✅ Compatible avec `diff`, `grep`, `sort`
- ✅ Portable (aucune dépendance)
- ❌ Pas de métadonnées (date, taille, mtime)
- ❌ Recherche lente sur gros volumes
- ❌ Pas d'index, pas de requêtes SQL

**Base SQLite (.db)** :
- ✅ Métadonnées enrichies (date scan, taille, mtime)
- ✅ Requêtes rapides et complexes
- ✅ Index pour performance
- ✅ Historique et versioning facile
- ❌ Nécessite SQLite
- ❌ Moins lisible directement

### Votre utilisation actuelle

Dans votre projet :

**Fichier `source.b3`** :
```
096fc1aadff334e739da7bde4bca5116735c85e097ec459c9765382656073b18  /path/fichier (1).txt
0f6591514285c2e48ce58e71cc34879e345b7414dba9201ba2c8c9bb812b7924  /path/fichier (2).txt
```

**Fichier `source_norm.b3`** (chemins normalisés) :
```
096fc1aadff334e739da7bde4bca5116735c85e097ec459c9765382656073b18  fichier (1).txt
0f6591514285c2e48ce58e71cc34879e345b7414dba9201ba2c8c9bb812b7924  fichier (2).txt
```

Puis comparaison :
```bash
diff source_norm.b3 destination_norm.b3
```

### Migration .b3 -> SQLite

Si vous voulez garder la compatibilité avec vos fichiers `.b3` existants :

```bash
#!/bin/bash
# import_b3_to_db.sh

B3_FILE="$1"
DB_FILE="$2"

sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS file_hashes (
    path TEXT PRIMARY KEY,
    hash_blake3 TEXT NOT NULL,
    size INTEGER,
    mtime INTEGER,
    scan_date TIMESTAMP
);
EOF

while IFS= read -r line; do
    hash=$(echo "$line" | awk '{print $1}')
    path=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
    
    sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO file_hashes (path, hash_blake3, scan_date) VALUES ('$path', '$hash', datetime('now'));"
done < "$B3_FILE"

echo "Import terminé : $(sqlite3 "$DB_FILE" 'SELECT COUNT(*) FROM file_hashes;') fichiers"
```

Usage :
```bash
./import_b3_to_db.sh test/hash/hashbase/source.b3 hashdb/source_imported.db
```

### Recommandation

**Garder .b3 pour** :
- Interopérabilité avec d'autres outils
- Archivage simple et pérenne
- Debug rapide (cat, grep)

**Utiliser SQLite pour** :
- Détection bit rot (besoin de métadonnées temporelles)
- Gros volumes (>10 000 fichiers)
- Requêtes complexes (fichiers >1GB, modifiés depuis X jours)
- Historique multi-dates

**Solution hybride** :
```bash
# Générer les deux formats
b3sum -r /data > backup.b3                    # Format texte simple
./hash_tool.sh baseline --dir /data --name backup  # SQLite avec métadonnées
```

Votre `.b3` est juste du texte brut - aucun problème à continuer de l'utiliser si ça suffit pour vos besoins.

