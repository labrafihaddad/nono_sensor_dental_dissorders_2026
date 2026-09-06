import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.svm import SVC
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import LeaveOneOut
from sklearn.metrics import confusion_matrix, classification_report, accuracy_score
from parse_teeth_data import load_all_data, SENSOR_COLS

# ── 1. Load and average per subject, subtract baseline ───────────────────────
all_data, _ = load_all_data()

# Average sensor values per (condition_group, subject_id, phenotype),
# collapsing all time-points and sessions into a single mean.
avg = (
    all_data
    .groupby(["condition_group", "subject_id", "phenotype"])[SENSOR_COLS]
    .mean()
    .reset_index()
)

# Subtract baseline from each subject: breath - baseline, clean - baseline
baseline = avg[avg["phenotype"] == "baseline"].set_index(["condition_group", "subject_id"])[SENSOR_COLS]
breath   = avg[avg["phenotype"] == "breath"].set_index(["condition_group", "subject_id"])[SENSOR_COLS]
clean    = avg[avg["phenotype"] == "clean"].set_index(["condition_group", "subject_id"])[SENSOR_COLS]

breath_sub = (breath - baseline).rename(columns={c: f"{c}_breath" for c in SENSOR_COLS})
clean_sub  = (clean  - baseline).rename(columns={c: f"{c}_clean"  for c in SENSOR_COLS})

features = pd.concat([breath_sub, clean_sub], axis=1).reset_index()
features = features.dropna()

print(f"Feature matrix: {features.shape[0]} subjects × {features.shape[1] - 2} features")
print(f"  (8 sensors × 2 phenotypes, baseline-subtracted)")
print(f"Classes: {sorted(features['condition_group'].unique())}")
print()

# ── 2. Prepare X, y ─────────────────────────────────────────────────────────
feature_cols = [c for c in features.columns if c not in ("condition_group", "subject_id")]
X = features[feature_cols].values
y = features["condition_group"].values
subject_ids = features["subject_id"].values

# ── 3. Leave-One-Out classification ─────────────────────────────────────────
loo = LeaveOneOut()
scaler = StandardScaler()

y_true = []
y_pred = []

for train_idx, test_idx in loo.split(X):
    X_train, X_test = X[train_idx], X[test_idx]
    y_train, y_test = y[train_idx], y[test_idx]

    # Scale features
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)

    clf = SVC(kernel="rbf", C=1.0, gamma="scale")
    clf.fit(X_train_s, y_train)

    y_true.append(y_test[0])
    y_pred.append(clf.predict(X_test_s)[0])

y_true = np.array(y_true)
y_pred = np.array(y_pred)

# ── 4. Results ───────────────────────────────────────────────────────────────
acc = accuracy_score(y_true, y_pred)
print(f"Overall LOO accuracy: {acc:.2%} ({int(acc * len(y_true))}/{len(y_true)})")
print()
print("Classification report:")
print(classification_report(y_true, y_pred, zero_division=0))

# ── 5. Confusion matrix ─────────────────────────────────────────────────────
labels = sorted(np.unique(np.concatenate([y_true, y_pred])))
cm = confusion_matrix(y_true, y_pred, labels=labels)

fig, ax = plt.subplots(figsize=(10, 8))
im = ax.imshow(cm, interpolation="nearest", cmap=plt.cm.Blues)
ax.figure.colorbar(im, ax=ax)

ax.set(
    xticks=np.arange(len(labels)),
    yticks=np.arange(len(labels)),
    xticklabels=labels,
    yticklabels=labels,
    ylabel="True disorder",
    xlabel="Predicted disorder",
    title=f"LOO Confusion Matrix — Accuracy: {acc:.2%}",
)
plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")

# Annotate cells with counts
for i in range(len(labels)):
    for j in range(len(labels)):
        color = "white" if cm[i, j] > cm.max() / 2 else "black"
        ax.text(j, i, str(cm[i, j]), ha="center", va="center", color=color, fontsize=12)

fig.tight_layout()
plt.savefig("confusion_matrix.png", dpi=150, bbox_inches="tight")
print("\nSaved confusion_matrix.png")
