import sqlite3
from pathlib import Path
from .compute import compute_file_hash, list_files

def build_database(root_folder, db_path):
    root_folder = Path(root_folder)
    files = list_files(root_folder)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS file_hashes (
            path TEXT PRIMARY KEY,
            hash TEXT NOT NULL
        )
    """)

    for file_path in files:
        rel_path = file_path.relative_to(root_folder).as_posix()
        h = compute_file_hash(file_path)
        if h:
            cur.execute(
                "INSERT OR REPLACE INTO file_hashes (path, hash) VALUES (?, ?)",
                (rel_path, h)
            )

    conn.commit()
    conn.close()

def load_database(db_path):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("SELECT path, hash FROM file_hashes")
    data = dict(cur.fetchall())
    conn.close()
    return data
