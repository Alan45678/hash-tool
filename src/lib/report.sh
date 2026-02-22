#!/usr/bin/env bash
# lib/report.sh — Génération des rapports de résultats
#
# Sourcé par integrity.sh. Ne pas exécuter directement.
#
# Fonctions exportées :
#   generate_compare_html  <old> <new> <nb_mod> <nb_dis> <nb_nou>
#                          <modifies.b3> <disparus.txt> <nouveaux.txt>
#                          <output.html>

# ── Génération du rapport HTML pour compare ───────────────────────────────────
#
# Produit un fichier HTML autonome (CSS inline, pas de dépendance externe).
# Les listes de fichiers sont injectées depuis les fichiers texte produits
# par run_compare(). Le fichier est lisible hors ligne.
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

  local date_rapport
  date_rapport=$(date '+%Y-%m-%d %H:%M:%S')

  local nom_old nom_new
  nom_old=$(basename "$old_b3")
  nom_new=$(basename "$new_b3")

  # Statut global
  local statut statut_class
  if (( nb_modifies == 0 && nb_disparus == 0 && nb_nouveaux == 0 )); then
    statut="IDENTIQUES"
    statut_class="status-ok"
  else
    statut="DIFFÉRENCES DÉTECTÉES"
    statut_class="status-diff"
  fi

  # Lecture des listes de fichiers → HTML
  _render_file_list() {
    local file="$1"
    local empty_msg="$2"
    if [ ! -s "$file" ]; then
      echo "    <p class=\"empty\">$empty_msg</p>"
      return
    fi
    echo "    <ul>"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      # Pour modifies.b3 : "hash  chemin" → on affiche juste le chemin
      local display
      display=$(echo "$line" | awk '{ if (NF >= 2) { $1=""; print substr($0,2) } else { print $0 } }')
      echo "      <li><code>$(html_escape "$display")</code></li>"
    done < "$file"
    echo "    </ul>"
  }

  html_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    echo "$s"
  }

  local list_modifies list_disparus list_nouveaux
  list_modifies=$(_render_file_list "$modifies_file" "Aucun fichier modifié")
  list_disparus=$(_render_file_list "$disparus_file" "Aucun fichier disparu")
  list_nouveaux=$(_render_file_list "$nouveaux_file" "Aucun nouveau fichier")

  cat > "$output_html" <<HTML
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Rapport — ${nom_old} vs ${nom_new}</title>
  <style>
    /* ── Tokens ──────────────────────────────────────────────────── */
    :root {
      --bg:          #0f1117;
      --bg-card:     #161b27;
      --bg-card-alt: #1c2233;
      --border:      #252d3f;
      --border-glow: #2e3d5a;
      --text:        #c8d4e8;
      --text-dim:    #5a6a85;
      --text-head:   #e8eef8;
      --mono:        'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace;
      --sans:        'DM Sans', 'Outfit', system-ui, sans-serif;
      --accent-ok:   #22c55e;
      --accent-diff: #f59e0b;
      --accent-mod:  #e879f9;
      --accent-dis:  #f87171;
      --accent-nou:  #34d399;
      --radius:      8px;
      --radius-lg:   14px;
    }

    /* ── Reset & base ─────────────────────────────────────────────── */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap');

    body {
      background: var(--bg);
      color: var(--text);
      font-family: var(--sans);
      font-size: 14px;
      line-height: 1.6;
      min-height: 100vh;
      padding: 0 0 64px;
    }

    /* ── Header ───────────────────────────────────────────────────── */
    .header {
      background: var(--bg-card);
      border-bottom: 1px solid var(--border);
      padding: 28px 40px 24px;
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 24px;
    }

    .header-left h1 {
      font-family: var(--mono);
      font-size: 13px;
      font-weight: 500;
      color: var(--text-dim);
      letter-spacing: .08em;
      text-transform: uppercase;
      margin-bottom: 8px;
    }

    .bases-compare {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
    }

    .base-name {
      font-family: var(--mono);
      font-size: 14px;
      font-weight: 500;
      color: var(--text-head);
      background: var(--bg-card-alt);
      border: 1px solid var(--border-glow);
      border-radius: var(--radius);
      padding: 5px 12px;
    }

    .arrow {
      color: var(--text-dim);
      font-size: 16px;
    }

    .meta {
      font-size: 12px;
      color: var(--text-dim);
      margin-top: 10px;
      font-family: var(--mono);
    }

    /* ── Status badge ─────────────────────────────────────────────── */
    .status-badge {
      font-family: var(--mono);
      font-size: 11px;
      font-weight: 500;
      letter-spacing: .1em;
      text-transform: uppercase;
      padding: 6px 14px;
      border-radius: 100px;
      border: 1px solid;
      white-space: nowrap;
      align-self: flex-start;
      margin-top: 4px;
    }

    .status-ok   { color: var(--accent-ok);   border-color: var(--accent-ok);   background: rgba(34,197,94,.08);  }
    .status-diff { color: var(--accent-diff);  border-color: var(--accent-diff); background: rgba(245,158,11,.08); }

    /* ── Stats bar ────────────────────────────────────────────────── */
    .stats-bar {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 1px;
      background: var(--border);
      border-bottom: 1px solid var(--border);
    }

    .stat {
      background: var(--bg-card);
      padding: 20px 32px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .stat-label {
      font-size: 11px;
      letter-spacing: .08em;
      text-transform: uppercase;
      color: var(--text-dim);
    }

    .stat-value {
      font-family: var(--mono);
      font-size: 28px;
      font-weight: 500;
      line-height: 1;
    }

    .stat-modifies .stat-value { color: var(--accent-mod); }
    .stat-disparus .stat-value { color: var(--accent-dis); }
    .stat-nouveaux .stat-value { color: var(--accent-nou); }

    /* ── Sections ─────────────────────────────────────────────────── */
    .main {
      max-width: 1100px;
      margin: 0 auto;
      padding: 36px 40px 0;
      display: grid;
      gap: 20px;
    }

    .section {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      overflow: hidden;
    }

    .section-header {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 14px 20px;
      border-bottom: 1px solid var(--border);
    }

    .section-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    .section-modifies .section-dot { background: var(--accent-mod); }
    .section-disparus .section-dot { background: var(--accent-dis); }
    .section-nouveaux .section-dot { background: var(--accent-nou); }

    .section-title {
      font-size: 12px;
      font-weight: 600;
      letter-spacing: .06em;
      text-transform: uppercase;
      color: var(--text-head);
    }

    .section-count {
      margin-left: auto;
      font-family: var(--mono);
      font-size: 12px;
      color: var(--text-dim);
      background: var(--bg-card-alt);
      border: 1px solid var(--border);
      border-radius: 100px;
      padding: 2px 10px;
    }

    .section-body {
      padding: 16px 20px;
    }

    .section-body ul {
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .section-body li {
      padding: 6px 10px;
      border-radius: var(--radius);
      background: var(--bg-card-alt);
      border: 1px solid transparent;
      transition: border-color .15s;
    }

    .section-body li:hover {
      border-color: var(--border-glow);
    }

    .section-body code {
      font-family: var(--mono);
      font-size: 12px;
      color: var(--text);
      word-break: break-all;
    }

    .empty {
      font-style: italic;
      color: var(--text-dim);
      font-size: 13px;
      padding: 4px 0;
    }

    /* ── Footer ───────────────────────────────────────────────────── */
    .footer {
      text-align: center;
      padding-top: 40px;
      font-size: 11px;
      color: var(--text-dim);
      font-family: var(--mono);
    }

    @media (max-width: 680px) {
      .header        { padding: 20px; flex-direction: column; }
      .stats-bar     { grid-template-columns: 1fr; }
      .main          { padding: 20px; }
    }
  </style>
</head>
<body>

  <!-- ── En-tête ──────────────────────────────────────────────────────── -->
  <header class="header">
    <div class="header-left">
      <h1>Rapport de comparaison — hash_tool</h1>
      <div class="bases-compare">
        <span class="base-name">$(html_escape "$nom_old")</span>
        <span class="arrow">→</span>
        <span class="base-name">$(html_escape "$nom_new")</span>
      </div>
      <div class="meta">Généré le ${date_rapport}</div>
    </div>
    <div class="status-badge ${statut_class}">${statut}</div>
  </header>

  <!-- ── Compteurs ────────────────────────────────────────────────────── -->
  <div class="stats-bar">
    <div class="stat stat-modifies">
      <span class="stat-label">Modifiés</span>
      <span class="stat-value">${nb_modifies}</span>
    </div>
    <div class="stat stat-disparus">
      <span class="stat-label">Disparus</span>
      <span class="stat-value">${nb_disparus}</span>
    </div>
    <div class="stat stat-nouveaux">
      <span class="stat-label">Nouveaux</span>
      <span class="stat-value">${nb_nouveaux}</span>
    </div>
  </div>

  <!-- ── Listes ───────────────────────────────────────────────────────── -->
  <main class="main">

    <div class="section section-modifies">
      <div class="section-header">
        <div class="section-dot"></div>
        <span class="section-title">Fichiers modifiés</span>
        <span class="section-count">${nb_modifies}</span>
      </div>
      <div class="section-body">
${list_modifies}
      </div>
    </div>

    <div class="section section-disparus">
      <div class="section-header">
        <div class="section-dot"></div>
        <span class="section-title">Fichiers disparus</span>
        <span class="section-count">${nb_disparus}</span>
      </div>
      <div class="section-body">
${list_disparus}
      </div>
    </div>

    <div class="section section-nouveaux">
      <div class="section-header">
        <div class="section-dot"></div>
        <span class="section-title">Nouveaux fichiers</span>
        <span class="section-count">${nb_nouveaux}</span>
      </div>
      <div class="section-body">
${list_nouveaux}
      </div>
    </div>

  </main>

  <footer class="footer">
    integrity.sh · BLAKE3 · ${date_rapport}
  </footer>

</body>
</html>
HTML
}