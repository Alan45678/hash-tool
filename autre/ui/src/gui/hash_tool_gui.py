#!/usr/bin/env python3
"""
Hash Tool GUI - tout en un fichier.
Lancement : python src/hash_tool_gui.py
"""

import sys
import subprocess
import threading
import json
from pathlib import Path

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTabWidget, QLabel, QPushButton, QTextEdit, QProgressBar,
    QMessageBox, QDialog, QListWidget, QListWidgetItem, QLineEdit,
)
from PySide6.QtCore import Qt, Signal, QObject


# =============================================== Explorateur personnalisé ===

class BrowserDialog(QDialog):
    """
    Fenêtre modale avec :
      - une barre d'adresse QLineEdit  (100 % éditable, Entrée pour naviguer)
      - une liste QListWidget          (double-clic pour entrer / sélectionner)
    """
    chosen = Signal(str)   # émis avec le chemin retenu

    def __init__(self, mode="dir", filt="*", start=None, parent=None):
        super().__init__(parent)
        # mode : "dir" | "file"
        # filt : suffixe attendu ex. ".db"  ".html"  ".json"  ou "*"
        self._mode = mode
        self._filt = filt
        self._pick = None                       # Path retenu

        p = Path(start).expanduser().resolve() if start else Path.home()
        self._cwd = p if p.is_dir() else p.parent

        self.setWindowTitle("Choisir un dossier" if mode == "dir" else "Choisir un fichier")
        self.setMinimumSize(800, 560)
        self._ui()
        self._load(self._cwd)

    # == construction UI ======================================================
    def _ui(self):
        v = QVBoxLayout(self)

        # barre d'adresse
        h = QHBoxLayout()
        h.addWidget(QLabel("Adresse :"))
        self._bar = QLineEdit()
        self._bar.returnPressed.connect(self._bar_enter)
        h.addWidget(self._bar)
        up = QPushButton("↑  Parent")
        up.setFixedWidth(90)
        up.clicked.connect(lambda: self._load(self._cwd.parent))
        h.addWidget(up)
        v.addLayout(h)

        # liste
        self._lst = QListWidget()
        self._lst.itemClicked.connect(self._click)
        self._lst.itemDoubleClicked.connect(self._dblclick)
        v.addWidget(self._lst)

        # boutons bas
        h2 = QHBoxLayout()
        h2.addStretch()
        QPushButton("Annuler", clicked=self.reject).setParent(self)  # contournement
        b_cancel = QPushButton("Annuler")
        b_cancel.clicked.connect(self.reject)
        h2.addWidget(b_cancel)
        b_ok = QPushButton("Sélectionner")
        b_ok.setDefault(True)
        b_ok.clicked.connect(self._ok)
        h2.addWidget(b_ok)
        v.addLayout(h2)

    # == chargement d'un dossier ==============================================
    def _load(self, path: Path):
        path = Path(path).resolve()
        if not path.is_dir():
            return
        self._cwd = path
        self._pick = None
        self._bar.setText(str(self._cwd))
        self._lst.clear()

        try:
            items = sorted(path.iterdir(),
                           key=lambda x: (not x.is_dir(), x.name.lower()))
        except PermissionError:
            return

        for p in items:
            if p.name.startswith("."):
                continue
            if p.is_dir():
                label = "📁  " + p.name
            elif self._mode == "file":
                if self._filt != "*" and p.suffix != self._filt:
                    continue
                label = "📄  " + p.name
            else:
                continue
            item = QListWidgetItem(label)
            item.setData(Qt.UserRole, p)
            self._lst.addItem(item)

    # == événements barre d'adresse ===========================================
    def _bar_enter(self):
        """Validation manuelle dans la barre : Entrée."""
        raw = self._bar.text().strip()
        p = Path(raw).expanduser().resolve()
        if p.is_dir():
            self._load(p)
        elif p.is_file() and self._mode == "file":
            if self._filt == "*" or p.suffix == self._filt:
                self._pick = p
                self._load(p.parent)
                self._highlight(p)
            else:
                self._bar.setText(str(self._cwd))
        else:
            self._bar.setText(str(self._cwd))

    # == événements liste =====================================================
    def _click(self, item: QListWidgetItem):
        p: Path = item.data(Qt.UserRole)
        self._bar.setText(str(p))       # mise à jour barre
        if p.is_file():
            self._pick = p

    def _dblclick(self, item: QListWidgetItem):
        p: Path = item.data(Qt.UserRole)
        if p.is_dir():
            self._load(p)
        elif p.is_file() and self._mode == "file":
            self._pick = p
            self.chosen.emit(str(p))
            self.accept()

    # == OK ===================================================================
    def _ok(self):
        if self._mode == "dir":
            self._pick = self._cwd
            self.chosen.emit(str(self._cwd))
            self.accept()
            return
        # mode file : _pick ou barre d'adresse
        if not self._pick:
            raw = self._bar.text().strip()
            p = Path(raw).expanduser().resolve()
            if p.is_file() and (self._filt == "*" or p.suffix == self._filt):
                self._pick = p
        if self._pick:
            self.chosen.emit(str(self._pick))
            self.accept()

    def _highlight(self, target: Path):
        for i in range(self._lst.count()):
            it = self._lst.item(i)
            if it.data(Qt.UserRole) == target:
                self._lst.setCurrentItem(it)
                break

    def result_path(self) -> str:
        return str(self._pick) if self._pick else str(self._cwd)


