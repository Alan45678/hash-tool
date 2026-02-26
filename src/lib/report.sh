# --- START OF REFACTORED FILE src/lib/report.sh ---
#!/usr/bin/env bash
# lib/report.sh - Génération des rapports de résultats à partir d'un template
#
# Sourcé par integrity.sh. Ne pas exécuter directement.
#
# Fonctions exportées :
#   generate_compare_html  <old> <new> <nb_mod> <nb_dis> <nb_nou>
#                          <modifies.b3> <disparus.txt> <nouveaux.txt>
#                          <output.html>

# _render_html_file_list <fichier_source> <message_si_vide>
#
# Fonction interne pour générer une liste <ul><li>...</li></ul> à partir d'un fichier texte.
# Gère les fichiers .b3 (en extrayant uniquement le chemin) et les .txt.
#
# Sortie : une chaîne de caractères contenant le bloc HTML.
_render_html_file_list() {
  local file="$1"
  local empty_msg="$2"
  
  # Fonction pour échapper les caractères HTML de base
  _html_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    echo "$s"
  }

  if [ ! -s "$file" ]; then
    echo "<p class=\"empty-msg\">$(_html_escape "$empty_msg")</p>"
    return
  fi

  echo "<ul class=\"file-list\">"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # Pour modifies.b3 ("hash  chemin"), on extrait juste le chemin.
    # Pour les .txt, on prend la ligne entière.
    local display
    if [[ "$file" == *.b3 ]]; then
      display=$(echo "$line" | awk '{ $1=""; print substr($0,2) }' | sed 's/^[ ]*//')
    else
      display="$line"
    fi
    echo "  <li>$(_html_escape "$display")</li>"
  done < "$file"
  echo "</ul>"
}

# generate_compare_html
#
# Produit un fichier HTML en injectant les données de comparaison
# dans le fichier template.html.
#
# Usage :
#   generate_compare_html \
#     "$old_b3" "$new_b3" \
#     "$nb_modifies" "$nb_disparus" "$nb_nouveaux" \
#     "$modifies_file" "$disparus_file" "$nouveaux_file" \
#     "$output_html"
generate_compare_html() {
  local old_b3="$1"
  local new_b3="$2"
  local nb_modifies="$3"
  local nb_disparus="$4"
  local nb_nouveaux="$5"
  local modifies_file="$6"
  local disparus_file="$7"
  local nouveaux_file="$8"
  local output_html="$9"

  # Le chemin vers le template est relatif au script principal (integrity.sh)
  local template_path
  template_path="${SCRIPT_DIR}/../reports/template.html"

  if [ ! -f "$template_path" ]; then
    die "Template de rapport introuvable : $template_path"
  fi

  # --- Préparation des données à injecter ---

  local date_rapport
  date_rapport=$(date '+%Y-%m-%d %H:%M:%S')

  local nom_old nom_new
  nom_old=$(basename "$old_b3")
  nom_new=$(basename "$new_b3")

  local title="Rapport de comparaison : ${nom_old} vs ${nom_new}"
  local paths="Base de référence : <code>${nom_old}</code> &nbsp;&middot;&nbsp; Base comparée : <code>${nom_new}</code>"

  # Statut global et couleur associée
  local status_text status_color
  if (( nb_modifies == 0 && nb_disparus == 0 && nb_nouveaux == 0 )); then
    status_text="IDENTIQUES"
    status_color="var(--accent-ok)"
  else
    status_text="DIFFÉRENCES"
    status_color="var(--accent-err)"
  fi

  # Génération des listes HTML de fichiers
  local list_modified list_deleted list_new
  list_modified=$(_render_html_file_list "$modifies_file" "Aucun fichier modifié.")
  list_deleted=$(_render_html_file_list "$disparus_file" "Aucun fichier disparu.")
  list_new=$(_render_html_file_list "$nouveaux_file" "Aucun nouveau fichier.")
  
  # Les métadonnées ne sont pas passées à cette fonction pour le moment.
  # On injecte un placeholder.
  local metadata_rows="<div class=\"info-label\">Métadonnées</div><div class=\"info-value\">Non implémenté</div>"

  # --- Injection des données dans le template via sed ---
  
  # On lit le template et on pipe le contenu dans une série de commandes sed.
  # L'utilisation de `|` comme délimiteur sed permet de gérer les `/` dans les chemins.
  awk -v TITLE="$title" \
      -v PATHS="$paths" \
      -v STATUS_TEXT="$status_text" \
      -v STATUS_COLOR="$status_color" \
      -v DATE="$date_rapport" \
      -v METADATA_ROWS="$metadata_rows" \
      -v LIST_MODIFIED="$list_modified" \
      -v LIST_DELETED="$list_deleted" \
      -v LIST_NEW="$list_new" '
  {
    gsub("{{TITLE}}", TITLE)
    gsub("{{PATHS}}", PATHS)
    gsub("{{STATUS_TEXT}}", STATUS_TEXT)
    gsub("{{STATUS_COLOR}}", STATUS_COLOR)
    gsub("{{DATE}}", DATE)
    gsub("{{METADATA_ROWS}}", METADATA_ROWS)
    gsub("{{LIST_MODIFIED}}", LIST_MODIFIED)
    gsub("{{LIST_DELETED}}", LIST_DELETED)
    gsub("{{LIST_NEW}}", LIST_NEW)
    print
  }
  ' "$template_path" > "$output_html"
}
# --- END OF REFACTORED FILE src/lib/report.sh ---