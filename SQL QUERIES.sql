USE PHARMA;

# SECTION 0 — DATA CLEANING VIEWS

# 0.1 Cleaned demographics: normalized sex, numeric age in years, numeric weight
CREATE VIEW v_demo_clean AS
SELECT
    primaryid,
    caseid,
    case_version,

    CASE
        WHEN UPPER(TRIM(sex)) IN ('F','FEMALE','2') THEN 'F'
        WHEN UPPER(TRIM(sex)) IN ('M','MALE','1') THEN 'M'
        ELSE 'UNK'
    END AS sex_clean,

    CASE
        WHEN age IS NULL
             OR UPPER(TRIM(age)) IN ('UNK','NA','N/A','999','-','')
             THEN NULL

        WHEN CAST(age AS CHAR) REGEXP '[^0-9.]'
             THEN NULL

        WHEN UPPER(TRIM(age_cod)) = 'MON'
             THEN ROUND(CAST(age AS DECIMAL(10,2))/12.0,2)

        WHEN UPPER(TRIM(age_cod)) = 'DEC'
             THEN CAST(age AS DECIMAL(10,2))

        ELSE CAST(age AS DECIMAL(10,2))
    END AS age_years,

    CASE
        WHEN wt_kg IS NULL
             OR UPPER(TRIM(wt_kg)) IN ('UNK','NA','N/A','999','-','')
             THEN NULL

        WHEN CAST(wt_kg AS CHAR) REGEXP '[^0-9.]'
             THEN NULL

        ELSE CAST(wt_kg AS DECIMAL(10,2))
    END AS wt_kg_clean,

    UPPER(TRIM(occr_country)) AS country_clean,
    UPPER(TRIM(reporter_occupation)) AS occupation_clean,
    event_dt,
    rept_dt

FROM demo;

# 0.2 Cleaned drug records, filtered to plausible role codes only
CREATE VIEW v_drug_clean AS
SELECT
    primaryid,
    drug_seq,
    UPPER(TRIM(drugname)) AS drugname_clean,
    UPPER(TRIM(role_cod)) AS role_cod,
    UPPER(TRIM(route)) AS route_clean,

    CASE
        WHEN dose_amt IS NULL THEN NULL
        WHEN TRIM(dose_amt) NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE CAST(dose_amt AS DECIMAL(10,2))
    END AS dose_amt_clean,

    UPPER(TRIM(dose_unit)) AS dose_unit_clean,
    UPPER(TRIM(dechal)) AS dechal_clean,
    UPPER(TRIM(rechal)) AS rechal_clean

FROM drug
WHERE drugname IS NOT NULL;

# 0.3 Cleaned reaction terms (Preferred Terms, case-normalized)
CREATE VIEW v_reac_clean AS
SELECT primaryid, UPPER(TRIM(pt)) AS pt_clean, UPPER(TRIM(drug_rec_act)) AS drug_rec_act_clean
FROM reac
WHERE pt IS NOT NULL;

# 0.4 One row per (suspect drug, reaction) pair per case — the base unit for
--     every disproportionality calculation below.
CREATE VIEW v_drug_reaction_pairs AS
SELECT DISTINCT d.primaryid, d.drugname_clean AS drug, r.pt_clean AS reaction
FROM v_drug_clean d
JOIN v_reac_clean r ON d.primaryid = r.primaryid
WHERE d.role_cod IN ('PS','SS');

# SECTION 1 — SIMPLE: exploration, counts, distincts

# 1.1 Total number of unique case reports
SELECT COUNT(DISTINCT primaryid) AS total_cases FROM demo;
 
# 1.2 Total drug records, reaction records, outcome records
SELECT
    (SELECT COUNT(*) FROM drug) AS drug_records,
    (SELECT COUNT(*) FROM reac) AS reaction_records,
    (SELECT COUNT(*) FROM outc) AS outcome_records,
    (SELECT COUNT(*) FROM indi) AS indication_records;
 
# 1.3 Distinct raw values in a dirty column (sanity check before cleaning)
SELECT DISTINCT sex FROM demo;
 
