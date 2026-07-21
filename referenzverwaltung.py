"""Python port of Referenzverwaltung.m - manage reference measurement sets.

Ported with tkinter. One thing simplifies a lot compared to the original:
the MATLAB version parsed uploaded csv/txt files into a numeric array and
saved that as a .mat file, because the analysis windows then loaded it back
with `load(...)`. The Python analysis windows (dcr.py, cv_ecsa.py, ...)
instead read reference data straight from raw .txt/.csv files in the
method folder via `_reference_files()` / read_all. So here, adding a
reference file is just a file copy (renamed to fit the existing
"Referenz#<n>_<name>.<ext>" scheme) - no .mat conversion involved.

The per-field "Allgemeine Config" / per-method config editors from the
MATLAB tool (editConfig, editAllConfig.m) are not reproduced field-by-field;
instead config.json (and the Standardconfig templates) are edited as raw
JSON text, consistent with method_base.MethodWindowBase.edit_config's
existing "edit config.json directly" placeholder.
"""

import glob
import json
import os
import shutil
import zipfile
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog

import paths
from auswahl import METHODS, method_label_text

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REFERENZEN_DIR = os.path.join(SCRIPT_DIR, "Referenzen")
STANDARDCONFIG_DIR = os.path.join(REFERENZEN_DIR, "Standardconfig")

# Original MATLAB default export/import location; used when it exists,
# otherwise dialogs just fall back to the Referenzen folder.
EXPORT_DIR_FALLBACK = r"P:\50_ARBEITSGRUPPEN\Analytik_FC\02_Fachbereichssoftware_KlaSu_3.2\15_FC-OPAT\Referenzexport"

BENCH_OPTIONS = ["G-60", "G-100", "G-400"]
CV_ECSA_SCANS = ["schneller_Scan", "langsamer_Scan"]
PK_PICK_OPTIONS = ["Excel für Export", "PK1", "PK2", "PK3"]
PK_SUBDIRS = ["", "PK1", "PK2", "PK3"]


# -- folder / file helpers ---------------------------------------------------

def load_reference_list():
    if not os.path.isdir(REFERENZEN_DIR):
        os.makedirs(REFERENZEN_DIR, exist_ok=True)
    names = [
        name for name in os.listdir(REFERENZEN_DIR)
        if name != "Standardconfig" and os.path.isdir(os.path.join(REFERENZEN_DIR, name))
    ]
    return sorted(names)


def create_method_dirs(ref_dir):
    for method in METHODS:
        method_dir = os.path.join(ref_dir, method)
        if method == "CV_ECSA":
            for sub in CV_ECSA_SCANS:
                os.makedirs(os.path.join(method_dir, sub), exist_ok=True)
        elif method == "PK":
            for sub in ("PK1", "PK2", "PK3"):
                os.makedirs(os.path.join(method_dir, sub), exist_ok=True)
        else:
            os.makedirs(method_dir, exist_ok=True)


