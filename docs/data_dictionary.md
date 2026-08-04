# Data Dictionary

## 1. Drug Table (`drug_table.csv`)
| Column | Type | Description |
|---|---|---|
| Drug_ID | string | Unique drug identifier (primary key) |
| Drug_Name | string | Generic drug name |
| Manufacturer | string | Pharmaceutical manufacturer |
| Drug_Class | string | Therapeutic classification (e.g., Cardiology, Oncology) |
| Approval_Date | date | Regulatory approval date |
| Therapeutic_Area | string | Clinical area of use |
| Generic_Name | string | Generic (non-branded) name |
| Brand_Name | string | Commercial brand name |

## 2. Patient Table (`patient_table.csv`)
| Column | Type | Description |
|---|---|---|
| Patient_ID | string | Unique patient identifier (primary key) |
| Age | int | Patient age at time of event |
| Gender | string | Male / Female |
| Weight | float | Patient weight (kg) |
| Country | string | Patient's country |
| Smoking_Status | string | Yes / No / Former |
| Diabetes | string | Yes / No |
| Hypertension | string | Yes / No |
| Pregnancy | string | Yes / No / N/A |
| Renal_Disease | string | Yes / No |

## 3. Reporter Table (`reporter_table.csv`)
| Column | Type | Description |
|---|---|---|
| Reporter_ID | string | Unique reporter identifier |
| Reporter_Type | string | Physician / Pharmacist / Nurse / Patient / etc. |
| Hospital | string | Reporting institution |
| Country | string | Reporter's country |
| Reporting_Date | date | Date the report was submitted |

## 4. Adverse Event Table (`adverse_event_table.csv`) — core fact table
| Column | Type | Description |
|---|---|---|
| Event_ID | string | Unique ADR report identifier (primary key) |
| Drug_ID | string | Foreign key -> Drug table |
| Reported_Drug_Name | string | As-reported drug name (may contain spelling variants pre-cleaning) |
| Patient_ID | string | Foreign key -> Patient table |
| Event_Date | date | Date the adverse event occurred |
| Side_Effect | string | Reported adverse reaction |
| Severity | string | Mild / Moderate / Severe / Life-threatening / Fatal |
| Outcome | string | Recovered / Recovering / Not Recovered / Fatal / Unknown |
| Hospitalized | string | Yes / No |
| Life_Threatening | string | Yes / No |
| Death | string | Yes / No |
| Seriousness | string | Serious / Non-Serious |

## 5. Drug Exposure Table (`drug_exposure_table.csv`)
| Column | Type | Description |
|---|---|---|
| Exposure_ID | string | Unique exposure record identifier |
| Drug_ID | string | Foreign key -> Drug table |
| Dose | float | Administered dose |
| Route | string | Oral / IV / Subcutaneous / Topical / Intramuscular |
| Therapy_Start | date | Start of drug therapy |
| Therapy_End | date | End of drug therapy |
| Duration | int | Therapy duration in days |

## 6. Follow-up Table (`followup_table.csv`)
| Column | Type | Description |
|---|---|---|
| Followup_ID | string | Unique follow-up record identifier |
| Event_ID | string | Foreign key -> Adverse Event table |
| Followup_Date | date | Date of follow-up |
| Outcome | string | Updated outcome at follow-up |
| Additional_Information | string | Free-text follow-up notes |

## 7. Master Analytics Table (`data/processed/master_analytics_table.csv`)
Engineered, analysis-ready table joining all six source tables plus derived
features: `Age_Group`, `Elderly_Flag`, `Pediatric_Flag`, `Chronic_Disease_Flag`,
`Serious_Event_Flag`, `Fatal_Event_Flag`, `Hospitalized_Flag`,
`Time_to_Onset_Days`, `Exposure_Duration_Days`, `Polypharmacy_Flag`,
`Rechallenge_Flag`, `Reporting_Month`, `Reporting_Season`.
This is the single table used by the KPI and signal-detection scripts, and is
the recommended source table to import into Power BI / Tableau.
