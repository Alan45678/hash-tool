# Progression temps réel et estimation ETA

## Le problème

Le pipeline `find | sort | xargs b3sum` est une boîte noire : `b3sum` ne remonte aucune progression. Par défaut, le mode `compute` s'exécute en silence jusqu'à complétion - aucun indicateur de durée ni d'avancement.

---

## Pourquoi l'ETA nécessite de casser le pipeline `xargs`

Intercaler `pv` dans le pipeline existant est techniquement possible mais inutilisable ici : mesurer le débit sur un flux `cat | pv | b3sum` produit un hash global du flux concaténé, pas une ligne par fichier. Le fichier `.b3` résultant est invalide pour `--check` ou `compare`.

```bash
# Cette approche est invalide - ne pas utiliser
TOTAL=$(find "$TARGET" -type f -print0 | xargs -0 du -sb | awk '{sum+=$1} END {print sum}')
find "$TARGET" -type f -print0 | sort -z \
  | xargs -0 cat \
  | pv -s "$TOTAL" \
  | b3sum \
  > "$HASHFILE"
# Produit un hash unique du flux concaténé - inutilisable
```

La seule approche compatible avec le format `.b3` : remplacer `xargs` par une boucle bash explicite, fichier par fichier. Le contrôle de progression devient trivial. Le coût en performance est négligeable - le disque est le goulot, pas le shell.

---

## Implémentation finale : `compute_with_progress`

```bash
compute_with_progress() {
  local target="$1"
  local hashfile="$2"

  local -a files
  mapfile -d '' files < <(find "$target" -type f -print0 | sort -z)

  local total_files=${#files[@]}
  local total_bytes
  total_bytes=$(du -sb "$target" | awk '{print $1}')

  local bytes_done=0
  local t_start
  t_start=$(date +%s)

  local i=0
  for file in "${files[@]}"; do
    b3sum "$file" >> "$hashfile"

    bytes_done=$(( bytes_done + $(stat -c%s "$file") ))
    i=$(( i + 1 ))

    local t_now elapsed
    t_now=$(date +%s)
    elapsed=$(( t_now - t_start ))

    if (( bytes_done > 0 && elapsed > 0 )); then
      local speed remaining
      speed=$(( bytes_done / elapsed ))
      remaining=$(( (total_bytes - bytes_done) / speed ))
      printf "\r[%d/%d] ETA : %dm %02ds   " \
        "$i" "$total_files" $(( remaining / 60 )) $(( remaining % 60 ))
    fi
  done

  printf "\r%*s\r" 40 ""  # effacer la ligne de progression
}
```

**`mapfile -d ''`** au lieu de `FILES=($(find ...))` : la substitution de commande `$(...)` découpe sur les espaces et les retours à la ligne - les noms de fichiers avec espaces seraient cassés en plusieurs éléments. `mapfile -d ''` lit le flux nul-séparé produit par `-print0` et charge chaque chemin comme un élément distinct du tableau, sans ambiguïté.

---

## Mécanique de l'estimation

L'ETA repose sur trois mesures :

- **octets traités** - cumulés après chaque fichier via `stat -c%s`
- **octets totaux** - calculés une fois avant la boucle via `du -sb`
- **débit instantané** - `octets_traités / secondes_écoulées`

```
ETA = (octets_restants) / débit_moyen
    = (total - fait) / (fait / elapsed)
```

Le débit moyen converge après ~10–20 secondes de traitement. Avant ce seuil, l'ETA est instable - comportement identique à `rsync`, `cp --progress`, ou tout outil du même type. Ce n'est pas un défaut d'implémentation, c'est une contrainte statistique inhérente à toute estimation par extrapolation linéaire sur fenêtre courte.

---

## Coût du changement de stratégie

| | Pipeline `xargs` | Boucle bash (avec progression) |
|---|---|---|
| Débit sur HDD | Optimal | Identique - I/O impose le rythme |
| Débit sur SSD séquentiel | Optimal | Identique |
| Débit sur SSD `-P 4` | +20–40 % | Non applicable - boucle séquentielle |
| Progression temps réel | Non | Oui |
| ETA | Non | Oui |

**Cas où la boucle dégrade les performances :** SSD avec `-P 4`. Le parallélisme par `xargs` n'est pas reproductible en boucle bash sans complexité significative. Sur HDD - cas le plus courant pour de gros volumes - la différence est nulle.
