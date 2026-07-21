"""Python port of Auswertungen/Leckage.m - leakage rate evaluation."""

import os
import tkinter as tk
from tkinter import messagebox

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

import read_all
from method_base import MethodWindowBase, clean_tex, first, comma


def calculate_leakage(values):
    """Port of calculateLeakage: values are the 8 selected cells
    (D,E,F,G,I,J,L,M by default). Returns
    (externalAnode, externalCathode, internalAnode, internalCathode)."""
    values = [float(v) for v in values]
    factor = 100.0
    external_anode = (values[0] - values[2]) * factor
    external_cathode = (values[1] - values[3]) * factor
    internal_anode = (values[4] - values[6]) * factor
    internal_cathode = (values[5] - values[7]) * factor
    return external_anode, external_cathode, internal_anode, internal_cathode


def _gradient_bar(ax, x, height, color, num_steps=256):
    """Port of createGradientBar: bar fading from opaque (bottom) to
    transparent (top)."""
    if height == 0:
        return
    rgba = np.zeros((num_steps, 1, 4))
    rgba[:, 0, :3] = color
    rgba[:, 0, 3] = np.linspace(1.0, 0.01, num_steps)
    top, bottom = (height, 0) if height >= 0 else (0, height)
    ax.imshow(
        rgba, extent=(x - 0.4, x + 0.4, bottom, top),
        origin="lower" if height >= 0 else "upper",
        aspect="auto", zorder=2,
    )