# =============================================== Widget chemin éditable =====

class PathField(QWidget):
    """QLineEdit + bouton Parcourir → ouvre BrowserDialog."""

    def __init__(self, mode="file", filt="*", parent=None):
        super().__init__(parent)
        self._mode = mode
        self._filt = filt
        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)
        self._edit = QLineEdit()
        self._edit.setPlaceholderText("Chemin… (éditable directement ou via Parcourir)")
        row.addWidget(self._edit)
        btn = QPushButton("Parcourir")
        btn.setFixedWidth(90)
        btn.clicked.connect(self._browse)
        row.addWidget(btn)

    def _browse(self):
        dlg = BrowserDialog(self._mode, self._filt,
                            self._edit.text() or str(Path.home()), self)
        dlg.chosen.connect(self._edit.setText)
        dlg.exec()

    def text(self):   return self._edit.text()
    def setText(self, v): self._edit.setText(v)
    def clear(self):  self._edit.clear()


# =============================================== Worker subprocess ===========

class _Sig(QObject):
    out  = Signal(str)
    done = Signal(int)

class Worker:
    def __init__(self, cmd):
        self.cmd = cmd
        self.sig = _Sig()
    def run(self):
        p = subprocess.Popen(self.cmd, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True)
        for line in p.stdout:
            self.sig.out.emit(line.rstrip())
        p.wait()
        self.sig.done.emit(p.returncode)


# =============================================== Fenêtre principale ==========