# 1.4 Distinct drug role codes and what they mean structurally
SELECT DISTINCT role_cod FROM drug;
 
# 1.5 List the 10 most recently reported cases (by rept_dt, as text sort —
--     acceptable only for the YYYYMMDD-style rows; see Section 5 for a real fix)
SELECT primaryid, rept_dt FROM demo ORDER BY rept_dt DESC LIMIT 10;

# SECTION 2 — FILTERING & BASIC AGGREGATION

# 2.1 Case counts by cleaned sex
SELECT sex_clean, COUNT(*) AS n
FROM v_demo_clean
GROUP BY sex_clean
ORDER BY n DESC;

# 2.2 Outcome frequency (which outcome codes dominate the case series)
SELECT outc_cod,
       CASE outc_cod
            WHEN 'DE' THEN 'Death'
            WHEN 'HO' THEN 'Hospitalization'
            WHEN 'CA' THEN 'Congenital Anomaly'
            WHEN 'DS' THEN 'Disability'
            WHEN 'RI' THEN 'Life-Threatening'
            WHEN 'OT' THEN 'Other'
            ELSE outc_cod
       END AS outcome_desc,
       COUNT(*) AS n
FROM outc
GROUP BY outc_cod
ORDER BY n DESC;

# 2.3 Reports where the outcome was Death, joined back to demographics
SELECT dc.primaryid, dc.sex_clean, dc.age_years, dc.country_clean
FROM v_demo_clean dc
JOIN outc o ON dc.primaryid = o.primaryid
WHERE o.outc_cod = 'DE'
LIMIT 20;

# 2.4 Top 10 most frequently reported adverse reactions 
SELECT pt_clean, COUNT(DISTINCT primaryid) AS case_count
FROM v_reac_clean
GROUP BY pt_clean
ORDER BY case_count DESC
LIMIT 10;

# 2.5 Top 10 most frequently implicated suspect drugs
SELECT drugname_clean, COUNT(DISTINCT primaryid) AS case_count
FROM v_drug_clean
WHERE role_cod IN ('PS','SS')
GROUP BY drugname_clean
ORDER BY case_count DESC
LIMIT 10;

# SECTION 3 — JOINS ACROSS THE CASE STRUCTURE

# 3.1 Full case profile: demographics + drug + reaction for one case
SELECT dc.primaryid, dc.sex_clean, dc.age_years, dc.country_clean,
       d.drugname_clean, d.role_cod, r.pt_clean AS reaction
FROM v_demo_clean dc
JOIN v_drug_clean d ON dc.primaryid = d.primaryid
JOIN v_reac_clean r ON dc.primaryid = r.primaryid
LIMIT 20;

# 3.2 Most common (drug, reaction) pairs overall — the raw co-occurrence table
SELECT drug, reaction, COUNT(DISTINCT primaryid) AS n_cases
FROM v_drug_reaction_pairs
GROUP BY drug, reaction
ORDER BY n_cases DESC
LIMIT 15;

# 3.3 Reactions reported for a specific drug of interest (parameterize the drug)
SELECT reaction, COUNT(DISTINCT primaryid) AS n_cases
FROM v_drug_reaction_pairs
WHERE drug = 'IBUPROFEN'
GROUP BY reaction
ORDER BY n_cases DESC;

# 3.4 Indications vs. reactions: cases where the indication and the reported
--     reaction share the same term (a rough proxy for "disease progression"
--     misclassified as an adverse event — a known PV data-quality issue)
SELECT i.indi_pt, COUNT(DISTINCT i.primaryid) AS n
FROM indi i
JOIN reac r ON i.primaryid = r.primaryid
WHERE UPPER(TRIM(i.indi_pt)) = UPPER(TRIM(r.pt))
GROUP BY i.indi_pt
ORDER BY n DESC;

# 3.5 Serious cases (Death or Hospitalization) by primary suspect drug
SELECT d.drugname_clean, COUNT(DISTINCT d.primaryid) AS serious_cases
FROM v_drug_clean d
JOIN outc o ON d.primaryid = o.primaryid
WHERE d.role_cod = 'PS' AND o.outc_cod IN ('DE','HO')
GROUP BY d.drugname_clean
ORDER BY serious_cases DESC
LIMIT 15;

