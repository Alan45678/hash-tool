def generate_html_report(results, db1_name, db2_name, output_path, log_text):
    html = f"""
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Rapport de comparaison</title>
<style>
body {{ font-family: Arial, sans-serif; background:#f0f0f0; }}
.section {{ background:white; margin:20px; padding:20px; border-radius:8px; }}
ul {{ font-family: Consolas; }}
</style>
</head>
<body>

<div class="section">
<h1>Rapport de comparaison</h1>
<p><b>Base 1 :</b> {db1_name}</p>
<p><b>Base 2 :</b> {db2_name}</p>
</div>

<div class="section">
<p>Fichiers identiques : {results['identical']}</p>
<p>Fichiers corrompus : {len(results['corrupted'])}</p>
<p>Fichiers manquants : {len(results['missing'])}</p>
<p>Fichiers en trop : {len(results['extra'])}</p>
</div>

<div class="section">
<h2>Fichiers corrompus</h2>
<ul>
{''.join(f"<li>{f}</li>" for f in results['corrupted'])}
</ul>
</div>

<div class="section">
<h2>Journal d'execution</h2>
<pre>{log_text}</pre>
</div>

</body>
</html>
"""
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)
