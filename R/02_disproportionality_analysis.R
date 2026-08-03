## =============================================================================
## 02_disproportionality_analysis.R
##
## Classical disproportionality analysis on the drug x event SRS matrix.
## For each drug-event cell N_ij, computes:
##   - Expected count E_ij under the independence assumption
##   - PRR   (Proportional Reporting Ratio)
##   - ROR   (Reporting Odds Ratio) + 95% CI
##   - Chi-square statistic
##   - IC    (Information Component, log2 observed/expected - Bayesian shrinkage)
##
## A signal is flagged using standard MHRA/EMA-style thresholds:
##   PRR >= 2, chi-square >= 4, N_ij >= 3
##
## Input : data/processed/drug_event_matrix.csv
## Output: data/processed/disproportionality_results.csv
## =============================================================================

mat <- read.csv("data/processed/drug_event_matrix.csv", row.names = 1, check.names = FALSE)
mat <- as.matrix(mat)

drugs  <- rownames(mat)
events <- colnames(mat)
N_total <- sum(mat)

results <- do.call(rbind, lapply(drugs, function(d) {
  do.call(rbind, lapply(events, function(e) {
    a <- mat[d, e]                          # drug d + event e
    b <- sum(mat[d, ]) - a                   # drug d + other events
    c <- sum(mat[, e]) - a                   # other drugs + event e
    dd <- N_total - a - b - c                # other drugs + other events

    # expected count under independence
    E_ij <- (sum(mat[d, ]) * sum(mat[, e])) / N_total

    # PRR
    prr <- if ((a + c) > 0 && b > 0) (a / (a + b)) / (c / (c + dd)) else NA

    # ROR + 95% CI (log scale)
    ror <- if (b > 0 && c > 0 && dd > 0) (a * dd) / (b * c) else NA
    se_log_ror <- if (all(c(a, b, c, dd) > 0)) sqrt(1/a + 1/b + 1/c + 1/dd) else NA
    ror_lower <- if (!is.na(ror) && !is.na(se_log_ror)) exp(log(ror) - 1.96 * se_log_ror) else NA
    ror_upper <- if (!is.na(ror) && !is.na(se_log_ror)) exp(log(ror) + 1.96 * se_log_ror) else NA

    # chi-square (Yates-corrected 2x2)
    chisq <- tryCatch({
      tbl <- matrix(c(a, b, c, dd), nrow = 2)
      suppressWarnings(chisq.test(tbl, correct = TRUE)$statistic)
    }, error = function(e) NA)

    # Information Component (empirical, non-shrunk version for reference;
    # shrunk/EB version computed in 03_empirical_bayes_gps.R)
    ic <- if (a > 0 && E_ij > 0) log2(a / E_ij) else NA

    data.frame(
      drug = d, event = e,
      N_ij = a, E_ij = round(E_ij, 3),
      PRR = round(prr, 3), ROR = round(ror, 3),
      ROR_lower95 = round(ror_lower, 3), ROR_upper95 = round(ror_upper, 3),
      chi_square = round(as.numeric(chisq), 3),
      IC_empirical = round(ic, 3),
      stringsAsFactors = FALSE
    )
  }))
}))

## --- signal flag: standard MHRA-style rule (PRR>=2, chi2>=4, N>=3) ----------
results$signal_flag <- with(results,
  !is.na(PRR) & !is.na(chi_square) & PRR >= 2 & chi_square >= 4 & N_ij >= 3)

results <- results[order(-results$PRR), ]

write.csv(results, "data/processed/disproportionality_results.csv", row.names = FALSE)

n_signals <- sum(results$signal_flag, na.rm = TRUE)
cat(sprintf("Disproportionality analysis complete: %d drug-event pairs evaluated\n", nrow(results)))
cat(sprintf("%d pairs flagged as potential signals (PRR>=2, chi2>=4, N>=3)\n", n_signals))
cat("Top 5 by PRR:\n")
print(head(results[, c("drug","event","N_ij","PRR","ROR","chi_square","signal_flag")], 5))
