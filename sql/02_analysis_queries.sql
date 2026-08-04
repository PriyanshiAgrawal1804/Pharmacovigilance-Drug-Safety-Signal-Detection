-- =====================================================================
-- Pharmacovigilance & Drug Safety Signal Detection Analytics Platform
-- Core SQL Analysis Queries (MySQL / PostgreSQL compatible)
-- =====================================================================

-- 1. Top 20 drugs by ADR count
SELECT d.Drug_Name, COUNT(*) AS ADR_Count
FROM Adverse_Event ae
JOIN Drug d ON ae.Drug_ID = d.Drug_ID
GROUP BY d.Drug_Name
ORDER BY ADR_Count DESC
LIMIT 20;

-- 2. Monthly ADR trend
SELECT DATE_FORMAT(Event_Date, '%Y-%m') AS Report_Month, COUNT(*) AS ADR_Count
FROM Adverse_Event
GROUP BY Report_Month
ORDER BY Report_Month;

-- 3. Fatal cases by drug
SELECT d.Drug_Name, COUNT(*) AS Fatal_Cases
FROM Adverse_Event ae
JOIN Drug d ON ae.Drug_ID = d.Drug_ID
WHERE ae.Death = 'Yes'
GROUP BY d.Drug_Name
ORDER BY Fatal_Cases DESC;