# SECTION 4 — WINDOW FUNCTIONS & RANKING

# 4.1 Rank reactions within each drug by frequency (top reaction per drug)
WITH ranked AS (
    SELECT drug, reaction, COUNT(DISTINCT primaryid) AS n,
           ROW_NUMBER() OVER (PARTITION BY drug ORDER BY COUNT(DISTINCT primaryid) DESC) AS rn
    FROM v_drug_reaction_pairs
    GROUP BY drug, reaction
)
SELECT drug, reaction, n
FROM ranked
WHERE rn = 1
ORDER BY n DESC
LIMIT 15;

# 4.2 Running share of total reaction volume 
WITH reac_counts AS (
    SELECT pt_clean, COUNT(DISTINCT primaryid) AS n
    FROM v_reac_clean
    GROUP BY pt_clean
)
SELECT pt_clean, n,
       ROUND(100.0 * n / SUM(n) OVER (), 2) AS pct_of_total,
       ROUND(100.0 * SUM(n) OVER (ORDER BY n DESC) / SUM(n) OVER (), 2) AS cumulative_pct
FROM reac_counts
ORDER BY n DESC
LIMIT 20;

# 4.3 Age-decile risk profile: does a reaction cluster in a specific age band?
WITH aged AS (
    SELECT dc.primaryid, dc.age_years,
           NTILE(5) OVER (ORDER BY dc.age_years) AS age_quintile
    FROM v_demo_clean dc
    WHERE dc.age_years IS NOT NULL
)
SELECT a.age_quintile,
       MIN(a.age_years) AS min_age, MAX(a.age_years) AS max_age,
       COUNT(DISTINCT r.primaryid) AS n_cases_with_reaction
FROM aged a
JOIN v_reac_clean r ON a.primaryid = r.primaryid
WHERE r.pt_clean = 'HEPATIC FAILURE'
GROUP BY a.age_quintile
ORDER BY a.age_quintile;

# SECTION 5 — DATE HANDLING

# 5.1 Normalize event_dt into ISO format across the mixed formats present
CREATE VIEW v_demo_dates AS
SELECT
    primaryid,
    event_dt AS event_dt_raw,

    CASE

        -- YYYYMMDD
        WHEN event_dt REGEXP '^[0-9]{8}$'
        THEN CONCAT(
            SUBSTRING(event_dt, 1, 4), '-',
            SUBSTRING(event_dt, 5, 2), '-',
            SUBSTRING(event_dt, 7, 2)
        )

        -- MM/DD/YYYY
        WHEN event_dt REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
        THEN CONCAT(
            SUBSTRING(event_dt, 7, 4), '-',
            SUBSTRING(event_dt, 1, 2), '-',
            SUBSTRING(event_dt, 4, 2)
        )

        -- YYYY-MM-DD
        WHEN event_dt REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN event_dt

        -- UNK, month-name formats, 2-digit years, etc.
        ELSE NULL

    END AS event_dt_iso

FROM demo;

# 5.2 Reporting lag in days (rept_dt - event_dt) for the subset of records
--     where both dates parsed cleanly to ISO format
SELECT
    dd.primaryid,
    dd.event_dt_iso,
    DATEDIFF(
        CURDATE(),
        STR_TO_DATE(dd.event_dt_iso, '%Y-%m-%d')
    ) AS days_since_event
FROM v_demo_dates dd
WHERE dd.event_dt_iso IS NOT NULL
ORDER BY dd.event_dt_iso DESC
LIMIT 10;

