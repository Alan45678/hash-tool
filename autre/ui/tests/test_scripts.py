import subprocess
import sys
from pathlib import Path
from src.hashing.database import load_database

def test_compute_baseline_script(temp_dirs, tmp_path):
    src, _ = temp_dirs
    db_file = tmp_path / "hash.db"
    script = Path("src/compute_baseline.py")
    cmd = [sys.executable, str(script), str(src), str(db_file)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    assert result.returncode == 0
    data = load_database(db_file)
    assert len(data) == 4

def test_compare_hashes_script(temp_dirs, tmp_path):
    src, dst = temp_dirs
    db1 = tmp_path / "db1.db"
    db2 = tmp_path / "db2.db"
    from src.hashing.database import build_database
    build_database(src, db1)
    build_database(dst, db2)

    report = tmp_path / "report.html"
    script = Path("src/compare_hashes.py")
    cmd = [sys.executable, str(script),
           "--base1", str(db1),
           "--base2", str(db2),
           "--output", str(report)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    assert result.returncode == 0
    assert report.exists()
    content = report.read_text()
    assert "Fichiers corrompus" in content