"""Smoke tests for the ported evaluation methods.

Reads the example files from Beispieldaten/ and Referenzen/Referenz1/,
runs each method's calculations, checks the results against the values the
examples were generated with, and saves test plots to
Beispieldaten/test_plots/.  Run:  python test_methods.py
"""

import json
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

import read_all
import leckage
import ocv_falloff
import h2_crossover
import cv_ecsa
import pk
import load_points
import eis
import s_plus_plus

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(ROOT, "Beispieldaten")
REF = os.path.join(ROOT, "Referenzen", "Referenz1")
PLOTS = os.path.join(DATA, "test_plots")
os.makedirs(PLOTS, exist_ok=True)

CONFIG = json.load(open(os.path.join(REF, "config.json"), encoding="utf-8"))
HEADER = CONFIG["read_txt"]["HeaderDerNurInZeileVorMessdatenIst"]

passed = []
failed = []


def check(name, condition, detail=""):
    (passed if condition else failed).append(name)
    print(f"{'PASS' if condition else 'FAIL'}  {name}  {detail}")


def save(fig, name):
    fig.savefig(os.path.join(PLOTS, name), dpi=110)
    plt.close(fig)
    print(f"plot  {name}")


# ------------------------------------------------------------------ DCR (already ported)
dcr_data, _ = read_all.read_txt(os.path.join(DATA, "DUT_Beispiel.txt"), HEADER)
check("DCR: DUT_Beispiel.txt lesbar", dcr_data is not None and dcr_data.shape[1] == 4,
      f"shape={None if dcr_data is None else dcr_data.shape}")

# ------------------------------------------------------------------ Leckage
rows, _ = read_all.read_csv_numeric(
    os.path.join(DATA, "Leckage_Beispiel.csv"), "last",
    [read_all.excel_col_to_index(c) for c in "D,E,F,G,I,J,L,M".split(",")],
)
ea, ec, ia, ic = leckage.calculate_leakage(rows[-1])
check("Leckage: externe Anode ~ 1.8", abs(ea - 1.8) < 0.01, f"{ea:.4f}")
check("Leckage: interne Kathode ~ 0.9", abs(ic - 0.9) < 0.01, f"{ic:.4f}")

fig, ax = plt.subplots()
leckage._gradient_bar(ax, 1, ea, (0.75, 0, 0))
leckage._gradient_bar(ax, 2, ec, (0, 0.44, 0.75))
ax.set_xlim(0.5, 2.5); ax.set_ylim(-2, 6)
ax.set_title("Leckage Beispiel (extern)")
save(fig, "leckage.png")

# ------------------------------------------------------------------ OCV-FallOff
ocv, _ = read_all.read_csv_numeric(os.path.join(DATA, "OCV_FallOff_Beispiel.csv"), None, [7])
voltage = ocv[:, 0]
start = ocv_falloff.find_start(voltage, 0.1)
check("OCV: Grenzwert-Index im Anstieg (600-641)", 600 <= start <= 641, f"start={start}")
x_min, x_max, err = ocv_falloff.process_x_axis_limits("auto", "auto", len(voltage), start - 50, 50, 2900, 50)
check("OCV: x-Limits ohne Fehler", err == "" and x_max > x_min, f"[{x_min}, {x_max}]")

fig, ax = plt.subplots(figsize=(10, 5))
ax.plot(np.arange(len(voltage)) - start, voltage, "b-", label="DUT")
ax.set_ylim(0, 1.2)
ax.set_title("OCV-FallOff Beispiel")
ax.legend()
save(fig, "ocv_falloff.png")

# ------------------------------------------------------------------ H2-Crossover
h2, slew = read_all.read_txt(os.path.join(DATA, "H2_Crossover_Beispiel.txt"), HEADER)
check("H2: Slewrate erkannt", abs(slew - 0.35) < 1e-9, f"{slew}")
u, i = h2[:, 2], h2[:, 3]
start, stop = h2_crossover.find_limits(u, 0.3, 0.6)
p = np.polyfit(u[start:stop + 1], i[start:stop + 1], 1)
i_cross = h2_crossover.crossover_current(p[1], 273)
# generated with intercept 0.95 A - the exp-dip is negligible above 0.3 V
check("H2: I_H2-Crossover ~ 0.95*1000/273", abs(i_cross - 0.95 * 1000 / 273) < 0.15, f"{i_cross:.3f} mA/cm²")

fig, ax = plt.subplots(figsize=(10, 5))
ax.plot(u, i, ".", ms=2, label="Messung")
x_fit = np.linspace(0, u.max(), 100)
ax.plot(x_fit, np.polyval(p, x_fit), "r-", label=f"Fit: y={p[0]:.3f}x+{p[1]:.3f}")
ax.set_title(f"H2-Crossover Beispiel (I ≈ {i_cross:.2f} mA/cm²)")
ax.legend()
save(fig, "h2_crossover.png")

