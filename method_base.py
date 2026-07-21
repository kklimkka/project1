"""Shared scaffolding for the evaluation method windows (Auswertungen/*.m).

Every MATLAB method window follows the same pattern: load its section of
config.json, clear the shared figure, build info text + file list +
parameter fields + bottom buttons, and read reference data from the
reference folder. This module keeps that boilerplate in one place; the
per-method modules only add their own parameters and plotting.
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

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


_MATHTEXT_SPECIAL = re.compile(r"([\\{}$#%&])")


def _escape_mathtext(fragment):
    """Escape characters mathtext treats as structural, so arbitrary user
    text can be dropped inside a \\mathrm{...} run without breaking parsing."""
    return _MATHTEXT_SPECIAL.sub(r"\\\1", fragment)


def _consume_group_or_char(text, i):
    """At text[i], consume either a {...}-delimited group (honouring the
    same \\{ \\} \\\\ escapes as the rest of clean_tex) or, if there is no
    brace, a single character - mirroring MATLAB's tex interpreter, where
    both ``x^2`` and ``x^{22}`` are valid superscript syntax. Returns
    (content, next_index)."""
    if i >= len(text):
        return "", i
    if text[i] != "{":
        return text[i], i + 1
    depth = 1
    j = i + 1
    start = j
    while j < len(text) and depth > 0:
        if text[j] == "\\" and j + 1 < len(text):
            j += 2
            continue
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    content = text[start:j]
    return content, min(j + 1, len(text))


def clean_tex(text):
    """Render MATLAB-tex-style title markup as matplotlib mathtext.

    Supports the same escapes the MATLAB app's title fields did:
    ``^{..}``/``^x`` for superscript, ``_{..}``/``_x`` for subscript, and
    ``\\{``, ``\\}``, ``\\\\`` to write literal ``{``, ``}``, ``\\``. Plain
    text (including umlauts, degree signs, etc.) is left untouched and
    rendered by matplotlib's normal text path; only the sup/subscript
    fragments are wrapped in mathtext (``$...$``) so they actually render
    raised/lowered instead of being stripped out.
    """
    if text is None:
        return ""
    # Legacy MATLAB rich-text commands that have no mathtext equivalent -
    # drop the wrapper but keep whatever text they contained.
    text = re.sub(r"\\fontsize\{[^}]*\}\{[^}]*\}", "", text)
    text = re.sub(r"\\fontsize\{[^}]*\}", "", text)
    text = re.sub(r"\\color\{[^}]*\}", "", text)

    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "\\" and i + 1 < n and text[i + 1] in "{}\\":
            out.append(text[i + 1])
            i += 2
            continue
        if ch in "^_":
            content, i = _consume_group_or_char(text, i + 1)
            escaped = _escape_mathtext(content)
            op = "^" if ch == "^" else "_"
            out.append(rf"${{}}{op}{{\mathrm{{{escaped}}}}}$")
            continue
        out.append(ch)
        i += 1
    return "".join(out).strip()


def first(value, default=""):
    """MATLAB configs wrap scalars in 1-element lists - unwrap them."""
    if isinstance(value, list):
        return value[0] if value else default
    return value if value is not None else default


def jet_colors(n):
    return plt.cm.jet(np.linspace(0, 1, max(n, 1)))


def comma(value, decimals):
    """Format a number with a decimal comma, like the MATLAB tool does."""
    return f"{value:.{decimals}f}".replace(".", ",")


REF_GREY = (0.9, 0.9, 0.9)


class MethodWindowBase:
    METHOD_KEY = None  # config.json section / reference sub-folder name
    WINDOW_TITLE = None

    def __init__(self, root, reference_folder):
        self.root = root
        self.reference_folder = reference_folder
        self.method_folder = os.path.join(reference_folder, self.METHOD_KEY)

        for child in list(self.root.children.values()):
            child.destroy()
        self.root.unbind("<Configure>")
        self.root.title(self.WINDOW_TITLE or self.METHOD_KEY)

        self.full_config = self._load_full_config()
        self.config = self.full_config.get(self.METHOD_KEY, {})

        # ordered mapping filename -> data (mirrors fileList Items/ItemsData)
        self.file_items = {}

        self._build_ui()
        self._load_references()

    # -- config / reference helpers ---------------------------------------
    def _load_full_config(self):
        config_path = os.path.join(self.reference_folder, "config.json")
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError) as exc:
            messagebox.showerror(f"Fehler beim Öffnen des {self.WINDOW_TITLE}-Fensters", str(exc))
            return {}

    def _header_marker(self):
        return self.full_config.get("read_txt", {}).get("HeaderDerNurInZeileVorMessdatenIst", "Number")

    def _standard_path(self):
        path = paths.resolve(self.full_config.get("Auswahl", {}).get("StandardPfad", ""))
        return path if path and os.path.isdir(path) else None

    def _reference_files(self, subfolder=None, pattern="Referenz#*"):
        folder = self.method_folder if subfolder is None else os.path.join(self.method_folder, subfolder)
        files = []
        for ext in (".txt", ".csv"):
            files += glob.glob(os.path.join(folder, pattern + ext))
        return sorted(files)

    def _load_references(self):
        """Overridden by methods that read reference data on startup."""

    # -- title font size -----------------------------------------------------
    def _title_fontsize_var(self, default=14, key="TitelFontSize"):
        """IntVar backing a 'Titelgröße' spinbox, seeded from config[key]
        (falling back to `default`) so the title's rendered size can be
        adjusted from the GUI, same as the text and sub/superscripts."""
        value = first(self.config.get(key), default)
        try:
            value = int(float(value))
        except (TypeError, ValueError):
            value = default
        return tk.IntVar(value=value)

    def _add_title_fontsize_field(self, parent, variable, row, column, **grid_kwargs):
        """Label + Spinbox pair for `variable` (see _title_fontsize_var),
        placed at (row, column) in `parent`."""
        tk.Label(parent, text="Titelgröße:").grid(row=row, column=column, sticky="e", padx=(10, 0), **grid_kwargs)
        tk.Spinbox(parent, from_=6, to=48, width=4, textvariable=variable).grid(
            row=row, column=column + 1, sticky="w", **grid_kwargs
        )

    # -- shared UI pieces --------------------------------------------------
    def _build_ui(self):
        raise NotImplementedError

    def _make_info_text(self, parent, text):
        self.info_text = tk.Text(parent, wrap="word")
        self.info_text.grid(row=0, column=0, sticky="nsew")
        self._set_info_text(text)

    def _set_info_text(self, text):
        self.info_text.delete("1.0", "end")
        self.info_text.insert("1.0", text)

    def _append_info_text(self, text):
        self.info_text.insert("end", "\n" + text)
        self.info_text.see("end")

    def _make_file_list(self, parent, multi=True):
        parent.rowconfigure(1, weight=1)
        parent.columnconfigure(0, weight=1)
        tk.Label(parent, text="Dateiauswahl:", font=("TkDefaultFont", 12, "bold")).grid(
            row=0, column=0, sticky="w"
        )
        self.file_listbox = tk.Listbox(parent, selectmode="extended" if multi else "browse", exportselection=False)
        self.file_listbox.grid(row=1, column=0, sticky="nsew")

    def _add_file_item(self, name, data):
        if name not in self.file_items:
            self.file_listbox.insert("end", name)
        self.file_items[name] = data

    def _selected_data(self, warn_if_empty=True):
        """Selected files' data, or all loaded files when nothing selected."""
        names = [self.file_listbox.get(i) for i in self.file_listbox.curselection()]
        if not names:
            names = list(self.file_items.keys())
        if not names and warn_if_empty:
            messagebox.showwarning("Warnung", "Bitte mindestens eine Datei laden.")
            return None, None
        return names, [self.file_items[n] for n in names if n in self.file_items]

    def _ask_filenames(self, filetypes):
        return filedialog.askopenfilenames(
            title="Wählen Sie eine Datei zur Auswertung aus",
            initialdir=self._standard_path(),
            filetypes=filetypes,
        )

    def edit_config(self):
        messagebox.showinfo(
            f"{self.WINDOW_TITLE} config",
            "Die Config-Bearbeitung ist noch nicht implementiert.\n"
            f"Bitte config.json im Referenzordner anpassen:\n{self.reference_folder}",
        )

    def back_to_selection(self):
        from auswahl import Auswahl

        plt.close("all")
        Auswahl(self.root)
