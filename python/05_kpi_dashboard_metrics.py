"""
05_kpi_dashboard_metrics.py
------------------------------------------------------------------
Calculates all core pharmacovigilance KPIs defined in the project
scope and exports them as clean CSVs ready to plug into Power BI /
Tableau, plus a single summary text/markdown report for the README.
------------------------------------------------------------------
"""

import pandas as pd
import numpy as np

PROCESSED = "../data/processed"
OUT = "../outputs/kpi_reports"

df = pd.read_csv(f"{PROCESSED}/master_analytics_table.csv", parse_dates=["Event_Date"])

total_reports = len(df)
kpi = {}

# 1. Total ADR Reports
kpi["Total_ADR_Reports"] = total_reports

# 2. Serious ADR %
kpi["Serious_ADR_Pct"] = round(df["Serious_Event_Flag"].sum() / total_reports * 100, 2)

# 3. Fatal Event Rate
kpi["Fatal_Event_Rate_Pct"] = round(df["Fatal_Event_Flag"].sum() / total_reports * 100, 2)

# 4. Hospitalization Rate
kpi["Hospitalization_Rate_Pct"] = round(df["Hospitalized_Flag"].sum() / total_reports * 100, 2)

# 6. Top Drugs with Maximum ADRs
top_drugs = df["Drug_Name"].value_counts().reset_index()
top_drugs.columns = ["Drug", "ADR_Count"]
top_drugs.to_csv(f"{OUT}/kpi_06_top_drugs_by_adr.csv", index=False)

# 7. Top Reported Side Effects
top_effects = df["Side_Effect"].value_counts().reset_index()
top_effects.columns = ["Side_Effect", "Count"]
top_effects.to_csv(f"{OUT}/kpi_07_top_side_effects.csv", index=False)

# 8. ADR Trend (monthly)
trend = df.groupby("Reporting_Month").size().reset_index(name="ADR_Count").sort_values("Reporting_Month")
trend.to_csv(f"{OUT}/kpi_08_monthly_adr_trend.csv", index=False)

# 9. Reporting Rate by Country
by_country = df["Country"].value_counts().reset_index()
by_country.columns = ["Country", "ADR_Reports"]
by_country.to_csv(f"{OUT}/kpi_09_reports_by_country.csv", index=False)

# 10. Severity Distribution
severity_dist = df["Severity"].value_counts().reset_index()
severity_dist.columns = ["Severity", "Count"]
severity_dist.to_csv(f"{OUT}/kpi_10_severity_distribution.csv", index=False)

# 11. Gender-wise ADR Rate
gender_dist = df["Gender"].value_counts(dropna=False).reset_index()
gender_dist.columns = ["Gender", "Count"]
gender_dist.to_csv(f"{OUT}/kpi_11_gender_distribution.csv", index=False)

# 12. Age-wise ADR Distribution
age_dist = df["Age_Group"].value_counts().reset_index()
age_dist.columns = ["Age_Group", "Count"]
age_dist.to_csv(f"{OUT}/kpi_12_age_group_distribution.csv", index=False)

# 13. Outcome Distribution
outcome_dist = df["Outcome"].value_counts().reset_index()
outcome_dist.columns = ["Outcome", "Count"]
outcome_dist.to_csv(f"{OUT}/kpi_13_outcome_distribution.csv", index=False)

# 14. Time to Onset (average)
kpi["Avg_Time_to_Onset_Days"] = round(df["Time_to_Onset_Days"].mean(), 1)

# 15. Drug Class Risk Ranking
class_risk = df.groupby("Drug_Class").agg(
    Total_Reports=("Event_ID", "count"),
    Serious_Pct=("Serious_Event_Flag", lambda x: round(x.mean() * 100, 2)),
    Fatal_Pct=("Fatal_Event_Flag", lambda x: round(x.mean() * 100, 2)),
).reset_index().sort_values("Serious_Pct", ascending=False)
class_risk.to_csv(f"{OUT}/kpi_15_drug_class_risk_ranking.csv", index=False)

# 16. Repeat ADR Reports (rechallenge as proxy for repeat/duplicate-type reports)
kpi["Repeat_Rechallenge_Pct"] = round(df["Rechallenge_Flag"].sum() / total_reports * 100, 2)

# 18. Reporting Timeliness -> avg days between event date and reporting date
# (reporter table has its own reporting date - approximate using follow-up/median as proxy)
kpi["Note_Reporting_Timeliness"] = "See reporter_table_clean.csv (Reporting_Date) vs Event_Date for timeliness analysis"

# 19. High-Risk Patient Groups
high_risk = df.groupby(["Age_Group", "Gender"]).agg(
    ADR_Count=("Event_ID", "count"),
    Serious_Pct=("Serious_Event_Flag", lambda x: round(x.mean() * 100, 2)),
).reset_index()
high_risk.to_csv(f"{OUT}/kpi_19_high_risk_patient_groups.csv", index=False)

chronic_risk = df.groupby("Chronic_Disease_Flag").agg(
    ADR_Count=("Event_ID", "count"),
    Serious_Pct=("Serious_Event_Flag", lambda x: round(x.mean() * 100, 2)),
    Fatal_Pct=("Fatal_Event_Flag", lambda x: round(x.mean() * 100, 2)),
).reset_index()
chronic_risk.to_csv(f"{OUT}/kpi_19b_chronic_disease_risk.csv", index=False)

# 20. Top Manufacturers by ADR Reports
top_manufacturers = df["Manufacturer"].value_counts().reset_index()
top_manufacturers.columns = ["Manufacturer", "ADR_Reports"]
top_manufacturers.to_csv(f"{OUT}/kpi_20_top_manufacturers.csv", index=False)

# ------------------------------------------------------------------
# Executive Summary KPI file
# ------------------------------------------------------------------
summary_df = pd.DataFrame(list(kpi.items()), columns=["KPI", "Value"])
summary_df.to_csv(f"{OUT}/kpi_00_executive_summary.csv", index=False)

print("All KPI CSVs generated in outputs/kpi_reports/\n")
print("EXECUTIVE SUMMARY KPIs")
print("=" * 40)
for k, v in kpi.items():
    print(f"{k:35s}: {v}")
