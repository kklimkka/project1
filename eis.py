"""Python port of Auswertungen/EIS.m - impedance spectroscopy evaluation.

File data columns (like the MATLAB tool):
1 number, 2 frequency [Hz], 3 impedance [Ω], 4 phase [°],
5 real [Ω*cm²], 6 imaginary [Ω*cm²],
7-10 (only MW&σ files): σ-impedance, σ-phase, σ-real, σ-imaginary.
"""

import os
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog

import numpy as np
import matplotlib.pyplot as plt

import read_all
from method_base import MethodWindowBase, clean_tex, first, jet_colors, REF_GREY


def add_real_imaginary(data, area):
    """Append the area-normalised real/imaginary parts (columns 5 and 6)."""
    impedance = data[:, 2]
    phase_deg = data[:, 3]
    real = impedance * np.cos(np.radians(phase_deg)) * area
    imaginary = impedance * np.sin(np.radians(phase_deg)) * area
    return np.column_stack([data, real, imaginary])


def average_and_sigma(datasets):
    """Port of addAverageAndSigmaFile: mean of all datasets plus the standard
    deviation of columns 3-6. Requires equally sized datasets."""
    stack = np.stack(datasets)
    avg = stack.mean(axis=0)
    std = np.std(stack[:, :, 2:6], axis=0, ddof=0)
    return np.hstack([avg[:, :6], std])


def common_name(names, shorten):
    """Port of getCommonName."""
    min_len = min(len(n) for n in names)
    trimmed = [n[:min_len] for n in names]
    diff_ids = [i for i in range(min_len) if len({n[i] for n in trimmed}) > 1]
    if shorten:
        if not diff_ids:
            return trimmed[0]
        cut = diff_ids[0] if len(names) == 1 else diff_ids[0]
        return trimmed[0][:cut]
    name = list(trimmed[0])
    for i in diff_ids:
        name[i] = "X"
    return "".join(name)


def extract_and_truncate_name(filename, shorten):
    """Port of extractAndTruncateName."""
    name = filename
    if shorten:
        idx = name.find("EIS")
        if idx >= 0:
            name = name[idx:]
    base, ext = os.path.splitext(name)
    if ext.lower() in (".txt", ".csv"):
        name = base
    if shorten and len(name) >= 4 and "_" in name:
        prefix, _, suffix = name.rpartition("_")
        if len(suffix) >= 4 and suffix.isdigit():
            name = prefix
    return name