# 5.3 Data-quality audit: what fraction of event dates failed to parse under
--     the known formats above?
SELECT
    COUNT(*) AS total,
    SUM(CASE WHEN event_dt_iso IS NOT NULL THEN 1 ELSE 0 END) AS parsed,
    SUM(CASE WHEN event_dt_iso IS NULL THEN 1 ELSE 0 END) AS unparsed,
    ROUND(100.0 * SUM(CASE WHEN event_dt_iso IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_unparsed
FROM v_demo_dates;

# SECTION 6 — DISPROPORTIONALITY / SIGNAL DETECTION

# 6.1 Build the full 2x2 contingency table components for every (drug, reaction)
--     pair with at least 3 co-occurring cases
CREATE VIEW v_signal_base AS
WITH pair_counts AS (
    SELECT drug, reaction, COUNT(DISTINCT primaryid) AS a
    FROM v_drug_reaction_pairs
    GROUP BY drug, reaction
),
drug_totals AS (
    SELECT drug, COUNT(DISTINCT primaryid) AS drug_total
    FROM v_drug_reaction_pairs
    GROUP BY drug
),
reaction_totals AS (
    SELECT reaction, COUNT(DISTINCT primaryid) AS reaction_total
    FROM v_drug_reaction_pairs
    GROUP BY reaction
),
grand_total AS (
    SELECT COUNT(DISTINCT primaryid) AS n FROM v_drug_reaction_pairs
)
SELECT
    pc.drug, pc.reaction, pc.a,
    (dt.drug_total - pc.a)                                   AS b,   -- drug, other reactions
    (rt.reaction_total - pc.a)                                AS c,   -- other drugs, this reaction
    (gt.n - dt.drug_total - rt.reaction_total + pc.a)         AS d,   -- other drugs, other reactions
    dt.drug_total, rt.reaction_total, gt.n
FROM pair_counts pc
JOIN drug_totals dt     ON pc.drug = dt.drug
JOIN reaction_totals rt ON pc.reaction = rt.reaction
CROSS JOIN grand_total gt
WHERE pc.a >= 3;

# 6.2 PRR and ROR per pair, with the conventional signal flag
--     (a>=3 AND PRR>=2 AND chi_square>=4)
SELECT
    drug, reaction, a, b, c, d,
    ROUND( (a*1.0/(a+b)) / (c*1.0/(c+d)), 3)                       AS prr,
    ROUND( (a*1.0*d) / (b*1.0*c), 3)                                AS ror,
    ROUND( ( (a*1.0*d - b*1.0*c) * (a*1.0*d - b*1.0*c) * (a+b+c+d) )
           / ( (a+b)*1.0*(c+d)*(a+c)*(b+d) ), 3)                    AS chi_square,
    CASE WHEN
        ( (a*1.0/(a+b)) / (c*1.0/(c+d)) ) >= 2
        AND ( ( (a*1.0*d - b*1.0*c) * (a*1.0*d - b*1.0*c) * (a+b+c+d) )
              / ( (a+b)*1.0*(c+d)*(a+c)*(b+d) ) ) >= 4
        THEN 'SIGNAL'
        ELSE 'no signal'
    END AS signal_flag
FROM v_signal_base
ORDER BY prr DESC
LIMIT 25;

# 6.3 Confirmed signals only, ranked by chi-square strength 
WITH scored AS (
    SELECT
        drug, reaction, a, b, c, d,
        (a*1.0/(a+b)) / (c*1.0/(c+d)) AS prr,
        ( (a*1.0*d - b*1.0*c) * (a*1.0*d - b*1.0*c) * (a+b+c+d) )
          / ( (a+b)*1.0*(c+d)*(a+c)*(b+d) ) AS chi_square
    FROM v_signal_base
)
SELECT drug, reaction, a AS n_cases, ROUND(prr,2) AS prr, ROUND(chi_square,2) AS chi_square
FROM scored
WHERE a >= 3 AND prr >= 2 AND chi_square >= 4
ORDER BY chi_square DESC
LIMIT 25;

# 6.4 Signal detection restricted to serious outcomes only (Death /
--     Hospitalization / Life-Threatening) — the highest-priority safety signals
WITH serious_pairs AS (
    SELECT DISTINCT d.primaryid, d.drugname_clean AS drug, r.pt_clean AS reaction
    FROM v_drug_clean d
    JOIN v_reac_clean r ON d.primaryid = r.primaryid
    JOIN outc o ON d.primaryid = o.primaryid
    WHERE d.role_cod IN ('PS','SS') AND o.outc_cod IN ('DE','HO','RI')
),
pair_counts AS (
    SELECT drug, reaction, COUNT(DISTINCT primaryid) AS a FROM serious_pairs GROUP BY drug, reaction
),
drug_totals AS (
    SELECT drug, COUNT(DISTINCT primaryid) AS drug_total FROM serious_pairs GROUP BY drug
),
reaction_totals AS (
    SELECT reaction, COUNT(DISTINCT primaryid) AS reaction_total FROM serious_pairs GROUP BY reaction
),
grand_total AS ( SELECT COUNT(DISTINCT primaryid) AS n FROM serious_pairs )
SELECT
    pc.drug, pc.reaction, pc.a AS n_serious_cases,
    ROUND( (pc.a*1.0/dt.drug_total) / ((rt.reaction_total-pc.a)*1.0/(gt.n-dt.drug_total)), 3) AS prr
FROM pair_counts pc
JOIN drug_totals dt ON pc.drug = dt.drug
JOIN reaction_totals rt ON pc.reaction = rt.reaction
CROSS JOIN grand_total gt
WHERE pc.a >= 3
ORDER BY prr DESC
LIMIT 20;

# SECTION 7 — DECHALLENGE / RECHALLENGE ANALYSIS

# 7.1 Drugs with the highest rate of positive dechallenge + positive rechallenge
--     among their suspect-drug reports
SELECT drugname_clean,
       COUNT(*) AS n_reports,
       SUM(CASE WHEN dechal_clean='Y' AND rechal_clean='Y' THEN 1 ELSE 0 END) AS positive_de_rechallenge,
       ROUND(100.0 * SUM(CASE WHEN dechal_clean='Y' AND rechal_clean='Y' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct
FROM v_drug_clean
WHERE role_cod IN ('PS','SS')
GROUP BY drugname_clean
HAVING n_reports >= 5
ORDER BY pct DESC
LIMIT 15;

# SECTION 8 — COHORT / DEMOGRAPHIC RISK STRATIFICATION

# 8.1 Sex-stratified PRR for a specific drug-reaction pair (does the signal
--     differ by sex? useful for flagging demographic-specific risk)
WITH base AS (
    SELECT dc.sex_clean, vp.drug, vp.reaction, vp.primaryid
    FROM v_drug_reaction_pairs vp
    JOIN v_demo_clean dc ON vp.primaryid = dc.primaryid
),
counts AS (
    SELECT sex_clean, drug, reaction, COUNT(DISTINCT primaryid) AS a
    FROM base
    GROUP BY sex_clean, drug, reaction
),
sex_reaction_totals AS (
    SELECT sex_clean, reaction, COUNT(DISTINCT primaryid) AS reaction_total
    FROM base GROUP BY sex_clean, reaction
),
sex_drug_totals AS (
    SELECT sex_clean, drug, COUNT(DISTINCT primaryid) AS drug_total
    FROM base GROUP BY sex_clean, drug
)
SELECT c.sex_clean, c.drug, c.reaction, c.a,
       ROUND( (c.a*1.0/dt.drug_total) /
              ((rt.reaction_total - c.a)*1.0 / NULLIF(rt.reaction_total,0)), 3) AS within_sex_share_ratio
FROM counts c
JOIN sex_drug_totals dt ON c.sex_clean=dt.sex_clean AND c.drug=dt.drug
JOIN sex_reaction_totals rt ON c.sex_clean=rt.sex_clean AND c.reaction=rt.reaction
WHERE c.drug = 'RIVAROXABAN' AND c.a >= 2
ORDER BY c.sex_clean, c.a DESC;

# 8.2 Country-level reporting volume and top reaction per country (useful for
--     spotting regional reporting artifacts vs. genuine geographic signals)
WITH by_country AS (
    SELECT dc.country_clean, r.pt_clean AS reaction, COUNT(DISTINCT dc.primaryid) AS n
    FROM v_demo_clean dc
    JOIN v_reac_clean r ON dc.primaryid = r.primaryid
    GROUP BY dc.country_clean, r.pt_clean
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY country_clean ORDER BY n DESC) AS rn
    FROM by_country
)
SELECT country_clean, reaction AS top_reaction, n
FROM ranked
WHERE rn = 1
ORDER BY n DESC
LIMIT 15;

