"""Python port of Auswertungen/PK.m - polarisation curve evaluation."""

import csv
import os
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk

import numpy as np
import matplotlib.pyplot as plt

import read_all
from method_base import MethodWindowBase, clean_tex, first, jet_colors, comma


def find_indices(data):
    """Port of findIndices: 0-based indices of current drops after the
    current maximum, plus the last index."""
    data = np.asarray(data, dtype=float)
    max_idx = int(np.argmax(data))
    tail = data[max_idx:]
    drops = np.where(np.diff(tail) < 0)[0] + max_idx  # last index before the drop
    return np.append(drops, len(data) - 1).astype(int)


def average_values(data, index_array, window):
    """Port of averageValues: mean over the `window + 1` samples up to and
    including each index."""
    data = np.asarray(data, dtype=float)
    result = np.full(len(index_array), np.nan)
    for i, idx in enumerate(index_array):
        start = idx - window
        if start < 0:
            raise ValueError("Richtige PK-Nummer auswählen oder Coolant-Temperatur in config anpassen.")
        result[i] = np.nanmean(data[start:idx + 1])
    return result


def calc_pk_table(data, config, window):
    """Port of calcPKTable for one file: split the data by coolant
    temperature into the PK1..PK3 sections and average at each load point.

    Returns {'Data': array, 'PK1': {...}|None, 'PK2': ..., 'PK3': ...} where
    each PK entry has 'avgCurrents' and 'avgVoltages'.
    """
    temps = [config.get("tempPK1", 60), config.get("tempPK2", 80), config.get("tempPK3", 90)]
    temp_idx = int(config.get("TempIndex", 30)) - 1
    result = {"Data": data}
    for k, temp in enumerate(temps, start=1):
        rows = np.where(data[:, temp_idx] == temp)[0]
        if len(rows) < window:
            result[f"PK{k}"] = None
            continue
        section = data[rows[0]:rows[-1] + 1, :]
        idx = find_indices(section[:, int(config.get("StromSetIndex", 5)) - 1])
        try:
            avg_currents = average_values(section[:, int(config.get("StromdichteIndex", 6)) - 1], idx, window)
            avg_voltages = average_values(section[:, int(config.get("SpannungsIndex", 2)) - 1], idx, window)
        except ValueError:
            result[f"PK{k}"] = None
            continue
        result[f"PK{k}"] = {"avgCurrents": avg_currents, "avgVoltages": avg_voltages}
    return result


def calc_losses(ref_values, all_avg_voltages, all_avg_currents):
    """Port of calcLosses: voltage loss [%] versus the mean reference curve,
    matched by (rounded) current density."""
    ref_voltages = np.column_stack([r["avgVoltages"] for r in ref_values])
    ref_currents = np.column_stack([r["avgCurrents"] for r in ref_values])
    no_loss_voltages = ref_voltages.mean(axis=1)
    no_loss_currents = np.round(ref_currents.mean(axis=1), 2)

    losses = np.zeros((len(no_loss_currents), len(all_avg_voltages)))
    for i, (voltages, currents) in enumerate(zip(all_avg_voltages, all_avg_currents)):
        rounded = np.round(currents, 2)
        for k in range(len(voltages)):
            match = np.where(no_loss_currents == rounded[k])[0]
            if len(match):
                h = match[0]
                losses[h, i] = (no_loss_voltages[h] - voltages[k]) / no_loss_voltages[h] * 100
    return losses, no_loss_currents


