import sys
from pathlib import Path

# Ajouter la racine du projet (hash_tool/) à sys.path, pas src/
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

import pytest
import tempfile
from pathlib import Path

@pytest.fixture
def temp_dirs():
    """Crée des dossiers source et destination temporaires avec fichiers test."""
    with tempfile.TemporaryDirectory() as tmpdir:
        src = Path(tmpdir) / "source"
        dst = Path(tmpdir) / "destination"
        src.mkdir()
        dst.mkdir()

        # Créer 4 fichiers identiques
        content = [
            "File 1 content\n",
            "File 2 content\n",
            "File 3 content\n",
            "File 4 content\n"
        ]
        for i, text in enumerate(content, 1):
            (src / f"fichier ({i}).txt").write_text(text, encoding="utf-8")
            # Destination copie les fichiers sauf le premier modifié
            text_dst = text if i != 1 else text + "modifié"
            (dst / f"fichier ({i}).txt").write_text(text_dst, encoding="utf-8")

        yield src, dst