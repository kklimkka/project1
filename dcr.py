"""Python port of Auswertungen/DCR.m - the DCR evaluation method window.

Ported with tkinter + matplotlib. Layout is a simplified, resizable
re-interpretation of the original MATLAB uifigure layout (grid based
instead of pixel-exact placement).
"""

import glob
import json
import os
import re
import tkinter as tk
from tkinter import filedialog, messagebox

import numpy as np
import matplotlib.pyplot as plt

import paths
from method_base import clean_tex as _clean_title

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def _read_measurement_file(filepath, header_marker):
    """Port of read_txt.m's readDataFromFile: skip to the header line, then read
    numeric rows. Used for both DUT files and reference files - both are plain
    .txt (whitespace separated) or .csv (comma separated) instrument exports
    with 4 numeric columns (index, time, U, I).
    """
    delimiter = "," if filepath.lower().endswith(".csv") else None

    with open(filepath, "r", errors="ignore") as f:
        lines = f.readlines()

    header_found = False
    start_idx = 0
    for i, line in enumerate(lines):
        if header_marker in line:
            header_found = True
            start_idx = i + 1
            break

    if not header_found:
        return None

    rows = []
    for line in lines[start_idx:]:
        parts = [p.strip() for p in line.split(delimiter)] if delimiter else line.split()
        parts = [p for p in parts if p]
        if len(parts) < 4:
            continue
        try:
            rows.append([float(p) for p in parts[:4]])
        except ValueError:
            continue

    if not rows:
        return None
    return np.array(rows, dtype=float)


