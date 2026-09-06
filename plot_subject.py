import matplotlib.pyplot as plt
import numpy as np
from parse_teeth_data import load_all_data, SENSOR_COLS

all_data, _ = load_all_data()

# Filter subject 005
s005 = all_data[all_data["subject_id"] == "005"].copy()

phenotypes = ["baseline", "breath", "clean"]
sessions = [1, 2]
colors = {"GNP1": "#e6194b", "GNP2": "#3cb44b", "GNP3": "#4363d8", "GNP4": "#f58231",
          "GNP5": "#911eb4", "GNP6": "#42d4f4", "GNP7": "#f032e6", "GNP8": "#bfef45"}

# Compute baseline mean per session for normalization (deltaR / R0)
baseline_means = {}
for session in sessions:
    mask = (s005["session"] == session) & (s005["phenotype"] == "baseline")
    baseline_means[session] = s005.loc[mask, SENSOR_COLS].mean()

fig, axes = plt.subplots(3, 2, figsize=(16, 12), sharex=False, sharey=True)

for row, phenotype in enumerate(phenotypes):
    for col, session in enumerate(sessions):
        ax = axes[row, col]
        mask = (s005["session"] == session) & (s005["phenotype"] == phenotype)
        data = s005.loc[mask, SENSOR_COLS].reset_index(drop=True)

        # Normalize: (value - baseline_mean) / baseline_mean
        r0 = baseline_means[session]
        data_norm = (data[SENSOR_COLS] - r0) / r0

        for sensor in SENSOR_COLS:
            ax.plot(data_norm.index, data_norm[sensor], label=sensor, color=colors[sensor], linewidth=1)

        ax.set_title(f"{phenotype} — session {session}", fontsize=12, fontweight="bold")
        ax.set_xlabel("Sample #")
        ax.set_ylabel("ΔR / R₀")
        ax.legend(fontsize=8, loc="upper right")

fig.suptitle("Subject 005 (CARIES) — Normalized sensor responses (ΔR/R₀)", fontsize=14, fontweight="bold")
fig.tight_layout(rect=[0, 0.03, 1, 0.96])
plt.savefig("subject_005_response.png", dpi=150, bbox_inches="tight")
plt.show()
print("Saved to subject_005_response.png")
