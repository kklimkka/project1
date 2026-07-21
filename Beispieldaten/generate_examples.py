"""Generate example measurement files for all evaluation methods.

Creates DUT example files in Beispieldaten/ and reference files in
Referenzen/Referenz1/<Method>/. Run:  python Beispieldaten/generate_examples.py
"""

import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REF = os.path.join(ROOT, "Referenzen", "Referenz1")

rng = np.random.default_rng(42)


def write_txt(path, data, slewrate=None, header="Number Time U[V] I[A]"):
    """Instrument-style txt export: preamble, optional Slewrate, header line
    containing 'Number', then whitespace separated numeric rows."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("Beispieldatei - generiert von generate_examples.py\n")
        if slewrate is not None:
            f.write(f"Slewrate: {slewrate} mV/s\n")
        f.write(header + "\n")
        for i, row in enumerate(data, start=1):
            f.write(f"{i}\t" + "\t".join(f"{v:.6f}" for v in row) + "\n")
    print("wrote", path)


def write_csv(path, rows, header_lines=()):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for line in header_lines:
            f.write(line + "\n")
        for row in rows:
            f.write(",".join(str(v) for v in row) + "\n")
    print("wrote", path)


# ---------------------------------------------------------------- H2-Crossover
def h2_crossover_curve(intercept, slope, noise=0.002):
    u = np.arange(0.05, 0.85, 0.005)
    t = np.arange(len(u)) * (0.005 / 0.00035)
    i = intercept + slope * u + rng.normal(0, noise, len(u))
    # small activation dip at low voltage (looks like the real measurement)
    i -= 0.4 * np.exp(-u / 0.03)
    return np.column_stack([t, u, i])


write_txt(os.path.join(HERE, "H2_Crossover_Beispiel.txt"),
          h2_crossover_curve(0.95, 0.08), slewrate=0.35)
write_txt(os.path.join(REF, "H2_Crossover", "Referenz#1.txt"),
          h2_crossover_curve(0.90, 0.07), slewrate=0.35)
write_txt(os.path.join(REF, "H2_Crossover", "Referenz#2.txt"),
          h2_crossover_curve(0.88, 0.09), slewrate=0.35)


# -------------------------------------------------------------------- CV-ECSA
def cv_fast(cycles=4, scale=1.0, noise=0.01):
    """Fast CV scan: double layer band + H adsorption/desorption peaks."""
    rows = []
    t = 0.0
    for _ in range(cycles):
        up = np.arange(0.07, 0.85, 0.005)
        down = np.arange(0.85, 0.07, -0.005)
        for u_arr, direction in ((up, 1), (down, -1)):
            for u in u_arr:
                i = 0.45 * direction * scale                       # double layer
                i += direction * scale * 1.6 * np.exp(-((u - 0.15) ** 2) / 0.004)  # H peaks
                i += rng.normal(0, noise)
                rows.append([t, u, i])
                t += 0.005 / 0.03
    return np.array(rows)


def cv_slow(noise=0.002):
    """Slow scan: essentially the crossover-limited baseline."""
    up = np.arange(0.07, 0.85, 0.005)
    down = np.arange(0.85, 0.07, -0.005)
    rows = []
    t = 0.0
    for u in np.concatenate([up, down]):
        i = 0.05 + 0.02 * u + rng.normal(0, noise)
        rows.append([t, u, i])
        t += 0.005 / 0.001
    return np.array(rows)


write_txt(os.path.join(HERE, "CV_fast_Beispiel.txt"), cv_fast(), slewrate=30)
write_txt(os.path.join(HERE, "CV_slow_Beispiel.txt"), cv_slow(), slewrate=1)
write_txt(os.path.join(REF, "CV_ECSA", "schneller_Scan", "Referenz#1.txt"),
          cv_fast(scale=1.1), slewrate=30)
write_txt(os.path.join(REF, "CV_ECSA", "langsamer_Scan", "Referenz#1.txt"),
          cv_slow(), slewrate=1)


# -------------------------------------------------------------------- Leckage
def leckage_rows(n_rows, base):
    """Leak check CSV: columns A..M; D,E,F,G / I,J,L,M are the pressure pairs
    used for the external/internal anode/cathode leak rates."""
    rows = []
    for i in range(n_rows):
        d, e = base[0], base[1]
        f_, g = d - base[2] / 100, e - base[3] / 100
        i_, j = base[4], base[5]
        l, m = i_ - base[6] / 100, j - base[7] / 100
        rows.append([i + 1, f"2026-07-{i % 28 + 1:02d}", 25.0,
                     f"{d:.5f}", f"{e:.5f}", f"{f_:.5f}", f"{g:.5f}", 0,
                     f"{i_:.5f}", f"{j:.5f}", 0, f"{l:.5f}", f"{m:.5f}"])
    return rows


leckage_header = ["Leak_Check - logger 2", "Index,Datum,Temp,pA1,pC1,pA2,pC2,x,piA1,piC1,y,piA2,piC2"]
# base: pA1, pC1, ext_anode, ext_cathode, piA1, piC1, int_anode, int_cathode (leak rates in mbar/min)
write_csv(os.path.join(HERE, "Leckage_Beispiel.csv"),
          leckage_rows(5, [2.5, 2.5, 1.8, 2.4, 1.5, 1.5, 0.6, 0.9]), leckage_header)
write_csv(os.path.join(REF, "Leckage", "Referenz#1.csv"),
          leckage_rows(5, [2.5, 2.5, 1.2, 1.5, 1.5, 1.5, 0.4, 0.5]), leckage_header)
write_csv(os.path.join(REF, "Leckage", "Referenz#2.csv"),
          leckage_rows(5, [2.5, 2.5, 1.0, 1.3, 1.5, 1.5, 0.3, 0.6]), leckage_header)


# ---------------------------------------------------------------- OCV-FallOff
def ocv_voltage(n=3000, ocv=0.98, tau=900.0):
    v = np.empty(n)
    v[:600] = 0.04 + rng.normal(0, 0.003, 600)             # H2/N2 short-circuit
    v[600:640] = np.linspace(0.04, ocv, 40)                # rise
    v[640:900] = ocv + rng.normal(0, 0.004, 260)           # OCV plateau
    t = np.arange(n - 900)
    v[900:] = ocv * np.exp(-t / tau) + rng.normal(0, 0.003, n - 900)  # fall-off
    return np.clip(v, 0, None)


def ocv_rows(v):
    return [[i + 1, 0, 0, 0, 0, 0, f"{vi:.5f}", 0] for i, vi in enumerate(v)]


ocv_header = ["OCV-FallOff Beispielmessung", "Index,c2,c3,c4,c5,c6,Voltage,c8"]
write_csv(os.path.join(HERE, "OCV_FallOff_Beispiel.csv"), ocv_rows(ocv_voltage()), ocv_header)
write_csv(os.path.join(REF, "OCV_FallOff", "Referenz#1.csv"),
          ocv_rows(ocv_voltage(ocv=1.0, tau=1100.0)), ocv_header)


# ------------------------------------------------------------------------- PK
def pk_csv_rows(temp=60, area=273.0, u0=0.95, r=0.10):
    """Full test-bench CSV (63 columns). The PK config selects columns
    [2, 7, ..., 63]; within the selection: col2 = cell voltage (orig. 7),
    col5 = current set (orig. 14), col6 = current density (orig. 15),
    col30 = coolant temp set (orig. 61)."""
    steps = [546, 464, 382, 300, 218, 136, 55]  # current set [A], descending
    samples_per_step = 80
    rows = []
    t = 0.0
    for step in steps:
        for _ in range(samples_per_step):
            row = ["0"] * 63
            density = step / area
            voltage = u0 - r * density + rng.normal(0, 0.002)
            row[1] = f"{t:.1f}"                    # col 2: elapsed time
            row[6] = f"{voltage:.5f}"              # col 7: cell voltage
            row[13] = f"{step}"                    # col 14: current set
            row[14] = f"{density + rng.normal(0, 0.002):.5f}"  # col 15: current density
            row[60] = f"{temp}"                    # col 61: coolant temp set
            rows.append(row)
            t += 0.5
    return rows


pk_header = ["PK Beispielmessung", ",".join(f"col{i}" for i in range(1, 64))]
write_csv(os.path.join(HERE, "PK_Beispiel.csv"), pk_csv_rows(u0=0.94, r=0.11), pk_header)

# PK references: plain 3-column numeric CSV [voltage, current set, current density]
def pk_ref_rows(u0=0.96, r=0.095, area=273.0):
    steps = [546, 464, 382, 300, 218, 136, 55]
    rows = []
    for step in steps:
        for _ in range(80):
            density = step / area
            rows.append([f"{u0 - r * density + rng.normal(0, 0.002):.5f}",
                         f"{step}", f"{density + rng.normal(0, 0.002):.5f}"])
    return rows


for n in (1, 2, 3):
    write_csv(os.path.join(REF, "PK", f"PK{n}", "Referenz#1.csv"), pk_ref_rows())


# ---------------------------------------------------------------- Load Points
def load_points_rows():
    """Test-bench CSV with 77 columns; the config selects columns
    [2, 7, ..., 63, 77]. Original col 2 = elapsed time, col 7 = cell voltage,
    col 13 = current, col 77 = trigger (3311..3315)."""
    triggers = [3311, 3312, 3313, 3314, 3315]
    rows = []
    t = 0.0
    for k, trig in enumerate(triggers):
        for phase, n in (("hold", 130), ("pause", 20)):
            for _ in range(n):
                row = ["0"] * 77
                row[1] = f"{t:.1f}"
                current = 100 + 80 * k if phase == "hold" else 5
                voltage = 0.9 - 0.0008 * current + rng.normal(0, 0.002)
                row[6] = f"{voltage:.5f}"       # col 7: cell voltage
                row[12] = f"{current:.2f}"      # col 13: current
                row[76] = f"{trig}" if phase == "hold" else "0"
                rows.append(row)
                t += 0.5
    return rows


lp_header = ["Load Points Beispielmessung", ",".join(f"col{i}" for i in range(1, 78))]
write_csv(os.path.join(HERE, "LoadPoints_Beispiel.csv"), load_points_rows(), lp_header)


# ------------------------------------------------------------------------ EIS
def eis_spectrum(r0=0.0004, r1=0.0011, c=0.15):
    freq = np.logspace(4, -1, 40)
    w = 2 * np.pi * freq
    z = r0 + r1 / (1 + 1j * w * r1 * c)
    imp = np.abs(z)
    phase = np.degrees(np.angle(z))
    return freq, imp, phase


def write_eis_txt(path, r0, r1):
    freq, imp, phase = eis_spectrum(r0, r1)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("EIS Beispielmessung\n")
        f.write("Number\tFrequency[Hz]\tImpedance[Ohm]\tPhase[deg]\n")
        for i, (fr, im, ph) in enumerate(zip(freq, imp, phase), start=1):
            f.write(f"{i}\t{fr:.6e}\t{im:.6e}\t{ph:.6e}\n")
    print("wrote", path)


write_eis_txt(os.path.join(HERE, "EIS_Beispiel_01.txt"), 0.0004, 0.0011)
write_eis_txt(os.path.join(HERE, "EIS_Beispiel_02.txt"), 0.00045, 0.0012)

freq, imp, phase = eis_spectrum(0.00042, 0.00115)
with open(os.path.join(HERE, "EIS_Beispiel_03.csv"), "w", encoding="utf-8") as f:
    f.write("EIS Beispielmessung (CSV)\n")
    f.write("Frequency,Impedance,Phase,Extra1,Extra2,Extra3,Extra4\n")
    f.write("[Hz],[Ohm],[rad],,,,\n")
    for fr, im, ph in zip(freq, imp, phase):
        f.write(f"{fr:.6e},{im:.6e},{np.radians(ph):.6e},0,0,0,0\n")
print("wrote", os.path.join(HERE, "EIS_Beispiel_03.csv"))


# ------------------------------------------------------------------------ S++
def spp_dat(path, kind, n_frames=20, rows=8, cols=10):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for frame in range(n_frames):
            second = frame % 60
            minute = frame // 60
            f.write(f"07/10/2026 10:{minute:02d}:{second:02d} AM.000\n")
            y, x = np.mgrid[0:rows, 0:cols]
            if kind == "cd":
                base = -(1.2 + 0.02 * frame)
                grid = base * (1 - 0.25 * ((x - cols / 2) ** 2 + (y - rows / 2) ** 2)
                               / ((cols / 2) ** 2 + (rows / 2) ** 2))
            else:
                grid = 65 + 0.1 * frame + 4 * y / rows + rng.normal(0, 0.2, (rows, cols))
            for r in range(rows):
                f.write("\t".join(f"{v:.4f}" for v in grid[r]) + "\n")
    print("wrote", path)


spp_dat(os.path.join(HERE, "SPP_CD_Beispiel.dat"), "cd")
spp_dat(os.path.join(HERE, "SPP_TD_Beispiel.dat"), "td")


def spp_csv_rows(n=20):
    rows = []
    for i in range(n):
        row = ["0"] * 63
        second = i % 60
        minute = i // 60
        row[0] = f"07/10/2026 10:{minute:02d}:{second:02d} AM.000"
        row[14] = f"{1.2 + 0.02 * i:.4f}"    # current density (Spalten pos 2)
        row[6] = f"{0.68 - 0.002 * i:.4f}"   # voltage (Spalten pos 3)
        row[12] = f"{330 + 5 * i:.1f}"       # current (Spalten pos 18)
        rows.append(row)
    return rows


spp_header = ["S++ Beispielmessung", ",".join(f"col{i}" for i in range(1, 64))]
write_csv(os.path.join(HERE, "SPP_Beispiel.csv"), spp_csv_rows(), spp_header)

print("\nAlle Beispieldateien wurden erstellt.")
