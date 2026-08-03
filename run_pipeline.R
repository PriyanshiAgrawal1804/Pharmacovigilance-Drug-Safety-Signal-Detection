## =============================================================================
## run_pipeline.R
## Runs the full pharmacovigilance signal-detection pipeline end-to-end.
##
## Usage:  Rscript run_pipeline.R
## =============================================================================

steps <- c(
  "R/00_generate_synthetic_data.R",
  "R/01_data_preprocessing.R",
  "R/02_disproportionality_analysis.R",
  "R/03_empirical_bayes_gps.R",
  "R/04_time_to_onset_weibull.R",
  "R/05_ensemble_ranking.R",
  "R/06_generate_visualizations.R"
)

for (s in steps) {
  cat("\n============================================================\n")
  cat("Running:", s, "\n")
  cat("============================================================\n")
  source(s, echo = FALSE)
}

cat("\nPipeline complete. See reports/prioritized_signal_report.csv and reports/figures/\n")
