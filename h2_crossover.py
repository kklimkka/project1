"""Python port of Auswertungen/H2_Crossover.m - hydrogen crossover evaluation."""

import os
import tkinter as tk
from tkinter import messagebox

import numpy as np
import matplotlib.pyplot as plt

import read_all
from method_base import MethodWindowBase, clean_tex, first, jet_colors, comma, REF_GREY


def find_limits(x, start_voltage, end_voltage):
    """Port of findLimits: (start, stop) 0-based slice indices for the first
    samples >= start/end voltage."""
    x = np.asarray(x)
    start_idx = np.argmax(x >= start_voltage)
    if not x[start_idx] >= start_voltage:
        start_idx = 0
    stop_idx = np.argmax(x >= end_voltage)
    if not x[stop_idx] >= end_voltage:
        stop_idx = len(x) - 1
    return int(start_idx), int(stop_idx)


def crossover_current(intercept, area):
    """I_H2-Crossover in mA/cm² from the fit intercept [A] and area [cm²]."""
    return intercept * 1000.0 / area


class H2CrossoverWindow(MethodWindowBase):
    METHOD_KEY = "H2_Crossover"
    WINDOW_TITLE = "H2-Crossover"

    def _build_ui(self):
        root = self.root
        for i in range(4):
            root.columnconfigure(i, weight=1)
        root.rowconfigure(1, weight=1)
        config = self.config

        top = tk.Frame(root)
        top.grid(row=0, column=0, columnspan=4, sticky="ew", padx=10, pady=5)
        top.columnconfigure(0, weight=1)
        tk.Button(top, text="H2-Crossover config", command=self.edit_config).grid(row=0, column=1, sticky="e")

        left = tk.Frame(root)
        left.grid(row=1, column=0, columnspan=2, sticky="nsew", padx=10, pady=5)
        left.rowconfigure(0, weight=1)
        left.columnconfigure(0, weight=1)
        self._make_info_text(
            left,
            'Die Auswertungsmethode "H2-Crossover" wurde ausgewählt:\n'
            ">> Titel Zeile 1 und 2: Titelanpassung (^{Text} für hochgestellten Text, _{Text} für "
            "tiefgestellten Text, \\{, \\} und \\\\ für {, } und \\; Titelgröße über das Feld "
            "rechts daneben einstellbar)\n"
            ">> Fläche [cm²]: aktive Fläche der Zelle\n"
            ">> Nachkommastellen bei I: Ausgabegenauigkeit von I\n"
            ">> Spannungsminimum & -maximum [V]: Spannungsbereich für den Geradenfit\n"
            ">> showRef / showDUT: Auswahl der geplotteten Daten\n\n"
            'Erst "Neue Datei laden" dann "Plotten" oder "Fitten"',
        )

        right = tk.Frame(root)
        right.grid(row=1, column=2, columnspan=2, sticky="nsew", padx=10, pady=5)
        self._make_file_list(right)

        titles = tk.Frame(root)
        titles.grid(row=2, column=0, columnspan=4, sticky="ew", padx=10, pady=5)
        titles.columnconfigure(1, weight=1)
        tk.Label(titles, text="Titel Zeile 1:").grid(row=0, column=0, sticky="w")
        self.title1_var = tk.StringVar(value=first(config.get("Titel1")))
        tk.Entry(titles, textvariable=self.title1_var).grid(row=0, column=1, sticky="ew", padx=5)
        tk.Label(titles, text="Titel Zeile 2:").grid(row=1, column=0, sticky="w")
        self.title2_var = tk.StringVar(value=first(config.get("Titel2")))
        tk.Entry(titles, textvariable=self.title2_var).grid(row=1, column=1, sticky="ew", padx=5)

        self.show_dut_var = tk.BooleanVar(value=bool(config.get("checkDUT", True)))
        self.show_reference_var = tk.BooleanVar(value=bool(config.get("checkRef", True)))
        tk.Checkbutton(titles, text="showDUT", variable=self.show_dut_var).grid(row=0, column=2, padx=5)
        tk.Checkbutton(titles, text="showRef", variable=self.show_reference_var).grid(row=0, column=3, padx=5)

        tk.Label(titles, text="I_H2-Crossover [mA/cm²]:").grid(row=1, column=2, sticky="e")
        self.result_var = tk.StringVar(value="")
        tk.Entry(titles, textvariable=self.result_var, state="readonly", width=10).grid(row=1, column=3, sticky="w")

        self.title_fontsize_var = self._title_fontsize_var()
        self._add_title_fontsize_field(titles, self.title_fontsize_var, row=2, column=0)

        params = tk.Frame(root)
        params.grid(row=3, column=0, columnspan=4, sticky="ew", padx=10, pady=5)
        self.area_var = tk.DoubleVar(value=config.get("Flaeche", 273))
        self.decimal_var = tk.IntVar(value=config.get("Nachkommastellen_I", 1))
        self.u_min_var = tk.DoubleVar(value=config.get("UMin", 0.3))
        self.u_max_var = tk.DoubleVar(value=config.get("UMax", 0.6))
        tk.Label(params, text="Fläche [cm²]:").grid(row=0, column=0, sticky="w")
        tk.Entry(params, textvariable=self.area_var, width=8).grid(row=0, column=1)
        tk.Label(params, text="Nachkommastellen bei I:").grid(row=0, column=2, sticky="w", padx=(15, 0))
        tk.Entry(params, textvariable=self.decimal_var, width=8).grid(row=0, column=3)
        tk.Label(params, text="Spannungsminimum [V]:").grid(row=0, column=4, sticky="w", padx=(15, 0))
        tk.Entry(params, textvariable=self.u_min_var, width=8).grid(row=0, column=5)
        tk.Label(params, text="Spannungsmaximum [V]:").grid(row=0, column=6, sticky="w", padx=(15, 0))
        tk.Entry(params, textvariable=self.u_max_var, width=8).grid(row=0, column=7)

        bottom = tk.Frame(root)
        bottom.grid(row=4, column=0, columnspan=4, sticky="ew", padx=10, pady=10)
        bottom.columnconfigure((0, 1, 2, 3), weight=1)
        tk.Button(bottom, text="Neue Datei laden", command=self.add_files).grid(row=0, column=0)
        tk.Button(bottom, text="Ganzen Bereich plotten", command=self.full_plot).grid(row=0, column=1)
        tk.Button(bottom, text="Fitten", command=self.plot_and_calc).grid(row=0, column=2)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=0, column=3)

    # -- data ---------------------------------------------------------------
    def _columns(self):
        return [c - 1 for c in self.config.get("Spalten", [3, 4])]

    def _load_references(self):
        self.reference_data = []
        marker = self._header_marker()
        for path in self._reference_files():
            data, _ = read_all.read_txt(path, marker)
            if data is not None:
                self.reference_data.append(data)

    def add_files(self):
        filenames = self._ask_filenames([("Text files", "*.txt")])
        if not filenames:
            return
        marker = self._header_marker()
        columns = self._columns()
        for path in filenames:
            data, _ = read_all.read_txt(path, marker)
            if data is None:
                messagebox.showwarning("Warnung", f"Keine Daten in Datei gefunden: {os.path.basename(path)}")
                continue
            self._add_file_item(os.path.basename(path), data[:, columns])

    def _axes_style(self, ax, x_lim, y_lim):
        config = self.config
        ax.grid(True, color=(0.5, 0.5, 0.5), alpha=0.7)
        ax.set_xlim(x_lim)
        ax.set_ylim(y_lim)
        ax.spines["left"].set_position("zero")
        ax.spines["bottom"].set_position("zero")
        ax.spines["right"].set_visible(False)
        ax.spines["top"].set_visible(False)
        ax.tick_params(labelsize=config.get("xTickSize", 18))

    # -- full range plot -------------------------------------------------------
    def full_plot(self):
        config = self.config
        show_reference = self.show_reference_var.get()
        show_dut = self.show_dut_var.get()
        if not show_reference and not show_dut:
            return
        data = []
        if show_dut:
            _, data = self._selected_data()
            if data is None:
                return

        line_width = config.get("lineWidth", 1)
        columns = self._columns()
        fig, ax = plt.subplots(figsize=(14, 8))

        if show_dut:
            if show_reference:
                for ref in self.reference_data:
                    ax.plot(ref[:, columns[0]], ref[:, columns[1]], "-o",
                            linewidth=line_width * 3, markersize=10, color=REF_GREY)
            colors = jet_colors(len(data))
            for i, current in enumerate(data):
                ax.plot(current[:, 0], current[:, 1], "-o", linewidth=line_width,
                        color=colors[i], label=f"{i + 1}. Messung")
        elif show_reference:
            colors = jet_colors(len(self.reference_data))
            for i, ref in enumerate(self.reference_data):
                ax.plot(ref[:, columns[0]], ref[:, columns[1]], "-o", linewidth=line_width,
                        color=colors[i], label=f"{i + 1}. Referenz")

        self._axes_style(ax, config.get("xAchsenLimitsGesamt", [0, 0.7]),
                         config.get("yAchsenLimitsGesamt", [-3.5, 1.5]))
        ax.set_title(
            f"{clean_tex(self.title1_var.get())}\n{clean_tex(self.title2_var.get())}",
            fontsize=self.title_fontsize_var.get(),
        )
        ax.set_xlabel(clean_tex(first(config.get("xlabel"), "U [V]")), fontweight="bold")
        ax.set_ylabel(clean_tex(first(config.get("ylabel"), "I [A]")), fontweight="bold")
        ax.legend(loc="center right", fontsize=config.get("legendFontSize", 14))
        plt.show(block=False)

    # -- fit plot + crossover calculation ---------------------------------------
    def plot_and_calc(self):
        config = self.config
        show_reference = self.show_reference_var.get()
        show_dut = self.show_dut_var.get()
        if not show_reference and not show_dut:
            return

        u_min, u_max = self.u_min_var.get(), self.u_max_var.get()
        columns = self._columns()
        line_width = config.get("lineWidth", 1)
        decimals_y = int(config.get("Nachkommastellen_y", 2))
        x_lim = config.get("xAchsenLimitsFit", [0, 0.9])
        y_lim = config.get("yAchsenLimitsFit", [0.8, 1.2])

        data = []
        if show_dut:
            _, data = self._selected_data()
            if data is None:
                return
            trimmed = []
            for current in data:
                start, stop = find_limits(current[:, 0], u_min, u_max)
                trimmed.append(current[start:stop + 1, :])
            data = trimmed

        refs = []
        if show_reference:
            for ref in self.reference_data:
                start, stop = find_limits(ref[:, columns[0]], u_min, u_max)
                refs.append(ref[start:stop + 1, :])

        fig, ax = plt.subplots(figsize=(14, 8))
        intercepts, slopes = [], []

        def fit_and_plot(x, y, color, name, grey=False):
            p = np.polyfit(x, y, 1)
            if grey:
                ax.plot(x, y, "-o", linewidth=line_width * 3, color=REF_GREY, markersize=12)
                x_fit = np.linspace(0, np.max(x), len(x))
                ax.plot(x_fit, np.polyval(p, x_fit), "-", linewidth=line_width * 3, color=REF_GREY)
                return None
            ax.plot(x, y, "-o", linewidth=line_width, color=color, label=name)
            x_fit = np.linspace(0, np.max(x), len(x))
            ax.plot(x_fit, np.polyval(p, x_fit), "-", linewidth=line_width, color=color)
            eq = f"y = {p[0]:.{decimals_y}f}x + {p[1]:.{decimals_y}f}"
            self._append_info_text(f"\nFitgerade {name}:\n{eq.replace('.', ',')}")
            return p

        if show_dut:
            for ref in refs:
                fit_and_plot(ref[:, columns[0]], ref[:, columns[1]], None, None, grey=True)
            colors = jet_colors(len(data))
            for i, current in enumerate(data):
                p = fit_and_plot(current[:, 0], current[:, 1], colors[i], f"{i + 1}. Messung")
                slopes.append(p[0]); intercepts.append(p[1])
        elif show_reference:
            colors = jet_colors(len(refs))
            for i, ref in enumerate(refs):
                p = fit_and_plot(ref[:, columns[0]], ref[:, columns[1]], colors[i], f"{i + 1}. Referenz")
                slopes.append(p[0]); intercepts.append(p[1])

        self._axes_style(ax, x_lim, y_lim)
        ax.set_xlabel(clean_tex(first(config.get("xlabel"), "U [V]")), fontweight="bold")
        ax.set_ylabel(clean_tex(first(config.get("ylabel"), "I [A]")), fontweight="bold")
        ax.legend(loc="center right", fontsize=config.get("legendFontSize", 14))

        if intercepts:
            y_mean = float(np.mean(intercepts))
            if len(intercepts) > 1:
                m_mean = float(np.mean(slopes))
                eq = f"y = {m_mean:.{decimals_y}f}x + {y_mean:.{decimals_y}f}"
                self._append_info_text(f"\nDurchschnittlicher Fit:\n{eq.replace('.', ',')}")
            decimals = self.decimal_var.get()
            h2 = round(crossover_current(y_mean, self.area_var.get()), decimals)
            self.result_var.set(comma(h2, decimals))
            ax.text(x_lim[0] + 0.056 * (x_lim[1] - x_lim[0]),
                    y_lim[0] + 0.3 * (y_lim[1] - y_lim[0]),
                    f"I(H2-Crossover) ≈ {comma(h2, decimals)} mA/cm²",
                    color=(192 / 255, 0, 0), backgroundcolor=(200 / 255, 200 / 255, 200 / 255),
                    fontsize=config.get("IH2_CrossoverSize", 18), fontweight="bold")
        plt.show(block=False)
