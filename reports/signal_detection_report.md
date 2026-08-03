# Validated Signal Detection Report

**Data source:** synthetic FAERS-structured sample (50,000 case reports, 15 drugs × 16 events) — see [`data/README.md`](../data/README.md) for status and real-data integration path.
**Pipeline:** `run_pipeline.R` → steps 00–06 (see [methodology](../docs/methodology.md))

## 1. Summary

The pipeline evaluated **240 drug-event pairs**, flagged **8** by classical
disproportionality criteria (PRR ≥ 2, χ² ≥ 4, N ≥ 3), and **3** by the
stricter empirical Bayes consensus criterion (EB05 > 2). After ensemble
ranking across disproportionality, GPS shrinkage, and time-to-onset
clustering, the top of the prioritized list cleanly separates into two
groups:

- **4 high-confidence signals** (Borda score 714–720) — well separated from
  the rest of the distribution, all showing significant early-onset
  clustering (Weibull shape κ < 1, p < 0.05)
- **A long tail of background pairs** (Borda score ≤ 648) with no
  early-onset pattern, consistent with chance co-occurrence

## 2. Validation against ground truth

Because the demo dataset has known seeded signals, the pipeline's output
can be checked against ground truth — this is normally impossible with real
FAERS data and is one of the reasons a synthetic dev/test set is useful
before wiring in production data.

**Result: 4 / 4 seeded true signals recovered as the top 4 ranked pairs**, with no false positives ranked above them.

| Rank | Drug | Event | N | PRR | EBGM | EB05 | Early onset (κ<1)? | Seeded true signal? |
|---|---|---|---|---|---|---|---|---|
| 1 | Metformin | Lactic acidosis | 1313 | 6.85 | 4.87 | 4.66 | ✅ | ✅ |
| 2 | Atorvastatin | Myopathy | 1002 | 5.27 | 4.13 | 3.92 | ✅ | ✅ |
| 3 | Empagliflozin | Acute kidney injury | 674 | 3.12 | 2.70 | 2.54 | ✅ | ✅ |
| 4 | Warfarin | GI haemorrhage | 434 | 2.21 | 2.02 | 1.87 | ✅ | ✅ |
| 5 | Glipizide | QT prolongation | 353 | 2.11 | 1.95 | 1.78 | ❌ | ❌ (background) |

Full ranked list: [`reports/prioritized_signal_report.csv`](prioritized_signal_report.csv)

## 3. Supporting visualizations

| Figure | Description |
|---|---|
| ![PRR heatmap](figures/prr_heatmap.png) | Drug × Event PRR heatmap across all 240 pairs |
| ![Eye plot](figures/eye_plot.png) | GPS eye plot — EBGM vs. report count, with EB05/EB95 credibility whiskers. Seeded true signals (red) sit clearly above background (blue) even after Bayesian shrinkage. |
| ![Forest plot](figures/forest_plot_top10.png) | ROR with 95% CI for the top 10 prioritized pairs |

## 4. Preliminary plausibility assessment

| Signal | Plausibility note |
|---|---|
| Metformin – Lactic acidosis | Consistent with the well-established (real-world) metformin/lactic acidosis association; useful as a known-positive control if this pipeline is later run on real FAERS data |
| Atorvastatin – Myopathy | Consistent with the established statin-class myopathy/rhabdomyolysis signal |
| Empagliflozin – Acute kidney injury | SGLT2 inhibitors have a recognized, monitored AKI signal in real pharmacovigilance |
| Warfarin – GI haemorrhage | Anticoagulant bleeding risk is a textbook expected signal |

*(These four pairs were deliberately modeled on well-known real-world
drug safety associations when designing the synthetic ground truth — the
point of the exercise was to confirm the pipeline recovers signals with
known real-world analogues, not to make a novel safety claim.)*

## 5. Next steps (see `docs/methodology.md` → Verification Study Protocol)

1. Replace synthetic input with a real FAERS/openFDA extract via `01_data_preprocessing.R`.
2. Run stratified/active-comparator analysis on the flagged pairs to control for confounding by indication.
3. Draft a nested case-control study protocol for the highest-priority signal once real data is in place.

---
*Generated from `run_pipeline.R`. Regenerate anytime with `Rscript run_pipeline.R`.*