class EISWindow(MethodWindowBase):
    METHOD_KEY = "EIS"
    WINDOW_TITLE = "EIS"

    def _build_ui(self):
        root = self.root
        config = self.config
        root.columnconfigure(0, weight=1)
        root.columnconfigure(1, weight=1)
        root.rowconfigure(1, weight=1)

        top = tk.Frame(root)
        top.grid(row=0, column=0, columnspan=2, sticky="ew", padx=10, pady=5)
        top.columnconfigure(3, weight=1)
        tk.Button(top, text="Exportieren", command=self.txt_export).grid(row=0, column=0, padx=2)
        tk.Button(top, text="EIS config", command=self.edit_config).grid(row=0, column=1, padx=2)
        tk.Label(top, text="Titel:").grid(row=0, column=2, padx=(10, 0))
        self.title_var = tk.StringVar(value=first(config.get("Titel")))
        tk.Entry(top, textvariable=self.title_var).grid(row=0, column=3, sticky="ew", padx=5)
        tk.Label(top, text="Aktive Fläche:").grid(row=0, column=4)
        self.area_var = tk.DoubleVar(value=config.get("Flaeche", 273))
        area_entry = tk.Entry(top, textvariable=self.area_var, width=8)
        area_entry.grid(row=0, column=5)
        area_entry.bind("<FocusOut>", lambda *_: self._area_warning())

        self.title_fontsize_var = self._title_fontsize_var()
        self._add_title_fontsize_field(top, self.title_fontsize_var, row=1, column=2)

        left = tk.Frame(root)
        left.grid(row=1, column=0, sticky="nsew", padx=10, pady=5)
        self._make_file_list(left)
        btns = tk.Frame(left)
        btns.grid(row=2, column=0, sticky="ew", pady=5)
        btns.columnconfigure((0, 1, 2, 3), weight=1)
        tk.Button(btns, text="Neue Dateien", command=self.add_files).grid(row=0, column=0, sticky="ew")
        tk.Button(btns, text="Alle wählen", command=lambda: self.file_listbox.selection_set(0, "end")).grid(row=0, column=1, sticky="ew")
        tk.Button(btns, text="Alle abwählen", command=lambda: self.file_listbox.selection_clear(0, "end")).grid(row=0, column=2, sticky="ew")
        tk.Button(btns, text="Löschen", command=self.clear_selected).grid(row=0, column=3, sticky="ew")

        right = tk.Frame(root)
        right.grid(row=1, column=1, sticky="nsew", padx=10, pady=5)
        right.columnconfigure((0, 1), weight=1)
        right.rowconfigure(5, weight=1)
        tk.Button(right, text="Mittelwert & σ berechnen", command=self.add_average_and_sigma).grid(row=0, column=0, sticky="ew", pady=2)
        tk.Button(right, text="MW&σ Dateien wählen", command=self.select_mw_sigma).grid(row=0, column=1, sticky="ew", pady=2)
        tk.Button(right, text="Datei umbenennen", command=self.rename_file).grid(row=1, column=0, columnspan=2, sticky="ew", pady=2)
        tk.Button(right, text="Als Referenz markieren", command=self.add_reference_mark).grid(row=2, column=0, sticky="ew", pady=2)
        tk.Button(right, text="Referenzmarkierung auflösen", command=self.remove_reference_mark).grid(row=2, column=1, sticky="ew", pady=2)

        options = tk.Frame(right)
        options.grid(row=3, column=0, columnspan=2, sticky="ew", pady=2)
        tk.Label(options, text="Spalten in der Plotlegende:").grid(row=0, column=0, sticky="w")
        self.num_columns_var = tk.IntVar(value=config.get("SplatenInPlotlegende", 5))
        tk.Entry(options, textvariable=self.num_columns_var, width=5).grid(row=0, column=1)
        self.show_sigma_var = tk.BooleanVar(value=bool(config.get("sigmaAnzeigen", True)))
        tk.Checkbutton(options, text="σ anzeigen", variable=self.show_sigma_var).grid(row=0, column=2, padx=8)
        self.shorten_names_var = tk.BooleanVar(value=True)
        tk.Checkbutton(options, text="Dateinamen kürzen", variable=self.shorten_names_var).grid(row=0, column=3)

        info_frame = tk.Frame(right)
        info_frame.grid(row=5, column=0, columnspan=2, sticky="nsew", pady=5)
        info_frame.rowconfigure(0, weight=1)
        info_frame.columnconfigure(0, weight=1)
        self._make_info_text(
            info_frame,
            'Die Auswertungsmethode "EIS" wurde ausgewählt:\n'
            ">> Aktive Fläche: Berechnung der flächenbezogenen Impedanz\n"
            ">> σ anzeigen: Standardabweichung als Fehlerkreuz\n"
            ">> Mittelwert & σ berechnen: MW-Datei aus gewählten Dateien\n"
            ">> Als Referenz markieren: Datei wird grau und dicker geplottet\n"
            ">> Exportieren: gewählte Dateien als .txt exportieren\n\n"
            'Erst "Neue Dateien" dann "Plot ..."',
        )

        bottom = tk.Frame(root)
        bottom.grid(row=2, column=0, columnspan=2, sticky="ew", padx=10, pady=10)
        bottom.columnconfigure((0, 1, 2), weight=1)
        tk.Button(bottom, text="Plot -Nyquist", command=self.nyquist_plot).grid(row=0, column=0)
        tk.Button(bottom, text="Plot Bode", command=self.bode_plot).grid(row=0, column=1)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=0, column=2)

    # -- file management ------------------------------------------------------
    def _area_warning(self):
        if self.file_items:
            messagebox.showwarning(
                "Warnung",
                "Bitte alle Dateien löschen und neu laden, da die Fläche nur beim "
                "Laden der Daten ausgewertet wird",
            )

    def _unique_name(self, name):
        while name in self.file_items:
            base, sep, counter = name.rpartition("(")
            if sep and counter.endswith(")") and counter[:-1].isdigit():
                name = f"{base}({int(counter[:-1]) + 1})"
            else:
                name = f"{name}(1)"
        return name

    def add_files(self):
        filenames = self._ask_filenames(
            [("Text and CSV Files", "*.txt *.csv"), ("Text files", "*.txt"), ("CSV files", "*.csv")]
        )
        if not filenames:
            return
        area = self.area_var.get()
        shorten = self.shorten_names_var.get()
        for path in filenames:
            if path.lower().endswith(".csv"):
                marker = self.full_config.get("read_eis_csv", {}).get(
                    "HeaderDerNurInZeileVorMessdatenIst", "Frequency")
                data = read_all.read_eis_csv(path, marker)
            else:
                data = read_all.read_eis_txt(path, self._header_marker())
            if data is None:
                messagebox.showwarning("Warnung", f"Keine Daten in Datei gefunden: {os.path.basename(path)}")
                continue
            data = add_real_imaginary(data, area)
            name = self._unique_name(extract_and_truncate_name(os.path.basename(path), shorten))
            self._add_file_item(name, data)

    def clear_selected(self):
        selection = list(self.file_listbox.curselection())
        for idx in reversed(selection):
            name = self.file_listbox.get(idx)
            self.file_listbox.delete(idx)
            self.file_items.pop(name, None)

    def rename_file(self):
        selection = self.file_listbox.curselection()
        if len(selection) != 1:
            messagebox.showwarning("Datei umbenennen", "Bitte genau eine Datei auswählen.")
            return
        idx = selection[0]
        old_name = self.file_listbox.get(idx)
        new_name = simpledialog.askstring("Datei umbenennen", "Geben Sie den neuen Namen für die Datei ein:",
                                          initialvalue=old_name, parent=self.root)
        if not new_name or new_name == old_name:
            return
        self._rename(idx, old_name, new_name)

    def _rename(self, idx, old_name, new_name):
        data = self.file_items.pop(old_name)
        items = list(self.file_items.items())
        self.file_items = {}
        self.file_listbox.delete(idx)
        self.file_listbox.insert(idx, new_name)
        # rebuild dict preserving order
        names = [self.file_listbox.get(i) for i in range(self.file_listbox.size())]
        lookup = dict(items)
        lookup[new_name] = data
        for name in names:
            self.file_items[name] = lookup[name]

    def add_reference_mark(self):
        for idx in list(self.file_listbox.curselection()):
            name = self.file_listbox.get(idx)
            if not name.startswith("Ref: "):
                self._rename(idx, name, "Ref: " + name)

    def remove_reference_mark(self):
        for idx in list(self.file_listbox.curselection()):
            name = self.file_listbox.get(idx)
            if name.startswith("Ref: "):
                self._rename(idx, name, name[5:])

    def select_mw_sigma(self):
        self.file_listbox.selection_clear(0, "end")
        for i in range(self.file_listbox.size()):
            if "MW&σ" in self.file_listbox.get(i):
                self.file_listbox.selection_set(i)

    def add_average_and_sigma(self):
        names, data = self._selected_data()
        if data is None:
            return
        shapes = {d.shape for d in data}
        if len(shapes) != 1:
            messagebox.showwarning(
                "Achtung",
                "Die Messdateien haben unterschiedlich viele Messwerte, daher ist die "
                "Berechnung nicht sinnvoll",
            )
            return
        avg = average_and_sigma([d[:, :6] for d in data])
        base = common_name(names, self.shorten_names_var.get()).rstrip("_")
        new_name = self._unique_name(f"{base}_MW&σ")
        self._add_file_item(new_name, avg)

    # -- plots -----------------------------------------------------------------
    def nyquist_plot(self):
        config = self.config
        names, data = self._selected_data()
        if data is None:
            return
        show_sigma = self.show_sigma_var.get()
        line_width = config.get("lineWidth", 1)

        fig, ax = plt.subplots(figsize=(14, 8))
        colors = jet_colors(len(data))
        max_real = []
        has_ref = False
        for i, (name, d) in enumerate(zip(names, data)):
            real, imag = d[:, 4], d[:, 5]
            max_real.append(np.max(real))
            if name.startswith("Ref: "):
                ax.plot(real, imag, "-", linewidth=line_width * 8, color=REF_GREY)
                ax.plot(real, imag, "o", markersize=line_width * 10, markerfacecolor=REF_GREY, color=REF_GREY)
                has_ref = True
            elif d.shape[1] >= 10 and show_sigma:
                ax.errorbar(real, imag, yerr=d[:, 9], xerr=d[:, 8], fmt="none", ecolor="k")
                ax.plot(real, imag, ".-", linewidth=line_width * 2, color=colors[i], label=name)
            else:
                ax.plot(real, imag, "-", linewidth=line_width * 2, color=colors[i], label=name)
                ax.plot(real, imag, "o", markersize=line_width * 3, markerfacecolor="w", color=colors[i])
        if has_ref:
            ax.plot([], [], "-o", linewidth=line_width * 8, markersize=line_width * 8,
                    markerfacecolor=REF_GREY, color=REF_GREY, label="Referenz")

        ax.grid(True, color=(0.5, 0.5, 0.5), alpha=0.7)
        ax.invert_yaxis()
        ax.set_xlim(0, max(max_real) + 0.025)
        ax.tick_params(labelsize=config.get("xTickSize", 10))
        ax.set_title(
            f"{clean_tex(self.title_var.get())}\n{clean_tex(first(config.get('nyquistXlabel')))}",
            fontsize=self.title_fontsize_var.get(),
        )
        ax.set_ylabel(clean_tex(first(config.get("nyquistYlabel"), "IMAGINARY PART [Ohm*cm²]")))
        ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.08),
                  ncol=max(self.num_columns_var.get(), 1), fontsize=config.get("legendFontSize", 9))
        fig.tight_layout()
        plt.show(block=False)

    def bode_plot(self):
        config = self.config
        names, data = self._selected_data()
        if data is None:
            return
        show_sigma = self.show_sigma_var.get()
        line_width = config.get("lineWidth", 1)

        fig, ax_imp = plt.subplots(figsize=(14, 8))
        ax_phase = ax_imp.twinx()
        colors = jet_colors(len(data))
        has_ref = False
        for i, (name, d) in enumerate(zip(names, data)):
            freq, imp, phase = d[:, 1], d[:, 2], d[:, 3]
            label = name.replace("_", " ")
            if name.startswith("Ref: "):
                ax_imp.plot(freq, imp, "o-", linewidth=line_width * 4.5, color=REF_GREY, markersize=8)
                ax_phase.plot(freq, np.abs(phase), "o--", linewidth=line_width * 4.5, color=REF_GREY, markersize=8)
                has_ref = True
            elif d.shape[1] >= 10 and show_sigma:
                ax_imp.errorbar(freq, imp, yerr=d[:, 6], fmt="o-", linewidth=line_width,
                                color=colors[i], markersize=5, label=f"{label} Impedance")
                ax_phase.errorbar(freq, np.abs(phase), yerr=d[:, 7], fmt="o--", linewidth=line_width,
                                  color=colors[i], markersize=5, label=f"{label} Phase")
            else:
                ax_imp.plot(freq, imp, "o-", linewidth=line_width * 1.5, color=colors[i],
                            markersize=4, label=f"{label} Impedance")
                ax_phase.plot(freq, np.abs(phase), "o--", linewidth=line_width * 1.5, color=colors[i],
                              markersize=4, label=f"{label} Phase")
        if has_ref:
            ax_imp.plot([], [], "o-", linewidth=line_width * 4.5, color=REF_GREY,
                        markersize=8, label="Referenz")

        ax_imp.set_xscale("log")
        ax_imp.set_yscale("log")
        ax_imp.set_xlabel(clean_tex(first(config.get("bodeXlabel"), "Frequency [Hz]")))
        ax_imp.set_ylabel(clean_tex(first(config.get("bodeYlabelLeft"), "Impedance [Ohms]")))
        ax_phase.set_ylabel(clean_tex(first(config.get("bodeYlabelRight"), "Phase (Degrees)")))
        ax_phase.set_ylim(0, 90)
        ax_imp.grid(True, which="both", color=(0.5, 0.5, 0.5), alpha=0.7)
        ax_imp.tick_params(labelsize=config.get("xTickSize", 10))
        ax_phase.tick_params(labelsize=config.get("yTickSize", 10))
        ax_imp.set_title(clean_tex(self.title_var.get()), fontsize=self.title_fontsize_var.get())
        handles1, labels1 = ax_imp.get_legend_handles_labels()
        handles2, labels2 = ax_phase.get_legend_handles_labels()
        ax_imp.legend(handles1 + handles2, labels1 + labels2, loc="upper center",
                      bbox_to_anchor=(0.5, -0.08), ncol=max(self.num_columns_var.get(), 1),
                      fontsize=config.get("legendFontSize", 9))
        fig.tight_layout()
        plt.show(block=False)

    # -- export -------------------------------------------------------------
    def txt_export(self):
        names, data = self._selected_data()
        if data is None:
            return
        folder = filedialog.askdirectory(title="Wählen Sie den Exportordner aus")
        if not folder:
            return
        titles = ["Number", "Frequency[Hz]", "Impedance[Ω]", "Phase[°]",
                  "Real[Ω*cm²]", "Imaginary[Ω*cm²]", "σ-Impedance[Ω]",
                  "σ-Phase[°]", "σ-Real[Ω*cm²]", "σ-Imaginary[Ω*cm²]"]
        for name, d in zip(names, data):
            path = os.path.join(folder, f"{name}.txt")
            cols = d.shape[1]
            with open(path, "w", encoding="utf-8") as f:
                f.write("\t".join(titles[:cols]) + "\n")
                for row in d:
                    f.write(f"{row[0]:g}\t" + "\t".join(f"{v:e}" for v in row[1:]) + "\n")
        self._append_info_text(f"Export abgeschlossen: {folder}")
