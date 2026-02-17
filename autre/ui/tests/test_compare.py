from src.comparison.compare import compare_databases
from src.comparison.report import generate_html_report
from pathlib import Path

def test_compare_databases(temp_dirs):
    src, dst = temp_dirs

    # Construire dict simple (fichier: hash)
    db1 = {f.name: f.name for f in src.iterdir()}
    db2 = {f.name: f.name + ("modifié" if "1" in f.name else "") for f in dst.iterdir()}

    results = compare_databases(db1, db2)
    assert results["identical"] == 3
    assert results["corrupted"] == ["fichier (1).txt"]
    assert results["missing"] == []
    assert results["extra"] == []

def test_generate_html(tmp_path):
    results = {
        "identical": 3,
        "corrupted": ["file1.txt"],
        "missing": [],
        "extra": []
    }
    output = tmp_path / "report.html"
    generate_html_report(results, "db1.db", "db2.db", output, "log text")
    assert output.exists()
    content = output.read_text()
    assert "Fichiers corrompus" in content
    assert "file1.txt" in content