# ------------------------------------------------------------------ CV-ECSA
fast, fast_slew = read_all.read_txt(os.path.join(DATA, "CV_fast_Beispiel.txt"), HEADER)
slow, _ = read_all.read_txt(os.path.join(DATA, "CV_slow_Beispiel.txt"), HEADER)
cx, cy = cv_ecsa.split_cycles(fast[:, 2], fast[:, 3])
check("CV: 4 Zyklen erkannt", len(cx) == 4, f"{len(cx)} Zyklen")
new_x, new_y = cv_ecsa.compare_fast_and_slow(cx[3], cy[3], slow[:, 2], slow[:, 3])
i_dl_f, i_dl_b = cv_ecsa.find_dl(new_x, new_y, CONFIG["CV_ECSA"]["SpannungsbereichFuerDLSuche"])
ads, des, mean = cv_ecsa.ecsa(new_x, new_y, i_dl_f, i_dl_b, 0.07, 0.07, fast_slew, 0.175, 273)
check("CV: ECSA endlich und > 0", np.isfinite(mean) and mean > 0, f"ECSA={mean:.2f} m²/gPt (ads={ads:.2f}, des={des:.2f})")

fig, ax = plt.subplots(figsize=(10, 5))
ax.plot(cx[3], cy[3], "--", label="fast")
ax.plot(slow[:, 2], slow[:, 3], ":", label="slow")
ax.plot(new_x, new_y, "-", label="corrected")
ax.axhline(i_dl_f, color="r", ls=":"); ax.axhline(i_dl_b, color="g", ls=":")
ax.set_title(f"CV-ECSA Beispiel (ECSA-Ø ≈ {mean:.1f} m²/gPt)")
ax.legend()
save(fig, "cv_ecsa.png")

# ------------------------------------------------------------------ PK
pk_config = CONFIG["PK"]
lines = read_all.process_inf(pk_config["Zeilen"])
pk_data, _ = read_all.read_csv_numeric(os.path.join(DATA, "PK_Beispiel.csv"), lines, pk_config["Spalten"])
window = int(pk_config["MWAbSekundenVor"] * pk_config["MesswerteProSekunde"] - 1)
entry = pk.calc_pk_table(pk_data, pk_config, window)
check("PK: PK1 berechnet", entry["PK1"] is not None,
      f"{0 if entry['PK1'] is None else len(entry['PK1']['avgCurrents'])} Lastpunkte")
check("PK: PK2 leer (Temp 80 fehlt)", entry["PK2"] is None)
pk1 = entry["PK1"]
check("PK: 7 Lastpunkte", len(pk1["avgCurrents"]) == 7, f"{len(pk1['avgCurrents'])}")
check("PK: Spannungen plausibel (0.7-1.0 V)",
      np.all((pk1["avgVoltages"] > 0.7) & (pk1["avgVoltages"] < 1.0)),
      f"U={np.round(pk1['avgVoltages'], 3)}")

ref, _ = read_all.read_csv_numeric(os.path.join(REF, "PK", "PK1", "Referenz#1.csv"))
idx = pk.find_indices(ref[:, 1])
ref_vals = [{
    "avgCurrents": pk.average_values(ref[:, 2], idx, window),
    "avgVoltages": pk.average_values(ref[:, 0], idx, window),
}]
losses, no_loss = pk.calc_losses(ref_vals, [pk1["avgVoltages"]], [pk1["avgCurrents"]])
check("PK: Verluste berechnet", losses.shape[1] == 1, f"max Verlust={losses.max():.2f}%")

fig, ax = plt.subplots(figsize=(10, 5))
ax.plot(ref_vals[0]["avgCurrents"], ref_vals[0]["avgVoltages"], "--o", color="grey", label="Referenz")
ax.plot(pk1["avgCurrents"], pk1["avgVoltages"], "--o", color="b", label="DUT")
ax.set_title("PK Beispiel"); ax.set_xlabel("i [A/cm²]"); ax.set_ylabel("U [V]")
ax.legend()
save(fig, "pk.png")

# ------------------------------------------------------------------ Load Points
lp_config = CONFIG["Load__Points"]
lines = read_all.process_inf(lp_config["Zeilen"])
lp_data, _ = read_all.read_csv_numeric(os.path.join(DATA, "LoadPoints_Beispiel.csv"), lines, lp_config["Spalten"])
headers = lp_config["Header"]
trigger_col = headers.index("Trigger")
index_arrays, trigger_names = load_points.find_trigger_indices(
    lp_data[:, trigger_col], lp_config["Trigger"], lp_config["TriggerNames"])
