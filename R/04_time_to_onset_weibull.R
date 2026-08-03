## =============================================================================
## 04_time_to_onset_weibull.R
##
## Time-to-onset (TTO) analysis, reproducing the Weibull Shape Parameter (WSP)
## test logic (the method implemented by the WSPsignal R package).
##
## For each candidate drug-event pair with sufficient reports (N_ij >= 20),
## a Weibull distribution is fit to the observed time-to-onset values via MLE
## (MASS::fitdistr). A shape parameter (kappa):
##   kappa < 1  -> hazard decreasing over time -> events cluster shortly
##                 after drug initiation (suggestive of a causal / early
##                 pharmacological reaction)
##   kappa ~= 1 -> constant hazard -> consistent with a random/background
##                 process, weakens the causal case
##   kappa > 1  -> hazard increasing over time -> late-onset pattern
##
## NOTE ON PACKAGES: WSPsignal itself is not installable without CRAN access
## in this environment; the Weibull MLE + shape-parameter test below
## implements the same statistical test (Weibull shape estimation with a
## one-sided test of kappa < 1) using MASS::fitdistr, which ships with
## base R. Swapping in WSPsignal::wsp_test() later is a drop-in replacement.
##
## Input : data/processed/case_level_clean.csv, data/processed/ebgm_results.csv
## Output: data/processed/time_to_onset_results.csv
## =============================================================================

suppressWarnings(suppressMessages(library(MASS)))

cases <- read.csv("data/processed/case_level_clean.csv", stringsAsFactors = FALSE)
ebgm  <- read.csv("data/processed/ebgm_results.csv", stringsAsFactors = FALSE)

# Only test pairs that already cleared the disproportionality/GPS stage
# with a reasonable case count, consistent with a staged discovery->
# verification workflow.
candidates <- ebgm[ebgm$N_ij >= 20, c("drug", "event", "N_ij", "PRR", "EBGM")]

results <- do.call(rbind, lapply(seq_len(nrow(candidates)), function(i) {
  d <- candidates$drug[i]; e <- candidates$event[i]
  tto <- cases$time_to_onset_days[cases$drug == d & cases$event == e]
  tto <- tto[tto > 0 & !is.na(tto)]
  if (length(tto) < 20) return(NULL)

  fit <- tryCatch(suppressWarnings(MASS::fitdistr(tto, "weibull")), error = function(e) NULL)
  if (is.null(fit)) return(NULL)

  kappa    <- unname(fit$estimate["shape"])
  kappa_se <- unname(fit$sd["shape"])
  z <- (kappa - 1) / kappa_se
  p_val <- pnorm(z)   # one-sided: P(kappa < 1)

  data.frame(
    drug = d, event = e, n_cases_tto = length(tto),
    median_onset_days = round(median(tto), 1),
    weibull_shape = round(kappa, 3),
    weibull_shape_se = round(kappa_se, 3),
    p_early_clustering = round(p_val, 4),
    early_onset_pattern = p_val < 0.05 & kappa < 1,
    stringsAsFactors = FALSE
  )
}))

results <- results[order(results$p_early_clustering), ]
write.csv(results, "data/processed/time_to_onset_results.csv", row.names = FALSE)

cat(sprintf("Weibull time-to-onset test run on %d candidate pairs\n", nrow(results)))
cat(sprintf("%d pairs show significant early-onset clustering (kappa<1, p<0.05)\n",
            sum(results$early_onset_pattern, na.rm = TRUE)))
print(results[, c("drug","event","n_cases_tto","median_onset_days","weibull_shape","early_onset_pattern")])
