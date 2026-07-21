"""Python port of Auswertungen/S_plus__plus_.m - S++ current/temperature
distribution evaluation (single frame "Testplot" and video "Plot")."""

import os
import tkinter as tk
from tkinter import filedialog, messagebox
from datetime import datetime

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation

import read_all
from method_base import MethodWindowBase

TIMESTAMP_FORMATS = (
    "%m/%d/%Y %I:%M:%S %p.%f",
    "%m/%d/%Y %I:%M:%S%p.%f",
    "%m/%d/%Y %I:%M:%S%p",
    "%Y-%m-%d %H:%M:%S.%f",
    "%Y-%m-%d %H:%M:%S",
)


def parse_timestamp(text):
    text = text.strip()
    for fmt in TIMESTAMP_FORMATS:
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    return None


def calc_balanced_area(data, deviation_percent):
    """Port of calcBalancedArea: percentage of segments within
    +-deviation_percent% of the mean absolute value."""
    data = np.asarray(data, dtype=float)
    deviation = deviation_percent / 100.0
    mittelwert = abs(np.nanmean(data))
    if mittelwert == 0:
        return 0.0
    difference = np.abs(data) / mittelwert - 1
    balanced = np.sum((-deviation <= difference) & (difference <= deviation))
    return float(balanced) / data.size * 100.0


def delete_segments(frames, lines_to_delete, rows_to_delete):
    """Port of the faulty-segment removal: set the given (row, column)
    segments to NaN in every frame and refill them linearly over time."""
    frames = np.array(frames, dtype=float)
    for line, row in zip(lines_to_delete, rows_to_delete):
        frames[:, int(line) - 1, int(row) - 1] = np.nan
    return fill_missing_linear(frames)


def fill_missing_linear(frames):
    """fillmissing(..., 'linear') along the time axis for every segment."""
    frames = np.array(frames, dtype=float)
    n = frames.shape[0]
    t = np.arange(n)
    for r in range(frames.shape[1]):
        for c in range(frames.shape[2]):
            series = frames[:, r, c]
            mask = np.isnan(series)
            if mask.any() and (~mask).any():
                frames[mask, r, c] = np.interp(t[mask], t[~mask], series[~mask])
            elif mask.all():
                frames[:, r, c] = 0.0
    return frames


