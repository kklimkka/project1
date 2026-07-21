"""Python port of Auswertungen/OCV_FallOff.m - short-circuit / OCV / fall-off test."""

import os
import tkinter as tk
from tkinter import messagebox

import numpy as np
import matplotlib.pyplot as plt

import read_all
from method_base import MethodWindowBase, clean_tex, first, jet_colors


def find_start(data, grenzwert):
    """Port of findStart: 1-based index where the data first exceeds the
    threshold (0 if never)."""
    idx = np.argmax(np.asarray(data) > grenzwert)
    if idx == 0 and not data[0] > grenzwert:
        return 0
    return int(idx) + 1


def process_x_axis_limits(x_min_input, x_max_input, data_length, start_index, abstand,
                          darstellungslaenge, zeilen_vor_grenzwert):
    """Port of processXAxisLimits. Returns (x_min, x_max, err_msg)."""
    x_min = 1
    x_max = darstellungslaenge - zeilen_vor_grenzwert
    err = ""

    x_min_input = (x_min_input or "").strip()
    x_max_input = (x_max_input or "").strip()

    if x_min_input in ("", "auto"):
        x_min = max(x_min, start_index - abstand)
    elif x_min_input == "last":
        x_min = data_length
    else:
        try:
            x_min = float(x_min_input)
        except ValueError:
            x_min = 1

    if x_max_input == "auto":
        x_max = min(data_length, start_index + x_max)
    elif x_max_input == "last":
        x_max = data_length
    else:
        try:
            x_max = float(x_max_input)
            if x_max > data_length:
                raise ValueError
        except ValueError:
            x_max = data_length
            err = ("Bitte 'last' für den letzten Wert eingeben oder 'auto' für "
                   "automatische Grenzwerte nutzen.")
    return x_min, x_max, err


