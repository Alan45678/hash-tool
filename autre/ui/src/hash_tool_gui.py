#!/usr/bin/env python3

import sys
import subprocess
import threading
import json
from pathlib import Path
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTabWidget, QLabel, QPushButton, QLineEdit, QTextEdit,
    QProgressBar, QFileDialog, QMessageBox, QStatusBar
)
from PySide6.QtCore import Qt, Signal, QObject
from PySide6.QtGui import QIcon


class WorkerSignals(QObject):
    """Signaux pour la communication thread -> GUI"""
    output = Signal(str)
    finished = Signal(int)
    progress_start = Signal()
    progress_stop = Signal()


class CommandWorker:
    """Worker pour exécuter des commandes en arrière-plan"""
    def __init__(self, cmd):
        self.cmd = cmd
        self.signals = WorkerSignals()

    def run(self):
        self.signals.progress_start.emit()
        process = subprocess.Popen(
            self.cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )

        for line in process.stdout:
            self.signals.output.emit(line)

        process.wait()
        self.signals.progress_stop.emit()
        self.signals.finished.emit(process.returncode)


class PathLineEdit(QWidget):
    """Widget combinant QLineEdit éditable + bouton parcourir"""
    def __init__(self, mode="file", file_filter="All Files (*)", parent=None):
        super().__init__(parent)
        self.mode = mode  # "file", "save", "directory"
        self.file_filter = file_filter

        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.line_edit = QLineEdit()
        self.line_edit.setPlaceholderText("Chemin du fichier/dossier...")
        
        self.browse_btn = QPushButton("📁")
        self.browse_btn.setFixedWidth(40)
        self.browse_btn.setToolTip("Parcourir")
        self.browse_btn.clicked.connect(self.browse)

        layout.addWidget(self.line_edit)
        layout.addWidget(self.browse_btn)

    def browse(self):
        """Ouvre le dialogue de sélection approprié"""
        if self.mode == "directory":
            path = QFileDialog.getExistingDirectory(
                self,
                "Sélectionner un dossier",
                self.line_edit.text() or str(Path.home())
            )
        elif self.mode == "save":
            path, _ = QFileDialog.getSaveFileName(
                self,
                "Enregistrer sous",
                self.line_edit.text() or str(Path.home()),
                self.file_filter
            )
        else:  # file
            path, _ = QFileDialog.getOpenFileName(
                self,
                "Ouvrir un fichier",
                self.line_edit.text() or str(Path.home()),
                self.file_filter
            )

        if path:
            self.line_edit.setText(path)

    def text(self):
        return self.line_edit.text()

    def setText(self, text):
        self.line_edit.setText(text)

    def clear(self):
        self.line_edit.clear()


class HashToolGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Hash Tool GUI - PySide6")
        self.setMinimumSize(1000, 700)

        # Déterminer le chemin des scripts
        self.script_dir = Path(__file__).resolve().parent / "src"

        # Widget central
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # Onglets
        self.tabs = QTabWidget()
        main_layout.addWidget(self.tabs)

        # Créer les onglets
        self.create_compute_tab()
        self.create_compare_tab()

        # Barre de statut
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Prêt")

    def create_compute_tab(self):
        """Onglet 1 : Calcul des hash"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setSpacing(10)

        # Titre
        title = QLabel("<h2>Calcul de la base de hash (BLAKE3)</h2>")
        layout.addWidget(title)

        # Dossier à analyser
        layout.addWidget(QLabel("Dossier à analyser :"))
        self.compute_folder = PathLineEdit(mode="directory")
        layout.addWidget(self.compute_folder)

        # Fichier de sortie
        layout.addWidget(QLabel("Fichier base de hash (.db) :"))
        self.compute_output = PathLineEdit(
            mode="save",
            file_filter="SQLite Database (*.db)"
        )
        layout.addWidget(self.compute_output)

        # Boutons d'action
        btn_layout = QHBoxLayout()
        
        import_btn = QPushButton("📥 Importer setup JSON")
        import_btn.clicked.connect(self.import_compute_setup)
        btn_layout.addWidget(import_btn)

        export_btn = QPushButton("💾 Exporter setup JSON")
        export_btn.clicked.connect(self.export_compute_setup)
        btn_layout.addWidget(export_btn)

        btn_layout.addStretch()

        self.compute_btn = QPushButton("▶ Lancer le calcul")
        self.compute_btn.setStyleSheet("""
            QPushButton {
                background-color: #4CAF50;
                color: white;
                font-weight: bold;
                padding: 10px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #45a049;
            }
            QPushButton:disabled {
                background-color: #cccccc;
            }
        """)
        self.compute_btn.clicked.connect(self.launch_compute)
        btn_layout.addWidget(self.compute_btn)

        layout.addLayout(btn_layout)

        # Barre de progression
        self.compute_progress = QProgressBar()
        self.compute_progress.setVisible(False)
        layout.addWidget(self.compute_progress)

        # Console
        layout.addWidget(QLabel("Journal d'exécution :"))
        self.compute_console = QTextEdit()
        self.compute_console.setReadOnly(True)
        self.compute_console.setStyleSheet("""
            QTextEdit {
                font-family: 'Courier New', monospace;
                background-color: #1e1e1e;
                color: #d4d4d4;
                border: 1px solid #555;
            }
        """)
        layout.addWidget(self.compute_console)

        self.tabs.addTab(tab, "1️⃣ Calcul des hash")

    def create_compare_tab(self):
        """Onglet 2 : Comparaison"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setSpacing(10)

        # Titre
        title = QLabel("<h2>Comparaison de deux bases de hash</h2>")
        layout.addWidget(title)

        # Base #1
        layout.addWidget(QLabel("Base de référence (#1) :"))
        self.base1_path = PathLineEdit(
            mode="file",
            file_filter="SQLite Database (*.db)"
        )
        layout.addWidget(self.base1_path)

        # Base #2
        layout.addWidget(QLabel("Base à comparer (#2) :"))
        self.base2_path = PathLineEdit(
            mode="file",
            file_filter="SQLite Database (*.db)"
        )
        layout.addWidget(self.base2_path)

        # Rapport HTML
        layout.addWidget(QLabel("Rapport de sortie (HTML) :"))
        self.report_path = PathLineEdit(
            mode="save",
            file_filter="HTML Files (*.html)"
        )
        layout.addWidget(self.report_path)

        # Boutons d'action
        btn_layout = QHBoxLayout()

        import_btn = QPushButton("📥 Importer setup JSON")
        import_btn.clicked.connect(self.import_compare_setup)
        btn_layout.addWidget(import_btn)

        export_btn = QPushButton("💾 Exporter setup JSON")
        export_btn.clicked.connect(self.export_compare_setup)
        btn_layout.addWidget(export_btn)

        btn_layout.addStretch()

        self.compare_btn = QPushButton("▶ Lancer la comparaison")
        self.compare_btn.setStyleSheet("""
            QPushButton {
                background-color: #2196F3;
                color: white;
                font-weight: bold;
                padding: 10px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #0b7dda;
            }
            QPushButton:disabled {
                background-color: #cccccc;
            }
        """)
        self.compare_btn.clicked.connect(self.launch_compare)
        btn_layout.addWidget(self.compare_btn)

        layout.addLayout(btn_layout)

        # Barre de progression
        self.compare_progress = QProgressBar()
        self.compare_progress.setVisible(False)
        layout.addWidget(self.compare_progress)

        # Console
        layout.addWidget(QLabel("Journal d'exécution :"))
        self.compare_console = QTextEdit()
        self.compare_console.setReadOnly(True)
        self.compare_console.setStyleSheet("""
            QTextEdit {
                font-family: 'Courier New', monospace;
                background-color: #1e1e1e;
                color: #d4d4d4;
                border: 1px solid #555;
            }
        """)
        layout.addWidget(self.compare_console)

        self.tabs.addTab(tab, "2️⃣ Comparaison")

    # ==================== IMPORT/EXPORT SETUP ====================

    def import_compute_setup(self):
        """Importer configuration onglet calcul"""
        path, _ = QFileDialog.getOpenFileName(
            self,
            "Importer setup",
            str(Path.home()),
            "JSON Files (*.json)"
        )
        if not path:
            return

        try:
            with open(path, "r", encoding="utf-8") as f:
                config = json.load(f)

            if "folder" in config:
                self.compute_folder.setText(config["folder"])
            if "output" in config:
                self.compute_output.setText(config["output"])

            QMessageBox.information(
                self,
                "Setup importé",
                "Configuration chargée avec succès"
            )
        except Exception as e:
            QMessageBox.critical(
                self,
                "Erreur",
                f"Impossible de charger le fichier JSON :\n{e}"
            )

    def export_compute_setup(self):
        """Exporter configuration onglet calcul"""
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Exporter setup",
            str(Path.home() / "setup_compute.json"),
            "JSON Files (*.json)"
        )
        if not path:
            return

        try:
            config = {
                "folder": self.compute_folder.text(),
                "output": self.compute_output.text()
            }
            with open(path, "w", encoding="utf-8") as f:
                json.dump(config, f, indent=4, ensure_ascii=False)

            QMessageBox.information(
                self,
                "Setup exporté",
                f"Configuration sauvegardée dans :\n{path}"
            )
        except Exception as e:
            QMessageBox.critical(
                self,
                "Erreur",
                f"Impossible de sauvegarder le fichier JSON :\n{e}"
            )

    def import_compare_setup(self):
        """Importer configuration onglet comparaison"""
        path, _ = QFileDialog.getOpenFileName(
            self,
            "Importer setup",
            str(Path.home()),
            "JSON Files (*.json)"
        )
        if not path:
            return

        try:
            with open(path, "r", encoding="utf-8") as f:
                config = json.load(f)

            if "base1" in config:
                self.base1_path.setText(config["base1"])
            if "base2" in config:
                self.base2_path.setText(config["base2"])
            if "report" in config:
                self.report_path.setText(config["report"])

            QMessageBox.information(
                self,
                "Setup importé",
                "Configuration chargée avec succès"
            )
        except Exception as e:
            QMessageBox.critical(
                self,
                "Erreur",
                f"Impossible de charger le fichier JSON :\n{e}"
            )

    def export_compare_setup(self):
        """Exporter configuration onglet comparaison"""
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Exporter setup",
            str(Path.home() / "setup_compare.json"),
            "JSON Files (*.json)"
        )
        if not path:
            return

        try:
            config = {
                "base1": self.base1_path.text(),
                "base2": self.base2_path.text(),
                "report": self.report_path.text()
            }
            with open(path, "w", encoding="utf-8") as f:
                json.dump(config, f, indent=4, ensure_ascii=False)

            QMessageBox.information(
                self,
                "Setup exporté",
                f"Configuration sauvegardée dans :\n{path}"
            )
        except Exception as e:
            QMessageBox.critical(
                self,
                "Erreur",
                f"Impossible de sauvegarder le fichier JSON :\n{e}"
            )

    # ==================== LANCEMENT DES SCRIPTS ====================

    def launch_compute(self):
        """Lancer le calcul de hash"""
        folder = self.compute_folder.text().strip()
        output = self.compute_output.text().strip()

        if not folder or not output:
            QMessageBox.warning(
                self,
                "Champs manquants",
                "Veuillez renseigner tous les champs"
            )
            return

        if not Path(folder).exists():
            QMessageBox.critical(
                self,
                "Erreur",
                f"Le dossier n'existe pas :\n{folder}"
            )
            return

        script = self.script_dir / "compute_baseline.py"
        cmd = [sys.executable, str(script), folder, output]

        self.run_command(
            cmd,
            self.compute_console,
            self.compute_progress,
            self.compute_btn
        )

    def launch_compare(self):
        """Lancer la comparaison"""
        base1 = self.base1_path.text().strip()
        base2 = self.base2_path.text().strip()
        report = self.report_path.text().strip()

        if not base1 or not base2 or not report:
            QMessageBox.warning(
                self,
                "Champs manquants",
                "Veuillez renseigner tous les champs"
            )
            return

        if not Path(base1).exists():
            QMessageBox.critical(
                self,
                "Erreur",
                f"La base #1 n'existe pas :\n{base1}"
            )
            return

        if not Path(base2).exists():
            QMessageBox.critical(
                self,
                "Erreur",
                f"La base #2 n'existe pas :\n{base2}"
            )
            return

        script = self.script_dir / "compare_hashes.py"
        cmd = [
            sys.executable, str(script),
            "--base1", base1,
            "--base2", base2,
            "--output", report
        ]

        self.run_command(
            cmd,
            self.compare_console,
            self.compare_progress,
            self.compare_btn
        )

    def run_command(self, cmd, console, progress_bar, button):
        """Exécute une commande en arrière-plan"""
        console.clear()
        progress_bar.setVisible(True)
        progress_bar.setRange(0, 0)  # Mode indéterminé
        button.setEnabled(False)
        self.status_bar.showMessage("Exécution en cours...")

        worker = CommandWorker(cmd)

        # Connexion des signaux
        worker.signals.output.connect(console.append)
        worker.signals.progress_start.connect(lambda: progress_bar.setVisible(True))
        worker.signals.progress_stop.connect(lambda: progress_bar.setVisible(False))
        worker.signals.finished.connect(
            lambda code: self.on_command_finished(code, button)
        )

        # Lancer dans un thread
        thread = threading.Thread(target=worker.run, daemon=True)
        thread.start()

    def on_command_finished(self, return_code, button):
        """Callback à la fin de l'exécution"""
        button.setEnabled(True)

        if return_code == 0:
            self.status_bar.showMessage("✓ Terminé avec succès", 5000)
            QMessageBox.information(
                self,
                "Succès",
                "Opération terminée avec succès"
            )
        else:
            self.status_bar.showMessage(f"✗ Erreur (code {return_code})", 5000)
            QMessageBox.critical(
                self,
                "Erreur",
                f"L'opération a échoué (code retour : {return_code})"
            )


def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")  # Style moderne
    
    window = HashToolGUI()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()