class HashToolGUI(QMainWindow):

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Hash Tool")
        self.setMinimumSize(940, 680)
        # src/gui/hash_tool_gui.py  →  scripts dans src/
        self._src = Path(__file__).resolve().parent

        c = QWidget()
        self.setCentralWidget(c)
        v = QVBoxLayout(c)
        tabs = QTabWidget()
        v.addWidget(tabs)
        tabs.addTab(self._tab_compute(),  "① Calcul hash")
        tabs.addTab(self._tab_compare(),  "② Comparaison")
        self._st = QLabel("Prêt")
        v.addWidget(self._st)

    # == onglet calcul ========================================================
    def _tab_compute(self):
        w, lay = QWidget(), QVBoxLayout()
        w.setLayout(lay)

        lay.addWidget(QLabel("<b>Dossier à analyser :</b>"))
        self._f_folder = PathField("dir")
        lay.addWidget(self._f_folder)

        lay.addWidget(QLabel("<b>Base de hash de sortie (.db) :</b>"))
        self._f_dbout = PathField("file", ".db")
        lay.addWidget(self._f_dbout)

        lay.addLayout(self._json_btns(self._imp_c, self._exp_c))

        self._btn_c = QPushButton("▶  Lancer le calcul")
        self._btn_c.clicked.connect(self._run_compute)
        lay.addWidget(self._btn_c)

        self._prg_c = QProgressBar(); self._prg_c.setVisible(False)
        lay.addWidget(self._prg_c)
        lay.addWidget(QLabel("Journal :"))
        self._log_c = self._console()
        lay.addWidget(self._log_c)
        return w

    # == onglet comparaison ===================================================
    def _tab_compare(self):
        w, lay = QWidget(), QVBoxLayout()
        w.setLayout(lay)

        lay.addWidget(QLabel("<b>Base de référence #1 (.db) :</b>"))
        self._f_b1 = PathField("file", ".db")
        lay.addWidget(self._f_b1)

        lay.addWidget(QLabel("<b>Base à comparer #2 (.db) :</b>"))
        self._f_b2 = PathField("file", ".db")
        lay.addWidget(self._f_b2)

        lay.addWidget(QLabel("<b>Rapport de sortie (.html) :</b>"))
        self._f_rp = PathField("file", ".html")
        lay.addWidget(self._f_rp)

        lay.addLayout(self._json_btns(self._imp_k, self._exp_k))

        self._btn_k = QPushButton("▶  Lancer la comparaison")
        self._btn_k.clicked.connect(self._run_compare)
        lay.addWidget(self._btn_k)

        self._prg_k = QProgressBar(); self._prg_k.setVisible(False)
        lay.addWidget(self._prg_k)
        lay.addWidget(QLabel("Journal :"))
        self._log_k = self._console()
        lay.addWidget(self._log_k)
        return w

    # == helpers UI ===========================================================
    def _console(self):
        t = QTextEdit(); t.setReadOnly(True)
        t.setStyleSheet("background:#1e1e1e;color:#d4d4d4;"
                        "font-family:monospace;font-size:12px;")
        return t

    def _json_btns(self, imp, exp):
        row = QHBoxLayout()
        bi = QPushButton("Importer JSON"); bi.clicked.connect(imp); row.addWidget(bi)
        be = QPushButton("Exporter JSON"); be.clicked.connect(exp); row.addWidget(be)
        row.addStretch()
        return row

    def _browser(self, filt=".json"):
        dlg = BrowserDialog("file", filt, str(Path.home()), self)
        return dlg if dlg.exec() else None

    # == import / export JSON =================================================
    def _imp_c(self):
        dlg = BrowserDialog("file", ".json", str(Path.home()), self)
        if dlg.exec():
            try:
                cfg = json.loads(Path(dlg.result_path()).read_text("utf-8"))
                self._f_folder.setText(cfg.get("folder",""))
                self._f_dbout.setText(cfg.get("output",""))
            except Exception as e: QMessageBox.critical(self,"Erreur",str(e))

    def _exp_c(self):
        dlg = BrowserDialog("file", ".json", str(Path.home()), self)
        if dlg.exec():
            try:
                Path(dlg.result_path()).write_text(
                    json.dumps({"folder":self._f_folder.text(),
                                "output":self._f_dbout.text()},
                               indent=4, ensure_ascii=False), "utf-8")
            except Exception as e: QMessageBox.critical(self,"Erreur",str(e))

    def _imp_k(self):
        dlg = BrowserDialog("file", ".json", str(Path.home()), self)
        if dlg.exec():
            try:
                cfg = json.loads(Path(dlg.result_path()).read_text("utf-8"))
                self._f_b1.setText(cfg.get("base1",""))
                self._f_b2.setText(cfg.get("base2",""))
                self._f_rp.setText(cfg.get("report",""))
            except Exception as e: QMessageBox.critical(self,"Erreur",str(e))

    def _exp_k(self):
        dlg = BrowserDialog("file", ".json", str(Path.home()), self)
        if dlg.exec():
            try:
                Path(dlg.result_path()).write_text(
                    json.dumps({"base1":self._f_b1.text(),
                                "base2":self._f_b2.text(),
                                "report":self._f_rp.text()},
                               indent=4, ensure_ascii=False), "utf-8")
            except Exception as e: QMessageBox.critical(self,"Erreur",str(e))

    # == lancement scripts ====================================================
    def _run_compute(self):
        folder = self._f_folder.text().strip()
        out    = self._f_dbout.text().strip()
        if not folder or not out:
            return QMessageBox.warning(self,"","Remplir tous les champs.")
        if not Path(folder).is_dir():
            return QMessageBox.critical(self,"Erreur",f"Dossier introuvable :\n{folder}")
        self._exec([sys.executable, str(self._src/"compute_baseline.py"), folder, out],
                   self._log_c, self._prg_c, self._btn_c)

    def _run_compare(self):
        b1 = self._f_b1.text().strip()
        b2 = self._f_b2.text().strip()
        rp = self._f_rp.text().strip()
        if not b1 or not b2 or not rp:
            return QMessageBox.warning(self,"","Remplir tous les champs.")
        for p,l in [(b1,"Base #1"),(b2,"Base #2")]:
            if not Path(p).is_file():
                return QMessageBox.critical(self,"Erreur",f"{l} introuvable :\n{p}")
        self._exec([sys.executable, str(self._src/"compare_hashes.py"),
                    "--base1",b1,"--base2",b2,"--output",rp],
                   self._log_k, self._prg_k, self._btn_k)

    def _exec(self, cmd, log, prg, btn):
        log.clear(); prg.setVisible(True); prg.setRange(0,0)
        btn.setEnabled(False); self._st.setText("Exécution…")
        w = Worker(cmd)
        w.sig.out.connect(log.append)
        w.sig.done.connect(lambda c: self._fin(c, prg, btn))
        threading.Thread(target=w.run, daemon=True).start()

    def _fin(self, code, prg, btn):
        prg.setVisible(False); btn.setEnabled(True)
        if code == 0:
            self._st.setText("✓ Terminé")
        else:
            self._st.setText(f"✗ Erreur (code {code})")
            QMessageBox.critical(self,"Erreur",f"Code retour : {code}")


# ======================================================================= main

def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    w = HashToolGUI()
    w.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()