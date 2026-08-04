"""
02_data_cleaning.py
------------------------------------------------------------------
Cleans the RAW pharmacovigilance tables and writes clean versions to
data/processed/. Demonstrates standard data-cleaning techniques used
in real-world PV / drug-safety analytics:

    - Standardizing text case & trimming whitespace
    - Fixing inconsistent country names
    - Standardizing drug name spelling
    - Parsing mixed date formats
    - Handling missing values (age, gender, outcome)
    - Removing impossible ages
    - Removing duplicate patient IDs and duplicate ADR reports
    - Fixing invalid dosage values
------------------------------------------------------------------
"""

import pandas as pd
import numpy as np

RAW = "../data/raw"
PROCESSED = "../data/processed"

# ------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------
def clean_text(series):
    return series.astype(str).str.strip().str.title().replace({"Nan": np.nan})


def parse_mixed_dates(series):
    """Try multiple common date formats and coalesce into one clean Series."""
    parsed = pd.to_datetime(series, format="%Y-%m-%d", errors="coerce")
    mask = parsed.isna()
    parsed.loc[mask] = pd.to_datetime(series[mask], format="%d/%m/%Y", errors="coerce")
    mask = parsed.isna()
    parsed.loc[mask] = pd.to_datetime(series[mask], format="%m-%d-%Y", errors="coerce")
    mask = parsed.isna()
    parsed.loc[mask] = pd.to_datetime(series[mask], errors="coerce")  # last resort
    return parsed


COUNTRY_MAP = {
    "usa": "United States", "u.s.a": "United States", "us": "United States",
    "united states": "United States",
    "india": "India", "ind": "India", "in dia": "India",
    "uk": "United Kingdom", "u.k.": "United Kingdom", "united kingdom": "United Kingdom",
    "germany": "Germany", "japan": "Japan", "brazil": "Brazil", "france": "France",
    "canada": "Canada", "australia": "Australia", "south africa": "South Africa",
}

DRUG_NAME_MAP = {
    "amoxicillin": "Amoxicillin", "amoxycillin": "Amoxicillin",
    "metformin": "Metformin", "metfomin": "Metformin",
    "atorvastatin": "Atorvastatin", "atorvastin": "Atorvastatin",
    "paclitaxel": "Paclitaxel", "pacletaxel": "Paclitaxel",
    "warfarin": "Warfarin", "warfrin": "Warfarin",
}

GENDER_MAP = {
    "male": "Male", "m": "Male", "female": "Female", "f": "Female", "unknown": np.nan,
}

# ------------------------------------------------------------------
# 1. DRUG TABLE  (already clean master data; light standardization only)
# ------------------------------------------------------------------
drug_df = pd.read_csv(f"{RAW}/drug_table.csv")
drug_df["Drug_Name"] = drug_df["Drug_Name"].str.strip()
drug_df.to_csv(f"{PROCESSED}/drug_table_clean.csv", index=False)

# ------------------------------------------------------------------
# 2. PATIENT TABLE
# ------------------------------------------------------------------
patient_df = pd.read_csv(f"{RAW}/patient_table.csv")
before = len(patient_df)

# remove duplicate Patient_IDs (keep first occurrence)
dupes_removed = patient_df.duplicated(subset="Patient_ID").sum()
patient_df = patient_df.drop_duplicates(subset="Patient_ID", keep="first")

# standardize country
patient_df["Country"] = (
    patient_df["Country"].astype(str).str.strip().str.lower().map(COUNTRY_MAP)
    .fillna(patient_df["Country"].astype(str).str.strip())
)

# standardize gender
patient_df["Gender_clean"] = patient_df["Gender"].astype(str).str.strip().str.lower().map(GENDER_MAP)
patient_df["Gender"] = patient_df["Gender_clean"].fillna(patient_df["Gender"])
patient_df.drop(columns=["Gender_clean"], inplace=True)
missing_gender = patient_df["Gender"].isna().sum()

# handle impossible ages -> set to NaN, then flag
impossible_age_mask = (patient_df["Age"] < 0) | (patient_df["Age"] > 110)
impossible_ages_found = impossible_age_mask.sum()
patient_df.loc[impossible_age_mask, "Age"] = np.nan

# impute missing age with median age (documented, standard PV practice for descriptive KPIs)
missing_age_count = patient_df["Age"].isna().sum()
median_age = patient_df["Age"].median()
patient_df["Age_was_missing"] = patient_df["Age"].isna()
patient_df["Age"] = patient_df["Age"].fillna(median_age)

patient_df.to_csv(f"{PROCESSED}/patient_table_clean.csv", index=False)

