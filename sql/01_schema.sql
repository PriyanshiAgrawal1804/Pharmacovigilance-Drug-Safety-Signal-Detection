-- =====================================================================
-- Pharmacovigilance & Drug Safety Signal Detection Analytics Platform
-- Database Schema (MySQL / PostgreSQL compatible)
-- =====================================================================
-- Run this after loading the cleaned CSVs from data/processed/ into
-- your database (see README.md "How to Reproduce" for load instructions).
-- =====================================================================

DROP TABLE IF EXISTS Followup;
DROP TABLE IF EXISTS Adverse_Event;
DROP TABLE IF EXISTS Drug_Exposure;
DROP TABLE IF EXISTS Reporter;
DROP TABLE IF EXISTS Patient;
DROP TABLE IF EXISTS Drug;

-- ---------------------------------------------------------------------
-- 1. DRUG TABLE
-- ---------------------------------------------------------------------
CREATE TABLE Drug (
    Drug_ID           VARCHAR(10)   PRIMARY KEY,
    Drug_Name         VARCHAR(100)  NOT NULL,
    Manufacturer      VARCHAR(100),
    Drug_Class        VARCHAR(50),
    Approval_Date     DATE,
    Therapeutic_Area  VARCHAR(50),
    Generic_Name      VARCHAR(100),
    Brand_Name        VARCHAR(100)
);

-- ---------------------------------------------------------------------
-- 2. PATIENT TABLE
-- ---------------------------------------------------------------------
CREATE TABLE Patient (
    Patient_ID       VARCHAR(10)  PRIMARY KEY,
    Age              INT,
    Gender           VARCHAR(10),
    Weight           DECIMAL(5,1),
    Country          VARCHAR(50),
    Smoking_Status   VARCHAR(10),
    Diabetes         VARCHAR(5),
    Hypertension     VARCHAR(5),
    Pregnancy        VARCHAR(5),
    Renal_Disease    VARCHAR(5)
);

-- ---------------------------------------------------------------------
-- 3. REPORTER TABLE
-- ---------------------------------------------------------------------
CREATE TABLE Reporter (
    Reporter_ID     VARCHAR(10)  PRIMARY KEY,
    Reporter_Type   VARCHAR(50),
    Hospital        VARCHAR(100),
    Country         VARCHAR(50),
    Reporting_Date  DATE
);

-- ---------------------------------------------------------------------
-- 4. ADVERSE EVENT TABLE  (fact table / core of signal detection)
-- ---------------------------------------------------------------------
CREATE TABLE Adverse_Event (
    Event_ID           VARCHAR(10)  PRIMARY KEY,
    Drug_ID             VARCHAR(10),
    Reported_Drug_Name   VARCHAR(100),
    Patient_ID          VARCHAR(10),
    Event_Date           DATE,
    Side_Effect          VARCHAR(100),
    Severity              VARCHAR(20),
    Outcome                VARCHAR(20),
    Hospitalized          VARCHAR(5),
    Life_Threatening       VARCHAR(5),
    Death                    VARCHAR(5),
    Seriousness              VARCHAR(20),
    FOREIGN KEY (Drug_ID)    REFERENCES Drug(Drug_ID),
    FOREIGN KEY (Patient_ID) REFERENCES Patient(Patient_ID)
);

-- ---------------------------------------------------------------------
-- 5. DRUG EXPOSURE TABLE
-- ---------------------------------------------------------------------
CREATE TABLE Drug_Exposure (
    Exposure_ID     VARCHAR(10)  PRIMARY KEY,
    Drug_ID         VARCHAR(10),
    Dose            DECIMAL(8,1),
    Route           VARCHAR(30),
    Therapy_Start   DATE,
    Therapy_End     DATE,
    Duration        INT,
    FOREIGN KEY (Drug_ID) REFERENCES Drug(Drug_ID)
);

-- ---------------------------------------------------------------------
-- 6. FOLLOW-UP TABLE
-- ---------------------------------------------------------------------
CREATE TABLE Followup (
    Followup_ID             VARCHAR(10)  PRIMARY KEY,
    Event_ID                VARCHAR(10),
    Followup_Date           DATE,
    Outcome                 VARCHAR(20),
    Additional_Information  VARCHAR(255),
    FOREIGN KEY (Event_ID) REFERENCES Adverse_Event(Event_ID)
);

-- Helpful indexes for analytical queries
CREATE INDEX idx_event_drug        ON Adverse_Event(Drug_ID);
CREATE INDEX idx_event_patient     ON Adverse_Event(Patient_ID);
CREATE INDEX idx_event_date        ON Adverse_Event(Event_Date);
CREATE INDEX idx_event_side_effect ON Adverse_Event(Side_Effect);