class OCVFallOffWindow(MethodWindowBase):
    METHOD_KEY = "OCV_FallOff"
    WINDOW_TITLE = "OCV-FallOff"

    def _build_ui(self):
        root = self.root
        for i in range(3):
            root.columnconfigure(i, weight=1)
        root.rowconfigure(1, weight=1)
        config = self.config

        top = tk.Frame(root)
        top.grid(row=0, column=0, columnspan=3, sticky="ew", padx=10, pady=5)
        top.columnconfigure(0, weight=1)
        tk.Button(top, text="OCV-FallOff config", command=self.edit_config).grid(row=0, column=1, sticky="e")

        left = tk.Frame(root)
        left.grid(row=1, column=0, columnspan=2, sticky="nsew", padx=10, pady=5)
        left.rowconfigure(0, weight=1)
        left.columnconfigure(0, weight=1)
        self._make_info_text(
            left,
            'Die Auswertungsmethode "OCV-FallOff" wurde ausgewählt:\n'
            ">> Titel Zeile 1 und 2: Titelanpassung (^{Text} für hochgestellten Text, _{Text} für "
            "tiefgestellten Text, \\{, \\} und \\\\ für {, } und \\; Titelgröße über das Feld "
            "rechts daneben einstellbar)\n"
            ">> Grenzwert [V]: Sobald dieser Wert das erste Mal erreicht wird, wird ein Index gespeichert\n"
            ">> Zeilen vor Grenzwert: Zeilenanzahl, die vom Index abgezogen wird\n"
            ">> Startzeile manuell (+ Checkbox): erste dargestellte Zeile direkt angeben\n"
            ">> x-Achsen Min & Max: Zahl, 'auto' oder 'last'\n\n"
            'Erst "Neue Datei laden" dann "Plotten"',
        )

        right = tk.Frame(root)
        right.grid(row=1, column=2, sticky="nsew", padx=10, pady=5)
        self._make_file_list(right, multi=False)

        titles = tk.Frame(root)
        titles.grid(row=2, column=0, columnspan=3, sticky="ew", padx=10, pady=5)
        titles.columnconfigure(1, weight=1)
        tk.Label(titles, text="Titel Zeile 1:").grid(row=0, column=0, sticky="w")
        self.title1_var = tk.StringVar(value=first(config.get("Titel1")))
        tk.Entry(titles, textvariable=self.title1_var).grid(row=0, column=1, sticky="ew", padx=5)
        tk.Label(titles, text="Titel Zeile 2:").grid(row=1, column=0, sticky="w")
        self.title2_var = tk.StringVar(value=first(config.get("Titel2")))
        tk.Entry(titles, textvariable=self.title2_var).grid(row=1, column=1, sticky="ew", padx=5)

        self.title_fontsize_var = self._title_fontsize_var()
        self._add_title_fontsize_field(titles, self.title_fontsize_var, row=0, column=2)

        params = tk.Frame(root)
        params.grid(row=3, column=0, columnspan=3, sticky="ew", padx=10, pady=5)

        self.grenzwert_var = tk.DoubleVar(value=config.get("Grenzwert", 0.1))
        self.abstand_var = tk.IntVar(value=config.get("ZeilenVorGrenzwert", 50))
        self.startwert_var = tk.IntVar(value=config.get("StartManuell", 0))
        self.manuell_var = tk.BooleanVar(value=bool(config.get("checkStartManuell", False)))
        self.x_min_var = tk.StringVar(value=str(first(config.get("xMin"), "auto")))
        self.x_max_var = tk.StringVar(value=str(first(config.get("xMax"), "auto")))
        self.show_reference_var = tk.BooleanVar(value=bool(config.get("checkRef", True)))
        self.show_dut_var = tk.BooleanVar(value=bool(config.get("checkDUT", True)))

        tk.Label(params, text="Grenzwert [V]:").grid(row=0, column=0, sticky="w")
        tk.Entry(params, textvariable=self.grenzwert_var, width=8).grid(row=0, column=1)
        tk.Label(params, text="Zeilen vor Grenzwert:").grid(row=0, column=2, sticky="w", padx=(15, 0))
        tk.Entry(params, textvariable=self.abstand_var, width=8).grid(row=0, column=3)
        tk.Label(params, text="Startzeile manuell:").grid(row=1, column=0, sticky="w")
        tk.Entry(params, textvariable=self.startwert_var, width=8).grid(row=1, column=1)
        tk.Checkbutton(params, text="Startzeile manuell angeben?", variable=self.manuell_var).grid(
            row=1, column=2, columnspan=2, sticky="w", padx=(15, 0)
        )
        tk.Checkbutton(params, text="Referenzdaten anzeigen", variable=self.show_reference_var).grid(
            row=0, column=4, sticky="w", padx=(20, 0)
        )
        tk.Checkbutton(params, text="DUT anzeigen", variable=self.show_dut_var).grid(
            row=1, column=4, sticky="w", padx=(20, 0)
        )
        tk.Label(params, text="x-Achsen Min:").grid(row=0, column=5, sticky="w", padx=(20, 0))
        tk.Entry(params, textvariable=self.x_min_var, width=8).grid(row=0, column=6)
        tk.Label(params, text="x-Achsen Max:").grid(row=1, column=5, sticky="w", padx=(20, 0))
        tk.Entry(params, textvariable=self.x_max_var, width=8).grid(row=1, column=6)

        bottom = tk.Frame(root)
        bottom.grid(row=4, column=0, columnspan=3, sticky="ew", padx=10, pady=10)
        bottom.columnconfigure((0, 1, 2), weight=1)
        tk.Button(bottom, text="Neue Datei laden", command=self.add_files).grid(row=0, column=0)
        tk.Button(bottom, text="Plotten", command=self.plot).grid(row=0, column=1)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=0, column=2)

    # -- data ---------------------------------------------------------------
    def _load_references(self):
        self.reference_data = []
        column = int(self.config.get("Spalten", 7))
        for path in self._reference_files():
            data, _ = read_all.read_csv_numeric(path, None, [column])
            if data.size:
                self.reference_data.append(data[:, 0])

    def add_files(self):
        filenames = self._ask_filenames([("CSV files", "*.csv")])
        if not filenames:
            return
        lines = read_all.process_inf(self.config.get("Zeilen", [1, "Inf"]))
        column = int(self.config.get("Spalten", 7))
        for path in filenames:
            data, _ = read_all.read_csv_numeric(path, lines, [column])
            if data.size == 0:
                messagebox.showwarning("Warnung", f"Keine Daten in Datei gefunden: {os.path.basename(path)}")
                continue
            self._add_file_item(os.path.basename(path), data[:, 0])

    # -- plotting -------------------------------------------------------------
    def plot(self):
        config = self.config
        show_reference = self.show_reference_var.get()
        show_dut = self.show_dut_var.get()
        if not show_reference and not show_dut:
            return

        abstand = self.abstand_var.get()
        t1 = clean_tex(self.title1_var.get())
        t2 = clean_tex(self.title2_var.get())

        data = None
        start_values = []
        if show_dut:
            names, all_data = self._selected_data()
            if all_data is None:
                return
            data = all_data[0]
            if self.manuell_var.get():
                start_values.append(self.startwert_var.get())
            else:
                start_values.append(find_start(data, self.grenzwert_var.get()) - abstand)

        ref_data = self.reference_data if show_reference else []
        if show_reference:
            ref_limits = config.get("RefGrenzenwerte", [])
            ref_start = config.get("RefStartzeile", [])
            ref_use_start = config.get("RefStartzeileNutzen", [])
            for i, ref in enumerate(ref_data):
                if i < len(ref_use_start) and ref_use_start[i]:
                    start_values.append(ref_start[i])
                else:
                    grenzwert = ref_limits[i] if i < len(ref_limits) else self.grenzwert_var.get()
                    start_values.append(find_start(ref, grenzwert) - abstand)

        if not start_values:
            return

        data_length = len(data) if show_dut else len(ref_data[0]) if ref_data else 0
        x_min, x_max, err = process_x_axis_limits(
            self.x_min_var.get(), self.x_max_var.get(), data_length, start_values[0], abstand,
            config.get("Darstellungslaenge", 2900), config.get("ZeilenVorGrenzwert", 50),
        )
        if err:
            self._append_info_text(err)
            return

        self._plotting(data, ref_data, start_values, t1, t2, show_reference, show_dut, x_min, x_max)

    def _plotting(self, data, ref_data, start_values, t1, t2, show_reference, show_dut, x_min, x_max):
        config = self.config
        line_width = config.get("lineWidth", 3)
        alpha = 0.1
        refcolor = tuple(0.01 * alpha + 1 * (1 - alpha) for _ in range(3))
        y_lim = config.get("yAchsenLimits", [0, 1.2])

        fig, ax = plt.subplots(figsize=(14, 8))

        if show_dut:
            self._plot_background(ax, alpha, y_lim)

        if show_reference and ref_data:
            if not show_dut:
                colors = jet_colors(len(ref_data))
                for i, ref in enumerate(ref_data):
                    x = np.arange(1, len(ref) + 1) - start_values[i]
                    ax.plot(x, ref, "-o", color=colors[i], markersize=line_width / 13,
                            linewidth=line_width, label=f"Referenz#{i + 1}")
            else:
                for i, ref in enumerate(ref_data):
                    x = np.arange(1, len(ref) + 1) - start_values[i + 1]
                    ax.plot(x, ref, ".-", markersize=line_width * 4 * 3.5,
                            linewidth=line_width * 4, color=refcolor)
                ax.plot([], [], ".-", markersize=line_width * 4 * 3, linewidth=line_width * 4,
                        color=refcolor, label="Referenz")

        if show_dut:
            x = np.arange(1, len(data) + 1) - start_values[0]
            ax.plot(x, data, "-", marker=".", markersize=line_width ** 2, color="b",
                    linewidth=line_width, label="DUT")

        ax.set_title(f"{t1}\n{t2}", fontsize=self.title_fontsize_var.get())
        ax.set_ylabel(clean_tex(first(config.get("ylabel"), "Voltage [V]")), fontweight="bold")
        ax.set_xlabel(clean_tex(first(config.get("xlabel"), "Time")), fontweight="bold")
        ax.grid(True, color=(0.5, 0.5, 0.5), alpha=0.7)

        x_max_rel = x_max - start_values[0]
        x_min_rel = x_min - start_values[0]
        if x_max_rel <= x_min_rel:
            x_min_rel = x_max_rel - 1
        ax.set_xlim(x_min_rel, x_max_rel)
        ax.set_ylim(y_lim)
        ax.set_xticks([])
        ax.tick_params(labelsize=config.get("yTickSize", 18))
        ax.legend(loc="upper right", fontsize=config.get("legendFontSize", 14))
        plt.show(block=False)

    def _plot_background(self, ax, alpha, y_lim):
        """Port of plotDUTBackground (without the drag interaction)."""
        config = self.config
        sections = [
            (config.get("H2N2Grenzen", [0, 595]), (190 / 255, 152 / 255, 9 / 255),
             "H2/N2 (Kurzschluss)", config.get("H2N2TextSize", 20)),
            (config.get("OCVGrenzen", [615, 880]), (61 / 255, 106 / 255, 60 / 255),
             "OCV", config.get("OCVTextSize", 20)),
            (config.get("FallOffGrenzen", [900, 2800]), (173 / 255, 185 / 255, 206 / 255),
             "FallOff", config.get("FallOffTextSize", 20)),
        ]
        for limits, color, label, size in sections:
            blended = tuple(c * alpha + 1 - alpha for c in color)
            ax.axvspan(limits[0], limits[1], color=blended, zorder=0)
            ax.text((limits[0] + limits[1]) / 2, y_lim[1], label, ha="center", va="top",
                    fontsize=size, color="k")
