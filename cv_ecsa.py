"""Python port of Auswertungen/CV_ECSA.m - cyclic voltammetry / ECSA evaluation."""

import os
import tkinter as tk
from tkinter import messagebox

import numpy as np
from scipy.interpolate import PchipInterpolator
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

import read_all
from method_base import MethodWindowBase, clean_tex, first, jet_colors, comma, REF_GREY

H2_SURFACE_CHARGE = 210e-6  # C/cm²


def split_cycles(x, y):
    """Port of the cycle splitting in fastData: cut at local minima of x."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    diffs = np.diff(x)
    idx = np.where((diffs[:-1] < 0) & (diffs[1:] > 0))[0] + 1  # 0-based end of cycle
    cycles_x, cycles_y = [], []
    start = 0
    for i in idx:
        cycles_x.append(x[start:i + 1])
        cycles_y.append(y[start:i + 1])
        start = i + 1
    cycles_x.append(x[start:])
    cycles_y.append(y[start:])
    return cycles_x, cycles_y


def _unique_last(x, y):
    """MATLAB unique(x, 'last'): sorted unique x, keeping the last y."""
    order = np.argsort(x, kind="stable")
    x_sorted, y_sorted = np.asarray(x)[order], np.asarray(y)[order]
    ux, idx_first = np.unique(x_sorted, return_index=True)
    counts = np.unique(x_sorted, return_counts=True)[1]
    idx_last = idx_first + counts - 1
    return ux, y_sorted[idx_last]


def compare_fast_and_slow(fast_x, fast_y, slow_x, slow_y):
    """Port of compareFastAndSlow: subtract the (pchip-interpolated) slow
    scan from the fast scan, split at the voltage maximum."""
    fast_x = np.asarray(fast_x, dtype=float)
    fast_y = np.asarray(fast_y, dtype=float)
    slow_x = np.asarray(slow_x, dtype=float)
    slow_y = np.asarray(slow_y, dtype=float)

    max_fast = int(np.argmax(fast_x))
    max_slow = int(np.argmax(slow_x))

    ux1, uy1 = _unique_last(slow_x[:max_slow + 1], slow_y[:max_slow + 1])
    ux2, uy2 = _unique_last(slow_x[max_slow + 1:], slow_y[max_slow + 1:])

    interp1 = PchipInterpolator(ux1, uy1, extrapolate=True)
    interp2 = PchipInterpolator(ux2, uy2, extrapolate=True)

    new_y = np.empty_like(fast_y)
    new_y[:max_fast + 1] = fast_y[:max_fast + 1] - interp1(fast_x[:max_fast + 1])
    new_y[max_fast + 1:] = fast_y[max_fast + 1:] - interp2(fast_x[max_fast + 1:])
    return fast_x.copy(), new_y


def find_dl(x, y, limits):
    """Port of findDL: double layer currents searched in the voltage window
    `limits` on the forward (min) and backward (max) branch."""
    x = np.asarray(x)
    y = np.asarray(y)
    max_idx = int(np.argmax(x))

    x1 = x[:max_idx + 1]
    x2 = x[max_idx + 1:]

    fwd = np.where((x1 >= limits[0]) & (x1 <= limits[1]))[0]
    bwd = np.where((x2 >= limits[0]) & (x2 <= limits[1]))[0]

    i_dl_forward = float(np.min(y[fwd])) if len(fwd) else float(np.min(y[:max_idx + 1]))
    if len(bwd):
        i_dl_backward = float(np.max(y[max_idx + 1 + bwd]))
    else:
        i_dl_backward = float(np.max(y[max_idx + 1:]))
    return i_dl_forward, i_dl_backward


def ecsa(x, y, i_dl_forward, i_dl_backward, start_int_cath, start_int_an, v, pt_loading, area):
    """Port of ECSA: returns (ecsa_ads, ecsa_des, ecsa_mean) in m²/gPt.

    v is the scan speed (slew rate) in mV/s.
    """
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    max_idx = int(np.argmax(x))

    x1, y1 = x[:max_idx + 1], y[:max_idx + 1]
    x2, y2 = x[max_idx + 1:], y[max_idx + 1:]

    diff1 = (y1 - i_dl_forward) / area
    diff2 = (y2 - i_dl_backward) / area

    idx11 = np.where(x1 >= start_int_an)[0]
    idx12_all = np.where(y1 == i_dl_forward)[0]
    idx12 = int(idx12_all[0]) if len(idx12_all) else int(np.argmin(np.abs(y1 - i_dl_forward)))
    idx21 = np.where(x2 >= start_int_cath)[0]
    idx22_all = np.where(y2 == i_dl_backward)[0]
    idx22 = int(idx22_all[0]) if len(idx22_all) else int(np.argmin(np.abs(y2 - i_dl_backward)))

    if len(idx11) == 0:
        q_des = np.nan
    else:
        s = int(idx11[0])
        q_des = np.trapezoid(diff1[s:idx12 + 1], x1[s:idx12 + 1]) / v
    if len(idx21) == 0:
        q_ads = np.nan
    else:
        e = int(idx21[-1])
        q_ads = np.trapezoid(diff2[idx22:e + 1], x2[idx22:e + 1]) / v

    ecsa_des = q_des / (H2_SURFACE_CHARGE * pt_loading) * 100
    ecsa_ads = q_ads / (H2_SURFACE_CHARGE * pt_loading) * 100
    ecsa_mean = (abs(ecsa_des) + ecsa_ads) / 2
    return float(ecsa_ads), float(ecsa_des), float(ecsa_mean)


class CVECSAWindow(MethodWindowBase):
    METHOD_KEY = "CV_ECSA"
    WINDOW_TITLE = "CV-ECSA"

    def _build_ui(self):
        root = self.root
        config = self.config
        root.columnconfigure(0, weight=3)
        root.columnconfigure(1, weight=1)
        root.rowconfigure(0, weight=1)

        # embedded preview axes (left)
        plot_frame = tk.Frame(root)
        plot_frame.grid(row=0, column=0, sticky="nsew", padx=10, pady=5)
        plot_frame.rowconfigure(0, weight=1)
        plot_frame.columnconfigure(0, weight=1)
        self.figure = Figure(figsize=(6, 4))
        self.ax = self.figure.add_subplot(111)
        self.ax.set_xlim(config.get("xAchsenLimits", [0, 0.9]))
        self.ax.set_ylim(config.get("yAchsenLimits", [-2, 2]))
        self.ax.set_xlabel("Voltage [V]")
        self.ax.set_ylabel("Current [A]")
        self.canvas = FigureCanvasTkAgg(self.figure, master=plot_frame)
        self.canvas.get_tk_widget().grid(row=0, column=0, sticky="nsew")

        # side panel (right)
        side = tk.Frame(root)
        side.grid(row=0, column=1, sticky="nsew", padx=10, pady=5)
        r = 0
        tk.Button(side, text="CV-ECSA config", command=self.edit_config).grid(row=r, column=0, columnspan=3, sticky="ew"); r += 1
        tk.Button(side, text="Load fast Data", command=self.load_fast_data).grid(row=r, column=0, columnspan=3, sticky="ew"); r += 1
        tk.Button(side, text="Load slow Data", command=self.load_slow_data).grid(row=r, column=0, columnspan=3, sticky="ew"); r += 1

        self.cycle_var = tk.StringVar(value="Cycle 4")
        self.cycle_menu = tk.OptionMenu(side, self.cycle_var, "Cycle 1", "Cycle 2", "Cycle 3", "Cycle 4",
                                        command=lambda *_: self.update_plot())
        self.cycle_menu.grid(row=r, column=0, columnspan=3, sticky="ew"); r += 1

        def numeric_field(label, value):
            nonlocal r
            tk.Label(side, text=label).grid(row=r, column=0, columnspan=3, sticky="w"); r += 1
            var = tk.DoubleVar(value=value)
            entry = tk.Entry(side, textvariable=var)
            entry.grid(row=r, column=0, columnspan=3, sticky="ew"); r += 1
            entry.bind("<Return>", lambda *_: self.update_plot())
            entry.bind("<FocusOut>", lambda *_: self.update_plot())
            return var

        self.start_int_cath_var = numeric_field("Start integration cathodic [V]:", config.get("StartIntCath", 0.07))
        self.start_int_an_var = numeric_field("Start integration anodic [V]:", config.get("StartIntAn", 0.07))
        self.pt_loading_var = numeric_field("Pt loading [mg/cm²]:", config.get("PtLoading", 0.175))
        self.area_var = numeric_field("Active area [cm²]:", config.get("Flaeche", 273))

        tk.Label(side, text="ECSA [m²/gPt]:", font=("TkDefaultFont", 10, "bold")).grid(
            row=r, column=0, columnspan=3, sticky="w"); r += 1
        self.result_vars = {}
        for row_name, label in (("Ref", "Ref - Ø / ads / des:"), ("DUT", "DUT - Ø / ads / des:"),
                                ("%", "Verlust - Ø / ads / des:")):
            tk.Label(side, text=label).grid(row=r, column=0, columnspan=3, sticky="w"); r += 1
            for c, suffix in enumerate(("", "_ads", "_des")):
                var = tk.StringVar(value="")
                tk.Entry(side, textvariable=var, state="readonly", width=8).grid(row=r, column=c, sticky="ew")
                self.result_vars[row_name + suffix] = var
            r += 1

        self.show_reference_var = tk.BooleanVar(value=bool(config.get("checkRef", True)))
        self.show_dut_var = tk.BooleanVar(value=bool(config.get("checkDUT", True)))
        self.show_fast_var = tk.BooleanVar(value=bool(config.get("checkFast", True)))
        self.show_slow_var = tk.BooleanVar(value=bool(config.get("checkSlow", True)))
        self.show_ecsa_var = tk.BooleanVar(value=bool(config.get("checkECSA", True)))
        for text, var in (("Referenzdaten anzeigen", self.show_reference_var),
                          ("DUT anzeigen", self.show_dut_var),
                          ("fast Data anzeigen", self.show_fast_var),
                          ("slow Data anzeigen", self.show_slow_var),
                          ("ECSA-Ø anzeigen", self.show_ecsa_var)):
            tk.Checkbutton(side, text=text, variable=var).grid(row=r, column=0, columnspan=3, sticky="w"); r += 1

        # title / buttons (bottom)
        bottom = tk.Frame(root)
        bottom.grid(row=1, column=0, columnspan=2, sticky="ew", padx=10, pady=5)
        bottom.columnconfigure(1, weight=1)
        tk.Label(bottom, text="Titel Zeile 1:").grid(row=0, column=0, sticky="w")
        self.title1_var = tk.StringVar(value=first(config.get("Titel1")))
        tk.Entry(bottom, textvariable=self.title1_var).grid(row=0, column=1, columnspan=2, sticky="ew", padx=5)
        tk.Label(bottom, text="Titel Zeile 2:").grid(row=1, column=0, sticky="w")
        self.title2_var = tk.StringVar(value=first(config.get("Titel2")))
        tk.Entry(bottom, textvariable=self.title2_var).grid(row=1, column=1, columnspan=2, sticky="ew", padx=5)
        self.title_fontsize_var = self._title_fontsize_var()
        self._add_title_fontsize_field(bottom, self.title_fontsize_var, row=0, column=3)
        tk.Button(bottom, text="Plot", command=self.plot_external).grid(row=2, column=0, pady=8)
        tk.Button(bottom, text="Zurück zur Auswahl", command=self.back_to_selection).grid(row=2, column=1, pady=8)
        tk.Button(bottom, text="Help", command=self.help_dialog).grid(row=2, column=2, pady=8)

        # DUT data state
        self.cycles_x = None
        self.cycles_y = None
        self.fast_slewrate = None
        self.slow_x = None
        self.slow_y = None
        self.slow_slewrate = None

    # -- data ---------------------------------------------------------------
    def _columns(self):
        return [c - 1 for c in self.config.get("Spalten", [3, 4])]

    def _load_references(self):
        marker = self._header_marker()
        self.fast_references = []
        for path in self._reference_files(subfolder="schneller_Scan"):
            data, _ = read_all.read_txt(path, marker)
            if data is not None:
                self.fast_references.append(data)
        self.slow_references = []
        for path in self._reference_files(subfolder="langsamer_Scan"):
            data, _ = read_all.read_txt(path, marker)
            if data is not None:
                self.slow_references.append(data)
        self.recalc_ref()

    def _pick_txt(self):
        filenames = self._ask_filenames([("Text files", "*.txt")])
        return filenames[0] if filenames else None

    def load_fast_data(self):
        path = self._pick_txt()
        if not path:
            return
        data, slew = read_all.read_txt(path, self._header_marker())
        if data is None:
            messagebox.showwarning("Warnung", "Keine Daten in Datei gefunden.")
            return
        cols = self._columns()
        self.cycles_x, self.cycles_y = split_cycles(data[:, cols[0]], data[:, cols[1]])
        self.fast_slewrate = slew or None
        menu = self.cycle_menu["menu"]
        menu.delete(0, "end")
        for i in range(len(self.cycles_x)):
            label = f"Cycle {i + 1}"
            menu.add_command(label=label, command=lambda v=label: (self.cycle_var.set(v), self.update_plot()))
        self.cycle_var.set(f"Cycle {len(self.cycles_x)}")
        self.update_plot()

    def load_slow_data(self):
        path = self._pick_txt()
        if not path:
            return
        data, slew = read_all.read_txt(path, self._header_marker())
        if data is None:
            messagebox.showwarning("Warnung", "Keine Daten in Datei gefunden.")
            return
        self.slow_x = data[:, 2]
        self.slow_y = data[:, 3]
        self.slow_slewrate = slew or None
        self.update_plot()

    def _selected_cycle(self):
        try:
            return int(self.cycle_var.get().split()[-1]) - 1
        except (ValueError, IndexError):
            return 0

    # -- embedded preview plot ------------------------------------------------
    def update_plot(self):
        config = self.config
        decimals = int(config.get("Nachkommastellen", 2))
        line_width = config.get("lineWidth", 2)
        ax = self.ax
        ax.clear()
        cycle = self._selected_cycle()

        if self.cycles_x is not None and cycle < len(self.cycles_x):
            ax.plot(self.cycles_x[cycle], self.cycles_y[cycle], "--", color="b",
                    linewidth=line_width, label="fast Data")
        if self.slow_x is not None:
            ax.plot(self.slow_x, self.slow_y, ":", color="b", linewidth=line_width, label="slow Data")

        if self.cycles_x is not None and self.slow_x is not None and cycle < len(self.cycles_x):
            new_x, new_y = compare_fast_and_slow(
                self.cycles_x[cycle], self.cycles_y[cycle], self.slow_x, self.slow_y
            )
            ax.plot(new_x, new_y, "-", color="b", linewidth=line_width, label="corrected Data")
            limits = config.get("SpannungsbereichFuerDLSuche", [0.3, 0.6])
            i_dl_f, i_dl_b = find_dl(new_x, new_y, limits)
            ax.axhline(i_dl_b, color="g", linestyle=":", label=f"I DL Backward = {i_dl_b:.3f}")
            ax.axhline(i_dl_f, color="r", linestyle=":", label=f"I DL Forward = {i_dl_f:.3f}")

            v = self.fast_slewrate
            if v is None:
                v = first(config.get("refFastSlewRate", [30]), 30)
                if isinstance(v, list):
                    v = v[0]
            ads, des, mean = ecsa(new_x, new_y, i_dl_f, i_dl_b,
                                  self.start_int_cath_var.get(), self.start_int_an_var.get(),
                                  v, self.pt_loading_var.get(), self.area_var.get())
            self.result_vars["DUT_ads"].set(comma(ads, decimals))
            self.result_vars["DUT_des"].set(comma(des, decimals))
            self.result_vars["DUT"].set(comma(mean, decimals))
            self._dut_ecsa = mean

        self.recalc_ref()
        ax.set_xlabel("Voltage [V]")
        ax.set_ylabel("Current [A]")
        if ax.lines:
            ax.legend(loc="lower right", fontsize=8)
        self.canvas.draw_idle()

    def recalc_ref(self):
        """Port of recalcRef: mean reference ECSA over all reference pairs."""
        config = self.config
        decimals = int(config.get("Nachkommastellen", 2))
        if not self.fast_references or not self.slow_references:
            return
        cycle = self._selected_cycle()
        cols = self._columns()
        limits = config.get("SpannungsbereichFuerDLSuche", [0.3, 0.6])

        all_ads, all_des, all_mean = [], [], []
        for i, (fast, slow) in enumerate(zip(self.fast_references, self.slow_references)):
            cx, cy = split_cycles(fast[:, cols[0]], fast[:, cols[1]])
            c = min(cycle, len(cx) - 1)
            new_x, new_y = compare_fast_and_slow(cx[c], cy[c], slow[:, 2], slow[:, 3])
            i_dl_f, i_dl_b = find_dl(new_x, new_y, limits)
            v = config.get("refFastSlewRate", [30])[min(i, len(config.get("refFastSlewRate", [30])) - 1)]
            pt = config.get("refPtLoading", [0.175])[min(i, len(config.get("refPtLoading", [0.175])) - 1)]
            area = config.get("refActiveArea", [273])[min(i, len(config.get("refActiveArea", [273])) - 1)]
            ads, des, mean = ecsa(new_x, new_y, i_dl_f, i_dl_b,
                                  self.start_int_cath_var.get(), self.start_int_an_var.get(),
                                  v, pt, area)
            all_ads.append(ads); all_des.append(des); all_mean.append(mean)

        self.result_vars["Ref"].set(comma(float(np.mean(all_mean)), decimals))
        self.result_vars["Ref_ads"].set(comma(float(np.mean(all_ads)), decimals))
        self.result_vars["Ref_des"].set(comma(float(np.mean(all_des)), decimals))
        self.recalc_loss()

    def recalc_loss(self):
        decimals = int(self.config.get("Nachkommastellen", 2))
        for suffix in ("", "_ads", "_des"):
            try:
                ref = float(self.result_vars["Ref" + suffix].get().replace(",", "."))
                dut = float(self.result_vars["DUT" + suffix].get().replace(",", "."))
                loss = (ref - dut) / ref * 100
            except (ValueError, ZeroDivisionError):
                loss = 0.0
            if np.isnan(loss):
                loss = 0.0
            self.result_vars["%" + suffix].set(comma(loss, decimals) + "%")

    # -- external plot ----------------------------------------------------------
    def plot_external(self):
        config = self.config
        show_reference = self.show_reference_var.get()
        show_dut = self.show_dut_var.get()
        show_fast = self.show_fast_var.get()
        show_slow = self.show_slow_var.get()
        if (not show_reference and not show_dut) or (not show_fast and not show_slow):
            return
        if show_dut and self.cycles_x is None and self.slow_x is None and not show_reference:
            return

        line_width = config.get("lineWidth", 2)
        cycle = self._selected_cycle()
        fig, ax = plt.subplots(figsize=(14, 8))

        alpha = 0.25
        refcolor = tuple(0.01 * alpha + 1 - alpha for _ in range(3))
        n_ref = max(len(self.fast_references), len(self.slow_references), 1)
        colors = jet_colors(n_ref)

        if show_reference:
            cols = self._columns()
            if show_fast:
                for i, fast in enumerate(self.fast_references):
                    cx, cy = split_cycles(fast[:, cols[0]], fast[:, cols[1]])
                    c = min(cycle, len(cx) - 1)
                    if show_dut:
                        ax.plot(cx[c], cy[c], ".-", markersize=line_width * 21,
                                linewidth=line_width * 6, color=refcolor)
                    else:
                        ax.plot(cx[c], cy[c], ".-", linewidth=line_width, markersize=10,
                                color=colors[i], label=f"Referenz#{i + 1}")
            if show_slow:
                for i, slow in enumerate(self.slow_references):
                    if show_dut:
                        ax.plot(slow[:, 2], slow[:, 3], ".-", markersize=line_width * 21,
                                linewidth=line_width * 6, color=refcolor)
                    else:
                        label = None if show_fast else f"Referenz#{i + 1}"
                        ax.plot(slow[:, 2], slow[:, 3], ".-", linewidth=line_width,
                                markersize=10, color=colors[i], label=label)

        if show_dut:
            if self.cycles_x is not None and show_fast and cycle < len(self.cycles_x):
                name = f"DUT_{self.fast_slewrate or '?'}mVs"
                ax.plot(self.cycles_x[cycle], self.cycles_y[cycle], ".-", linewidth=line_width,
                        markersize=10, color="b", label=name)
            if self.slow_x is not None and show_slow:
                name = f"DUT_{self.slow_slewrate or '?'}mVs"
                ax.plot(self.slow_x, self.slow_y, ".-", linewidth=line_width, markersize=10,
                        color="b", label=name)
            if self.show_ecsa_var.get() and getattr(self, "_dut_ecsa", None) is not None:
                decimals = int(config.get("Nachkommastellen", 2))
                ax.text(0.5, -1, f"ECSA-Ø ≈ {comma(self._dut_ecsa, decimals)} m²/gPt",
                        color=(192 / 255, 0, 0), backgroundcolor=(200 / 255, 200 / 255, 200 / 255),
                        fontsize=config.get("ECSALabelFontSize", 18), fontweight="bold")

        replacement = "xx&x"
        if self.fast_slewrate and self.slow_slewrate:
            replacement = f"{self.fast_slewrate:g}&{self.slow_slewrate:g}"
        elif self.fast_slewrate:
            replacement = f"{self.fast_slewrate:g}"
        t1 = clean_tex(self.title1_var.get().replace("xx&x", replacement))
        t2 = clean_tex(self.title2_var.get())
        ax.set_title(f"{t1}\n{t2}", fontsize=self.title_fontsize_var.get())
        ax.set_xlabel(clean_tex(first(config.get("xlabel"), "U [V]")), fontweight="bold")
        ax.set_ylabel(clean_tex(first(config.get("ylabel"), "I [A]")), fontweight="bold")
        ax.set_xlim(config.get("xAchsenLimits", [0, 0.9]))
        ax.set_ylim(config.get("yAchsenLimits", [-2, 2]))
        ax.grid(True, color=(0.5, 0.5, 0.5), alpha=0.7)
        ax.spines["left"].set_position("zero")
        ax.spines["bottom"].set_position("zero")
        ax.tick_params(labelsize=config.get("xTickSize", 18))
        ax.legend(loc="lower right", fontsize=config.get("legendFontSize", 14))
        plt.show(block=False)

    def help_dialog(self):
        messagebox.showinfo(
            "Information",
            ">> Dropdown 'Cycle ...': Zyklus des schnellen Scans\n"
            ">> Load fast & slow Data: Laden der Scans\n"
            ">> Start integration cathodic & anodic [V]: Integrationsgrenzen\n"
            ">> Pt loading [mg/cm²], Active Area [cm²]: Zellparameter\n"
            ">> ECSA: Referenz-, DUT-Werte und Verlust (ads/des = kathodisch/anodisch)\n\n"
            "Formeln:\n"
            "ECSA_ges = (|ECSA_des|+ECSA_ads)/2\n"
            "Q = (∫((I-I_DL)/Area dU))/Scangeschwindigkeit\n"
            "ECSA = (Q*100)/(H2SurfaceCharge*Pt loading)",
        )
