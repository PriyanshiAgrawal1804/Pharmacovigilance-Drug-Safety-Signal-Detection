## =============================================================================
## 01_data_preprocessing.R
##
## Loads raw case-level reports, performs light cleaning, and constructs the
## drug x event Spontaneous Reporting System (SRS) contingency table used by
## every downstream disproportionality / signal detection method.
##
## Input : data/raw/synthetic_faers_sample.csv
## Output: data/processed/drug_event_matrix.csv   (N_ij counts)
##         data/processed/case_level_clean.csv
## =============================================================================

suppressWarnings(suppressMessages({
  library(stats)
}))

raw <- read.csv("data/raw/synthetic_faers_sample.csv", stringsAsFactors = FALSE)
raw$report_date <- as.Date(raw$report_date)

cat(sprintf("Loaded %d raw case reports\n", nrow(raw)))

## --- basic cleaning ---------------------------------------------------------
before <- nrow(raw)
raw <- raw[!is.na(raw$drug) & !is.na(raw$event) & raw$drug != "" & raw$event != "", ]
raw <- raw[!duplicated(raw), ]  # de-duplicate exact-duplicate case rows
cat(sprintf("Removed %d incomplete/duplicate rows -> %d remain\n", before - nrow(raw), nrow(raw)))

## harmonise text casing/whitespace (stand-in for MedDRA/ATC coding step)
raw$drug  <- trimws(raw$drug)
raw$event <- trimws(raw$event)

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
write.csv(raw, "data/processed/case_level_clean.csv", row.names = FALSE)

## --- build N_ij contingency table -------------------------------------------
tab <- table(raw$drug, raw$event)
mat <- as.data.frame.matrix(tab)

write.csv(mat, "data/processed/drug_event_matrix.csv", row.names = TRUE)

cat(sprintf("Built drug x event matrix: %d drugs x %d events\n", nrow(mat), ncol(mat)))
cat(sprintf("Total reports in matrix: %d\n", sum(mat)))
