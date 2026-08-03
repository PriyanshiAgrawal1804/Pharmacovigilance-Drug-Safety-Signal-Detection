# Methodology

## Overview

This project implements a two-phase signal management workflow, following
standard pharmacovigilance practice (WHO/EMA/FDA-aligned):

```
                 ┌─────────────────────┐
 Raw case        │  Phase 1: DISCOVERY  │
 reports  ─────▶ │  (statistical mining)│
                 └──────────┬───────────┘
                            │ candidate signals
                            ▼
                 ┌─────────────────────┐
                 │ Phase 2: VERIFICATION│
                 │ (confounding control,│
                 │  ensemble consensus) │
                 └──────────┬───────────┘
                            │
                            ▼
                 Prioritized signal report
```

## Phase 1 — Signal Discovery

### 1.1 Data preprocessing (`01_data_preprocessing.R`)
- De-duplication of exact-duplicate case rows
- Text harmonisation (trim/case) as a stand-in for full MedDRA/ATC coding
- Construction of the drug × event contingency table (`N_ij`)

### 1.2 Disproportionality analysis (`02_disproportionality_analysis.R`)
Standard 2×2 contingency-table statistics computed for every drug-event pair:

| Metric | Formula | Signal threshold used here |
|---|---|---|
| PRR | (a/(a+b)) / (c/(c+d)) | PRR ≥ 2 |
| ROR | (a·d)/(b·c), with 95% CI | reported, not used as sole gate |
| χ² | Yates-corrected 2×2 chi-square | χ² ≥ 4 |
| N | raw count | N ≥ 3 |

These are the classic MHRA-style rule-of-three criteria used as a first
coarse filter.

### 1.3 Empirical Bayes GPS shrinkage (`03_empirical_bayes_gps.R`)
Disproportionality metrics are unstable for low-count pairs, so a
Gamma-Poisson Shrinker (GPS / MGPS, DuMouchel 1999) is fit to pull noisy
ratios toward a data-driven prior:

1. A two-component Gamma mixture prior is fit to the empirical `N_ij / E_ij`
   distribution by maximum likelihood (`optim`, Nelder-Mead).
2. Each cell's posterior mean relative-reporting-ratio (**EBGM**) and its
   90% credibility interval (**EB05**, **EB95**) are computed by shrinking
   the raw ratio toward the fitted prior, weighted by the posterior mixture
   probability.
3. Standard MGPS signal criterion: **EB05 > 2**.

> **Package note:** the `pvEBayes` CRAN package implements a more complete
> version of this parametric + non-parametric empirical Bayes model. This
> environment did not have outbound CRAN access, so the core GPS algorithm
> above was implemented directly in base R to keep the pipeline runnable
> end-to-end. The interface (`fit → posterior_ebgm`) is designed so that
> swapping in `pvEBayes::pvEB()` later is a small, localized change in
> `03_empirical_bayes_gps.R` only.

### 1.4 Time-to-onset analysis (`04_time_to_onset_weibull.R`)
For candidate pairs with N ≥ 20, a Weibull distribution is fit to the
observed time-to-onset values (`MASS::fitdistr`), and the shape parameter
κ is tested against 1:

- **κ < 1** (hazard decreasing) → events cluster shortly after drug
  initiation → supportive of a causal, early pharmacological reaction
- **κ ≈ 1** → consistent with a random/background process
- **κ > 1** → late-onset pattern

> **Package note:** same situation as above — `WSPsignal::wsp_test()` was
> not installable without CRAN access, so the same statistical test
> (Weibull MLE + one-sided shape test) is implemented directly using
> `MASS::fitdistr`, which ships with base R.

## Phase 2 — Signal Verification

### 2.1 Ensemble ranking (`05_ensemble_ranking.R`)
The three methods above are combined via **Borda count**: each pair is
ranked within each method, and the (inverted) ranks are summed to produce
a single consensus score. This down-weights signals that only one method
flags and rewards pairs that multiple independent statistical approaches
agree on — the same logic as combining GPS, penalized regression, and
random forests described in the original project scope, using GPS,
disproportionality, and time-to-onset as the three independent legs here.

### 2.2 Confounding control (planned / next phase)
Not yet implemented against real data (no comparator/covariate data exists
in the synthetic set beyond age/sex/country), but designed for:
- **Active comparator analysis** — compare against a clinically appropriate
  alternative drug in the same class, rather than "all other drugs"
- **Stratification / logistic regression** — adjust for age, sex, and
  concomitant medications once RWD (EHR/claims) is integrated

### 2.3 Verification study protocol
See [`docs/verification_study_protocol.md`](verification_study_protocol.md)
for the planned nested case-control study design for the highest-priority
signal once real data is wired in.

## Reproducibility

- All steps are plain R scripts, no notebook state — `run_pipeline.R` runs
  them in order from a clean checkout.
- Random seed fixed (`set.seed(42)`) in the synthetic data generator.
- No external network calls required to run the pipeline (synthetic data
  generation is entirely local).
