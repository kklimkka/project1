"""Python port of Auswertungen/Load__Points.m - load point evaluation."""

import csv
import os
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import numpy as np
import matplotlib.pyplot as plt

import read_all
from method_base import MethodWindowBase, clean_tex, first


def find_trigger_indices(data, trigger, trigger_names):
    """Port of findIndices: for each trigger value that occurs in `data`,
    the 0-based indices where a trigger block ends (plus the last
    occurrence). Returns (index_arrays, names)."""
    data = np.asarray(data, dtype=float)
    found_triggers, found_names, index_arrays = [], [], []
    for value, name in zip(trigger, trigger_names):
        occurrences = np.where(data == value)[0]
        if len(occurrences) == 0:
            continue
        block_ends = occurrences[np.where(np.diff(occurrences) != 1)[0]]
        block_ends = np.append(block_ends, occurrences[-1])
        found_triggers.append(value)
        found_names.append(name)
        index_arrays.append(block_ends.astype(int))
    return index_arrays, found_names


def avg_values(data, index_array, window):
    """Port of avgValues: mean over `window + 1` samples ending at each index."""
    data = np.asarray(data, dtype=float)
    return np.array([np.nanmean(data[idx - window:idx + 1]) for idx in index_array])


def all_avg(data, index_arrays, window):
    """Port of allAvg: one averages matrix (rows = trigger block, cols =
    data columns) per trigger."""
    result = []
    for idx in index_arrays:
        result.append(np.column_stack([avg_values(data[:, c], idx, window) for c in range(data.shape[1])]))
    return result


def _hex2rgb(hexcolor):
    hexcolor = hexcolor.lstrip("#")
    return tuple(int(hexcolor[i:i + 2], 16) / 255 for i in (0, 2, 4))


