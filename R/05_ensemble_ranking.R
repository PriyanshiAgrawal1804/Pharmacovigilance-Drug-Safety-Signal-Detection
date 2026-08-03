## =============================================================================
## 05_ensemble_ranking.R
##
## Combines the three independent signal-detection methods:
##   1. Disproportionality (PRR / chi-square)
##   2. Empirical Bayes GPS shrinkage (EBGM / EB05)
##   3. Weibull time-to-onset early-clustering test
## into a single consensus ranking using Borda count, then cross-checks
## the final prioritised list against the seeded ground-truth signals
## for validation.
##
## Input : data/processed/disproportionality_results.csv
##         data/processed/ebgm_results.csv
##         data/processed/time_to_onset_results.csv
##         data/raw/ground_truth_signals.csv
## Output: reports/prioritized_signal_report.csv
## =============================================================================

disp <- read.csv("data/processed/disproportionality_results.csv", stringsAsFactors = FALSE)
gps  <- read.csv("data/processed/ebgm_results.csv", stringsAsFactors = FALSE)
tto  <- read.csv("data/processed/time_to_onset_results.csv", stringsAsFactors = FALSE)
truth <- read.csv("data/raw/ground_truth_signals.csv", stringsAsFactors = FALSE)

key <- function(d, e) paste(d, e, sep = "||")

disp$key <- key(disp$drug, disp$event)
gps$key  <- key(gps$drug, gps$event)
tto$key  <- key(tto$drug, tto$event)
truth$key <- key(truth$drug, truth$event)

## rank within each method (1 = strongest signal)
disp$rank_disp <- rank(-disp$PRR, ties.method = "min")
gps$rank_gps   <- rank(-gps$EBGM, ties.method = "min")
tto$rank_tto   <- rank(tto$p_early_clustering, ties.method = "min")  # lower p = stronger

merged <- merge(disp[, c("key","drug","event","N_ij","PRR","chi_square","signal_flag","rank_disp")],
                 gps[, c("key","EBGM","EB05","EB95","gps_signal_flag","rank_gps")], by = "key")
merged <- merge(merged, tto[, c("key","median_onset_days","weibull_shape",
                                  "p_early_clustering","early_onset_pattern","rank_tto")],
                 by = "key", all.x = TRUE)

## Borda count: sum of inverse ranks across the (up to) 3 methods available
## for a given pair; pairs not tested for TTO (N_ij<20) get no penalty/bonus
## for that leg and are combined across the 2 methods that did run.
max_rank <- max(merged$rank_disp, merged$rank_gps, na.rm = TRUE)
merged$borda_score <- with(merged, {
  s <- (max_rank - rank_disp + 1) + (max_rank - rank_gps + 1)
  n <- 2
  if (any(!is.na(rank_tto))) {
    s <- ifelse(!is.na(rank_tto), s + (max_rank - rank_tto + 1), s)
  }
  s
})

merged$is_ground_truth <- merged$key %in% truth$key
merged$consensus_flag <- merged$signal_flag & merged$gps_signal_flag

merged <- merged[order(-merged$borda_score), ]
merged$key <- NULL

dir.create("reports", recursive = TRUE, showWarnings = FALSE)
write.csv(merged, "reports/prioritized_signal_report.csv", row.names = FALSE)

## --- validation summary against seeded ground truth ------------------------
top10 <- head(merged, 10)
n_truth_in_top10 <- sum(top10$is_ground_truth)

cat("=== ENSEMBLE SIGNAL PRIORITIZATION COMPLETE ===\n")
cat(sprintf("Total drug-event pairs ranked: %d\n", nrow(merged)))
cat(sprintf("Pairs flagged by consensus (both PRR+chi2 AND EB05>2): %d\n", sum(merged$consensus_flag)))
cat(sprintf("Seeded ground-truth signals recovered in Top 10: %d / %d\n",
            n_truth_in_top10, nrow(truth)))
cat("\nTop 10 prioritized signals:\n")
print(top10[, c("drug","event","N_ij","PRR","EBGM","EB05","early_onset_pattern",
                 "borda_score","is_ground_truth")])
