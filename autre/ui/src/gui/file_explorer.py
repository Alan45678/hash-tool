#!/usr/bin/env python3
"""
Explorateur de fichiers personnalisé - PySide6
Barre d'adresse éditable + liste de navigation (QListWidget).
Synchronisation bidirectionnelle : saisie manuelle <-> clic visuel.
"""

from pathlib import Path

from PySide6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout,
    QLineEdit, QListWidget, QListWidgetItem,
    QPushButton, QLabel, QWidget,
)
from PySide6.QtCore import Qt, Signal


# ============================================================ Explorateur ===

class FileExplorerDialog(QDialog):
    """
    Fenêtre modale d'exploration du système de fichiers.

    Deux modes d'interaction :
      - Saisie directe dans la barre d'adresse  → Entrée pour valider
      - Navigation visuelle dans QListWidget     → double-clic pour entrer/sélectionner

    Les deux modes sont synchronisés en permanence.
    """

    path_selected = Signal(str)

    def __init__(self, mode="directory", file_filter="*",
                 initial_path=None, parent=None):
        """
        Parameters
        ----------
        mode        : "directory" | "file"
        file_filter : suffixe attendu, ex. ".db" ".html" ".json", ou "*" pour tout
        initial_path: chemin de départ (str | Path | None)
        """
        super().__init__(parent)
        self.mode = mode
        self.file_filter = file_filter
        self._selected_path: Path | None = None

        # Déterminer le dossier de départ
        start = Path(initial_path).expanduser().resolve() if initial_path else Path.home()
        self._current = start if start.is_dir() else start.parent

        self.setWindowTitle(
            "Sélectionner un fichier" if mode == "file" else "Sélectionner un dossier"
        )
        self.setMinimumSize(780, 540)
        self._build_ui()
        self._refresh()

    # ----------------------------------------------------------------- UI ---

    def _build_ui(self):
        root = QVBoxLayout(self)

        # == Barre d'adresse ==================================================
        bar = QHBoxLayout()
        bar.addWidget(QLabel("Adresse :"))

        self._addr = QLineEdit()
        # La barre d'adresse est un QLineEdit standard : entièrement éditable.
        # La validation se déclenche sur Entrée uniquement - pas à chaque frappe.
        self._addr.returnPressed.connect(self._on_addr_enter)
        bar.addWidget(self._addr)

        btn_up = QPushButton("↑")
        btn_up.setFixedWidth(32)
        btn_up.setToolTip("Dossier parent")
        btn_up.clicked.connect(self._go_up)
        bar.addWidget(btn_up)

        root.addLayout(bar)

        # == Liste =============================================================
        self._list = QListWidget()
        self._list.itemClicked.connect(self._on_click)
        self._list.itemDoubleClicked.connect(self._on_dblclick)
        root.addWidget(self._list)

        # == Boutons bas =======================================================
        btns = QHBoxLayout()
        btns.addStretch()

        btn_cancel = QPushButton("Annuler")
        btn_cancel.clicked.connect(self.reject)
        btns.addWidget(btn_cancel)

        self._btn_ok = QPushButton("Sélectionner")
        self._btn_ok.setDefault(True)
        self._btn_ok.clicked.connect(self._on_ok)
        btns.addWidget(self._btn_ok)

        root.addLayout(btns)

    # ---------------------------------------------------------- Navigation ---

    def _refresh(self):
        """Recharge la liste depuis self._current et met à jour la barre."""
        self._addr.setText(str(self._current))
        self._selected_path = None
        self._list.clear()

        entries = []
        try:
            for p in sorted(
                self._current.iterdir(),
                key=lambda x: (not x.is_dir(), x.name.lower()),
            ):
                if p.name.startswith("."):
                    continue
                if p.is_dir():
                    entries.append((f"📁  {p.name}", p))
                elif self.mode == "file":
                    if self.file_filter == "*" or p.suffix == self.file_filter:
                        entries.append((f"📄  {p.name}", p))
        except PermissionError:
            pass

        for label, path in entries:
            item = QListWidgetItem(label)
            item.setData(Qt.UserRole, path)
            self._list.addItem(item)

    def _navigate(self, path: Path):
        """Entre dans un dossier."""
        if path.is_dir():
            self._current = path
            self._refresh()

    def _go_up(self):
        parent = self._current.parent
        if parent != self._current:
            self._navigate(parent)

    # ---------------------------------- Gestion barre d'adresse (saisie) ----

    def _on_addr_enter(self):
        """
        Appelé uniquement quand l'utilisateur appuie sur Entrée dans la barre.
        Interprète le texte saisi :
          - dossier existant  → navigation
          - fichier existant  → sélection directe (mode file uniquement)
          - chemin invalide   → restauration de l'adresse courante
        """
        raw = self._addr.text().strip()
        path = Path(raw).expanduser().resolve()

        if path.is_dir():
            self._navigate(path)

        elif path.is_file() and self.mode == "file":
            ok = self.file_filter == "*" or path.suffix == self.file_filter
            if ok:
                self._selected_path = path
                # Naviguer dans le dossier parent et surligner le fichier
                self._current = path.parent
                self._refresh()
                self._highlight(path)
            else:
                self._addr.setText(str(self._current))

        else:
            # Chemin invalide : on remet le chemin courant
            self._addr.setText(str(self._current))

    # --------------------------------------- Gestion clics dans la liste ----

    def _on_click(self, item: QListWidgetItem):
        """Clic simple : met à jour la barre d'adresse sans naviguer."""
        path: Path = item.data(Qt.UserRole)
        self._addr.setText(str(path))
        if path.is_file():
            self._selected_path = path

    def _on_dblclick(self, item: QListWidgetItem):
        """Double-clic : entre dans un dossier ou sélectionne un fichier."""
        path: Path = item.data(Qt.UserRole)
        if path.is_dir():
            self._navigate(path)
        elif path.is_file() and self.mode == "file":
            self._selected_path = path
            self.path_selected.emit(str(path))
            self.accept()

    # ---------------------------------------------------- Bouton OK --------

    def _on_ok(self):
        if self.mode == "directory":
            self._selected_path = self._current
            self.path_selected.emit(str(self._current))
            self.accept()
            return

        # Mode file : priorité à _selected_path, sinon lire la barre
        candidate = self._selected_path
        if candidate is None:
            raw = self._addr.text().strip()
            p = Path(raw).expanduser().resolve()
            if p.is_file():
                candidate = p

        if candidate and candidate.is_file():
            ok = self.file_filter == "*" or candidate.suffix == self.file_filter
            if ok:
                self._selected_path = candidate
                self.path_selected.emit(str(candidate))
                self.accept()

    # ----------------------------------------------------------- Helpers ----

    def _highlight(self, target: Path):
        """Surligne l'item correspondant à target dans la liste."""
        for i in range(self._list.count()):
            item = self._list.item(i)
            if item.data(Qt.UserRole) == target:
                self._list.setCurrentItem(item)
                break

    def get_selected_path(self) -> str:
        """Retourne le chemin sélectionné sous forme de chaîne."""
        return str(self._selected_path) if self._selected_path else str(self._current)


# ============================================================= PathLineEdit ==

class PathLineEdit(QWidget):
    """
    Widget composite intégrable dans un layout :
      QLineEdit éditable  +  bouton « Parcourir » ouvrant FileExplorerDialog.
    """

    def __init__(self, mode="file", file_filter="*", parent=None):
        super().__init__(parent)
        self.mode = mode
        self.file_filter = file_filter

        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)

        self._edit = QLineEdit()
        self._edit.setPlaceholderText("Saisir le chemin ou cliquer sur Parcourir…")
        row.addWidget(self._edit)

        btn = QPushButton("Parcourir")
        btn.setFixedWidth(90)
        btn.clicked.connect(self._browse)
        row.addWidget(btn)

    def _browse(self):
        initial = self._edit.text().strip() or str(Path.home())
        dlg = FileExplorerDialog(
            mode=self.mode,
            file_filter=self.file_filter,
            initial_path=initial,
            parent=self,
        )
        # Connexion signal : met à jour le QLineEdit dès la sélection
        dlg.path_selected.connect(self._edit.setText)
        dlg.exec()

    # API publique
    def text(self) -> str:
        return self._edit.text()

    def setText(self, v: str):
        self._edit.setText(v)

    def clear(self):
        self._edit.clear()