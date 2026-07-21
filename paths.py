"""Cross-platform path handling for the tool.

The project is used from Windows and macOS (synced via OneDrive), so paths
stored in JSON files (currentReference.json, config.json StandardPfad) may
come from the other OS: different separator ('\\' vs '/') AND a different
absolute root (C:\\Users\\... vs /Users/...).

`resolve()` makes such stored paths usable on the current machine,
`to_portable()` converts a path to the form that should be stored:
relative to the project folder where possible, always with forward slashes.
"""

import os
import re

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))


def _split(path):
    """Split a path from either OS into its components."""
    path = str(path).strip().strip('"')
    # drop drive letters ('c:') and leading separators, unify separators
    path = re.sub(r"^[A-Za-z]:", "", path)
    return [p for p in re.split(r"[\\/]+", path) if p and p != "."]


def normalize(path):
    """Rewrite separators from either OS to the current OS (no resolving)."""
    if not path:
        return path
    text = str(path).strip().strip('"')
    drive = ""
    match = re.match(r"^[A-Za-z]:", text)
    if match:
        drive = match.group(0)
    parts = _split(path)
    if text.startswith(("\\\\", "//")):
        # UNC network share (\\server\share\...): keep the double-sep root
        return os.sep * 2 + os.sep.join(parts)
    is_abs = bool(drive) or text.startswith(("/", "\\"))
    root = drive + os.sep if is_abs else ""
    return root + os.sep.join(parts)


def resolve(path, must_exist=True):
    """Resolve a stored path on the current machine.

    Tries, in order:
    1. the path as-is (separators normalized),
    2. the path interpreted relative to the project folder,
    3. the longest tail of the path found under the project folder
       (handles absolute paths saved on the other OS, e.g.
       'c:\\Users\\x\\OneDrive - TUM\\py\\Referenzen\\Referenz1' ->
       '<project>/Referenzen/Referenz1').

    Returns an absolute path, or None if nothing exists (when must_exist).
    """
    if not path:
        return None
    parts = _split(path)
    if not parts:
        return None

    normalized = normalize(path)
    if os.path.isabs(normalized) and os.path.exists(normalized):
        return os.path.abspath(normalized)

    relative = os.path.join(PROJECT_DIR, *parts)
    if os.path.exists(relative):
        return relative

    for i in range(1, len(parts)):
        candidate = os.path.join(PROJECT_DIR, *parts[i:])
        if os.path.exists(candidate):
            return candidate

    if must_exist:
        return None
    return os.path.abspath(normalized)


def to_portable(path):
    """Form in which a path should be written to JSON: relative to the
    project folder if possible, always with forward slashes."""
    if not path:
        return path
    path = os.path.abspath(normalize(path))
    try:
        rel = os.path.relpath(path, PROJECT_DIR)
    except ValueError:  # different drive on Windows
        rel = None
    if rel is not None and not rel.startswith(".."):
        path = rel
    return path.replace(os.sep, "/")
