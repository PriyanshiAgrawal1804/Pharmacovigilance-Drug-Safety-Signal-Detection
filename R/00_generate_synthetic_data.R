## =============================================================================
## 00_generate_synthetic_data.R
##
## Generates a SYNTHETIC, FAERS-STRUCTURED case-report dataset for demo /
## development purposes. This is NOT real FAERS data.
##
## Real FAERS quarterly data (ASCII/XML) is public and free at:
##   https://fis.fda.gov/extensions/FPD-QDE-FAERS/FPD-QDE-FAERS.html
## and can be queried directly via the openFDA API:
##   https://api.fda.gov/drug/event.json
##
## This script simulates the same structure (case, drug, event, demographics,
## time-to-onset) so the downstream pipeline (01-05) can be built, tested and
## demonstrated end-to-end before / while real FAERS extracts are wired in.
##
## A handful of drug-event pairs are deliberately seeded with an elevated
## true reporting rate so the detection pipeline has genuine signals to find,
## and its output can be sanity-checked against known ground truth.
## =============================================================================

set.seed(42)

n_cases   <- 50000
drugs     <- c("Metformin", "Sitagliptin", "Empagliflozin", "Glipizide",
                "Atorvastatin", "Rosuvastatin", "Lisinopril", "Losartan",
                "Amlodipine", "Warfarin", "Apixaban", "Levothyroxine",
                "Omeprazole", "Sertraline", "Ibuprofen")

events    <- c("Acute kidney injury", "Lactic acidosis", "Hypoglycemia",
                "Myopathy", "Rhabdomyolysis", "Angioedema", "Hyperkalemia",
                "Gastrointestinal haemorrhage", "Hepatic failure",
                "Peripheral oedema", "Diarrhoea", "Nausea", "Headache",
                "Dizziness", "Rash", "QT prolongation")

sex       <- c("F", "M")
age_band  <- c("18-30", "31-45", "46-60", "61-75", "76+")
country   <- c("US", "GB", "DE", "FR", "CA", "AU", "JP")

# --- baseline (background) drug-event co-occurrence probabilities ----------
base_prob <- outer(seq_along(drugs), seq_along(events),
                    function(i, j) 0.0006 + 0.0004 * sin(i + j))
base_prob[base_prob < 0.0001] <- 0.0001

# --- seeded TRUE signals (ground truth for validation) ---------------------
# format: drug, event, relative-risk multiplier applied to background rate
true_signals <- data.frame(
  drug        = c("Empagliflozin", "Metformin",     "Atorvastatin", "Warfarin"),
  event       = c("Acute kidney injury", "Lactic acidosis", "Myopathy", "Gastrointestinal haemorrhage"),
  rr          = c(6.5, 9.0, 5.0, 4.2),
  stringsAsFactors = FALSE
)

signal_matrix <- matrix(1, nrow = length(drugs), ncol = length(events),
                         dimnames = list(drugs, events))
for (k in seq_len(nrow(true_signals))) {
  signal_matrix[true_signals$drug[k], true_signals$event[k]] <- true_signals$rr[k]
}

adj_prob <- base_prob * signal_matrix
adj_prob <- adj_prob / max(adj_prob) * 0.02   # rescale to plausible report rate

# --- simulate individual case reports ---------------------------------------
cases <- vector("list", n_cases)
for (i in seq_len(n_cases)) {
  d_idx <- sample(seq_along(drugs), 1)
  e_idx <- sample(seq_along(events), 1, prob = adj_prob[d_idx, ] / sum(adj_prob[d_idx, ]))

  is_true_pair <- any(true_signals$drug == drugs[d_idx] & true_signals$event == events[e_idx])

  # time-to-onset (days): true signals cluster earlier (early-onset pattern)
  tto <- if (is_true_pair) {
    round(rweibull(1, shape = 0.7, scale = 25))
  } else {
    round(rweibull(1, shape = 1.4, scale = 120))
  }
  tto <- max(tto, 1)

  cases[[i]] <- data.frame(
    case_id       = sprintf("CASE-%06d", i),
    drug          = drugs[d_idx],
    event         = events[e_idx],
    sex           = sample(sex, 1, prob = c(0.55, 0.45)),
    age_band      = sample(age_band, 1, prob = c(0.10, 0.18, 0.27, 0.28, 0.17)),
    country       = sample(country, 1, prob = c(0.45, 0.12, 0.10, 0.08, 0.10, 0.08, 0.07)),
    report_date   = as.Date("2020-01-01") + sample(0:2190, 1),
    time_to_onset_days = tto,
    serious       = sample(c("Y", "N"), 1, prob = if (is_true_pair) c(0.7, 0.3) else c(0.25, 0.75)),
    stringsAsFactors = FALSE
  )
}

faers_sample <- do.call(rbind, cases)

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
write.csv(faers_sample, "data/raw/synthetic_faers_sample.csv", row.names = FALSE)
write.csv(true_signals, "data/raw/ground_truth_signals.csv", row.names = FALSE)

cat(sprintf("Generated %d synthetic case reports -> data/raw/synthetic_faers_sample.csv\n", n_cases))
cat(sprintf("Ground-truth seeded signals written -> data/raw/ground_truth_signals.csv\n"))
