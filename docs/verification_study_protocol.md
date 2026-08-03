# Verification Study Protocol (Draft)

**Status:** 🚧 Protocol draft only — not yet executed. This is the "Verification
Study Protocol" deliverable described in the project objective; it specifies
the design for a follow-up epidemiological study on the highest-priority
signal once real-world data (RWD) access is in place.

## Target signal

Highest-priority signal from `reports/prioritized_signal_report.csv`:
**Metformin – Lactic acidosis** (Borda score 720/720, EB05 = 4.66, significant
early-onset clustering).

*(In the current synthetic-data run this is a seeded positive control; in a
real deployment this section would be filled in from the actual top-ranked
signal.)*

## Study design

**Type:** Nested case-control study within a claims/EHR cohort (e.g. FDA
Sentinel Initiative or EMA DARWIN EU data partner).

**Rationale for design choice:** A nested case-control design is
computationally efficient for a rare outcome (lactic acidosis) within a
large exposed cohort (metformin users), and allows adjustment for
time-varying confounders via incidence-density sampling of controls.

### Population
- **Source cohort:** adult patients with a new metformin prescription,
  identified in the RWD source.
- **Cases:** cohort members with an incident lactic acidosis diagnosis
  during follow-up.
- **Controls:** incidence-density sampled from the same cohort, matched on
  calendar time and follow-up duration (4:1 control:case ratio).

### Exposure definition
- Current metformin use vs. active comparator (e.g. sulfonylurea
  monotherapy) at index date, to control for confounding by indication
  (as specified in the project's Active Comparator Analysis approach).

### Covariates for adjustment
- Age, sex, baseline renal function (eGFR), diabetes duration, relevant
  comorbidities (CKD, heart failure, hepatic impairment), concomitant
  nephrotoxic/interacting medications.

### Statistical analysis
- Conditional logistic regression (matched design) → adjusted odds ratio
  with 95% CI.
- Pre-specified sensitivity analyses: restrict to patients without
  pre-existing renal impairment; vary the exposure risk window
  (e.g., 30/90/180-day lookback).

### Outputs
- Adjusted effect estimate with CI
- E-value for unmeasured confounding
- Comparison against the discovery-phase EBGM/PRR estimates to assess
  consistency between spontaneous-report and RWD-based effect sizes

## Timeline (indicative)
1. Data partner access / IRB or equivalent approval — 4–8 weeks
2. Cohort construction and QC — 2–3 weeks
3. Analysis — 2 weeks
4. Report and internal review — 1–2 weeks

---
*This protocol is a design document only. No RWD access or IRB approval has
been sought as part of this portfolio project.*