-- 4. Hospitalization rate by drug class
SELECT d.Drug_Class,
       ROUND(100.0 * SUM(CASE WHEN ae.Hospitalized = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Hospitalization_Rate_Pct
FROM Adverse_Event ae
JOIN Drug d ON ae.Drug_ID = d.Drug_ID
GROUP BY d.Drug_Class
ORDER BY Hospitalization_Rate_Pct DESC;

-- 5. Serious ADRs by country
SELECT p.Country,
       SUM(CASE WHEN ae.Seriousness = 'Serious' THEN 1 ELSE 0 END) AS Serious_Reports,
       COUNT(*) AS Total_Reports,
       ROUND(100.0 * SUM(CASE WHEN ae.Seriousness = 'Serious' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Serious_Pct
FROM Adverse_Event ae
JOIN Patient p ON ae.Patient_ID = p.Patient_ID
GROUP BY p.Country
ORDER BY Serious_Pct DESC;

-- 6. Top reported side effects
SELECT Side_Effect, COUNT(*) AS Report_Count
FROM Adverse_Event
GROUP BY Side_Effect
ORDER BY Report_Count DESC
LIMIT 15;

-- 7. Average time to onset (days) by drug
SELECT d.Drug_Name,
       ROUND(AVG(DATEDIFF(ae.Event_Date, de.Therapy_Start)), 1) AS Avg_Time_to_Onset_Days
FROM Adverse_Event ae
JOIN Drug d ON ae.Drug_ID = d.Drug_ID
JOIN Drug_Exposure de ON de.Drug_ID = ae.Drug_ID
GROUP BY d.Drug_Name
ORDER BY Avg_Time_to_Onset_Days DESC;

-- 8. ADRs by age group
SELECT
    CASE
        WHEN p.Age < 18 THEN 'Pediatric'
        WHEN p.Age >= 65 THEN 'Elderly'
        ELSE 'Adult'
    END AS Age_Group,
    COUNT(*) AS ADR_Count
FROM Adverse_Event ae
JOIN Patient p ON ae.Patient_ID = p.Patient_ID
GROUP BY Age_Group;

-- 9. ADRs by gender
SELECT p.Gender, COUNT(*) AS ADR_Count
FROM Adverse_Event ae
JOIN Patient p ON ae.Patient_ID = p.Patient_ID
GROUP BY p.Gender;

-- 10. Manufacturer risk ranking (serious ADR %)
SELECT d.Manufacturer,
       COUNT(*) AS Total_Reports,
       ROUND(100.0 * SUM(CASE WHEN ae.Seriousness = 'Serious' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Serious_Pct
FROM Adverse_Event ae
JOIN Drug d ON ae.Drug_ID = d.Drug_ID
GROUP BY d.Manufacturer
ORDER BY Serious_Pct DESC;

-- 11. Drug class comparison (fatal % and serious %)
SELECT d.Drug_Class,
       COUNT(*) AS Total_Reports,
       ROUND(100.0 * SUM(CASE WHEN ae.Death = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Fatal_Pct,
       ROUND(100.0 * SUM(CASE WHEN ae.Seriousness = 'Serious' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Serious_Pct
FROM Adverse_Event ae
JOIN Drug d ON ae.Drug_ID = d.Drug_ID
GROUP BY d.Drug_Class
ORDER BY Fatal_Pct DESC;

-- 12. Follow-up completion rate
SELECT
    ROUND(100.0 * COUNT(DISTINCT f.Event_ID) / (SELECT COUNT(*) FROM Adverse_Event), 2) AS Followup_Completion_Pct
FROM Followup f;

-- 13. Duplicate report detection (same patient + drug + date + side effect)
SELECT Patient_ID, Drug_ID, Event_Date, Side_Effect, COUNT(*) AS Report_Count
FROM Adverse_Event
GROUP BY Patient_ID, Drug_ID, Event_Date, Side_Effect
HAVING COUNT(*) > 1;

-- 14. Reporter type analysis
SELECT Reporter_Type, COUNT(*) AS Reports_Submitted
FROM Reporter
GROUP BY Reporter_Type
ORDER BY Reports_Submitted DESC;

-- 15. Seasonal ADR trends (by month number)
SELECT MONTH(Event_Date) AS Month_Num, COUNT(*) AS ADR_Count
FROM Adverse_Event
GROUP BY Month_Num
ORDER BY Month_Num;

-- 16. Drug Risk Score (weighted formula, matches Python signal-detection output)
--     Risk Score = 5*Fatal + 3*Serious + 2*Hospitalized  (New Signals added in Python step)
SELECT d.Drug_Name,
       SUM(CASE WHEN ae.Death = 'Yes' THEN 1 ELSE 0 END)            AS Fatal_Events,
       SUM(CASE WHEN ae.Seriousness = 'Serious' THEN 1 ELSE 0 END)  AS Serious_Events,
       SUM(CASE WHEN ae.Hospitalized = 'Yes' THEN 1 ELSE 0 END)     AS Hospitalizations,
       (5 * SUM(CASE WHEN ae.Death = 'Yes' THEN 1 ELSE 0 END))
     + (3 * SUM(CASE WHEN ae.Seriousness = 'Serious' THEN 1 ELSE 0 END))
     + (2 * SUM(CASE WHEN ae.Hospitalized = 'Yes' THEN 1 ELSE 0 END)) AS Risk_Score
FROM Adverse_Event ae
JOIN Drug d ON ae.Drug_ID = d.Drug_ID
GROUP BY d.Drug_Name
ORDER BY Risk_Score DESC;

-- 17. High-risk patient groups (comorbidity breakdown)
SELECT
    p.Diabetes, p.Hypertension, p.Renal_Disease,
    COUNT(*) AS ADR_Count,
    ROUND(100.0 * SUM(CASE WHEN ae.Seriousness = 'Serious' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Serious_Pct
FROM Adverse_Event ae
JOIN Patient p ON ae.Patient_ID = p.Patient_ID
GROUP BY p.Diabetes, p.Hypertension, p.Renal_Disease
ORDER BY Serious_Pct DESC;

-- 18. Reporting timeliness (avg days between event date and reporter submission)
--     Requires joining Adverse_Event to Reporter via a shared reporting context;
--     in this schema Reporter is linked at the report-submission level.
SELECT ROUND(AVG(DATEDIFF(r.Reporting_Date, ae.Event_Date)), 1) AS Avg_Reporting_Delay_Days
FROM Adverse_Event ae
JOIN Reporter r ON r.Country = (SELECT Country FROM Patient WHERE Patient_ID = ae.Patient_ID)
WHERE r.Reporting_Date >= ae.Event_Date;