def _load_config(ref_dir):
    try:
        with open(os.path.join(ref_dir, "config.json"), "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}


def standard_path_for(ref_dir):
    raw = _load_config(ref_dir).get("Auswahl", {}).get("StandardPfad", "")
    resolved = paths.resolve(raw)
    return resolved if resolved and os.path.isdir(resolved) else None


def copy_reference_file(src_path, method_dir):
    """Copy an uploaded file into a method's reference folder.

    csv/txt files are renamed into the existing 'Referenz#<n>_<name>.<ext>'
    scheme so _reference_files()'s 'Referenz#*' glob picks them up. xlsx/xlsm
    export templates replace any existing template, same as the original.
    """
    os.makedirs(method_dir, exist_ok=True)
    ext = os.path.splitext(src_path)[1].lower()
    if ext in (".xlsx", ".xlsm"):
        for existing in glob.glob(os.path.join(method_dir, "*.xlsx")) + glob.glob(os.path.join(method_dir, "*.xlsm")):
            os.remove(existing)
        shutil.copy(src_path, method_dir)
    else:
        existing = glob.glob(os.path.join(method_dir, "Referenz#*"))
        base_name = os.path.splitext(os.path.basename(src_path))[0]
        dest_name = f"Referenz#{len(existing) + 1}_{base_name}{ext}"
        shutil.copy(src_path, os.path.join(method_dir, dest_name))


def edit_json_file(parent, title, path):
    """Raw-JSON editor Toplevel: load, let the user edit, validate on save."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        text = json.dumps(data, indent=2, ensure_ascii=False)
    except (OSError, json.JSONDecodeError) as exc:
        messagebox.showerror("Fehler", str(exc))
        return

    win = tk.Toplevel(parent)
    win.title(title)
    win.geometry("560x680")

    text_frame = tk.Frame(win)
    text_frame.pack(fill="both", expand=True, padx=10, pady=(10, 0))
    scrollbar = tk.Scrollbar(text_frame)
    scrollbar.pack(side="right", fill="y")
    text_widget = tk.Text(text_frame, wrap="none", yscrollcommand=scrollbar.set)
    text_widget.pack(side="left", fill="both", expand=True)
    scrollbar.config(command=text_widget.yview)
    text_widget.insert("1.0", text)

    def save():
        try:
            parsed = json.loads(text_widget.get("1.0", "end"))
        except json.JSONDecodeError as exc:
            messagebox.showerror("Ungültige Eingaben", f"Ungültiges JSON-Format:\n{exc}")
            return
        with open(path, "w", encoding="utf-8") as f:
            json.dump(parsed, f, indent=2, ensure_ascii=False)
        win.destroy()

    tk.Button(win, text="Speichern", command=save).pack(pady=10)


# -- modal single-selection list dialog (tkinter analogue of listdlg) -------

class ListDialog(tk.Toplevel):
    def __init__(self, parent, title, prompt, options):
        super().__init__(parent)
        self.title(title)
        self.result = None
        self.transient(parent)
        self.resizable(False, False)

        tk.Label(self, text=prompt).pack(padx=10, pady=(10, 4))
        frame = tk.Frame(self)
        frame.pack(padx=10, pady=4, fill="both", expand=True)
        scrollbar = tk.Scrollbar(frame)
        scrollbar.pack(side="right", fill="y")
        self.listbox = tk.Listbox(
            frame, width=40, height=min(12, max(4, len(options))),
            yscrollcommand=scrollbar.set, exportselection=False,
        )
        for opt in options:
            self.listbox.insert("end", opt)
        self.listbox.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.listbox.yview)
        if options:
            self.listbox.selection_set(0)
        self.listbox.bind("<Double-Button-1>", lambda e: self._ok())

        btns = tk.Frame(self)
        btns.pack(pady=(4, 10))
        tk.Button(btns, text="OK", width=10, command=self._ok).pack(side="left", padx=4)
        tk.Button(btns, text="Abbrechen", width=10, command=self._cancel).pack(side="left", padx=4)

        self.protocol("WM_DELETE_WINDOW", self._cancel)
        self.grab_set()
        self.focus_set()
        self.wait_window(self)

    def _ok(self):
        sel = self.listbox.curselection()
        self.result = sel[0] if sel else None
        self.destroy()

    def _cancel(self):
        self.result = None
        self.destroy()


def ask_list(parent, title, prompt, options):
    if not options:
        messagebox.showwarning(title, "Keine Optionen verfügbar.")
        return None
    return ListDialog(parent, title, prompt, options).result


# -- per-method-folder file management window --------------------------------

class ManageFilesWindow(tk.Toplevel):
    def __init__(self, manager, ref_dir, ref_name, method_dir, method_label):
        super().__init__(manager)
        self.manager = manager
        self.ref_dir = ref_dir
        self.ref_name = ref_name
        self.method_dir = method_dir

        self.title(f"{method_label} Referenzdateien")
        self.geometry("340x480")

        tk.Label(self, text=f"Dateien: {method_label}").pack(pady=(10, 4))

        frame = tk.Frame(self)
        frame.pack(padx=20, fill="both", expand=True)
        scrollbar = tk.Scrollbar(frame)
        scrollbar.pack(side="right", fill="y")
        self.file_listbox = tk.Listbox(frame, selectmode="extended", yscrollcommand=scrollbar.set)
        self.file_listbox.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.file_listbox.yview)
        self._reload_files()

        btns = tk.Frame(self)
        btns.pack(pady=10, padx=20, fill="x")
        btns.columnconfigure(0, weight=1)
        btns.columnconfigure(1, weight=1)
        tk.Button(btns, text="Datei löschen", command=self.delete_files).grid(row=0, column=0, sticky="ew", padx=4)
        tk.Button(btns, text="Neue Datei", command=self.add_files).grid(row=0, column=1, sticky="ew", padx=4)

        tk.Button(self, text="Zurück zur Methodenauswahl", command=self.back).pack(padx=20, pady=(0, 10), fill="x")

    def _reload_files(self):
        self.file_listbox.delete(0, "end")
        if os.path.isdir(self.method_dir):
            for name in sorted(os.listdir(self.method_dir)):
                if os.path.isfile(os.path.join(self.method_dir, name)):
                    self.file_listbox.insert("end", name)

    def add_files(self):
        filenames = filedialog.askopenfilenames(
            title="Wählen Sie Referenzdateien und Exportvorlagen aus",
            initialdir=standard_path_for(self.ref_dir),
            filetypes=[("Referenzdateien", "*.csv *.txt *.xlsx *.xlsm"), ("Alle Dateien", "*.*")],
        )
        for path in filenames:
            copy_reference_file(path, self.method_dir)
        self._reload_files()

    def delete_files(self):
        names = [self.file_listbox.get(i) for i in self.file_listbox.curselection()]
        for name in names:
            os.remove(os.path.join(self.method_dir, name))
        self._reload_files()

    def back(self):
        self.destroy()
        self.manager.edit_reference(self.ref_name)


# -- main reference-management window -----------------------------------------

class ReferenceManager(tk.Toplevel):
    def __init__(self, parent, on_close=None):
        super().__init__(parent)
        self.on_close = on_close

        self.title("Referenzverwaltung")
        self.geometry("340x500")
        self.resizable(True, True)

        tk.Label(self, text="Verwalte die Referenzmessungen.").pack(pady=(10, 4))

        frame = tk.Frame(self)
        frame.pack(padx=20, fill="both", expand=True)
        scrollbar = tk.Scrollbar(frame)
        scrollbar.pack(side="right", fill="y")
        self.ref_listbox = tk.Listbox(frame, yscrollcommand=scrollbar.set, exportselection=False)
        self.ref_listbox.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.ref_listbox.yview)
        self.ref_listbox.bind("<Double-Button-1>", lambda e: self.edit_selected())
        self._reload_list()

        btns = tk.Frame(self)
        btns.pack(pady=10, padx=20, fill="x")
        btns.columnconfigure(0, weight=1)
        btns.columnconfigure(1, weight=1)
        specs = [
            ("Referenz bearbeiten", self.edit_selected),
            ("Neue Referenz", self.new_reference),
            ("Referenz löschen", self.delete_selected),
            ("Referenz auswählen", self.select_selected),
            ("Referenz importieren", self.import_reference),
            ("Referenz exportieren", self.export_selected),
        ]
        for i, (text, cmd) in enumerate(specs):
            tk.Button(btns, text=text, command=cmd).grid(row=i // 2, column=i % 2, sticky="ew", padx=4, pady=3)

        tk.Button(self, text="Standardconfig anpassen", command=self.edit_standard).pack(
            padx=20, pady=(0, 10), fill="x"
        )

        self.protocol("WM_DELETE_WINDOW", self.close)

    # -- helpers -----------------------------------------------------------
    def _reload_list(self):
        self.ref_listbox.delete(0, "end")
        for name in load_reference_list():
            self.ref_listbox.insert("end", name)

    def _selected_name(self):
        sel = self.ref_listbox.curselection()
        return self.ref_listbox.get(sel[0]) if sel else None

    def close(self):
        self.destroy()
        if self.on_close:
            self.on_close()

    # -- reference-level actions -------------------------------------------
    def new_reference(self):
        idx = ask_list(self, "Neue Referenz", "Wählen Sie einen Prüfstand aus:", BENCH_OPTIONS)
        if idx is None:
            return
        bench = BENCH_OPTIONS[idx]
        name = simpledialog.askstring(
            "Neue Referenz", "Geben Sie den Namen für den neuen Referenzsatz ein:", parent=self
        )
        if not name:
            return
        ref_dir = os.path.join(REFERENZEN_DIR, name)
        if os.path.isdir(ref_dir):
            messagebox.showerror("Fehler", "Eine Referenz mit diesem Namen existiert bereits.")
            return

        os.makedirs(ref_dir, exist_ok=True)
        create_method_dirs(ref_dir)
        template = os.path.join(STANDARDCONFIG_DIR, f"{bench}_config.json")
        if os.path.isfile(template):
            shutil.copyfile(template, os.path.join(ref_dir, "config.json"))

        self._reload_list()
        self.edit_reference(name)

    def edit_selected(self):
        name = self._selected_name()
        if name:
            self.edit_reference(name)

    def edit_reference(self, name):
        ref_dir = os.path.join(REFERENZEN_DIR, name)
        options = ["Referenz umbenennen", "Allgemeine Config"] + [method_label_text(m) for m in METHODS]
        idx = ask_list(self, "Referenz bearbeiten", "Wählen Sie eine Methode aus:", options)
        if idx is None:
            return
        if idx == 0:
            self.rename_reference(name, ref_dir)
        elif idx == 1:
            edit_json_file(self, "Allgemeine Config", os.path.join(ref_dir, "config.json"))
        else:
            method = METHODS[idx - 2]
            method_dir = self._pick_method_dir(ref_dir, method)
            if method_dir is not None:
                os.makedirs(method_dir, exist_ok=True)
                ManageFilesWindow(self, ref_dir, name, method_dir, method_label_text(method))

    def _pick_method_dir(self, ref_dir, method):
        method_dir = os.path.join(ref_dir, method)
        if method == "CV_ECSA":
            idx = ask_list(self, "Scantyp", "Wählen Sie den Scantyp aus:", CV_ECSA_SCANS)
            return os.path.join(method_dir, CV_ECSA_SCANS[idx]) if idx is not None else None
        if method == "PK":
            idx = ask_list(self, "Polarisationskurve", "Wählen Sie die Polarisationskurve aus:", PK_PICK_OPTIONS)
            if idx is None:
                return None
            sub = PK_SUBDIRS[idx]
            return os.path.join(method_dir, sub) if sub else method_dir
        return method_dir

    def rename_reference(self, old_name, old_dir):
        new_name = simpledialog.askstring(
            "Referenz umbenennen", "Geben Sie den neuen Namen für die Referenz ein:",
            initialvalue=old_name, parent=self,
        )
        if not new_name or new_name == old_name:
            return
        new_dir = os.path.join(REFERENZEN_DIR, new_name)
        if os.path.isdir(new_dir):
            messagebox.showerror("Fehler", "Eine Referenz mit diesem Namen existiert bereits.")
            return
        os.rename(old_dir, new_dir)
        self._reload_list()
        messagebox.showinfo("Erfolg", "Referenz erfolgreich umbenannt.")

    def delete_selected(self):
        name = self._selected_name()
        if not name:
            return
        if messagebox.askyesno("Referenz löschen", f'Soll die Referenz "{name}" wirklich gelöscht werden?'):
            shutil.rmtree(os.path.join(REFERENZEN_DIR, name))
            self._reload_list()

    def select_selected(self):
        name = self._selected_name()
        if not name:
            messagebox.showerror("Fehler", "Bitte wählen Sie eine Referenz aus.")
            return
        from auswahl import Auswahl

        Auswahl.save_reference_path(os.path.join(REFERENZEN_DIR, name))
        self.close()

    def export_selected(self):
        name = self._selected_name()
        if not name:
            messagebox.showerror("Fehler", "Bitte wählen Sie eine Referenz aus.")
            return
        ref_dir = os.path.join(REFERENZEN_DIR, name)
        initialdir = EXPORT_DIR_FALLBACK if os.path.isdir(EXPORT_DIR_FALLBACK) else REFERENZEN_DIR
        target = filedialog.asksaveasfilename(
            title="Referenz exportieren", initialdir=initialdir,
            initialfile=f"Referenz_{name}.zip", defaultextension=".zip",
            filetypes=[("ZIP-Dateien", "*.zip")],
        )
        if not target:
            return
        archive_base = target[:-4] if target.lower().endswith(".zip") else target
        shutil.make_archive(archive_base, "zip", ref_dir)
        messagebox.showinfo("Erfolg", "Referenz erfolgreich exportiert.")

    def import_reference(self):
        initialdir = EXPORT_DIR_FALLBACK if os.path.isdir(EXPORT_DIR_FALLBACK) else REFERENZEN_DIR
        zip_paths = filedialog.askopenfilenames(
            title="Referenz importieren", initialdir=initialdir, filetypes=[("ZIP-Dateien", "*.zip")]
        )
        if not zip_paths:
            return
        for zip_path in zip_paths:
            base_name = os.path.splitext(os.path.basename(zip_path))[0].replace("Referenz_", "")
            target_dir = os.path.join(REFERENZEN_DIR, base_name)
            counter = 1
            while os.path.isdir(target_dir):
                target_dir = os.path.join(REFERENZEN_DIR, f"{base_name}_{counter}")
                counter += 1
            with zipfile.ZipFile(zip_path) as zf:
                zf.extractall(target_dir)
        self._reload_list()
        messagebox.showinfo("Erfolg", "Referenz(en) erfolgreich importiert.")

    def edit_standard(self):
        if not os.path.isdir(STANDARDCONFIG_DIR):
            messagebox.showerror("Fehler", "Standardconfig-Ordner nicht gefunden.")
            return
        names = sorted(f for f in os.listdir(STANDARDCONFIG_DIR) if f.lower().endswith(".json"))
        idx = ask_list(self, "Standardconfig anpassen", "Wählen Sie einen Prüfstand aus:", names)
        if idx is None:
            return
        edit_json_file(self, names[idx], os.path.join(STANDARDCONFIG_DIR, names[idx]))
