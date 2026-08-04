"""
06_visualizations.py
------------------------------------------------------------------
Generates all chart images used in the README / as Power BI mockup
substitutes, saved to outputs/images/. Uses matplotlib only (no
internet / API dependency) so this runs anywhere.
------------------------------------------------------------------
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

PROCESSED = "../data/processed"
KPI = "../outputs/kpi_reports"
IMG = "../outputs/images"

plt.rcParams.update({
    "figure.facecolor": "white",
    "axes.facecolor": "white",
    "font.size": 11,
    "axes.titleweight": "bold",
    "axes.titlesize": 13,
    "axes.edgecolor": "#444444",
    "axes.grid": True,
    "grid.color": "#e6e6e6",
    "grid.linewidth": 0.7,
})

PALETTE = ["#0B5394", "#3D85C6", "#6FA8DC", "#9FC5E8", "#CFE2F3",
           "#B71C1C", "#E06666", "#F4CCCC", "#38761D", "#93C47D"]

df = pd.read_csv(f"{PROCESSED}/master_analytics_table.csv", parse_dates=["Event_Date"])


def savefig(fig, name):
    fig.tight_layout()
    fig.savefig(f"{IMG}/{name}.png", dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {name}.png")


# ------------------------------------------------------------------
# 1. Top 10 Drugs by ADR Count
# ------------------------------------------------------------------
top_drugs = pd.read_csv(f"{KPI}/kpi_06_top_drugs_by_adr.csv").head(10)
fig, ax = plt.subplots(figsize=(9, 5.5))
ax.barh(top_drugs["Drug"][::-1], top_drugs["ADR_Count"][::-1], color=PALETTE[0])
ax.set_title("Top 10 Drugs by ADR Report Count")
ax.set_xlabel("Number of ADR Reports")
savefig(fig, "01_top_drugs_by_adr")

# ------------------------------------------------------------------
# 2. Monthly ADR Trend
# ------------------------------------------------------------------
trend = pd.read_csv(f"{KPI}/kpi_08_monthly_adr_trend.csv")
fig, ax = plt.subplots(figsize=(11, 5))
ax.plot(trend["Reporting_Month"], trend["ADR_Count"], marker="o", color=PALETTE[1], linewidth=2)
ax.set_title("Monthly ADR Reporting Trend")
ax.set_xlabel("Month")
ax.set_ylabel("ADR Reports")
ax.xaxis.set_major_locator(mticker.MultipleLocator(4))
plt.xticks(rotation=45, ha="right")
savefig(fig, "02_monthly_adr_trend")

# ------------------------------------------------------------------
# 3. Severity Distribution (pie)
# ------------------------------------------------------------------
sev = pd.read_csv(f"{KPI}/kpi_10_severity_distribution.csv")
fig, ax = plt.subplots(figsize=(7, 7))
ax.pie(sev["Count"], labels=sev["Severity"], autopct="%1.1f%%",
       colors=PALETTE[:len(sev)], startangle=90,
       wedgeprops={"edgecolor": "white", "linewidth": 1.5})
ax.set_title("ADR Severity Distribution")
savefig(fig, "03_severity_distribution")

# ------------------------------------------------------------------
# 4. Age Group vs Serious ADR %
# ------------------------------------------------------------------
age_serious = df.groupby("Age_Group")["Serious_Event_Flag"].mean().mul(100).round(2)
age_serious = age_serious.reindex(["Pediatric", "Adult", "Elderly"])
fig, ax = plt.subplots(figsize=(7, 5))
ax.bar(age_serious.index, age_serious.values, color=[PALETTE[2], PALETTE[0], PALETTE[6]])
ax.set_title("Serious ADR % by Age Group")
ax.set_ylabel("Serious ADR %")
for i, v in enumerate(age_serious.values):
    ax.text(i, v + 0.5, f"{v}%", ha="center", fontweight="bold")
savefig(fig, "04_serious_adr_by_age_group")

# ------------------------------------------------------------------
# 5. Gender-wise ADR distribution
# ------------------------------------------------------------------
gender = pd.read_csv(f"{KPI}/kpi_11_gender_distribution.csv").dropna()
fig, ax = plt.subplots(figsize=(6, 5))
ax.bar(gender["Gender"], gender["Count"], color=[PALETTE[1], PALETTE[6]])
ax.set_title("ADR Reports by Gender")
ax.set_ylabel("ADR Count")
savefig(fig, "05_gender_distribution")

# ------------------------------------------------------------------
# 6. Drug Class Risk Ranking (Serious %)
# ------------------------------------------------------------------
class_risk = pd.read_csv(f"{KPI}/kpi_15_drug_class_risk_ranking.csv").sort_values("Serious_Pct")
fig, ax = plt.subplots(figsize=(9, 5.5))
ax.barh(class_risk["Drug_Class"], class_risk["Serious_Pct"], color=PALETTE[3])
ax.set_title("Serious ADR % by Therapeutic / Drug Class")
ax.set_xlabel("Serious ADR %")
savefig(fig, "06_drug_class_risk_ranking")

# ------------------------------------------------------------------
# 7. Top Manufacturers by ADR Reports
# ------------------------------------------------------------------
manu = pd.read_csv(f"{KPI}/kpi_20_top_manufacturers.csv")
fig, ax = plt.subplots(figsize=(8, 5))
ax.bar(manu["Manufacturer"], manu["ADR_Reports"], color=PALETTE[0])
ax.set_title("ADR Reports by Manufacturer")
ax.set_ylabel("ADR Reports")
plt.xticks(rotation=35, ha="right")
savefig(fig, "07_top_manufacturers")

# ------------------------------------------------------------------
# 8. Top 15 Reported Side Effects
# ------------------------------------------------------------------
effects = pd.read_csv(f"{KPI}/kpi_07_top_side_effects.csv").head(15)
fig, ax = plt.subplots(figsize=(9, 6.5))
ax.barh(effects["Side_Effect"][::-1], effects["Count"][::-1], color=PALETTE[7])
ax.set_title("Top 15 Reported Side Effects")
ax.set_xlabel("Number of Reports")
savefig(fig, "08_top_side_effects")

# ------------------------------------------------------------------
# 9. Drug Risk Score Ranking (Top 10)
# ------------------------------------------------------------------
risk = pd.read_csv(f"{KPI}/drug_risk_score_ranking.csv").sort_values("Risk_Score", ascending=False).head(10)
fig, ax = plt.subplots(figsize=(9, 5.5))
ax.barh(risk["Drug_Name"][::-1], risk["Risk_Score"][::-1], color=PALETTE[6])
ax.set_title("Top 10 Highest-Risk Drugs (Weighted Risk Score)")
ax.set_xlabel("Risk Score  =  5xFatal + 3xSerious + 2xHospitalized + New Signals")
savefig(fig, "09_drug_risk_score_top10")

# ------------------------------------------------------------------
# 10. PRR vs ROR scatter for signal detection
# ------------------------------------------------------------------
signals = pd.read_csv(f"{KPI}/prr_ror_signal_detection.csv")
fig, ax = plt.subplots(figsize=(8, 6))
colors = signals["Signal_Detected"].map({True: PALETTE[6], False: PALETTE[3]})
ax.scatter(signals["PRR"], signals["ROR"], c=colors, alpha=0.7, edgecolors="white", s=60)
ax.set_xlabel("PRR (Proportional Reporting Ratio)")
ax.set_ylabel("ROR (Reporting Odds Ratio)")
ax.set_title("Signal Detection: PRR vs ROR by Drug-Event Pair")
ax.axvline(2, color="gray", linestyle="--", linewidth=1)
handles = [plt.Line2D([0], [0], marker='o', color='w', markerfacecolor=PALETTE[6], markersize=9, label='Signal Detected'),
           plt.Line2D([0], [0], marker='o', color='w', markerfacecolor=PALETTE[3], markersize=9, label='No Signal')]
ax.legend(handles=handles)
savefig(fig, "10_prr_vs_ror_signal_scatter")

# ------------------------------------------------------------------
# 11. Executive summary KPI card (text-based image)
# ------------------------------------------------------------------
summary = pd.read_csv(f"{KPI}/kpi_00_executive_summary.csv")
summary_display = summary[summary["KPI"] != "Note_Reporting_Timeliness"]
fig, ax = plt.subplots(figsize=(9, 4.5))
ax.axis("off")
ax.set_title("Executive Summary - Key Pharmacovigilance KPIs", fontsize=15, pad=20)
n = len(summary_display)
cols = 3
for i, (_, row) in enumerate(summary_display.iterrows()):
    col = i % cols
    r = i // cols
    x = 0.05 + col * 0.33
    y = 0.75 - r * 0.35
    ax.text(x, y, str(row["Value"]), fontsize=22, fontweight="bold", color=PALETTE[0])
    ax.text(x, y - 0.13, row["KPI"].replace("_", " "), fontsize=10, color="#444444", wrap=True)
savefig(fig, "00_executive_summary_kpi_card")

print("\nAll visualizations generated in outputs/images/")