# ------------------------------------------------------------------
# 3. REPORTER TABLE
# ------------------------------------------------------------------
reporter_df = pd.read_csv(f"{RAW}/reporter_table.csv")
reporter_df["Reporting_Date"] = parse_mixed_dates(reporter_df["Reporting_Date"])
reporter_df["Country"] = reporter_df["Country"].astype(str).str.strip().str.title()
reporter_df.to_csv(f"{PROCESSED}/reporter_table_clean.csv", index=False)

# ------------------------------------------------------------------
# 4. ADVERSE EVENT TABLE (core table)
# ------------------------------------------------------------------
event_df = pd.read_csv(f"{RAW}/adverse_event_table.csv")
before_events = len(event_df)

# remove exact duplicate ADR reports
event_dupes_removed = event_df.duplicated(subset=[
    "Drug_ID", "Patient_ID", "Event_Date", "Side_Effect", "Severity"
]).sum()
event_df = event_df.drop_duplicates(subset=[
    "Drug_ID", "Patient_ID", "Event_Date", "Side_Effect", "Severity"
], keep="first")

# standardize reported drug name using mapping, fall back to Drug_ID join
event_df["Reported_Drug_Name_clean"] = (
    event_df["Reported_Drug_Name"].astype(str).str.strip().str.lower().map(DRUG_NAME_MAP)
)
event_df["Reported_Drug_Name_clean"] = event_df["Reported_Drug_Name_clean"].fillna(
    event_df["Reported_Drug_Name"].astype(str).str.strip()
)

# parse mixed date formats
event_df["Event_Date"] = parse_mixed_dates(event_df["Event_Date"])

# handle missing outcomes
missing_outcome_count = event_df["Outcome"].isna().sum()
event_df["Outcome"] = event_df["Outcome"].fillna("Unknown")

# standardize categorical Yes/No fields
for col in ["Hospitalized", "Life_Threatening", "Death"]:
    event_df[col] = event_df[col].astype(str).str.strip().str.title()

event_df.to_csv(f"{PROCESSED}/adverse_event_table_clean.csv", index=False)

# ------------------------------------------------------------------
# 5. DRUG EXPOSURE TABLE
# ------------------------------------------------------------------
exposure_df = pd.read_csv(f"{RAW}/drug_exposure_table.csv")
invalid_dose_mask = (exposure_df["Dose"] <= 0) | (exposure_df["Dose"] > 2000)
invalid_doses_found = invalid_dose_mask.sum()
exposure_df.loc[invalid_dose_mask, "Dose"] = np.nan
median_dose = exposure_df["Dose"].median()
exposure_df["Dose"] = exposure_df["Dose"].fillna(median_dose)

exposure_df["Therapy_Start"] = pd.to_datetime(exposure_df["Therapy_Start"], errors="coerce")
exposure_df["Therapy_End"] = pd.to_datetime(exposure_df["Therapy_End"], errors="coerce")
exposure_df.to_csv(f"{PROCESSED}/drug_exposure_table_clean.csv", index=False)

# ------------------------------------------------------------------
# 6. FOLLOW-UP TABLE
# ------------------------------------------------------------------
followup_df = pd.read_csv(f"{RAW}/followup_table.csv")
followup_df["Followup_Date"] = pd.to_datetime(followup_df["Followup_Date"], errors="coerce")
followup_df.to_csv(f"{PROCESSED}/followup_table_clean.csv", index=False)

# ------------------------------------------------------------------
# DATA QUALITY REPORT
# ------------------------------------------------------------------
report_lines = [
    "PHARMACOVIGILANCE DATA CLEANING REPORT",
    "=" * 55,
    f"Patient table: {before} raw rows -> {len(patient_df)} clean rows",
    f"  - Duplicate Patient_IDs removed : {dupes_removed}",
    f"  - Impossible ages corrected     : {impossible_ages_found}",
    f"  - Missing ages imputed (median) : {missing_age_count}",
    f"  - Missing gender values         : {missing_gender}",
    "",
    f"Adverse Event table: {before_events} raw rows -> {len(event_df)} clean rows",
    f"  - Duplicate ADR reports removed : {event_dupes_removed}",
    f"  - Missing outcomes set to 'Unknown' : {missing_outcome_count}",
    "",
    f"Drug Exposure table: invalid dosage values corrected: {invalid_doses_found}",
    "",
    "Standardization applied:",
    "  - Country names mapped to canonical values",
    "  - Drug name spelling variants mapped to canonical generic names",
    "  - Gender values normalized (M/F/male/female -> Male/Female)",
    "  - Event/Reporting/Therapy dates parsed from mixed formats (YYYY-MM-DD, DD/MM/YYYY, MM-DD-YYYY)",
]
report_text = "\n".join(report_lines)
with open("../outputs/kpi_reports/data_cleaning_report.txt", "w") as f:
    f.write(report_text)

print(report_text)
print("\nAll cleaned tables written to data/processed/")
