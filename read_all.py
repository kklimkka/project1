"""Python port of the read_all/*.m file readers.

All functions return plain numpy arrays / lists instead of MATLAB cell
arrays. GUI progress dialogs of the originals are dropped - reading is
fast enough in Python.
"""

import csv
import math
import re

import numpy as np


def read_txt(filepath, header_marker):
    """Port of read_txt.m: skip lines until the header line containing
    `header_marker`, then read whitespace separated numeric rows with 4
    columns. Also extracts a 'Slewrate' value if present above the header.

    Returns (data, slew_rate): data is an (N, 4) float array or None,
    slew_rate is a float (0 if not found).
    """
    slew_rate = 0.0
    delimiter = "," if filepath.lower().endswith(".csv") else None

    with open(filepath, "r", errors="ignore") as f:
        lines = f.readlines()

    header_found = False
    start_idx = 0
    for i, line in enumerate(lines):
        if header_marker in line:
            header_found = True
            start_idx = i + 1
            break
        if not slew_rate and "Slewrate" in line:
            match = re.search(r"\d+\.?\d*", line)
            if match:
                slew_rate = float(match.group(0))

    if not header_found:
        return None, slew_rate

    rows = []
    for line in lines[start_idx:]:
        parts = [p.strip() for p in line.split(delimiter)] if delimiter else line.split()
        parts = [p for p in parts if p]
        if len(parts) < 4:
            continue
        try:
            rows.append([float(p) for p in parts[:4]])
        except ValueError:
            continue

    if not rows:
        return None, slew_rate
    return np.array(rows, dtype=float), slew_rate


def _to_float(value):
    try:
        return float(str(value).replace('"', "").strip())
    except (TypeError, ValueError):
        return math.nan


def read_csv_table(filepath):
    """Read a whole CSV file as a list of row lists (strings)."""
    with open(filepath, "r", errors="ignore", newline="") as f:
        return [row for row in csv.reader(f) if row]


def find_header_row(rows):
    """Port of the header detection in read_csv.m: the header is the last
    row whose first column is not numeric (NaN after conversion)."""
    header_row = 0
    for i, row in enumerate(rows):
        if math.isnan(_to_float(row[0])):
            header_row = i + 1  # 1-based, like MATLAB
    return header_row


def read_csv(filepath, data_lines=None, selected_columns=None):
    """Port of read_csv.m for one file.

    data_lines: None/(start, end) 1-based inclusive on the data region,
                float('inf') allowed as end, or 'last' for only the last row.
    selected_columns: list of 1-based column indices or None for all.

    Returns (data, header_row): data is a list of row lists with floats
    where possible (non-numeric cells like timestamps stay strings),
    header_row is the 1-based index of the last header line.
    """
    rows = read_csv_table(filepath)
    header_row = find_header_row(rows)
    data_rows = rows[header_row:]

    check_last = data_lines == "last"
    if data_lines is None or check_last:
        start, end = 1, float("inf")
    else:
        start, end = data_lines
    start = max(int(start), 1)
    end = len(data_rows) if math.isinf(float(end)) else int(end)
    data_rows = data_rows[start - 1:end]

    if check_last and data_rows:
        data_rows = [data_rows[-1]]

    result = []
    for row in data_rows:
        if selected_columns:
            row = [row[c - 1] if c - 1 < len(row) else "" for c in selected_columns]
        converted = []
        for cell in row:
            value = _to_float(cell)
            converted.append(cell if (math.isnan(value) and str(cell).strip() != "") and not _is_nan_literal(cell) else value)
        result.append(converted)
    return result, header_row


def _is_nan_literal(cell):
    return str(cell).strip().lower() in ("nan", "")


def read_csv_numeric(filepath, data_lines=None, selected_columns=None):
    """Like read_csv but forces a float numpy array (non-numeric -> NaN)."""
    data, header_row = read_csv(filepath, data_lines, selected_columns)
    numeric = [[_to_float(c) for c in row] for row in data]
    return np.array(numeric, dtype=float), header_row


