"""Python port of Auswahl.m - the tool's start/selection window.

Ported with tkinter. Layout is a direct translation of the original MATLAB
uifigure positioning logic (absolute pixel positions, rescaled on resize),
just converted from MATLAB's bottom-left origin to tkinter's top-left origin.
"""

import json
import os
import tkinter as tk
from tkinter import messagebox

from PIL import Image, ImageTk

import paths

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BILDER_DIR = os.path.join(SCRIPT_DIR, "Bilder")
AUSWERTUNGEN_DIR = os.path.join(SCRIPT_DIR, "Auswertungen")
REFERENZEN_DIR = os.path.join(SCRIPT_DIR, "Referenzen")
CURRENT_REFERENCE_FILE = os.path.join(REFERENZEN_DIR, "currentReference.json")

METHODS = [
    "DCR", "Leckage", "OCV_FallOff", "CV_ECSA", "H2_Crossover",
    "PK", "Load__Points", "EIS", "S_plus__plus_",
]

MARGIN = 20
LABEL_HEIGHT = 20
BTN_WIDTH = 273.3333
BTN_HEIGHT = 160
EXIT_BTN_HEIGHT = 50
NUM_COLUMNS = 3
WINDOW_WIDTH = 900
WINDOW_HEIGHT = 625


def method_label_text(method):
    text = method.replace("_plus_", "+")
    text = text.replace("__", " ")
    text = text.replace("_", "-")
    return text


