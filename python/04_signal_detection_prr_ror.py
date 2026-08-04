"""
04_signal_detection_prr_ror.py
------------------------------------------------------------------
Disproportionality analysis for pharmacovigilance signal detection.

For every (Drug, Side_Effect) pair, builds a 2x2 contingency table:

                    Event of Interest   All Other Events
Drug of Interest           a                   b
All Other Drugs            c                   d

And computes the standard industry disproportionality statistics:

    - PRR  (Proportional Reporting Ratio)
    - ROR  (Reporting Odds Ratio)
    - IC   (Information Component, Bayesian shrinkage)
    - Chi-square statistic (with Yates' correction)

A signal is flagged using the common regulatory convention:
    PRR >= 2, Chi-square >= 4, and a >= 3 cases (Evans criteria)
------------------------------------------------------------------
"""

import pandas as pd
import numpy as np
from scipy.stats import chi2_contingency

PROCESSED = "../data/processed"
OUT = "../outputs/kpi_reports"

df = pd.read_csv(f"{PROCESSED}/master_analytics_table.csv")

total_reports = len(df)

# Build drug-event pair counts
pair_counts = df.groupby(["Drug_Name", "Side_Effect"]).size().reset_index(name="a")
drug_totals = df.groupby("Drug_Name").size().rename("drug_total")
event_totals = df.groupby("Side_Effect").size().rename("event_total")

results = []
for _, row in pair_counts.iterrows():
    drug, event, a = row["Drug_Name"], row["Side_Effect"], row["a"]

    drug_total = drug_totals[drug]
    event_total = event_totals[event]

    b = drug_total - a                       # this drug, other events
    c = event_total - a                      # other drugs, this event
    d = total_reports - a - b - c            # other drugs, other events

    # avoid zero-division; use Haldane-Anscombe correction where needed
    a_c, b_c, c_c, d_c = a, b, c, d
    if min(a, b, c, d) == 0:
        a_c, b_c, c_c, d_c = a + 0.5, b + 0.5, c + 0.5, d + 0.5

    prr = (a_c / (a_c + b_c)) / (c_c / (c_c + d_c))
    ror = (a_c * d_c) / (b_c * c_c)

    # Information Component (IC) - Bayesian shrinkage, log2 of observed/expected
    expected = ((a + b) * (a + c)) / total_reports if total_reports > 0 else np.nan
    ic = np.log2((a + 0.5) / (expected + 0.5)) if expected and expected > 0 else np.nan

    # Chi-square with Yates correction
    try:
        chi2, p_val, _, _ = chi2_contingency([[a, b], [c, d]], correction=True)
    except ValueError:
        chi2, p_val = np.nan, np.nan

    is_signal = (prr >= 2) and (chi2 >= 4) and (a >= 3)

    results.append({
        "Drug_Name": drug,
        "Side_Effect": event,
        "Reports_a_DrugAndEvent": a,
        "Reports_b_DrugOnly": b,
        "Reports_c_EventOnly": c,
        "Reports_d_Neither": d,
        "PRR": round(prr, 3),
        "ROR": round(ror, 3),
        "Information_Component": round(ic, 3) if not np.isnan(ic) else np.nan,
        "Chi_Square": round(chi2, 3) if not np.isnan(chi2) else np.nan,
        "P_Value": round(p_val, 5) if not np.isnan(p_val) else np.nan,
        "Signal_Detected": is_signal,
    })

signal_df = pd.DataFrame(results).sort_values(["Signal_Detected", "PRR"], ascending=[False, False])
signal_df.to_csv(f"{OUT}/prr_ror_signal_detection.csv", index=False)

n_signals = signal_df["Signal_Detected"].sum()
print(f"Disproportionality analysis complete for {len(signal_df)} drug-event pairs.")
print(f"New safety signals detected (PRR>=2, Chi2>=4, cases>=3): {n_signals}")
print("\nTop 10 strongest signals:")
print(signal_df[signal_df["Signal_Detected"]].head(10)[
    ["Drug_Name", "Side_Effect", "Reports_a_DrugAndEvent", "PRR", "ROR", "Chi_Square"]
].to_string(index=False))

# Drug-level risk score (combining fatal/serious/hospitalization + signal count)
risk = df.groupby("Drug_Name").agg(
    Total_Reports=("Event_ID", "count"),
    Fatal_Events=("Fatal_Event_Flag", "sum"),
    Serious_Events=("Serious_Event_Flag", "sum"),
    Hospitalizations=("Hospitalized_Flag", "sum"),
).reset_index()

signal_counts = signal_df[signal_df["Signal_Detected"]].groupby("Drug_Name").size().rename("New_Signals")
risk = risk.merge(signal_counts, on="Drug_Name", how="left")
risk["New_Signals"] = risk["New_Signals"].fillna(0).astype(int)

risk["Risk_Score"] = (
    5 * risk["Fatal_Events"] + 3 * risk["Serious_Events"] + 2 * risk["Hospitalizations"] + risk["New_Signals"]
)
risk = risk.sort_values("Risk_Score", ascending=False)
risk.to_csv(f"{OUT}/drug_risk_score_ranking.csv", index=False)

print("\nTop 10 highest-risk drugs (weighted Risk Score):")
print(risk.head(10).to_string(index=False))