class LeckageWindow(MethodWindowBase):
    METHOD_KEY = "Leckage"
    WINDOW_TITLE = "Leckage"

    def _build_ui(self):
        root = self.root
        for i in range(3):
            root.columnconfigure(i, weight=1)
        root.rowconfigure(1, weight=1)

        top = tk.Frame(root)
        top.grid(row=0, column=0, columnspan=3, sticky="ew", padx=10, pady=5)
        top.columnconfigure(0, weight=1)
        tk.Button(top, text="Leckage config", command=self.edit_config).grid(row=0, column=1, sticky="e")

        left = tk.Frame(root)
        left.grid(row=1, column=0, columnspan=2, sticky="nsew", padx=10, pady=5)
        left.rowconfigure(0, weight=1)
        left.columnconfigure(0, weight=1)
        self._make_info_text(
            left,
            'Die Auswertungsmethode "Leckage" wurde ausgewählt:\n'
            'Bitte "Leak_Check - logger 2" zur Auswertung nutzen\n'
            ">> Zeile: Zeile der CSV, deren Daten ausgewertet werden sollen\n"
            ">> Spalten: Spalten der CSV (A=1, B=2,... wie in Excel), deren Daten "
            "ausgewertet werden sollen\n"
            ">> Referenzdaten anzeigen / DUT anzeigen: Auswahl der geplotteten Daten\n\n"
            'Erst "Neue Datei laden" dann "Plotten"',
        )

        right = tk.Frame(root)
        right.grid(row=1, column=2, sticky="nsew", padx=10, pady=5)
        self._make_file_list(right)

        # result table (Anode/Kathode x Extern/Intern)
        table = tk.LabelFrame(root, text="Leckraten [mbar/min]")
        table.grid(row=2, column=0, columnspan=3, sticky="ew", padx=10, pady=5)
        for i in range(3):
            table.columnconfigure(i, weight=1)
        tk.Label(table, text="").grid(row=0, column=0)
        tk.Label(table, text="Extern (mbar/min)").grid(row=0, column=1)
        tk.Label(table, text="Intern (mbar/min)").grid(row=0, column=2)
        self.table_vars = {}
        for r, name in enumerate(("Anode", "Kathode"), start=1):
            tk.Label(table, text=name).grid(row=r, column=0, sticky="w")
            for c, kind in enumerate(("extern", "intern"), start=1):
                var = tk.StringVar(value="")
                tk.Entry(table, textvariable=var, state="readonly", justify="center").grid(
                    row=r, column=c, sticky="ew", padx=2
                )
                self.table_vars[(name, kind)] = var

        params = tk.Frame(root)
        params.grid(row=3, column=0, columnspan=3, sticky="ew", padx=10, pady=5)
        params.columnconfigure(1, weight=1)

        tk.Label(params, text="Zeile:").grid(row=0, column=0, sticky="w")
        self.row_var = tk.StringVar(value=str(first(self.config.get("Zeilen"), "last")))
        tk.Entry(params, textvariable=self.row_var).grid(row=0, column=1, sticky="ew", padx=5)

        tk.Label(params, text="Spalten:").grid(row=1, column=0, sticky="w")
        self.cols_var = tk.StringVar(value=str(first(self.config.get("Spalten"), "D,E,F,G,I,J,L,M")))
        tk.Entry(params, textvariable=self.cols_var).grid(row=1, column=1, sticky="ew", padx=5)

        tk.Label(params, text="Bezeichnung der DUT:").grid(row=0, column=2, sticky="w", padx=(15, 0))
        self.dut_name_var = tk.StringVar(value="DUT")
        tk.Entry(params, textvariable=self.dut_name_var, width=15).grid(row=0, column=3, sticky="w")

        self.show_reference_var = tk.BooleanVar(value=bool(self.config.get("checkRef", True)))
        self.show_dut_var = tk.BooleanVar(value=bool(self.config.get("checkDUT", True)))
        tk.Checkbutton(params, text="Referenzdaten anzeigen", variable=self.show_reference_var).grid(
            row=1, column=2, sticky="w", padx=(15, 0)
        )
        tk.Checkbutton(params, text="DUT anzeigen", variable=self.show_dut_var).grid(
            row=1, column=3, sticky="w"
        )

        bottom = tk.Frame(root)
        bottom.grid(row=4, column=0, columnspan=3, sticky="ew", padx=10, pady=10)
        bottom.columnconfigure((0, 1, 2), weight=1)
        tk.Button(bottom, text="Neue Datei laden", command=self.add_files).grid(row=0, column=0)
        tk.Button(bottom, text="Plotten", command=self.plot).grid(row=0, column=1)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=0, column=2)

    # -- data ----------------------------------------------------------------
    def _load_references(self):
        self.reference_values = []
        for path in self._reference_files():
            values = self._read_values(path)
            if values is not None:
                self.reference_values.append(values)

    def _data_locations(self):
        row_input = self.row_var.get().strip()
        if not row_input or not row_input.replace(".", "", 1).isdigit():
            row_input = "last"
        else:
            row_input = int(float(row_input))
        col_letters = [c.strip() for c in self.cols_var.get().split(",") if c.strip()]
        columns = [read_all.excel_col_to_index(c) for c in col_letters]
        return row_input, columns

    def _read_values(self, path):
        row_input, columns = self._data_locations()
        data_lines = "last" if row_input == "last" else (row_input, row_input)
        data, _ = read_all.read_csv_numeric(path, data_lines, columns)
        if data.size == 0:
            messagebox.showwarning("Warnung", f"Keine Daten in Datei gefunden: {os.path.basename(path)}")
            return None
        return data[-1]

    def add_files(self):
        filenames = self._ask_filenames([("CSV files", "*.csv")])
        if not filenames:
            return
        for path in filenames:
            values = self._read_values(path)
            if values is None:
                continue
            self._add_file_item(os.path.basename(path), values)
            values_str = ", ".join(comma(v, 6) for v in values)
            self._append_info_text(f"\nDUT-Daten ({os.path.basename(path)}):\n{values_str}")

    # -- plotting --------------------------------------------------------------
    def plot(self):
        use_reference = self.show_reference_var.get()
        use_dut = self.show_dut_var.get()
        if not use_reference and not use_dut:
            return

        ext_anode, ext_cathode, int_anode, int_cathode, names = [], [], [], [], []
        if use_reference:
            for i, values in enumerate(self.reference_values, start=1):
                ea, ec, ia, ic = calculate_leakage(values)
                ext_anode.append(ea); ext_cathode.append(ec)
                int_anode.append(ia); int_cathode.append(ic)
                names.append(f"Ref#{i}")

        dut_count = 0
        if use_dut:
            _, data = self._selected_data()
            if data is None:
                return
            decimals = int(self.config.get("NachkommastellenTabelle", 4))
            for values in data:
                ea, ec, ia, ic = calculate_leakage(values)
                self.table_vars[("Anode", "extern")].set(comma(ea, decimals))
                self.table_vars[("Anode", "intern")].set(comma(ia, decimals))
                self.table_vars[("Kathode", "extern")].set(comma(ec, decimals))
                self.table_vars[("Kathode", "intern")].set(comma(ic, decimals))
                ext_anode.append(ea); ext_cathode.append(ec)
                int_anode.append(ia); int_cathode.append(ic)
            dut_count = len(data)
            if dut_count > 1:
                names += [f"Zelle #{i + 1}" for i in range(dut_count)]
            else:
                names.append(self.dut_name_var.get() or "DUT")

        if not ext_anode:
            messagebox.showerror("Fehler beim Erstellen des Plots", "Keine Referenz-/DUT-Datei gefunden")
            return

        self._leakage_plot(ext_anode, ext_cathode, names, "Externe Leckage", use_dut, use_reference, dut_count)
        self._leakage_plot(int_anode, int_cathode, names, "Interne Leckage", use_dut, use_reference, dut_count)
        plt.show(block=False)

    def _leakage_plot(self, anode_data, cathode_data, labels, title, use_dut, use_reference, dut_count):
        config = self.config
        y_lim = config.get("yAchsenLimits", [-2, 6])
        fig, ax = plt.subplots(num=title, figsize=(12, 7))

        n = len(anode_data)
        if use_dut and use_reference:
            ref_end = (n - dut_count) * 2 + 0.5
            ax.axvspan(0.5, ref_end, color=(0.7, 0.7, 0.7), alpha=0.5, zorder=1)

        for i in range(n):
            _gradient_bar(ax, i * 2 + 1, anode_data[i], (192 / 255, 0, 0))
            _gradient_bar(ax, i * 2 + 2, cathode_data[i], (0, 112 / 255, 192 / 255))
            self._bar_text(ax, i * 2 + 1, anode_data[i])
            self._bar_text(ax, i * 2 + 2, cathode_data[i])

        ax.set_xticks(np.arange(1.5, n * 2 + 0.5, 2))
        ax.set_xticklabels(labels, fontsize=config.get("xTickSize", 10))
        ax.tick_params(axis="y", labelsize=config.get("yTickSize", 10))
        ax.set_xlabel(clean_tex(first(config.get("xlabel"), "Zelle")), fontweight="bold")
        ax.set_ylabel(clean_tex(first(config.get("ylabel"), "Leckrate [mbar/min]")), fontweight="bold")
        ax.set_title(title, fontsize=config.get("titleFontSize", 25))
        ax.set_ylim(y_lim)
        ax.set_xlim(0.5, 2 * n + 0.5)
        ax.axhline(config.get("Grenzwert", 5), color=(1, 0.5, 0), alpha=0.5, linewidth=2)
        ax.grid(axis="y", alpha=0.2)
        handles = [
            plt.Rectangle((0, 0), 1, 1, color=(192 / 255, 0, 0)),
            plt.Rectangle((0, 0), 1, 1, color=(0, 112 / 255, 192 / 255)),
        ]
        ax.legend(handles, ["Anode", "Kathode"], fontsize=config.get("legendFontSize", 15))

    def _bar_text(self, ax, x, value):
        decimals = int(self.config.get("NachkommastellenPlot", 2))
        va = "top" if value < 0 else "bottom"
        ax.text(x, value, comma(value, decimals), ha="center", va=va,
                fontweight="bold", fontsize=self.config.get("barTextSize", 10), zorder=3)