class DCRWindow:
    def __init__(self, root, reference_folder):
        self.root = root
        self.reference_folder = reference_folder
        self.dcr_ref_folder = os.path.join(reference_folder, "DCR")

        for child in list(self.root.children.values()):
            child.destroy()
        self.root.title("DCR")

        self.full_config = self._load_full_config()
        self.config = self.full_config.get("DCR", {})
        self.reference_data_array, self.ref_file_names = self._load_reference_data()

        # ordered dict: filename -> np.ndarray (mirrors MATLAB fileList Items/ItemsData)
        self.file_items = {}

        self._build_ui()

    # -- setup ------------------------------------------------------------
    def _load_full_config(self):
        config_path = os.path.join(self.reference_folder, "config.json")
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError) as exc:
            messagebox.showerror("Fehler beim Öffnen des DCR-Fensters", str(exc))
            return {}

    def _header_marker(self):
        return self.full_config.get("read_txt", {}).get("HeaderDerNurInZeileVorMessdatenIst", "Number")

    def _load_reference_data(self):
        ref_files = sorted(
            glob.glob(os.path.join(self.dcr_ref_folder, "Referenz#*.txt"))
            + glob.glob(os.path.join(self.dcr_ref_folder, "Referenz#*.csv"))
        )
        header_marker = self._header_marker()
        data_array = []
        names = []
        for path in ref_files:
            data = _read_measurement_file(path, header_marker)
            if data is None:
                messagebox.showwarning("Warnung", f"Keine Daten in Referenzdatei gefunden: {os.path.basename(path)}")
                continue
            data_array.append(data)
            names.append(os.path.basename(path))
        return data_array, names

    def _build_ui(self):
        root = self.root
        for i in range(3):
            root.columnconfigure(i, weight=1)
        root.rowconfigure(1, weight=1)

        # -- title row -----------------------------------------------------
        top = tk.Frame(root)
        top.grid(row=0, column=0, columnspan=3, sticky="ew", padx=10, pady=5)
        top.columnconfigure(1, weight=1)

        tk.Label(top, text="Titel Zeile 1:").grid(row=0, column=0, sticky="w")
        self.title1_var = tk.StringVar(value=self._first(self.config.get("Titel1"), ""))
        tk.Entry(top, textvariable=self.title1_var).grid(row=0, column=1, sticky="ew", padx=5)

        tk.Label(top, text="Titel Zeile 2:").grid(row=1, column=0, sticky="w")
        self.title2_var = tk.StringVar(value=self._first(self.config.get("Titel2"), ""))
        tk.Entry(top, textvariable=self.title2_var).grid(row=1, column=1, sticky="ew", padx=5)

        self.title_fontsize_var = tk.IntVar(value=int(self._first(self.config.get("TitelFontSize"), 14)))
        tk.Label(top, text="Titelgröße:").grid(row=1, column=4, sticky="e", padx=(10, 0))
        tk.Spinbox(top, from_=6, to=48, width=4, textvariable=self.title_fontsize_var).grid(
            row=1, column=5, sticky="w"
        )

        tk.Label(top, text="Widerstand [Ω]:").grid(row=0, column=2, sticky="e", padx=(10, 0))
        self.resistance_var = tk.StringVar(value="")
        tk.Entry(top, textvariable=self.resistance_var, state="readonly", width=10).grid(
            row=0, column=3, sticky="w"
        )

        tk.Button(top, text="DCR config", command=self.edit_config).grid(row=1, column=3, sticky="e")

        # -- info text (left) -----------------------------------------------
        left = tk.Frame(root)
        left.grid(row=1, column=0, columnspan=2, sticky="nsew", padx=10, pady=5)
        left.rowconfigure(0, weight=1)
        left.columnconfigure(0, weight=1)

        self.info_text = tk.Text(left, wrap="word")
        self.info_text.grid(row=0, column=0, sticky="nsew")
        self._set_info_text(
            'Die Auswertungsmethode "DCR" wurde ausgewählt:\n'
            ">> Titel Zeile 1 und 2: Titelanpassung (^{Text} für hochgestellten Text, _{Text} für "
            "tiefgestellten Text, \\{, \\} und \\\\ für {, } und \\; Titelgröße über das Feld "
            "rechts daneben einstellbar)\n"
            ">> xyUnten/xyOben Start/Ende: Zeilen der Messdatei mit den Start- und Endwerte "
            "der oberen und unteren Fitgerade zur DCR-Berechnung\n"
            ">> Referenzdaten anzeigen: Falls diese Checkbox gewählt wird, werden die "
            "Referenzdaten im Plot angezeigt\n"
            ">> DUT anzeigen: Falls diese Checkbox gewählt wird, werden die DUT-Daten im "
            "Plot angezeigt\n\n"
            'Erst "Neue Datei laden" dann "Plotten"'
        )

        # -- file list (right) ------------------------------------------------
        right = tk.Frame(root)
        right.grid(row=1, column=2, sticky="nsew", padx=10, pady=5)
        right.rowconfigure(1, weight=1)
        right.columnconfigure(0, weight=1)

        tk.Label(right, text="Dateiauswahl:", font=("TkDefaultFont", 12, "bold")).grid(
            row=0, column=0, sticky="w"
        )
        self.file_listbox = tk.Listbox(right, selectmode="extended")
        self.file_listbox.grid(row=1, column=0, sticky="nsew")

        # -- parameter fields --------------------------------------------------
        params = tk.Frame(root)
        params.grid(row=2, column=0, columnspan=3, sticky="ew", padx=10, pady=5)

        self.xy_unten_start_var = tk.IntVar(value=self.config.get("xyUntenStart", 1))
        self.xy_unten_end_var = tk.IntVar(value=self.config.get("xyUntenEnde", 1))
        self.xy_oben_start_var = tk.IntVar(value=self.config.get("xyObenStart", 1))
        self.xy_oben_end_var = tk.IntVar(value=self.config.get("xyObenEnde", 1))

        tk.Label(params, text="xyUnten Start:").grid(row=0, column=0, sticky="w")
        tk.Entry(params, textvariable=self.xy_unten_start_var, width=8).grid(row=0, column=1)
        tk.Label(params, text="xyUnten Ende:").grid(row=0, column=2, sticky="w", padx=(15, 0))
        tk.Entry(params, textvariable=self.xy_unten_end_var, width=8).grid(row=0, column=3)

        tk.Label(params, text="xyOben Start:").grid(row=1, column=0, sticky="w")
        tk.Entry(params, textvariable=self.xy_oben_start_var, width=8).grid(row=1, column=1)
        tk.Label(params, text="xyOben Ende:").grid(row=1, column=2, sticky="w", padx=(15, 0))
        tk.Entry(params, textvariable=self.xy_oben_end_var, width=8).grid(row=1, column=3)

        self.show_reference_var = tk.BooleanVar(value=bool(self.config.get("checkRef", True)))
        self.show_dut_var = tk.BooleanVar(value=bool(self.config.get("checkDUT", True)))
        tk.Checkbutton(params, text="Referenzdaten anzeigen", variable=self.show_reference_var).grid(
            row=0, column=4, sticky="w", padx=(20, 0)
        )
        tk.Checkbutton(params, text="DUT anzeigen", variable=self.show_dut_var).grid(
            row=1, column=4, sticky="w", padx=(20, 0)
        )

        # -- bottom buttons -----------------------------------------------------
        bottom = tk.Frame(root)
        bottom.grid(row=3, column=0, columnspan=3, sticky="ew", padx=10, pady=10)
        bottom.columnconfigure((0, 1, 2), weight=1)

        tk.Button(bottom, text="Neue Datei laden", command=self.add_files).grid(row=0, column=0)
        tk.Button(bottom, text="Plotten", command=self.plot).grid(row=0, column=1)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=0, column=2)

    @staticmethod
    def _first(value, default):
        if isinstance(value, list):
            return value[0] if value else default
        return value if value is not None else default

    def _set_info_text(self, text):
        self.info_text.delete("1.0", "end")
        self.info_text.insert("1.0", text)

    def _append_info_text(self, text):
        self.info_text.insert("end", "\n" + text)

    # -- callbacks ----------------------------------------------------------
    def edit_config(self):
        messagebox.showinfo("DCR config", "Die Config-Bearbeitung ist noch nicht implementiert.")

    def add_files(self):
        if not self.show_dut_var.get():
            return
        standard_path = self._standard_path()
        filenames = filedialog.askopenfilenames(
            title="Wählen Sie eine Datei zur Auswertung aus",
            initialdir=standard_path if os.path.isdir(standard_path) else None,
            filetypes=[("Messdaten", "*.txt *.csv"), ("Text files", "*.txt"), ("CSV files", "*.csv")],
        )
        if not filenames:
            return

        header_marker = self._header_marker()
        columns = [c - 1 for c in self.config.get("Spalten", [3, 4])]

        for path in filenames:
            data = _read_measurement_file(path, header_marker)
            if data is None:
                messagebox.showwarning("Warnung", f"Keine Daten in Datei gefunden: {os.path.basename(path)}")
                continue
            data = data[:, columns]
            name = os.path.basename(path)
            if name not in self.file_items:
                self.file_listbox.insert("end", name)
            self.file_items[name] = data

    def _standard_path(self):
        path = paths.resolve(self.full_config.get("Auswahl", {}).get("StandardPfad", ""))
        return path or ""

    def plot(self):
        show_reference = self.show_reference_var.get()
        show_dut = self.show_dut_var.get()
        if not show_reference and not show_dut:
            return

        t1 = _clean_title(self.title1_var.get())
        t2 = _clean_title(self.title2_var.get())

        selection = [self.file_listbox.get(i) for i in self.file_listbox.curselection()]
        if not selection:
            selection = list(self.file_items.keys())
        if not selection and show_dut:
            messagebox.showwarning("Warnung", "Bitte mindestens eine Datei laden.")
            return
        data = [self.file_items[name] for name in selection if name in self.file_items]

        xy_unten_start = self.xy_unten_start_var.get()
        xy_unten_end = self.xy_unten_end_var.get()
        xy_oben_start = self.xy_oben_start_var.get()
        xy_oben_end = self.xy_oben_end_var.get()

        if show_reference and not show_dut:
            full_area = np.arange(1, len(self.reference_data_array[0]) + 1) if self.reference_data_array else []
            self._plotting([], full_area, "b", t1, t2, show_reference, show_dut)

            fit_area = np.concatenate(
                [
                    np.arange(xy_unten_start, xy_unten_end + 1),
                    np.arange(xy_oben_start, xy_oben_end + 1),
                ]
            )
            self._plotting([], fit_area, "r", t1, t2, show_reference, show_dut)

            self._append_info_text("DCR der Referenzdateien:")
            columns = [c - 1 for c in self.config.get("Spalten", [3, 4])]
            for name, ref in zip(self.ref_file_names, self.reference_data_array):
                ref_dcr = self._widerstand([ref[:, columns]], xy_unten_start, xy_unten_end, xy_oben_start, xy_oben_end)
                self._append_info_text(f"{name}:\t{ref_dcr:.4f} Ω")
            return

        if show_dut:
            if not data:
                messagebox.showwarning("Warnung", "Bitte mindestens eine Datei laden.")
                return
            x = data[0][:, 0]
            full_area = np.arange(1, len(x) + 1)
            fit_area = np.concatenate(
                [
                    np.arange(xy_unten_start, xy_unten_end + 1),
                    np.arange(xy_oben_start, xy_oben_end + 1),
                ]
            )
            if xy_unten_start < 1 or xy_unten_end > len(x) or xy_oben_start < 1 or xy_oben_end > len(x):
                messagebox.showerror("Fehler", "Die angegebenen Bereichsindizes liegen außerhalb des gültigen Bereichs der Daten.")
                return

            self._plotting(data, full_area, "b", t1, t2, show_reference, show_dut)
            self._plotting(data, fit_area, "r", t1, t2, show_reference, show_dut)

            dcr = self._widerstand(data, xy_unten_start, xy_unten_end, xy_oben_start, xy_oben_end)
            decimals = int(self.config.get("Nachkommastellen", 1))
            self.resistance_var.set(f"{dcr:.{decimals}f}")

    def back_to_selection(self):
        from auswahl import Auswahl

        Auswahl(self.root)

    # -- data processing ------------------------------------------------------
    def _widerstand(self, data, xy_unten_start, xy_unten_end, xy_oben_start, xy_oben_end):
        values = []
        for current in data:
            x = current[:, 0]
            y = current[:, 1]
            x_unten = x[xy_unten_start - 1:xy_unten_end]
            y_unten = y[xy_unten_start - 1:xy_unten_end]
            x_oben = x[xy_oben_start - 1:xy_oben_end]
            y_oben = y[xy_oben_start - 1:xy_oben_end]

            fit_unten = np.polyfit(x_unten, y_unten, 1)
            fit_oben = np.polyfit(x_oben, y_oben, 1)

            slope = (fit_unten[0] + fit_oben[0]) / 2
            values.append(1 / slope)
        return float(np.mean(values))

    def _plotting(self, data, area, color, t1, t2, show_reference, show_dut):
        config = self.config
        columns = [c - 1 for c in config.get("Spalten", [3, 4])]
        area = np.asarray(area, dtype=int)

        fig, ax = plt.subplots()

        split_index = None
        diffs = np.diff(area)
        gap = np.where(diffs > 1)[0]
        split_index = (gap[0] + 1) if len(gap) else len(area)

        colors = plt.cm.jet(np.linspace(0, 1, max(len(self.reference_data_array), 1)))

        if show_reference and self.reference_data_array and show_dut:
            for ref in self.reference_data_array:
                ref_u = ref[:, columns[0]]
                ref_i = ref[:, columns[1]]
                self._plot_ref_segments(ax, ref_u, ref_i, area, split_index)
            ax.plot([], [], "-o", linewidth=config.get("Linienbreite", 1) * 3, markersize=8,
                    color=(0.9, 0.9, 0.9), label="Referenz")
        elif show_reference and self.reference_data_array and not show_dut:
            for i, ref in enumerate(self.reference_data_array):
                ref_u = ref[:, columns[0]]
                ref_i = ref[:, columns[1]]
                self._plot_segments(ax, ref_u, ref_i, area, colors[i % len(colors)], split_index,
                                     f"Referenz#{i + 1}", config.get("Linienbreite", 1))

        self._configure_axes(ax)

        if show_dut:
            for current in data:
                x = current[:, 0]
                y = current[:, 1]
                self._plot_segments(ax, x, y, area, color, split_index, "DUT", config.get("Linienbreite", 1))

        ax.set_title(f"{t1}\n{t2}", fontsize=self.title_fontsize_var.get())
        ax.set_xlabel(_clean_title(self._first(config.get("xlabel"), "U [V]")))
        ax.set_ylabel(_clean_title(self._first(config.get("ylabel"), "I [A]")))
        ax.grid(True)
        ax.legend(loc="upper right", fontsize=config.get("legendFontSize", 10))
        fig.show()

    def _plot_ref_segments(self, ax, u, i, area, split_index):
        idx1 = area[:split_index] - 1
        ax.plot(u[idx1], i[idx1], "-o", linewidth=1 * 3, markersize=8, color=(0.9, 0.9, 0.9))
        if split_index < len(area):
            idx2 = area[split_index:] - 1
            ax.plot(u[idx2], i[idx2], "-o", linewidth=1 * 3, markersize=8, color=(0.9, 0.9, 0.9))

    def _plot_segments(self, ax, x, y, area, color, split_index, name, line_width):
        idx1 = area[:split_index] - 1
        ax.plot(x[idx1], y[idx1], "-o", linewidth=line_width, markersize=4, color=color, label=name)
        if split_index < len(area):
            idx2 = area[split_index:] - 1
            ax.plot(x[idx2], y[idx2], "-o", linewidth=line_width, markersize=4, color=color)

    def _configure_axes(self, ax):
        config = self.config
        x_lim = config.get("xAchsenLimits", [-0.15, 0.15])
        y_lim = config.get("yAchsenLimits", [-0.1, 0.1])
        ax.set_xlim(x_lim)
        ax.set_ylim(y_lim)
        ax.axhline(config.get("obererGrenzwert", 0.1), color=(1, 0.5, 0), alpha=0.5, linewidth=2)
        ax.axhline(config.get("untererGrenzwert", -0.1), color=(1, 0.5, 0), alpha=0.5, linewidth=2)
        ax.tick_params(labelsize=config.get("xTickSize", 10))
        ax.spines["left"].set_position("zero")
        ax.spines["bottom"].set_position("zero")
        ax.spines["right"].set_visible(False)
        ax.spines["top"].set_visible(False)