# SECTION 9 — CASE-LEVEL COMPLETENESS / DATA QUALITY SCORING

# 9.1 Completeness score per case: presence of age, sex, weight, dose,
--     indication, and dechallenge status (0-6 scale)
SELECT
    dc.primaryid,

    (
        CASE
            WHEN dc.age_years IS NOT NULL THEN 1
            ELSE 0
        END

        +

        CASE
            WHEN dc.sex_clean <> 'UNK' THEN 1
            ELSE 0
        END

        +

        CASE
            WHEN dc.wt_kg_clean IS NOT NULL THEN 1
            ELSE 0
        END

        +

        CASE
            WHEN d.has_dose = 1 THEN 1
            ELSE 0
        END

        +

        CASE
            WHEN i.has_indication = 1 THEN 1
            ELSE 0
        END

        +

        CASE
            WHEN d.has_dechallenge = 1 THEN 1
            ELSE 0
        END
    ) AS completeness_score

FROM v_demo_clean dc

LEFT JOIN (
    SELECT
        primaryid,
        MAX(
            CASE
                WHEN dose_amt_clean IS NOT NULL THEN 1
                ELSE 0
            END
        ) AS has_dose,

        MAX(
            CASE
                WHEN dechal_clean IN ('Y', 'N') THEN 1
                ELSE 0
            END
        ) AS has_dechallenge

    FROM v_drug_clean
    GROUP BY primaryid
) d
    ON d.primaryid = dc.primaryid