class PKWindow(MethodWindowBase):
    METHOD_KEY = "PK"
    WINDOW_TITLE = "PK"

    def _build_ui(self):
        root = self.root
        config = self.config
        for i in range(4):
            root.columnconfigure(i, weight=1)
        root.rowconfigure(0, weight=1)

        left = tk.Frame(root)
        left.grid(row=0, column=0, columnspan=2, sticky="nsew", padx=10, pady=5)
        left.rowconfigure(0, weight=2)
        left.rowconfigure(1, weight=1)
        left.columnconfigure(0, weight=1)
        info_frame = tk.Frame(left)
        info_frame.grid(row=0, column=0, sticky="nsew")
        info_frame.rowconfigure(0, weight=1)
        info_frame.columnconfigure(0, weight=1)
        self._make_info_text(
            info_frame,
            'Die Auswertungsmethode "PK" wurde ausgewählt:\n'
            '>> Dropdown "PK ...": Titel & Referenzen der jeweiligen Polarisationskurve\n'
            ">> Tabelle (rechts): Strom- und Spannungsdurchschnitte an den Messpunkten\n"
            ">> Mittelwert ab ...: Sekunden vor jedem Stromabfall für die Mittelung\n"
            ">> Messwerte pro Sekunde: Abtastrate der Datei\n"
            ">> Export: erzeugt eine CSV-Datei mit allen Mittelwerten",
        )
        files_frame = tk.Frame(left)
        files_frame.grid(row=1, column=0, sticky="nsew", pady=(5, 0))
        self._make_file_list(files_frame)

        right = tk.Frame(root)
        right.grid(row=0, column=2, columnspan=2, sticky="nsew", padx=10, pady=5)
        right.rowconfigure(0, weight=1)
        right.columnconfigure(0, weight=1)
        self.table = ttk.Treeview(right, columns=("i", "U", "loss"), show="headings")
        self.table.heading("i", text="i [A/cm²]")
        self.table.heading("U", text="U [V]")
        self.table.heading("loss", text="Verlust [%]")
        self.table.grid(row=0, column=0, sticky="nsew")

        params = tk.Frame(root)
        params.grid(row=1, column=0, columnspan=4, sticky="ew", padx=10, pady=5)
        params.columnconfigure(1, weight=1)

        tk.Label(params, text="Titel Zeile 1:").grid(row=0, column=0, sticky="w")
        self.title1_var = tk.StringVar()
        tk.Entry(params, textvariable=self.title1_var).grid(row=0, column=1, columnspan=4, sticky="ew", padx=5)
        tk.Label(params, text="Titel Zeile 2:").grid(row=1, column=0, sticky="w")
        self.title2_var = tk.StringVar()
        tk.Entry(params, textvariable=self.title2_var).grid(row=1, column=1, columnspan=4, sticky="ew", padx=5)

        self.pk_var = tk.StringVar(value="PK 1")
        tk.OptionMenu(params, self.pk_var, "PK 1", "PK 2", "PK 3",
                      command=lambda *_: self._update_title_and_ref()).grid(row=0, column=5, padx=5)
        tk.Button(params, text="PK config", command=self.edit_config).grid(row=1, column=5, padx=5)

        self.title_fontsize_var = self._title_fontsize_var()
        self._add_title_fontsize_field(params, self.title_fontsize_var, row=0, column=6)

        self.time_var = tk.DoubleVar(value=config.get("MWAbSekundenVor", 30))
        self.factor_var = tk.DoubleVar(value=config.get("MesswerteProSekunde", 2))
        tk.Label(params, text="Mittelwert ab ... Sekunden vor jedem Stromabfall:").grid(row=2, column=0, columnspan=2, sticky="w")
        tk.Entry(params, textvariable=self.time_var, width=8).grid(row=2, column=2, sticky="w")
        tk.Label(params, text="Messwerte pro Sekunde:").grid(row=3, column=0, sticky="w")
        tk.Entry(params, textvariable=self.factor_var, width=8).grid(row=3, column=2, sticky="w")

        self.show_reference_var = tk.BooleanVar(value=bool(config.get("checkRef", True)))
        self.show_dut_var = tk.BooleanVar(value=bool(config.get("checkDUT", True)))
        self.show_txt_var = tk.BooleanVar(value=bool(config.get("checkWerteInPlot", False)))
        self.export_var = tk.BooleanVar(value=bool(config.get("checkExport", False)))
        tk.Checkbutton(params, text="Referenzdaten anzeigen", variable=self.show_reference_var).grid(row=2, column=3, sticky="w")
        tk.Checkbutton(params, text="DUT anzeigen", variable=self.show_dut_var).grid(row=2, column=4, sticky="w")
        tk.Checkbutton(params, text="Werte in Plot anzeigen", variable=self.show_txt_var).grid(row=3, column=3, sticky="w")
        tk.Checkbutton(params, text="Export (CSV)", variable=self.export_var).grid(row=3, column=4, sticky="w")

        bottom = tk.Frame(root)
        bottom.grid(row=2, column=0, columnspan=4, sticky="ew", padx=10, pady=10)
        bottom.columnconfigure((0, 1, 2, 3), weight=1)
        tk.Button(bottom, text="Neue Datei laden", command=self.add_files).grid(row=0, column=0)
        tk.Button(bottom, text="Eigene PK erstellen", command=self.add_new_pk_data).grid(row=0, column=1)
        tk.Button(bottom, text="Plotten", command=self.plot).grid(row=0, column=2)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=0, column=3)

        self._update_title_and_ref()

    # -- helpers ---------------------------------------------------------------
    def _pk_number(self):
        return int(self.pk_var.get().split()[-1])

    def _window(self):
        return int(self.time_var.get() * self.factor_var.get() - 1)

    def _update_title_and_ref(self):
        config = self.config
        n = self._pk_number()
        self.title1_var.set(f"{first(config.get('Titel1'))}{n}")
        self.title2_var.set(first(config.get(f"Titel2_PK{n}")))
        self._load_references()

    def _load_references(self):
        """Reference CSVs live in PK/PK<n>/Referenz#*.csv with three columns:
        voltage, current set, current density."""
        if not hasattr(self, "pk_var"):
            return
        self.reference_data = []
        self.reference_names = []
        for path in self._reference_files(subfolder=f"PK{self._pk_number()}"):
            data, _ = read_all.read_csv_numeric(path)
            if data.size:
                self.reference_data.append(data)
                self.reference_names.append(os.path.basename(path))

    def _ref_values(self):
        window = self._window()
        values = []
        for ref in self.reference_data:
            idx = find_indices(ref[:, 1])
            values.append({
                "avgCurrents": average_values(ref[:, 2], idx, window),
                "avgVoltages": average_values(ref[:, 0], idx, window),
            })
        return values

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
                messagebox.showwarning("Warnung", f"Keine Daten in Datei gefunden: {os.path.basename(path)}")
                continue
            try:
                entry = calc_pk_table(data, config, self._window())
            except ValueError as exc:
                messagebox.showerror("Fehler beim Lesen der Daten", str(exc))
                continue
            self._add_file_item(os.path.basename(path), entry)

    def add_new_pk_data(self):
        """Port of addNewPKData, simplified: manual i/U pairs via a dialog."""
        name = simpledialog.askstring("neue PK erstellen", "Geben Sie den Namen für die neue PK ein:",
                                      initialvalue="PK", parent=self.root)
        if not name:
            return
        raw = simpledialog.askstring(
            "neue PK erstellen",
            "Wertepaare 'i;U' (eine Zeile pro Punkt, mit | getrennt), z.B. 0.2;0.85|0.5;0.78",
            parent=self.root,
        )
        if not raw:
            return
        try:
            pairs = [tuple(float(x.replace(",", ".")) for x in pair.split(";")) for pair in raw.split("|")]
        except ValueError:
            messagebox.showerror("Fehler", "Ungültiges Format.")
            return
        pk = {"avgCurrents": np.array([p[0] for p in pairs]),
              "avgVoltages": np.array([p[1] for p in pairs])}
        self._add_file_item(name, {"Data": None, "PK1": pk, "PK2": pk, "PK3": pk})

    # -- plotting -------------------------------------------------------------
    def plot(self):
        config = self.config
        show_reference = self.show_reference_var.get()
        show_dut = self.show_dut_var.get()
        show_txt = self.show_txt_var.get()
        export = self.export_var.get()
        if not (show_reference or show_dut or export):
            return
        line_width = config.get("lineWidth", 3)
        pk_key = f"PK{self._pk_number()}"

        names, data = ([], [])
        if show_dut or export:
            names, data = self._selected_data()
            if data is None:
                return

        all_currents, all_voltages = [], []
        if show_dut:
            for name, entry in zip(names, data):
                pk = entry.get(pk_key)
                if not pk:
                    messagebox.showerror("Fehler", "Richtige PK-Nummer auswählen oder Coolant-Temperatur in config anpassen.")
                    return
                all_currents.append(pk["avgCurrents"])
                all_voltages.append(pk["avgVoltages"])

        if show_reference or show_dut:
            fig, ax = plt.subplots(figsize=(14, 8))
            self._configure_axes(ax)

            ref_values = self._ref_values() if self.reference_data else []
            if show_reference and ref_values:
                if not show_dut:
                    for i, ref in enumerate(ref_values):
                        line, = ax.plot(ref["avgCurrents"], ref["avgVoltages"], "--o",
                                        linewidth=line_width, label=f"Referenz#{i + 1}")
                        if show_txt:
                            self._add_labels(ax, ref["avgCurrents"], ref["avgVoltages"], line.get_color())
                    self._edit_table([r["avgCurrents"] for r in ref_values],
                                     [r["avgVoltages"] for r in ref_values],
                                     self.reference_names, None, None)
                else:
                    for ref in ref_values:
                        for lw in np.linspace(1, line_width * 15, 6):
                            ax.plot(ref["avgCurrents"], ref["avgVoltages"], linewidth=lw,
                                    color=(0.5, 0.5, 0.5, 0.08 / max(len(ref_values), 1)),
                                    solid_joinstyle="round")
                    ax.plot([], [], linewidth=line_width * 5, color=(0.75, 0.75, 0.75), label="Referenz")

            if show_dut:
                colors = jet_colors(len(all_currents)) if len(all_currents) > 1 else ["b"]
                for i, (x, y) in enumerate(zip(all_currents, all_voltages)):
                    label = "DUT" if len(all_currents) == 1 else names[i]
                    line, = ax.plot(x, y, "--o", linewidth=line_width, color=colors[i], label=label)
                    if show_txt:
                        self._add_labels(ax, x, y, line.get_color())
                if ref_values:
                    losses, no_loss_currents = calc_losses(ref_values, all_voltages, all_currents)
                else:
                    losses, no_loss_currents = None, None
                self._edit_table(all_currents, all_voltages, names, losses, no_loss_currents)

            ax.legend(fontsize=config.get("legendFontSize", 14))
            plt.show(block=False)

        if export:
            self._export_csv(names, data)

    def _add_labels(self, ax, x, y, color):
        config = self.config
        for xi, yi in zip(x, y):
            ax.text(xi + 0.01, yi + 0.01, comma(yi, 3), ha="center", va="bottom",
                    color=color, fontsize=config.get("LabelFontSize", 11))

    def _configure_axes(self, ax):
        config = self.config
        x_lim = config.get("xAchsenLimits", [0, 2.6])
        y_lim = config.get("yAchsenLimits", [0.3, 1])
        # gradient background (port of gradient())
        gradient = np.linspace(220 / 255, 1.0, 256).reshape(-1, 1)
        rgba = np.dstack([gradient, gradient, gradient])
        ax.imshow(rgba, extent=(x_lim[0] - 0.2, x_lim[1] + 0.2, y_lim[0] - 0.1, y_lim[1] + 0.1),
                  origin="lower", aspect="auto", zorder=0)
        ax.set_xlim(x_lim)
        ax.set_ylim(y_lim)
        ax.grid(True, color=(170 / 255, 170 / 255, 170 / 255), alpha=0.7)
        ax.set_xticks(np.arange(0, x_lim[1] + 0.2, 0.2))
        ax.set_yticks(np.arange(round(y_lim[0], 1), y_lim[1] + 0.05, 0.1))
        ax.set_title(
            f"{clean_tex(self.title1_var.get())}\n{clean_tex(self.title2_var.get())}",
            fontsize=self.title_fontsize_var.get(),
        )
        ax.set_xlabel(clean_tex(first(config.get("xlabel"), "Current density [A/cm²]")), fontweight="bold")
        ax.set_ylabel(clean_tex(first(config.get("ylabel"), "Cell Voltage [V]")), fontweight="bold")
        ax.tick_params(labelsize=config.get("xTickSize", 18))

    def _edit_table(self, all_currents, all_voltages, names, losses, no_loss_currents):
        for item in self.table.get_children():
            self.table.delete(item)
        for i, (currents, voltages) in enumerate(zip(all_currents, all_voltages)):
            self.table.insert("", "end", values=(names[i] if i < len(names) else f"#{i + 1}", "", ""))
            for k in range(len(currents)):
                loss = ""
                if losses is not None and no_loss_currents is not None:
                    match = np.where(no_loss_currents == round(float(currents[k]), 2))[0]
                    if len(match):
                        loss = comma(float(losses[match[0], i]), 2)
                self.table.insert("", "end", values=(f"{currents[k]:.5f}", f"{voltages[k]:.5f}", loss))

    def _export_csv(self, names, data):
        """CSV replacement for the Excel COM export of the original."""
        config = self.config
        pk_temp = config.get(f"tempPK{self._pk_number()}")
        temp_idx = int(config.get("TempIndex", 30)) - 1
        headers = config.get("Header", [])
        for name, entry in zip(names, data):
            raw = entry.get("Data")
            if raw is None:
                continue
            rows = np.where(raw[:, temp_idx] == pk_temp)[0]
            if not len(rows):
                messagebox.showerror("Fehler", "Richtige PK-Nummer auswählen oder Coolant-Temperatur in config anpassen.")
                return
            section = raw[rows[0]:rows[-1] + 1, :]
            idx = find_indices(section[:, 4])
            window = self._window()
            avg = np.column_stack([average_values(section[:, c], idx, window) for c in range(section.shape[1])])
            path = filedialog.asksaveasfilename(
                title="Wählen Sie einen Speicherort und Dateinamen",
                initialfile=os.path.splitext(name)[0] + "_Export.csv",
                defaultextension=".csv", filetypes=[("CSV", "*.csv")],
            )
            if not path:
                continue
            with open(path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(headers[:avg.shape[1]])
                writer.writerows(avg.tolist())
            self._append_info_text(f"Export gespeichert: {path}")