class Auswahl:
    def __init__(self, root=None):
        self.widgets = {}
        self._images = {}  # keep PhotoImage refs alive

        if root is None:
            self.root = tk.Tk()
            self._center_window()
        else:
            self.root = root
            for child in list(self.root.children.values()):
                child.destroy()

        self.root.title("Auswahlfenster")
        self.root.resizable(True, True)

        self.ref_dir = self.load_reference_path()

        if self.ref_dir is None:
            self.display_info()
        else:
            self.create_buttons_and_labels()

        self.create_exit_and_reference_buttons()
        self.display_current_reference()

        self.root.bind("<Configure>", self._on_resize)
        self.root.after_idle(self.resize_ui_components)

    def _center_window(self):
        screen_w = self.root.winfo_screenwidth()
        screen_h = self.root.winfo_screenheight()
        x = int((screen_w - WINDOW_WIDTH) / 2)
        y = int((screen_h - WINDOW_HEIGHT) / 2)
        self.root.geometry(f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}+{x}+{y}")

    # -- coordinate helper: MATLAB positions use a bottom-left origin -------
    def _place(self, widget, tag, x, y, w, h):
        win_h = self._current_window_height()
        tk_y = win_h - y - h
        widget.place(x=x, y=tk_y, width=max(1, w), height=max(1, h))
        self.widgets[tag] = widget

    def _current_window_height(self):
        h = self.root.winfo_height()
        return h if h > 1 else WINDOW_HEIGHT

    def _current_window_width(self):
        w = self.root.winfo_width()
        return w if w > 1 else WINDOW_WIDTH

    # -- setup ---------------------------------------------------------
    def create_buttons_and_labels(self):
        for i, method in enumerate(METHODS, start=1):
            image_path = os.path.join(BILDER_DIR, f"{method}.PNG")
            btn_x, btn_y = self._button_pos(
                MARGIN, MARGIN, BTN_HEIGHT, i, BTN_WIDTH, LABEL_HEIGHT,
                self._current_window_height(),
            )
            self._create_button_and_label(image_path, method, btn_x, btn_y)

    def _load_icon(self, image_path, method):
        # Source images are much larger than the button (e.g. ~1900x1070px vs
        # 273x160px). Without downscaling, Tk clips the image to the button's
        # placed size instead of showing it whole, and the button's internal
        # size request (based on the oversized image) can end up mismatched
        # with the placed hit-test area, making clicks unreliable. Scaling
        # the icon down to exactly fit the button avoids both problems.
        if not os.path.isfile(image_path):
            return None
        try:
            image = Image.open(image_path).convert("RGBA")
        except OSError:
            return None

        box_w, box_h = int(BTN_WIDTH), int(BTN_HEIGHT)
        image.thumbnail((box_w, box_h), Image.LANCZOS)

        canvas = Image.new("RGBA", (box_w, box_h), (0, 0, 0, 0))
        offset = ((box_w - image.width) // 2, (box_h - image.height) // 2)
        canvas.paste(image, offset, image)

        icon = ImageTk.PhotoImage(canvas)
        self._images[method] = icon
        return icon

    def _create_button_and_label(self, image_path, method, btn_x, btn_y):
        icon = self._load_icon(image_path, method)

        btn = tk.Button(
            self.root,
            text="" if icon else method_label_text(method),
            image=icon if icon else None,
            compound="center",
            command=lambda m=method: self.method_action(m),
        )
        self._place(btn, method, btn_x, btn_y, BTN_WIDTH, BTN_HEIGHT)

        label_y = btn_y - LABEL_HEIGHT
        label = tk.Label(self.root, text=method_label_text(method), anchor="center")
        self._place(label, f"{method}label", btn_x, label_y, BTN_WIDTH, LABEL_HEIGHT)

    def create_exit_and_reference_buttons(self):
        win_w = WINDOW_WIDTH
        win_h = WINDOW_HEIGHT
        new_margin = MARGIN * (win_w / WINDOW_WIDTH)
        new_btn_width = 200 * (win_w / WINDOW_WIDTH)
        new_exit_btn_height = EXIT_BTN_HEIGHT * (win_h / WINDOW_HEIGHT)

        exit_btn = tk.Button(self.root, text="Tool Beenden", command=self.close_and_cleanup)
        self._place(
            exit_btn, "Beenden",
            win_w - new_btn_width - new_margin, new_margin / 2,
            new_btn_width, new_exit_btn_height,
        )

        ref_btn = tk.Button(self.root, text="Referenzen", command=self.open_reference_management)
        self._place(ref_btn, "Referenzen", new_margin, new_margin / 2, new_btn_width, new_exit_btn_height)

        help_btn = tk.Button(self.root, text="Help", command=self.help_button)
        self._place(
            help_btn, "Help",
            (win_w - new_btn_width) / 2, 15,
            new_btn_width, new_exit_btn_height / 2,
        )

    def display_current_reference(self):
        if self.ref_dir:
            folder_name = os.path.basename(os.path.normpath(self.ref_dir))
            text = f"aktuelle Referenz: {folder_name}"
        else:
            text = "Bitte Referenz wählen."
        label = tk.Label(self.root, text=text, anchor="center")
        self._place(
            label, "refLabel",
            MARGIN + BTN_WIDTH, MARGIN / 2 + EXIT_BTN_HEIGHT - LABEL_HEIGHT,
            WINDOW_WIDTH - 2 * (MARGIN + BTN_WIDTH), LABEL_HEIGHT,
        )

    def display_info(self):
        label = tk.Label(
            self.root,
            text="Bitte wählen Sie einen gültigen Referenzordner aus.",
            font=("TkDefaultFont", 10, "bold"),
            anchor="center",
        )
        self._place(
            label, "noRef",
            MARGIN, WINDOW_HEIGHT - MARGIN - LABEL_HEIGHT,
            WINDOW_WIDTH - 2 * MARGIN, LABEL_HEIGHT,
        )

    # -- resize handling -------------------------------------------------
    def _on_resize(self, event):
        if event.widget is self.root:
            self.resize_ui_components()

    def resize_ui_components(self):
        win_w = self._current_window_width()
        win_h = self._current_window_height()

        new_width_margin = MARGIN * (win_w / WINDOW_WIDTH)
        new_height_margin = MARGIN * (win_h / WINDOW_HEIGHT)
        new_label_height = LABEL_HEIGHT * (win_h / WINDOW_HEIGHT)
        new_btn_width = BTN_WIDTH * (win_w / WINDOW_WIDTH)
        new_btn_height = BTN_HEIGHT * (win_h / WINDOW_HEIGHT)
        new_exit_btn_height = EXIT_BTN_HEIGHT * (win_h / WINDOW_HEIGHT)

        self._resize_component(
            "noRef",
            new_width_margin, win_h - new_height_margin - new_label_height,
            win_w - 2 * new_width_margin, LABEL_HEIGHT,
        )

        for i, method in enumerate(METHODS, start=1):
            btn_x, btn_y = self._button_pos(
                new_width_margin, new_height_margin, new_btn_height, i, new_btn_width, new_label_height,
                win_h,
            )
            self._resize_component(method, btn_x, btn_y, new_btn_width, new_btn_height)
            label_y = btn_y - new_label_height
            self._resize_component(f"{method}label", btn_x, label_y, new_btn_width, new_label_height)

        if new_exit_btn_height < LABEL_HEIGHT:
            new_exit_btn_height = LABEL_HEIGHT

        self._resize_component(
            "Beenden",
            win_w - new_btn_width - new_width_margin, new_height_margin / 2,
            new_btn_width, new_exit_btn_height,
        )
        self._resize_component(
            "Referenzen",
            new_width_margin, new_height_margin / 2,
            new_btn_width, new_exit_btn_height,
        )
        self._resize_component(
            "refLabel",
            new_width_margin + new_btn_width,
            new_height_margin / 2 + new_exit_btn_height - LABEL_HEIGHT,
            win_w - 2 * (new_width_margin + new_btn_width), LABEL_HEIGHT,
        )
        self._resize_component(
            "Help",
            (win_w - new_btn_width) / 2, new_height_margin / 2,
            new_btn_width, new_exit_btn_height / 2,
        )

    def _resize_component(self, tag, x, y, w, h):
        widget = self.widgets.get(tag)
        if widget is None or not widget.winfo_exists():
            return
        win_h = self._current_window_height()
        tk_y = win_h - y - h
        widget.place(x=x, y=tk_y, width=max(1, w), height=max(1, h))

    @staticmethod
    def _button_pos(new_width_margin, new_height_margin, btn_height, number, btn_width, label_height,
                    window_height=WINDOW_HEIGHT):
        # window_height must be the CURRENT height: using the 625px design
        # constant here made the button grid overlap the bottom button row
        # (created later, hence stacked on top) whenever the window was taller
        # than the design size - that is what made buttons "randomly"
        # unclickable.
        start_x = new_width_margin
        start_y = window_height - btn_height - new_height_margin / 2
        col = (number - 1) % NUM_COLUMNS
        row = (number - 1) // NUM_COLUMNS
        btn_x = start_x + col * (btn_width + new_width_margin)
        btn_y = start_y - row * (btn_height + new_height_margin + label_height / 4)
        return btn_x, btn_y

    # -- callbacks --------------------------------------------------------
    def method_action(self, method):
        if self.ref_dir is None:
            messagebox.showwarning("Warnung", "Bitte zuerst einen gültigen Referenzordner wählen.")
            return

        window_classes = {
            "DCR": ("dcr", "DCRWindow"),
            "Leckage": ("leckage", "LeckageWindow"),
            "OCV_FallOff": ("ocv_falloff", "OCVFallOffWindow"),
            "CV_ECSA": ("cv_ecsa", "CVECSAWindow"),
            "H2_Crossover": ("h2_crossover", "H2CrossoverWindow"),
            "PK": ("pk", "PKWindow"),
            "Load__Points": ("load_points", "LoadPointsWindow"),
            "EIS": ("eis", "EISWindow"),
            "S_plus__plus_": ("s_plus_plus", "SPlusPlusWindow"),
        }
        module_name, class_name = window_classes[method]
        # Drop our resize handler before the method window takes over the
        # root; otherwise it keeps firing on destroyed widgets.
        self.root.unbind("<Configure>")
        module = __import__(module_name)
        getattr(module, class_name)(self.root, self.ref_dir)

    def close_and_cleanup(self):
        self.root.destroy()

    def help_button(self):
        messagebox.showinfo(
            "Information",
            ">> \"aktuelle Referenz:\" zeigt den aktuell für Auswertungen gewählten Referenzdatensatz\n"
            ">> Methodenbuttons öffnen Methoden\n"
            ">> \"Referenzen\" öffnet die Referenzverwaltung\n"
            ">>> \"Standardconfig anpassen\" öffnet ein Menü in dem die Standard-Config-Dateien "
            "für die Methoden angepasst werden können\n"
            ">>> \"Referenz importieren/exportieren\" ermöglicht den import/export eines Referenzsatzes als .zip\n"
            ">>> \"Referenz bearbeiten\" öffnet ein Bearbeitungsmenü für die Referenzen\n"
            ">>> \"Neue Referenz\" erstellt einen neuen Referenzdatensatz\n"
            ">>>> Im Referenzdatensatz gibt es vorerst nur eine config-Datei und leere Methodenordner\n"
            ">>>>> Die \"Allgemeine Config\" muss der Zelle entsprechend angepasst werden\n"
            ">>>>> Danach erst Dateien in die Methodenordner hochladen\n"
            ">>>>>> Methoden-Configs können auch in der Methode selber noch bearbeitet werden.",
        )

    def open_reference_management(self):
        import referenzverwaltung

        # Refresh once the management window closes, mirroring Auswahl(fig)
        # in the original (the reference selection or list may have changed).
        referenzverwaltung.ReferenceManager(self.root, on_close=lambda: Auswahl(self.root))

    def load_reference_path(self):
        try:
            if not os.path.isfile(CURRENT_REFERENCE_FILE):
                return None
            with open(CURRENT_REFERENCE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            # Stored paths may come from the other OS (Windows <-> macOS);
            # resolve re-anchors them to this machine's project folder.
            ref_dir = paths.resolve(data.get("refDir"))
            if not ref_dir or not os.path.isdir(ref_dir):
                return None
            self.save_reference_path(ref_dir)
            return ref_dir
        except (OSError, json.JSONDecodeError) as exc:
            messagebox.showerror("Fehler beim Laden des Referenzordnerpfads", str(exc))
            return None

    @staticmethod
    def save_reference_path(ref_dir):
        """Store the reference folder portably (project-relative, forward
        slashes) so the file works on Windows and macOS alike."""
        try:
            with open(CURRENT_REFERENCE_FILE, "w", encoding="utf-8") as f:
                json.dump({"refDir": paths.to_portable(ref_dir)}, f, indent=2)
        except OSError as exc:
            messagebox.showerror("Fehler beim Speichern des Referenzordnerpfads", str(exc))


def main():
    app = Auswahl()
    app.root.mainloop()


if __name__ == "__main__":
    main()
