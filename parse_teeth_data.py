import pandas as pd
import re
from pathlib import Path


DATA_FILE = Path(__file__).parent / "teethSniffphoneData_V2.xlsx"

# Mapping from sheet name to the dental condition group
SHEET_CONDITIONS = {
    "p1": "CARIES",
    "p2": "GINGIVITIS",
    "p3": "PERIODONTITIS",
    "p4": "IMPLANT",
    "p5": "PERIIMPLANTITIS",
    "p6": "IMP+CAR",
    "p7": "Perio+CAR",
    "p8": "IMP+PER",
    "p9": "Nitrogen",
}

SENSOR_COLS = ["GNP1", "GNP2", "GNP3", "GNP4", "GNP5", "GNP6", "GNP7", "GNP8"]


def parse_subject_id(raw_id):
    """Extract base subject ID and session number from IDs like '005(2)'.

    Returns (subject_id, session) e.g. ('005', 2).
    For Nitrogen sheet entries like 'N1', returns ('N1', 1).
    """
    if pd.isna(raw_id):
        return None, None
    raw_id = str(raw_id).strip()
    match = re.match(r"^(\d+)\((\d+)\)$", raw_id)
    if match:
        return match.group(1), int(match.group(2))
    # Nitrogen-style IDs (N1, N2, ...)
    return raw_id, 1


def read_sheet(xls, sheet_name):
    """Read and parse a single sheet into a cleaned DataFrame.

    Returns a DataFrame with columns:
        condition_group, phenotype, subject_raw, subject_id, session,
        GNP1..GNP8
    """
    df = pd.read_excel(xls, sheet_name=sheet_name)

    # Standardize column names: first col -> phenotype, second col -> subject_raw
    phenotype_col = df.columns[0]
    subject_col = df.columns[1]

    df = df.rename(columns={phenotype_col: "phenotype", subject_col: "subject_raw"})

    # Drop rows where both phenotype and subject are NaN (header/spacer rows)
    df = df.dropna(subset=["phenotype", "subject_raw"], how="all")

    # Drop rows where all sensor values are NaN
    df = df.dropna(subset=SENSOR_COLS, how="all")

    # Parse subject IDs
    parsed = df["subject_raw"].apply(parse_subject_id)
    df["subject_id"] = parsed.apply(lambda x: x[0])
    df["session"] = parsed.apply(lambda x: x[1])

    # Add the condition group
    df["condition_group"] = SHEET_CONDITIONS[sheet_name]

    # Reorder columns
    cols = ["condition_group", "phenotype", "subject_raw", "subject_id", "session"] + SENSOR_COLS
    df = df[cols].reset_index(drop=True)

    return df


def load_all_data(file_path=DATA_FILE):
    """Load and parse all sheets from the Excel file.

    Returns:
        all_data: DataFrame with all sheets concatenated, containing columns:
            condition_group, phenotype, subject_raw, subject_id, session,
            GNP1..GNP8
        by_sheet: dict mapping sheet name -> individual DataFrame
    """
    xls = pd.ExcelFile(file_path)
    by_sheet = {}
    frames = []

    for sheet_name in xls.sheet_names:
        df = read_sheet(xls, sheet_name)
        by_sheet[sheet_name] = df
        frames.append(df)

    all_data = pd.concat(frames, ignore_index=True)
    return all_data, by_sheet


def group_by_subject(all_data):
    """Group the data by subject.

    Returns a dict: (condition_group, subject_id) -> DataFrame of all
    that subject's measurements across sessions and phenotypes.
    """
    grouped = {}
    for (cond, sid), group_df in all_data.groupby(["condition_group", "subject_id"]):
        grouped[(cond, sid)] = group_df.reset_index(drop=True)
    return grouped


if __name__ == "__main__":
    all_data, by_sheet = load_all_data()

    print(f"Total rows: {len(all_data)}")
    print(f"Sheets loaded: {list(by_sheet.keys())}")
    print()

    # Summary per condition group
    print("=== Summary per condition group ===")
    summary = all_data.groupby("condition_group").agg(
        rows=("subject_id", "size"),
        unique_subjects=("subject_id", "nunique"),
        phenotypes=("phenotype", lambda x: sorted(x.unique())),
    )
    print(summary.to_string())
    print()

    # Summary per subject
    print("=== Example: first 5 subjects ===")
    subjects = group_by_subject(all_data)
    for i, ((cond, sid), sdf) in enumerate(subjects.items()):
        if i >= 5:
            break
        sessions = sdf["session"].unique()
        phenotypes = sdf["phenotype"].unique()
        print(f"  {cond} / subject {sid}: {len(sdf)} rows, "
              f"sessions={list(sessions)}, phenotypes={list(phenotypes)}")
