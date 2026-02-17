from src.hashing.compute import compute_file_hash, list_files
from src.hashing.database import build_database, load_database
from pathlib import Path

def test_list_files(temp_dirs):
    src, _ = temp_dirs
    files = list_files(src)
    assert len(files) == 4
    assert all(f.is_file() for f in files)

def test_compute_file_hash(temp_dirs):
    src, _ = temp_dirs
    f = src / "fichier (2).txt"
    h = compute_file_hash(f)
    assert isinstance(h, str)
    assert len(h) == 64  # BLAKE3 hex hash

def test_build_and_load_database(temp_dirs, tmp_path):
    src, _ = temp_dirs
    db_path = tmp_path / "test.db"
    build_database(src, db_path)
    data = load_database(db_path)
    assert len(data) == 4
    for f in src.iterdir():
        rel = f.relative_to(src).as_posix()
        assert rel in data