class LoadPointsWindow(MethodWindowBase):
    METHOD_KEY = "Load__Points"
    WINDOW_TITLE = "Load Points"

    def _build_ui(self):
        root = self.root
        config = self.config
        root.columnconfigure(0, weight=1)
        root.columnconfigure(1, weight=1)
        root.rowconfigure(1, weight=1)

        top = tk.Frame(root)
        top.grid(row=0, column=0, columnspan=2, sticky="ew", padx=10, pady=5)
        top.columnconfigure(0, weight=1)
        tk.Button(top, text="Load Points config", command=self.edit_config).grid(row=0, column=1, sticky="e")

        # left: info + column table
        left = tk.Frame(root)
        left.grid(row=1, column=0, sticky="nsew", padx=10, pady=5)
        left.rowconfigure(1, weight=1)
        left.columnconfigure(0, weight=1)
        info_frame = tk.Frame(left)
        info_frame.grid(row=0, column=0, sticky="nsew")
        info_frame.rowconfigure(0, weight=1)
        info_frame.columnconfigure(0, weight=1)
        self._make_info_text(
            info_frame,
            'Die Auswertungsmethode "Load Points" wurde ausgewählt:\n'
            "> Daten werden direkt vor dem Ende der Triggerpunkte ausgewertet\n"
            ">> Mittelwert ab ...: Sekunden vor jedem Triggerwechsel für die Mittelung\n"
            ">> Messwerte pro Sekunde: Abtastrate der Datei\n"
            ">> Spaltentabelle: Zeilen auswählen, die geplottet werden sollen\n"
            ">> Export: erzeugt eine CSV-Datei mit den Mittelwerten",
        )
        self.info_text.configure(height=8)

        tk.Label(left, text="Spalten der CSV-Datei, die geplottet werden sollen:").grid(row=1, column=0, sticky="nw")
        self.column_table = ttk.Treeview(left, columns=("header", "col", "color", "limits"), show="headings",
                                         selectmode="extended", height=12)
        for cid, text, width in (("header", "Header", 240), ("col", "Spalten", 60),
                                 ("color", "Hex-Farbe", 80), ("limits", "Achsenlimits", 90)):
            self.column_table.heading(cid, text=text)
            self.column_table.column(cid, width=width)
        self.column_table.grid(row=2, column=0, sticky="nsew")
        left.rowconfigure(2, weight=2)
        headers = config.get("Header", [])
        spalten = config.get("Spalten", [])
        colors = config.get("Colors", [])
        limits = config.get("Limits", [])
        for i, header in enumerate(headers):
            self.column_table.insert("", "end", iid=str(i), values=(
                header, spalten[i] if i < len(spalten) else "",
                colors[i] if i < len(colors) else "#000000",
                limits[i] if i < len(limits) else "auto",
            ))

        # right: file list + result table
        right = tk.Frame(root)
        right.grid(row=1, column=1, sticky="nsew", padx=10, pady=5)
        right.rowconfigure(0, weight=1)
        right.rowconfigure(1, weight=2)
        right.columnconfigure(0, weight=1)
        files_frame = tk.Frame(right)
        files_frame.grid(row=0, column=0, sticky="nsew")
        self._make_file_list(files_frame)
        self.result_table = ttk.Treeview(right, columns=("lp", "p1", "p2"), show="headings", height=10)
        self.result_table.heading("lp", text="Load Point")
        self.result_table.heading("p1", text="Parameter 1")
        self.result_table.heading("p2", text="Parameter 2")
        self.result_table.grid(row=1, column=0, sticky="nsew", pady=(5, 0))

        params = tk.Frame(root)
        params.grid(row=2, column=0, columnspan=2, sticky="ew", padx=10, pady=5)
        params.columnconfigure(3, weight=1)
        self.decimal_i_var = tk.IntVar(value=config.get("NachkommastellenStrom", 1))
        self.decimal_u_var = tk.IntVar(value=config.get("NachkommastellenSpannung", 1))
        self.factor_var = tk.DoubleVar(value=config.get("MesswerteProSekunde", 2))
        self.time_var = tk.DoubleVar(value=config.get("MWAbSekundenVor", 60))
        self.title_var = tk.StringVar(value=first(config.get("Titel")))
        self.export_var = tk.BooleanVar(value=bool(config.get("checkExport", False)))

        tk.Label(params, text="Nachkommastellen des Stroms:").grid(row=0, column=0, sticky="w")
        tk.Entry(params, textvariable=self.decimal_i_var, width=6).grid(row=0, column=1)
        tk.Label(params, text="Titel:").grid(row=0, column=2, sticky="w", padx=(15, 0))
        tk.Entry(params, textvariable=self.title_var).grid(row=0, column=3, sticky="ew", padx=5)
        tk.Label(params, text="Nachkommastellen der Spannung:").grid(row=1, column=0, sticky="w")
        tk.Entry(params, textvariable=self.decimal_u_var, width=6).grid(row=1, column=1)
        tk.Label(params, text="Messwerte pro Sekunde:").grid(row=1, column=2, sticky="w", padx=(15, 0))
        tk.Entry(params, textvariable=self.factor_var, width=8).grid(row=1, column=3, sticky="w", padx=5)
        tk.Label(params, text="Mittelwert ab ... Sekunden vor Ende des Triggers:").grid(row=2, column=0, columnspan=2, sticky="w")
        tk.Entry(params, textvariable=self.time_var, width=8).grid(row=2, column=2, sticky="w", padx=(15, 0))
        tk.Checkbutton(params, text="Export (CSV)", variable=self.export_var).grid(row=2, column=3, sticky="w")

        self.title_fontsize_var = self._title_fontsize_var()
        self._add_title_fontsize_field(params, self.title_fontsize_var, row=3, column=2)

        bottom = tk.Frame(root)
        bottom.grid(row=3, column=0, columnspan=2, sticky="ew", padx=10, pady=10)
        bottom.columnconfigure((0, 1, 2), weight=1)
        tk.Button(bottom, text="Neue Datei laden", command=self.add_files).grid(row=0, column=0)
        tk.Button(bottom, text="Daten Plotten", command=self.plot).grid(row=0, column=1)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=0, column=2)

    # -- data ---------------------------------------------------------------
    def add_files(self):
        filenames = self._ask_filenames([("CSV files", "*.csv")])
        if not filenames:
            return
        config = self.config
        lines = read_all.process_inf(config.get("Zeilen", [1, "Inf"]))
        columns = config.get("Spalten")
        for path in filenames:
            data, _ = read_all.read_csv_numeric(path, lines, columns)
            if data.size == 0:
                messagebox.showwarning(
                    "Fehler beim Hinzufügen einer Datei",
                    "Wahrscheinlich wird mind. ein Parameter in einer Spalte gesucht, "
                    "die in der Datei leer ist.",
                )
                continue
            self._add_file_item(os.path.basename(path), data)

    def _window(self):
        return int(self.time_var.get() * self.factor_var.get() - 1)

    # -- plotting -------------------------------------------------------------
    def plot(self):
        config = self.config
        headers = config.get("Header", [])
        line_width = config.get("lineWidth", 1)
        names, data = self._selected_data()
        if data is None:
            return

        # trigger column: the header literally named 'Trigger'
        trigger_col = next((i for i, h in enumerate(headers) if h.lower() == "trigger"), len(headers) - 1)
        window = self._window()

        all_trigger_names, all_avg_arrays = [], []
        for current in data:
            index_arrays, trigger_names = find_trigger_indices(
                current[:, trigger_col], config.get("Trigger", []), config.get("TriggerNames", [])
            )
            avg_arrays = all_avg(current, index_arrays, window)
            all_trigger_names.append(trigger_names)
            all_avg_arrays.append(avg_arrays)
            if self.export_var.get():
                self._export_csv(headers, avg_arrays, names)
        if all_avg_arrays and all_avg_arrays[0]:
            self._edit_table(all_avg_arrays, all_trigger_names)

        selection = [int(i) for i in self.column_table.selection()]
        zeit_idx = int(config.get("ZeitIndex", 1)) - 1
        if not selection:
            selection = [int(config.get("SpannungsIndex", 2)) - 1, int(config.get("StromIndex", 4)) - 1]
        elif len(selection) == 1 and selection[0] == zeit_idx:
            selection = [zeit_idx, int(config.get("SpannungsIndex", 2)) - 1, int(config.get("StromIndex", 4)) - 1]
        if selection[0] != zeit_idx:
            selection = [zeit_idx] + selection

        colors = [_hex2rgb(c) for c in config.get("Colors", [])]
        limits = config.get("Limits", [])
        sel_headers = [headers[i] for i in selection]
        sel_colors = [colors[i] if i < len(colors) else (0, 0, 0) for i in selection]
        sel_limits = [limits[i] if i < len(limits) else "auto" for i in selection]

        times = [current[:, zeit_idx] for current in data]
        plot_data = [current[:, selection] for current in data]

        fig, ax = plt.subplots(figsize=(14, 8))
        n_cols = len(selection)
        n_files = len(plot_data)
        color_order = plt.rcParams["axes.prop_cycle"].by_key()["color"]

        def series_style(header):
            return "--" if "set" in header.lower() else "-"

        if n_cols == 2:
            for n, current in enumerate(plot_data):
                color = sel_colors[1] if n_files == 1 else color_order[n % len(color_order)]
                label = sel_headers[1] + (f" #{n + 1}" if n_files > 1 else "")
                ax.plot(times[n], current[:, 1], series_style(sel_headers[1]),
                        linewidth=line_width, color=color, label=label)
            ax.set_ylabel(sel_headers[1], fontsize=config.get("ylabelSize", 12))
            self._apply_y_limit(ax, sel_limits[1], np.concatenate([c[:, 1] for c in plot_data]))
        elif n_cols == 3:
            ax2 = ax.twinx()
            for i, axis in ((1, ax), (2, ax2)):
                for n, current in enumerate(plot_data):
                    color = sel_colors[i] if n_files == 1 else color_order[(n + (i - 1) * n_files) % len(color_order)]
                    label = sel_headers[i] + (f" #{n + 1}" if n_files > 1 else "")
                    axis.plot(times[n], current[:, i], series_style(sel_headers[i]),
                              linewidth=line_width, color=color, label=label)
                axis.set_ylabel(sel_headers[i], fontsize=config.get("ylabelSize", 12), color=sel_colors[i])
                self._apply_y_limit(axis, sel_limits[i], np.concatenate([c[:, i] for c in plot_data]))
            handles1, labels1 = ax.get_legend_handles_labels()
            handles2, labels2 = ax2.get_legend_handles_labels()
            ax.legend(handles1 + handles2, labels1 + labels2, fontsize=config.get("legendFontSize", 9))
        else:
            # normalised plot for arbitrary column counts
            for i in range(1, n_cols):
                for n, current in enumerate(plot_data):
                    values = current[:, i].astype(float)
                    limit = sel_limits[i]
                    if isinstance(limit, str) and limit not in ("auto", "") and "," in limit:
                        current_max = float(limit.split(",")[1])
                    else:
                        current_max = np.nanmax(values)
                        if current_max <= 0:
                            current_max = np.nanmin(values)
                    values = values / current_max
                    color = sel_colors[i] if n_files == 1 else color_order[(n + (i - 1) * n_files) % len(color_order)]
                    label = f"{sel_headers[i]}, Faktor {current_max:.5g}"
                    if n_files > 1:
                        label = f"{sel_headers[i]} #{n + 1}, Faktor {current_max:.5g}"
                    ax.plot(times[n], values, series_style(sel_headers[i]),
                            linewidth=line_width, color=color, label=label)
            ax.set_ylim(0, 1.005)

        # x limits
        x1, x2 = 0.0, 0.0
        limit = sel_limits[0]
        if isinstance(limit, str) and limit not in ("auto", "") and limit != "auto":
            parts = limit.split(",")
            if len(parts) == 1:
                x2 = float(parts[0])
            else:
                x1, x2 = float(parts[0]), float(parts[1])
        else:
            for t in times:
                x2 = max(x2, t[-1])
                x1 = min(x1, t[-1]) if t[-1] < x1 else x1
        ax.set_xlim(x1, x2)
        ax.set_xlabel(clean_tex(first(config.get("xlabel"), "Time [s]")))
        ax.tick_params(labelsize=config.get("xTickSize", 10))
        if n_cols != 3:
            ax.legend(fontsize=config.get("legendFontSize", 9))
        ax.set_title(clean_tex(self.title_var.get()), fontsize=self.title_fontsize_var.get())
        plt.show(block=False)

    @staticmethod
    def _apply_y_limit(axis, limit, values):
        if isinstance(limit, str) and limit not in ("auto", "") and "," in limit:
            lo, hi = (float(x) for x in limit.split(","))
            axis.set_ylim(lo, hi)
        else:
            upper = np.nanmax(values)
            lower = np.nanmin(values)
            if upper > 0:
                axis.set_ylim(0, upper)
            elif lower < 0:
                axis.set_ylim(lower, 0)

    def _edit_table(self, all_avg_arrays, all_trigger_names):
        config = self.config
        strom_idx = int(config.get("StromIndex", 4)) - 1
        spannung_idx = int(config.get("SpannungsIndex", 2)) - 1
        headers = config.get("Header", [])
        self.result_table.heading("p1", text=headers[strom_idx] if strom_idx < len(headers) else "I")
        self.result_table.heading("p2", text=headers[spannung_idx] if spannung_idx < len(headers) else "U")
        dec_i, dec_u = self.decimal_i_var.get(), self.decimal_u_var.get()

        for item in self.result_table.get_children():
            self.result_table.delete(item)
        for i, (avg_arrays, trigger_names) in enumerate(zip(all_avg_arrays, all_trigger_names)):
            self.result_table.insert("", "end", values=(f"Datei #{i + 1}", "", ""))
            for name, avg in zip(trigger_names, avg_arrays):
                for m in range(avg.shape[0]):
                    self.result_table.insert("", "end", values=(
                        f"{name} ({m + 1})",
                        f"{avg[m, strom_idx]:.{dec_i}f}",
                        f"{avg[m, spannung_idx]:.{dec_u}f}",
                    ))

    def _export_csv(self, headers, avg_arrays, names):
        """CSV replacement for the Excel COM export."""
        if not avg_arrays:
            return
        combined = np.vstack(avg_arrays)
        combined = combined[np.argsort(combined[:, 0])]
        path = filedialog.asksaveasfilename(
            title="Wählen Sie einen Speicherort und Dateinamen",
            initialfile="Load Points-Export.csv",
            defaultextension=".csv", filetypes=[("CSV", "*.csv")],
        )
        if not path:
            return
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(headers[:combined.shape[1]])
            writer.writerows(combined.tolist())
        self._append_info_text(f"Export gespeichert: {path}")