def read_eis_txt(filepath, header_marker):
    """Port of read_eis_txt.m. Returns an (N, 4) array
    [number, frequency, impedance, phase(deg)] or None."""
    with open(filepath, "r", errors="ignore") as f:
        lines = f.readlines()

    header_idx = None
    for i, line in enumerate(lines):
        if header_marker in line:
            header_idx = i
            break

    rows = []
    if header_idx is None:
        # No header: skip first line, columns 1, 2 and 4 of a 10-column file
        for line in lines[1:]:
            parts = line.replace("\t", " ").split()
            if len(parts) < 4:
                continue
            try:
                rows.append([float(parts[0]), float(parts[1]), float(parts[3])])
            except ValueError:
                continue
        if not rows:
            return None
        data = np.array(rows, dtype=float)
        index = np.arange(2, len(data) + 2).reshape(-1, 1)
        return np.hstack([index, data])

    for line in lines[header_idx + 1:]:
        parts = line.replace("\t", " ").split()
        if len(parts) < 4:
            continue
        try:
            rows.append([float(p) for p in parts[:4]])
        except ValueError:
            continue
    if not rows:
        return None
    return np.array(rows, dtype=float)


def read_eis_csv(filepath, header_marker):
    """Port of read_eis_csv.m. Returns an (N, 4) array
    [number, frequency, impedance, phase(deg)] or None. In the CSV format
    the phase is stored in radians and converted to degrees here."""
    with open(filepath, "r", errors="ignore") as f:
        lines = f.readlines()

    header_idx = None
    for i, line in enumerate(lines):
        if header_marker in line:
            header_idx = i
            break
    if header_idx is None:
        return None

    rows = []
    for line in lines[header_idx + 2:]:  # 'HeaderLines', 1 -> skip one extra line
        parts = [p.strip() for p in line.split(",") if p.strip()]
        if len(parts) < 3:
            continue
        try:
            rows.append([float(parts[0]), float(parts[1]), float(parts[2])])
        except ValueError:
            continue
    if not rows:
        return None
    data = np.array(rows, dtype=float)
    index = np.arange(1, len(data) + 1).reshape(-1, 1)
    return np.hstack([index, data[:, [0, 1]], np.degrees(data[:, [2]])])


def read_s_plus_plus_dat(filepath, seek_timestamps):
    """Port of read_s_plus__plus__dat.m.

    The .dat files consist of repeated blocks: one timestamp line followed
    by a fixed number of tab separated numeric grid rows.

    Returns (frames, timestamps): frames is a 3D float array
    (n_frames, rows, cols); timestamps a list of strings (empty when
    seek_timestamps is False - matching the MATLAB behaviour of only
    scanning them for the TD file).
    """
    timestamps = []
    frames = []
    current = []
    with open(filepath, "r", errors="ignore") as f:
        for line in f:
            line = line.rstrip("\n\r")
            if not line.strip():
                continue
            parts = line.split("\t")
            try:
                row = [float(p) for p in parts if p.strip() != ""]
                if not row:
                    raise ValueError
                current.append(row)
            except ValueError:
                # timestamp / non numeric line -> starts a new block
                if current:
                    frames.append(current)
                    current = []
                timestamps.append(line.strip())
    if current:
        frames.append(current)

    if not frames:
        return np.empty((0, 0, 0)), timestamps
    frames = np.array(frames, dtype=float)
    if not seek_timestamps:
        timestamps = []
    return frames, timestamps


def excel_col_to_index(letters):
    """Port of colLetterToIndex: 'A' -> 1, 'D' -> 4, 'AA' -> 27."""
    letters = letters.strip().upper()
    index = 0
    for ch in letters:
        index = index * 26 + (ord(ch) - 64)
    return index


def process_inf(values):
    """Port of processInf: ['1', 'Inf'] -> (1, inf)."""
    result = []
    for v in values:
        if isinstance(v, str):
            v = v.replace('"', "")
            result.append(float("inf") if v.strip().lower() == "inf" else float(v))
        else:
            result.append(float(v))
    return tuple(result)
