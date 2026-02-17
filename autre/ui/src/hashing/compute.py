import blake3
from pathlib import Path

def compute_file_hash(file_path, chunk_size=1024*1024):
    """Calcule le hash BLAKE3 d'un fichier."""
    hasher = blake3.blake3()
    try:
        with open(file_path, "rb") as f:
            while chunk := f.read(chunk_size):
                hasher.update(chunk)
        return hasher.hexdigest()
    except Exception as e:
        print(f"Erreur lecture fichier : {file_path} -> {e}")
        return None

def list_files(folder):
    folder = Path(folder)
    return [p for p in folder.rglob("*") if p.is_file()]
