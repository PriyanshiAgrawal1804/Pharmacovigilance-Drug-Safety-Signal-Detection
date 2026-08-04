"""
03_feature_engineering.py
------------------------------------------------------------------
Builds analytical features on top of the cleaned pharmacovigilance
tables and produces one wide, analysis-ready master table:

    data/processed/master_analytics_table.csv

Features created:
    - Age_Group (Pediatric / Adult / Elderly)
    - Time_to_Onset (days between therapy start and event date)
    - Exposure_Duration
    - Serious_Event_Flag
    - Fatal_Event_Flag
    - Polypharmacy_Flag (patient has >1 distinct drug exposure)
    - Rechallenge_Flag (same patient + same drug reported more than once)
    - Elderly_Flag (Age >= 65)
    - Pediatric_Flag (Age < 18)
    - Chronic_Disease_Flag (diabetes / hypertension / renal disease)
    - Reporting_Month / Reporting_Season
------------------------------------------------------------------
"""

import pandas as pd
import numpy as np

PROCESSED = "../data/processed"

drug_df = pd.read_csv(f"{PROCESSED}/drug_table_clean.csv")
patient_df = pd.read_csv(f"{PROCESSED}/patient_table_clean.csv")
event_df = pd.read_csv(f"{PROCESSED}/adverse_event_table_clean.csv", parse_dates=["Event_Date"])
exposure_df = pd.read_csv(f"{PROCESSED}/drug_exposure_table_clean.csv",
                           parse_dates=["Therapy_Start", "Therapy_End"])

# ------------------------------------------------------------------
# Join event -> drug -> patient -> exposure (1:1 by row order, exposure was
# generated per-event in the source data so we align on position via a key)
# ------------------------------------------------------------------
exposure_df = exposure_df.reset_index().rename(columns={"index": "row_key"})
event_df = event_df.reset_index().rename(columns={"index": "row_key"})

master = event_df.merge(drug_df, on="Drug_ID", how="left", suffixes=("", "_drug"))
master = master.merge(patient_df, on="Patient_ID", how="left", suffixes=("", "_patient"))
master = master.merge(
    exposure_df[["row_key", "Dose", "Route", "Therapy_Start", "Therapy_End", "Duration"]],
    on="row_key", how="left"
)

# ------------------------------------------------------------------
# Feature: Age Group
# ------------------------------------------------------------------
def age_group(age):
    if pd.isna(age):
        return "Unknown"
    if age < 18:
        return "Pediatric"
    elif age < 65:
        return "Adult"
    else:
        return "Elderly"

master["Age_Group"] = master["Age"].apply(age_group)
master["Elderly_Flag"] = (master["Age"] >= 65).astype(int)
master["Pediatric_Flag"] = (master["Age"] < 18).astype(int)

# ------------------------------------------------------------------
# Feature: Time to Onset & Exposure Duration
# ------------------------------------------------------------------
master["Time_to_Onset_Days"] = (master["Event_Date"] - master["Therapy_Start"]).dt.days
master.loc[master["Time_to_Onset_Days"] < 0, "Time_to_Onset_Days"] = np.nan  # data artifact guard
master["Exposure_Duration_Days"] = master["Duration"]

# ------------------------------------------------------------------
# Feature: Serious / Fatal flags
# ------------------------------------------------------------------
master["Serious_Event_Flag"] = (master["Seriousness"] == "Serious").astype(int)
master["Fatal_Event_Flag"] = (master["Death"] == "Yes").astype(int)
master["Hospitalized_Flag"] = (master["Hospitalized"] == "Yes").astype(int)

# ------------------------------------------------------------------
# Feature: Chronic disease flag
# ------------------------------------------------------------------
master["Chronic_Disease_Flag"] = (
    (master["Diabetes"] == "Yes") | (master["Hypertension"] == "Yes") | (master["Renal_Disease"] == "Yes")
).astype(int)

# ------------------------------------------------------------------
# Feature: Polypharmacy flag (patient appears with >1 distinct drug)
# ------------------------------------------------------------------
drugs_per_patient = master.groupby("Patient_ID")["Drug_ID"].nunique()
master["Polypharmacy_Flag"] = master["Patient_ID"].map(drugs_per_patient).gt(1).astype(int)

# ------------------------------------------------------------------
# Feature: Rechallenge indicator (same patient + same drug, >1 ADR report)
# ------------------------------------------------------------------
pair_counts = master.groupby(["Patient_ID", "Drug_ID"]).size()
mapped_counts = pd.Series(
    master.set_index(["Patient_ID", "Drug_ID"]).index.map(pair_counts),
    index=master.index,
)
master["Rechallenge_Flag"] = (mapped_counts > 1).astype(int)

# ------------------------------------------------------------------
# Feature: Reporting month / season
# ------------------------------------------------------------------
master["Reporting_Month"] = master["Event_Date"].dt.to_period("M").astype(str)
master["Reporting_Season"] = master["Event_Date"].dt.month % 12 // 3 + 1
season_map = {1: "Winter", 2: "Spring", 3: "Summer", 4: "Fall"}
master["Reporting_Season"] = master["Reporting_Season"].map(season_map)

# ------------------------------------------------------------------
# Save master analytics table
# ------------------------------------------------------------------
keep_cols = [
    "Event_ID", "Drug_ID", "Drug_Name", "Reported_Drug_Name_clean", "Manufacturer", "Drug_Class",
    "Therapeutic_Area", "Patient_ID", "Age", "Age_Group", "Elderly_Flag", "Pediatric_Flag", "Gender",
    "Country", "Smoking_Status", "Diabetes", "Hypertension", "Pregnancy", "Renal_Disease",
    "Chronic_Disease_Flag", "Event_Date", "Side_Effect", "Severity", "Outcome", "Hospitalized",
    "Hospitalized_Flag", "Life_Threatening", "Death", "Fatal_Event_Flag", "Seriousness",
    "Serious_Event_Flag", "Dose", "Route", "Therapy_Start", "Therapy_End", "Exposure_Duration_Days",
    "Time_to_Onset_Days", "Polypharmacy_Flag", "Rechallenge_Flag", "Reporting_Month", "Reporting_Season",
]
master_final = master[keep_cols].rename(columns={"Reported_Drug_Name_clean": "Reported_Drug_Name"})
master_final.to_csv(f"{PROCESSED}/master_analytics_table.csv", index=False)

print(f"Master analytics table created: {len(master_final):,} rows x {len(master_final.columns)} columns")
print(f"Saved to: {PROCESSED}/master_analytics_table.csv")
print("\nSample feature distribution:")
print(master_final["Age_Group"].value_counts())
print(master_final["Serious_Event_Flag"].value_counts())
