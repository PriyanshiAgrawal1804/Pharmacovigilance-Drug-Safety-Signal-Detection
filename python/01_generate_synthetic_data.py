"""
01_generate_synthetic_data.py
------------------------------------------------------------------
Pharmacovigilance & Drug Safety Signal Detection Analytics Platform

Generates a realistic, RAW (i.e. deliberately messy) synthetic
adverse-drug-reaction (ADR) dataset that mirrors real pharmacovigilance
data feeds (FAERS / EudraVigilance style), including common data
quality problems analysts have to clean:

    - Missing ages / genders / outcomes
    - Duplicate ADR reports
    - Inconsistent drug name spelling / casing
    - Mixed date formats
    - Impossible ages
    - Duplicate patient IDs
    - Invalid dosage values
    - Inconsistent country names
    - Extra whitespace, mixed casing

Output: data/raw/*.csv  (6 relational tables)
------------------------------------------------------------------
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import random

RNG_SEED = 42
random.seed(RNG_SEED)
np.random.seed(RNG_SEED)

OUT_DIR = "../data/raw"

# ------------------------------------------------------------------
# 1. DRUG TABLE
# ------------------------------------------------------------------
drug_master = [
    ("D001", "Amoxicillin", "Pfizer", "Antibiotic", "Amoxil"),
    ("D002", "Metformin", "Sun Pharma", "Antidiabetic", "Glucophage"),
    ("D003", "Atorvastatin", "Pfizer", "Cardiology", "Lipitor"),
    ("D004", "Ibuprofen", "GSK", "Pain Management", "Advil"),
    ("D005", "Omeprazole", "AstraZeneca", "Gastroenterology", "Prilosec"),
    ("D006", "Paclitaxel", "Bristol-Myers Squibb", "Oncology", "Taxol"),
    ("D007", "Insulin Glargine", "Sanofi", "Antidiabetic", "Lantus"),
    ("D008", "Losartan", "Novartis", "Cardiology", "Cozaar"),
    ("D009", "Azithromycin", "Pfizer", "Antibiotic", "Zithromax"),
    ("D010", "Warfarin", "Bristol-Myers Squibb", "Cardiology", "Coumadin"),
    ("D011", "Rituximab", "Roche", "Oncology", "Rituxan"),
    ("D012", "Sertraline", "Pfizer", "Psychiatry", "Zoloft"),
    ("D013", "Clopidogrel", "Sanofi", "Cardiology", "Plavix"),
    ("D014", "Ciprofloxacin", "Bayer", "Antibiotic", "Cipro"),
    ("D015", "Trastuzumab", "Roche", "Oncology", "Herceptin"),
    ("D016", "Levothyroxine", "AbbVie", "Endocrinology", "Synthroid"),
    ("D017", "Amlodipine", "Pfizer", "Cardiology", "Norvasc"),
    ("D018", "Gabapentin", "Pfizer", "Neurology", "Neurontin"),
    ("D019", "Prednisone", "Novartis", "Immunology", "Deltasone"),
    ("D020", "Methotrexate", "Sanofi", "Oncology", "Trexall"),
    ("D021", "Hydrochlorothiazide", "Novartis", "Cardiology", "Microzide"),
    ("D022", "Doxorubicin", "Pfizer", "Oncology", "Adriamycin"),
    ("D023", "Metoprolol", "Novartis", "Cardiology", "Lopressor"),
    ("D024", "Cetuximab", "Eli Lilly", "Oncology", "Erbitux"),
    ("D025", "Diclofenac", "Novartis", "Pain Management", "Voltaren"),
]

drug_rows = []
for drug_id, generic, manufacturer, area, brand in drug_master:
    approval_date = datetime(1995, 1, 1) + timedelta(days=random.randint(0, 10000))
    drug_rows.append({
        "Drug_ID": drug_id,
        "Drug_Name": generic,
        "Manufacturer": manufacturer,
        "Drug_Class": area,
        "Approval_Date": approval_date.strftime("%Y-%m-%d"),
        "Therapeutic_Area": area,
        "Generic_Name": generic,
        "Brand_Name": brand,
    })
drug_df = pd.DataFrame(drug_rows)

# introduce inconsistent spelling / casing (data quality issue) via a lookup
# used later when generating adverse events, NOT in the master table itself
NAME_VARIANTS = {
    "Amoxicillin": ["amoxicillin", "AMOXICILLIN", "Amoxycillin", "Amoxicillin "],
    "Metformin": ["metformin", "METFORMIN", "Metfomin", " Metformin"],
    "Atorvastatin": ["atorvastatin", "Atorvastin", "ATORVASTATIN"],
    "Paclitaxel": ["paclitaxel", "Pacletaxel", "PACLITAXEL"],
    "Warfarin": ["warfarin", "Warfrin", "WARFARIN "],
}

drug_df.to_csv(f"{OUT_DIR}/drug_table.csv", index=False)

# ------------------------------------------------------------------
# 2. PATIENT TABLE
# ------------------------------------------------------------------
N_PATIENTS = 5000
countries_clean = ["United States", "India", "Germany", "United Kingdom", "Japan",
                    "Brazil", "France", "Canada", "Australia", "South Africa"]
country_dirty_map = {
    "United States": ["USA", "U.S.A", "us", "United states", " United States"],
    "India": ["india", "IND", "In dia", "India "],
    "United Kingdom": ["UK", "U.K.", "united kingdom"],
}

patient_rows = []
used_ids = []
for i in range(N_PATIENTS):
    pid = f"P{i+1:05d}"
    used_ids.append(pid)

    age = np.random.randint(1, 90)
    # inject impossible ages (~1%)
    if random.random() < 0.01:
        age = random.choice([-5, 150, 999, 0])
    # inject missing ages (~4%)
    if random.random() < 0.04:
        age = np.nan

    gender = random.choice(["Male", "Female"])
    if random.random() < 0.03:
        gender = np.nan
    elif random.random() < 0.02:
        gender = random.choice(["M", "F", "male", "female", "unknown"])

    weight = round(np.random.normal(70, 15), 1)
    if weight < 3:
        weight = round(random.uniform(45, 100), 1)

    country = random.choice(countries_clean)
    if country in country_dirty_map and random.random() < 0.35:
        country = random.choice(country_dirty_map[country])

    smoking = random.choices(["Yes", "No", "Former"], weights=[0.2, 0.65, 0.15])[0]
    diabetes = random.choices(["Yes", "No"], weights=[0.18, 0.82])[0]
    hypertension = random.choices(["Yes", "No"], weights=[0.25, 0.75])[0]
    pregnancy = "N/A"
    if gender in ("Female", "female", "F") and isinstance(age, (int, float)) and not pd.isna(age) and 15 <= age <= 45:
        pregnancy = random.choices(["Yes", "No"], weights=[0.08, 0.92])[0]
    renal = random.choices(["Yes", "No"], weights=[0.12, 0.88])[0]

    patient_rows.append({
        "Patient_ID": pid,
        "Age": age,
        "Gender": gender,
        "Weight": weight,
        "Country": country,
        "Smoking_Status": smoking,
        "Diabetes": diabetes,
        "Hypertension": hypertension,
        "Pregnancy": pregnancy,
        "Renal_Disease": renal,
    })

# inject duplicate patient IDs (~1.5%)
n_dupes = int(N_PATIENTS * 0.015)
for _ in range(n_dupes):
    dupe = random.choice(patient_rows[:2000]).copy()
    patient_rows.append(dupe)

patient_df = pd.DataFrame(patient_rows)
patient_df.to_csv(f"{OUT_DIR}/patient_table.csv", index=False)

# ------------------------------------------------------------------
# 3. REPORTER TABLE
# ------------------------------------------------------------------
N_REPORTERS = 800
reporter_types = ["Physician", "Pharmacist", "Nurse", "Patient", "Other Health Professional", "Lawyer"]
hospitals = ["City General Hospital", "St. Mary's Medical Center", "Metro Health Clinic",
             "National Care Hospital", "Sunrise Medical Institute", "Central Regional Hospital"]

reporter_rows = []
for i in range(N_REPORTERS):
    rid = f"R{i+1:05d}"
    reporting_date = datetime(2019, 1, 1) + timedelta(days=random.randint(0, 2190))
    date_str = reporting_date.strftime("%Y-%m-%d") if random.random() > 0.15 else reporting_date.strftime("%d/%m/%Y")
    reporter_rows.append({
        "Reporter_ID": rid,
        "Reporter_Type": random.choice(reporter_types),
        "Hospital": random.choice(hospitals),
        "Country": random.choice(countries_clean),
        "Reporting_Date": date_str,
    })
reporter_df = pd.DataFrame(reporter_rows)
reporter_df.to_csv(f"{OUT_DIR}/reporter_table.csv", index=False)

# ------------------------------------------------------------------
# 4. ADVERSE EVENT TABLE  (core signal-detection table)
# ------------------------------------------------------------------
side_effects_by_class = {
    "Antibiotic": ["Rash", "Diarrhea", "Nausea", "Anaphylaxis", "Liver Injury", "C. diff Colitis"],
    "Antidiabetic": ["Hypoglycemia", "Lactic Acidosis", "Nausea", "GI Upset", "Weight Loss"],
    "Cardiology": ["Bleeding", "Hypotension", "Bradycardia", "Angioedema", "Myopathy", "Stroke"],
    "Pain Management": ["GI Bleeding", "Kidney Injury", "Nausea", "Dizziness", "Ulcer"],
    "Gastroenterology": ["Headache", "Diarrhea", "B12 Deficiency", "Fracture Risk"],
    "Oncology": ["Neutropenia", "Nausea", "Hair Loss", "Cardiotoxicity", "Infusion Reaction", "Fatigue", "Death"],
    "Psychiatry": ["Suicidal Ideation", "Insomnia", "Weight Gain", "Sexual Dysfunction"],
    "Neurology": ["Dizziness", "Somnolence", "Peripheral Edema", "Ataxia"],
    "Immunology": ["Immunosuppression", "Weight Gain", "Hyperglycemia", "Osteoporosis"],
    "Endocrinology": ["Palpitations", "Weight Loss", "Insomnia", "Tremor"],
}

severities = ["Mild", "Moderate", "Severe", "Life-threatening", "Fatal"]
severity_weights = [0.40, 0.32, 0.18, 0.07, 0.03]
outcomes = ["Recovered", "Recovering", "Not Recovered", "Fatal", "Unknown"]

N_EVENTS = 9000
drug_lookup = drug_df.set_index("Drug_ID").to_dict("index")
drug_ids = drug_df["Drug_ID"].tolist()
patient_ids_pool = patient_df["Patient_ID"].tolist()

event_rows = []
for i in range(N_EVENTS):
    eid = f"E{i+1:06d}"
    drug_id = random.choice(drug_ids)
    d_class = drug_lookup[drug_id]["Drug_Class"]
    generic_name = drug_lookup[drug_id]["Generic_Name"]

    patient_id = random.choice(patient_ids_pool)

    event_date = datetime(2020, 1, 1) + timedelta(days=random.randint(0, 1825))
    # mixed date formats
    fmt_choice = random.random()
    if fmt_choice < 0.7:
        date_str = event_date.strftime("%Y-%m-%d")
    elif fmt_choice < 0.9:
        date_str = event_date.strftime("%d/%m/%Y")
    else:
        date_str = event_date.strftime("%m-%d-%Y")

    # 35% of the time report a common, non-specific side effect that can occur
    # with ANY drug (mirrors real-world PV data where generic AEs like headache/
    # nausea/fatigue are reported broadly) -> creates a realistic PRR/ROR spread
    # instead of every pair looking like a maximal, class-locked signal.
    COMMON_SIDE_EFFECTS = ["Headache", "Nausea", "Fatigue", "Dizziness", "Rash", "Diarrhea"]
    if random.random() < 0.35:
        side_effect = random.choice(COMMON_SIDE_EFFECTS)
    else:
        side_effect_pool = side_effects_by_class.get(d_class, ["Headache", "Nausea", "Rash"])
        side_effect = random.choice(side_effect_pool)

    severity = random.choices(severities, weights=severity_weights)[0]
    hospitalized = "Yes" if severity in ("Severe", "Life-threatening", "Fatal") and random.random() < 0.7 else "No"
    life_threatening = "Yes" if severity in ("Life-threatening", "Fatal") else "No"
    death = "Yes" if severity == "Fatal" else "No"
    seriousness = "Serious" if severity in ("Severe", "Life-threatening", "Fatal") else "Non-Serious"

    outcome = random.choice(outcomes) if severity != "Fatal" else "Fatal"
    if random.random() < 0.05:
        outcome = np.nan  # missing outcome

    # use dirty drug-name variant occasionally instead of clean master name
    reported_drug_name = generic_name
    if generic_name in NAME_VARIANTS and random.random() < 0.30:
        reported_drug_name = random.choice(NAME_VARIANTS[generic_name])

    event_rows.append({
        "Event_ID": eid,
        "Drug_ID": drug_id,
        "Reported_Drug_Name": reported_drug_name,
        "Patient_ID": patient_id,
        "Event_Date": date_str,
        "Side_Effect": side_effect,
        "Severity": severity,
        "Outcome": outcome,
        "Hospitalized": hospitalized,
        "Life_Threatening": life_threatening,
        "Death": death,
        "Seriousness": seriousness,
    })

# inject duplicate ADR reports (~3%)
n_dupe_events = int(N_EVENTS * 0.03)
for _ in range(n_dupe_events):
    dupe = random.choice(event_rows).copy()
    event_rows.append(dupe)

event_df = pd.DataFrame(event_rows)
event_df.to_csv(f"{OUT_DIR}/adverse_event_table.csv", index=False)

# ------------------------------------------------------------------
# 5. DRUG EXPOSURE TABLE
# ------------------------------------------------------------------
routes = ["Oral", "Intravenous", "Subcutaneous", "Topical", "Intramuscular"]
exposure_rows = []
for i, row in enumerate(event_rows):
    exp_id = f"X{i+1:06d}"
    d_id = row["Drug_ID"]

    therapy_start = datetime(2019, 6, 1) + timedelta(days=random.randint(0, 2000))
    duration = random.randint(1, 365)
    therapy_end = therapy_start + timedelta(days=duration)

    dose = round(np.random.uniform(5, 500), 1)
    # invalid dosage values
    if random.random() < 0.02:
        dose = random.choice([-10, 0, 99999])

    exposure_rows.append({
        "Exposure_ID": exp_id,
        "Drug_ID": d_id,
        "Dose": dose,
        "Route": random.choice(routes),
        "Therapy_Start": therapy_start.strftime("%Y-%m-%d"),
        "Therapy_End": therapy_end.strftime("%Y-%m-%d"),
        "Duration": duration,
    })
exposure_df = pd.DataFrame(exposure_rows)
exposure_df.to_csv(f"{OUT_DIR}/drug_exposure_table.csv", index=False)

# ------------------------------------------------------------------
# 6. FOLLOW-UP TABLE
# ------------------------------------------------------------------
followup_rows = []
fu_counter = 1
for row in event_rows:
    if random.random() < 0.4:  # only some events get a follow-up
        fu_id = f"F{fu_counter:06d}"
        fu_counter += 1
        followup_rows.append({
            "Followup_ID": fu_id,
            "Event_ID": row["Event_ID"],
            "Followup_Date": (datetime(2020, 1, 1) + timedelta(days=random.randint(30, 2000))).strftime("%Y-%m-%d"),
            "Outcome": random.choice(outcomes),
            "Additional_Information": random.choice([
                "Patient improved after drug discontinuation",
                "No additional information provided",
                "Re-exposed to drug, symptoms recurred",
                "Lost to follow-up",
                "Confirmed by laboratory results",
            ]),
        })
followup_df = pd.DataFrame(followup_rows)
followup_df.to_csv(f"{OUT_DIR}/followup_table.csv", index=False)

# ------------------------------------------------------------------
print("RAW synthetic data generated successfully:")
for name, df in [("drug_table", drug_df), ("patient_table", patient_df),
                  ("reporter_table", reporter_df), ("adverse_event_table", event_df),
                  ("drug_exposure_table", exposure_df), ("followup_table", followup_df)]:
    print(f"  {name:25s} -> {len(df):6,d} rows")