class SPlusPlusWindow(MethodWindowBase):
    METHOD_KEY = "S_plus__plus_"
    WINDOW_TITLE = "S++"

    def _build_ui(self):
        root = self.root
        config = self.config
        root.columnconfigure(0, weight=1)
        root.columnconfigure(1, weight=1)
        root.rowconfigure(0, weight=1)

        left = tk.Frame(root)
        left.grid(row=0, column=0, sticky="nsew", padx=10, pady=5)
        left.rowconfigure(0, weight=1)
        left.columnconfigure(0, weight=1)
        info_frame = tk.Frame(left)
        info_frame.grid(row=0, column=0, sticky="nsew")
        info_frame.rowconfigure(0, weight=1)
        info_frame.columnconfigure(0, weight=1)
        self._make_info_text(
            info_frame,
            'Die Auswertungsmethode "S++" wurde ausgewählt:\n'
            "TD-Datei noch nicht geladen\n"
            "CD-Datei noch nicht geladen\n\n"
            "Links: Parameter für Auswertung und Videoerstellung\n"
            "Rechts: Verteilungsdaten (.dat) und CSV-Dateien laden\n"
            "Unten: Koordinaten der ausgeblendeten Segmente angeben\n\n"
            'Erst "Ausgewählte Dateien laden", dann "Testplot" oder "Plot"',
        )

        params = tk.Frame(left)
        params.grid(row=1, column=0, sticky="ew", pady=5)
        params.columnconfigure(1, weight=1)

        def field(row, label, value):
            tk.Label(params, text=label).grid(row=row, column=0, sticky="w")
            var = tk.StringVar(value=str(value))
            tk.Entry(params, textvariable=var, width=14).grid(row=row, column=1, sticky="w")
            return var

        self.deviation_var = field(0, "Erlaubte Abweichung vom Mittelwert [%] (Balanced Area):",
                                   config.get("deviationBalancedArea", 20))
        self.segment_area_var = field(1, "Fläche der einzelnen Segmente [cm²]:", config.get("segmentArea", 1))
        self.framerate_var = field(2, "Videogeschwindigkeit [Bilder pro Sekunde]:", config.get("framerate", 10))
        self.frequency_var = field(3, "Jeder wie vielte Messpunkt soll angezeigt werden?:", config.get("frequency", 1))
        self.single_frame_var = field(4, "Index/Zeitpunkt des Messpunktes im Testplot:", config.get("singleFrame", 1))

        self.show_plot_var = tk.BooleanVar(value=bool(config.get("showPlotWindow", True)))
        self.cd_grid_var = tk.BooleanVar(value=bool(config.get("cdGridCheck", False)))
        self.td_grid_var = tk.BooleanVar(value=bool(config.get("tdGridCheck", False)))
        self.cd_color_var = tk.BooleanVar(value=bool(config.get("cdColorCheck", False)))
        self.td_color_var = tk.BooleanVar(value=bool(config.get("tdColorCheck", False)))
        self.plot_iu_var = tk.BooleanVar(value=False)
        checks = tk.Frame(left)
        checks.grid(row=2, column=0, sticky="ew")
        tk.Checkbutton(checks, text="Plotbild anzeigen", variable=self.show_plot_var).grid(row=0, column=0, sticky="w")
        tk.Checkbutton(checks, text="Strom-/Spannungsplot", variable=self.plot_iu_var).grid(row=0, column=1, sticky="w")
        tk.Label(checks, text="Feste Farbskala:").grid(row=1, column=0, sticky="w")
        tk.Checkbutton(checks, text="CD", variable=self.cd_color_var).grid(row=1, column=1, sticky="w")
        tk.Checkbutton(checks, text="TD", variable=self.td_color_var).grid(row=1, column=2, sticky="w")
        tk.Label(checks, text="Plot mit Raster:").grid(row=2, column=0, sticky="w")
        tk.Checkbutton(checks, text="CD", variable=self.cd_grid_var).grid(row=2, column=1, sticky="w")
        tk.Checkbutton(checks, text="TD", variable=self.td_grid_var).grid(row=2, column=2, sticky="w")

        right = tk.Frame(root)
        right.grid(row=0, column=1, sticky="nsew", padx=10, pady=5)
        right.columnconfigure(1, weight=1)
        tk.Label(right, text="Messdateien:", font=("TkDefaultFont", 12, "bold")).grid(row=0, column=0, sticky="w")
        tk.Button(right, text="Temperature Distribution", command=lambda: self._pick_dat("td")).grid(row=1, column=0, sticky="ew")
        self.td_path_var = tk.StringVar(value="")
        tk.Label(right, textvariable=self.td_path_var, anchor="w").grid(row=1, column=1, sticky="ew", padx=5)
        tk.Button(right, text="Current Distribution", command=lambda: self._pick_dat("cd")).grid(row=2, column=0, sticky="ew")
        self.cd_path_var = tk.StringVar(value="")
        tk.Label(right, textvariable=self.cd_path_var, anchor="w").grid(row=2, column=1, sticky="ew", padx=5)

        tk.Label(right, text="CSV-Dateien:", font=("TkDefaultFont", 11, "bold")).grid(row=3, column=0, sticky="w", pady=(8, 0))
        files_frame = tk.Frame(right)
        files_frame.grid(row=4, column=0, columnspan=2, sticky="nsew")
        right.rowconfigure(4, weight=1)
        self._make_file_list(files_frame)
        csv_btns = tk.Frame(right)
        csv_btns.grid(row=5, column=0, columnspan=2, sticky="ew", pady=3)
        csv_btns.columnconfigure((0, 1), weight=1)
        tk.Button(csv_btns, text="Neue CSV-Datei laden", command=self.add_files).grid(row=0, column=0, sticky="ew")
        tk.Button(csv_btns, text="Löschen", command=self.clear_selected).grid(row=0, column=1, sticky="ew")

        segs = tk.Frame(right)
        segs.grid(row=6, column=0, columnspan=2, sticky="ew", pady=5)
        segs.columnconfigure(1, weight=1)
        tk.Label(segs, text="Fehlerhafte Segmente der Temperature Distribution:").grid(row=0, column=0, columnspan=2, sticky="w")
        self.td_lines_var = self._seg_field(segs, 1, "Zeilen (Y):", self.config.get("tdLinesToDelete", ""))
        self.td_rows_var = self._seg_field(segs, 2, "Spalten (X):", self.config.get("tdRowsToDelete", ""))
        tk.Label(segs, text="Fehlerhafte Segmente der Current Distribution:").grid(row=3, column=0, columnspan=2, sticky="w")
        self.cd_lines_var = self._seg_field(segs, 4, "Zeilen (Y):", self.config.get("cdLinesToDelete", ""))
        self.cd_rows_var = self._seg_field(segs, 5, "Spalten (X):", self.config.get("cdRowsToDelete", ""))

        bottom = tk.Frame(root)
        bottom.grid(row=1, column=0, columnspan=2, sticky="ew", padx=10, pady=10)
        bottom.columnconfigure((0, 1, 2, 3, 4), weight=1)
        tk.Button(bottom, text="Ausgewählte Dateien laden", command=self.load_files).grid(row=0, column=0)
        tk.Button(bottom, text="Testplot", command=lambda: self.plot(show_all=False)).grid(row=0, column=1)
        tk.Button(bottom, text="Plot", command=lambda: self.plot(show_all=True)).grid(row=0, column=2)
        tk.Button(bottom, text="S++ config", command=self.edit_config).grid(row=0, column=3)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=0, column=4)

        self.td_file = None
        self.cd_file = None
        self.td_frames = None
        self.cd_frames = None
        self.timestamps = []

    @staticmethod
    def _seg_field(parent, row, label, value):
        tk.Label(parent, text=label).grid(row=row, column=0, sticky="w")
        var = tk.StringVar(value=str(value))
        tk.Entry(parent, textvariable=var).grid(row=row, column=1, sticky="ew")
        return var

    # -- data ---------------------------------------------------------------
    def _pick_dat(self, kind):
        filenames = filedialog.askopenfilenames(
            title="Wählen Sie eine .dat Datei aus", initialdir=self._standard_path(),
            filetypes=[("DAT files", "*.dat"), ("Alle Dateien", "*")],
        )
        if not filenames:
            return
        if kind == "td":
            self.td_file = filenames[0]
            self.td_path_var.set(os.path.basename(filenames[0]))
            self.td_frames = None
        else:
            self.cd_file = filenames[0]
            self.cd_path_var.set(os.path.basename(filenames[0]))
            self.cd_frames = None

    def load_files(self):
        if self.td_file and self.td_frames is None:
            self.td_frames, self.timestamps = read_all.read_s_plus_plus_dat(self.td_file, True)
            self._append_info_text(f"Read TD: {os.path.basename(self.td_file)} ({len(self.td_frames)} Frames)")
        if self.cd_file and self.cd_frames is None:
            self.cd_frames, _ = read_all.read_s_plus_plus_dat(self.cd_file, False)
            self._append_info_text(f"Read CD: {os.path.basename(self.cd_file)} ({len(self.cd_frames)} Frames)")

    def add_files(self):
        filenames = self._ask_filenames([("CSV files", "*.csv")])
        if not filenames:
            return
        config = self.config
        lines = read_all.process_inf(config.get("Zeilen", [1, "Inf"]))
        columns = config.get("Spalten")
        for path in filenames:
            data, _ = read_all.read_csv(path, lines, columns)
            if not data:
                messagebox.showwarning("Warnung", f"Keine Daten in Datei gefunden: {os.path.basename(path)}")
                continue
            self._add_file_item(os.path.basename(path), data)

    def clear_selected(self):
        for idx in reversed(list(self.file_listbox.curselection())):
            name = self.file_listbox.get(idx)
            self.file_listbox.delete(idx)
            self.file_items.pop(name, None)

    def _csv_rows(self):
        """Concatenate CSV files sorted by their first timestamp (simplified
        port of sortCSVFiles + compareTimeAndCSV: rows are matched to frames
        by index)."""
        entries = []
        for name, rows in self.file_items.items():
            ts = parse_timestamp(str(rows[0][0])) if rows else None
            entries.append((ts or datetime.min, rows))
        entries.sort(key=lambda e: e[0])
        combined = []
        for _, rows in entries:
            combined.extend(rows)
        return combined

    @staticmethod
    def _parse_segments(text):
        values = [v.strip() for v in str(text).split(",") if v.strip()]
        try:
            return [int(float(v)) for v in values]
        except ValueError:
            return []

    # -- plotting -------------------------------------------------------------
    def plot(self, show_all):
        if self.cd_frames is None or self.td_frames is None or not len(self.cd_frames) or not len(self.td_frames):
            messagebox.showwarning("Warnung", 'Bitte zuerst TD- und CD-Datei laden ("Ausgewählte Dateien laden").')
            return
        config = self.config
        area = float(self.segment_area_var.get())
        deviation = float(self.deviation_var.get())
        frequency = max(int(float(self.frequency_var.get())), 1)
        framerate = max(int(float(self.framerate_var.get())), 1)

        cd = self.cd_frames / area
        cd_lines = self._parse_segments(self.cd_lines_var.get())
        cd_rows = self._parse_segments(self.cd_rows_var.get())
        if cd_lines and len(cd_lines) == len(cd_rows):
            cd = delete_segments(cd, cd_lines, cd_rows)
        else:
            cd = fill_missing_linear(cd)

        td = self.td_frames
        td_lines = self._parse_segments(self.td_lines_var.get())
        td_rows = self._parse_segments(self.td_rows_var.get())
        if td_lines and len(td_lines) == len(td_rows):
            td = delete_segments(td, td_lines, td_rows)
        else:
            td = fill_missing_linear(td)

        cd_abs = np.abs(cd)
        cd_min, cd_max = float(np.nanmin(cd_abs)), float(np.nanmax(cd_abs))
        td_min, td_max = float(np.nanmin(td)), float(np.nanmax(td))

        csv_rows = self._csv_rows()

        n_frames = min(len(cd), len(td))
        if show_all:
            indices = list(range(0, n_frames, frequency))
        else:
            indices = [self._single_frame_index(n_frames)]

        fig = plt.figure(figsize=(16, 9))
        show_iu = self.plot_iu_var.get() and csv_rows
        rect_bottom = 0.32 if show_iu else 0.08
        ax1 = fig.add_axes([0.04, rect_bottom, 0.33, 0.55], projection="3d")
        ax2 = fig.add_axes([0.45, rect_bottom, 0.2, 0.5])
        ax3 = fig.add_axes([0.74, rect_bottom, 0.2, 0.5])

        title_kw = dict(fontsize=14, fontweight="bold")
        ax2.set_title("Current distribution", **title_kw)
        ax3.set_title("Temperature distribution", **title_kw)

        if show_iu:
            ax4 = fig.add_axes([0.06, 0.05, 0.88, 0.2])
            currents = [self._num(row, 17) for row in csv_rows]
            voltages = [self._num(row, 2) for row in csv_rows]
            x = np.arange(1, len(csv_rows) + 1)
            color_i = self._hex(config.get("Farbe_I", "#7030A0"))
            color_u = self._hex(config.get("Farbe_U", "#000000"))
            ax4.plot(x, currents, "-", color=color_i, linewidth=1)
            ax4.set_ylabel("Current [A]", color=color_i)
            ax4b = ax4.twinx()
            ax4b.plot(x, voltages, "-", color=color_u, linewidth=1)
            ax4b.set_ylabel("Voltage [V]", color=color_u)
            ax4.set_xticks([])
            marker_line = ax4.axvline(indices[0] + 1, color="r", linewidth=2)
        else:
            marker_line = None

        info_text = fig.text(0.01, 0.97, "", fontsize=11, va="top")

        surf_holder = {}

        def draw_frame(i):
            frame_cd = cd_abs[i]
            frame_td = td[i]
            for key in ("surf",):
                if key in surf_holder:
                    surf_holder[key].remove()
            ax1.clear()
            rows_y, cols_x = frame_cd.shape
            X, Y = np.meshgrid(np.arange(1, cols_x + 1), np.arange(1, rows_y + 1))
            surf_holder["surf"] = ax1.plot_surface(X, Y, frame_cd, cmap="jet",
                                                   vmin=cd_min if self.cd_color_var.get() else None,
                                                   vmax=cd_max if self.cd_color_var.get() else None)
            ax1.set_zlabel("Current density [A/cm²]")
            ax1.view_init(35, -55)

            ax2.clear()
            ax2.set_title("Current distribution", **title_kw)
            kw = {"cmap": "jet"}
            if self.cd_color_var.get():
                kw.update(vmin=cd_min, vmax=cd_max)
            mesh = ax2.pcolormesh(frame_cd, edgecolors="k" if self.cd_grid_var.get() else "none",
                                  shading="auto" if not self.cd_grid_var.get() else "flat", **kw)
            ax2.set_xticks([]); ax2.set_yticks([])

            ax3.clear()
            ax3.set_title("Temperature distribution", **title_kw)
            kw = {"cmap": "jet"}
            if self.td_color_var.get():
                kw.update(vmin=td_min, vmax=td_max)
            ax3.pcolormesh(frame_td, edgecolors="k" if self.td_grid_var.get() else "none",
                           shading="auto" if not self.td_grid_var.get() else "flat", **kw)
            ax3.set_xticks([]); ax3.set_yticks([])

            balanced = calc_balanced_area(frame_cd, deviation)
            time_str = self.timestamps[i] if i < len(self.timestamps) else str(i + 1)
            lines = [f"Time: {time_str}",
                     f"Balance area: {balanced:.2f} %",
                     f"CSS min/max: {np.nanmin(frame_cd):.3f}/{np.nanmax(frame_cd):.3f} A/cm²"]
            if csv_rows and i < len(csv_rows):
                row = csv_rows[i]
                lines.append(f"Current Density: {self._num(row, 1):.2f} A/cm²   "
                             f"Voltage: {self._num(row, 2):.3f} V")
            info_text.set_text("\n".join(lines))
            if marker_line is not None:
                marker_line.set_xdata([i + 1, i + 1])

        draw_frame(indices[0])

        if show_all and len(indices) > 1:
            path = filedialog.asksaveasfilename(
                title="Speicherort für das Video auswählen",
                defaultextension=".mp4", filetypes=[("MP4", "*.mp4"), ("GIF", "*.gif")],
            )
            if not path:
                plt.close(fig)
                return
            anim = animation.FuncAnimation(fig, draw_frame, frames=indices, interval=1000 / framerate)
            try:
                if path.lower().endswith(".gif"):
                    writer = animation.PillowWriter(fps=framerate)
                else:
                    writer = animation.FFMpegWriter(fps=framerate)
                anim.save(path, writer=writer)
                self._append_info_text(f"Video gespeichert: {path}")
            except (FileNotFoundError, ValueError):
                gif_path = os.path.splitext(path)[0] + ".gif"
                anim.save(gif_path, writer=animation.PillowWriter(fps=framerate))
                self._append_info_text(
                    f"ffmpeg nicht gefunden - GIF stattdessen gespeichert: {gif_path}")
        if self.show_plot_var.get():
            plt.show(block=False)
        else:
            plt.close(fig)

    def _single_frame_index(self, n_frames):
        raw = self.single_frame_var.get().strip()
        try:
            return min(max(int(float(raw)) - 1, 0), n_frames - 1)
        except ValueError:
            target = parse_timestamp(raw)
            if target is None or not self.timestamps:
                return 0
            diffs = []
            for ts in self.timestamps[:n_frames]:
                parsed = parse_timestamp(ts)
                diffs.append(abs((parsed - target).total_seconds()) if parsed else float("inf"))
            return int(np.argmin(diffs))

    @staticmethod
    def _num(row, index):
        try:
            return float(row[index])
        except (TypeError, ValueError, IndexError):
            return float("nan")

    @staticmethod
    def _hex(hexcolor):
        hexcolor = hexcolor.lstrip("#")
        return tuple(int(hexcolor[i:i + 2], 16) / 255 for i in (0, 2, 4))