check("LoadPoints: alle 5 Trigger gefunden", len(trigger_names) == 5, f"{trigger_names}")
window = int(lp_config["MWAbSekundenVor"] * lp_config["MesswerteProSekunde"] - 1)
avg_arrays = load_points.all_avg(lp_data, index_arrays, window)
strom_idx = lp_config["StromIndex"] - 1
currents = [a[0, strom_idx] for a in avg_arrays]
check("LoadPoints: Stromstufen gemittelt (100..420 A)",
      all(90 < c < 430 for c in currents), f"I={np.round(currents, 1)}")

fig, ax = plt.subplots(figsize=(10, 5))
zeit_idx = lp_config["ZeitIndex"] - 1
ax.plot(lp_data[:, zeit_idx], lp_data[:, strom_idx], label="Current")
ax2 = ax.twinx()
ax2.plot(lp_data[:, zeit_idx], lp_data[:, lp_config["SpannungsIndex"] - 1], color="k", label="Voltage")
ax.set_title("Load Points Beispiel"); ax.set_xlabel("Time [s]")
save(fig, "load_points.png")

# ------------------------------------------------------------------ EIS
eis_txt = read_all.read_eis_txt(os.path.join(DATA, "EIS_Beispiel_01.txt"), HEADER)
eis_csv = read_all.read_eis_csv(os.path.join(DATA, "EIS_Beispiel_03.csv"),
                                CONFIG["read_eis_csv"]["HeaderDerNurInZeileVorMessdatenIst"])
check("EIS: txt gelesen", eis_txt is not None and eis_txt.shape == (40, 4))
check("EIS: csv gelesen (Phase in Grad)", eis_csv is not None and eis_csv.shape == (40, 4)
      and np.all(np.abs(eis_csv[:, 3]) <= 90), f"phase range {eis_csv[:, 3].min():.1f}..{eis_csv[:, 3].max():.1f}")

area = CONFIG["EIS"]["Flaeche"]
d1 = eis.add_real_imaginary(eis_txt, area)
d2 = eis.add_real_imaginary(read_all.read_eis_txt(os.path.join(DATA, "EIS_Beispiel_02.txt"), HEADER), area)
check("EIS: Realteil bei hoher Frequenz ~ R0*A", abs(d1[0, 4] - 0.0004 * area) < 0.02, f"{d1[0, 4]:.4f}")
avg = eis.average_and_sigma([d1[:, :6], d2[:, :6]])
check("EIS: MW&σ-Datei hat 10 Spalten", avg.shape[1] == 10, f"{avg.shape}")
check("EIS: Namen kürzen", eis.extract_and_truncate_name("XX_EIS_test_20260710.txt", True) == "EIS_test")

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5))
ax1.plot(d1[:, 4], d1[:, 5], "o-", label="Nr. 1")
ax1.plot(d2[:, 4], d2[:, 5], "o-", label="Nr. 2")
ax1.invert_yaxis(); ax1.set_title("-Nyquist"); ax1.legend()
ax2.loglog(d1[:, 1], d1[:, 2], "o-", label="Impedanz")
ax2b = ax2.twinx()
ax2b.semilogx(d1[:, 1], np.abs(d1[:, 3]), "o--", color="orange", label="Phase")
ax2.set_title("Bode")
save(fig, "eis.png")

# ------------------------------------------------------------------ S++
cd_frames, _ = read_all.read_s_plus_plus_dat(os.path.join(DATA, "SPP_CD_Beispiel.dat"), False)
td_frames, timestamps = read_all.read_s_plus_plus_dat(os.path.join(DATA, "SPP_TD_Beispiel.dat"), True)
check("S++: CD-Frames gelesen", cd_frames.shape == (20, 8, 10), f"{cd_frames.shape}")
check("S++: TD-Timestamps gelesen", len(timestamps) == 20, f"{len(timestamps)}")
check("S++: Timestamp parsebar", s_plus_plus.parse_timestamp(timestamps[0]) is not None, timestamps[0])

balanced = s_plus_plus.calc_balanced_area(np.abs(cd_frames[0]), 20)
check("S++: Balanced Area in (0, 100]", 0 < balanced <= 100, f"{balanced:.1f}%")
filled = s_plus_plus.delete_segments(cd_frames, [3], [4])
check("S++: Segment-Löschung füllt linear", np.isfinite(filled).all(), "")

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))
m1 = ax1.pcolormesh(np.abs(cd_frames[0]), cmap="jet"); fig.colorbar(m1, ax=ax1)
ax1.set_title(f"Current distribution (Balanced {balanced:.1f}%)")
m2 = ax2.pcolormesh(td_frames[0], cmap="jet"); fig.colorbar(m2, ax=ax2)
ax2.set_title("Temperature distribution")
save(fig, "s_plus_plus.png")

# ------------------------------------------------------------------ summary
print(f"\n{len(passed)} passed, {len(failed)} failed")
if failed:
    print("Failed:", *failed, sep="\n  ")
    raise SystemExit(1)