LEFT JOIN (
    SELECT
        primaryid,
        1 AS has_indication
    FROM indi
    GROUP BY primaryid
) i
    ON i.primaryid = dc.primaryid

ORDER BY completeness_score ASC
LIMIT 20;

# 9.2 Distribution of completeness scores across the whole case series
WITH scored AS (
    SELECT
        dc.primaryid,
        (CASE WHEN dc.age_years IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN dc.sex_clean != 'UNK' THEN 1 ELSE 0 END) +
        (CASE WHEN dc.wt_kg_clean IS NOT NULL THEN 1 ELSE 0 END) AS completeness_score
    FROM v_demo_clean dc
)
SELECT completeness_score, COUNT(*) AS n_cases
FROM scored
GROUP BY completeness_score
ORDER BY completeness_score;

# SECTION 10 — EXECUTIVE SUMMARY

# 10.1 One consolidated "signal watchlist" row per confirmed signal: case
--      counts, PRR, chi-square, serious-outcome rate, and dechallenge support
--      -- the kind of single table a PV dashboard would page through.
WITH sig AS (
    SELECT
        drug, reaction, a AS n_cases, b, c, d,
        (a*1.0/(a+b)) / (c*1.0/(c+d)) AS prr,
        ( (a*1.0*d - b*1.0*c) * (a*1.0*d - b*1.0*c) * (a+b+c+d) )
          / ( (a+b)*1.0*(c+d)*(a+c)*(b+d) ) AS chi_square
    FROM v_signal_base
),
serious_rate AS (
    SELECT vp.drug, vp.reaction,
           ROUND(100.0 * SUM(CASE WHEN o.outc_cod IN ('DE','HO','RI') THEN 1 ELSE 0 END)
                 / COUNT(DISTINCT vp.primaryid), 1) AS pct_serious
    FROM v_drug_reaction_pairs vp
    LEFT JOIN outc o ON vp.primaryid = o.primaryid
    GROUP BY vp.drug, vp.reaction
)
SELECT
    s.drug, s.reaction, s.n_cases,
    ROUND(s.prr,2) AS prr, ROUND(s.chi_square,2) AS chi_square,
    sr.pct_serious,
    CASE WHEN s.prr>=2 AND s.chi_square>=4 THEN 'SIGNAL' ELSE 'monitor' END AS status
FROM sig s
JOIN serious_rate sr ON s.drug = sr.drug AND s.reaction = sr.reaction
WHERE s.n_cases >= 3
ORDER BY s.chi_square DESC
LIMIT 30;
 