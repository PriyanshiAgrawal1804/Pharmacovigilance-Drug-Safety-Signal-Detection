## =============================================================================
## 03_empirical_bayes_gps.R
##
## Empirical Bayes Gamma-Poisson Shrinker (GPS / MGPS, DuMouchel 1999) -
## the method underlying FDA's MGPS signal-detection system and the basis
## for the pvEBayes package's parametric estimator.
##
## NOTE ON PACKAGES: this environment does not have outbound access to CRAN,
## so `pvEBayes` could not be installed here. Rather than fake its output,
## this script implements the core GPS algorithm directly in base R:
##   1. Fit a 2-component Gamma mixture prior to the empirical N_ij/E_ij
##      distribution via maximum likelihood (numerical optimisation).
##   2. Compute the posterior mean of the true reporting ratio lambda_ij
##      (the "EBGM" score) and its 90% credibility interval (EB05, EB95)
##      by shrinking each cell's raw ratio toward the fitted prior.
## This reproduces the statistical logic of pvEBayes's parametric GPS model.
## Swapping in the real package (once CRAN access is available) only
## requires replacing the fit_gps_prior()/posterior_ebgm() calls below.
##
## Input : data/processed/disproportionality_results.csv
## Output: data/processed/ebgm_results.csv
## =============================================================================

df <- read.csv("data/processed/disproportionality_results.csv", stringsAsFactors = FALSE)
df <- df[!is.na(df$N_ij) & !is.na(df$E_ij) & df$E_ij > 0, ]

N <- df$N_ij
E <- df$E_ij

## --- 1. Fit two-component Gamma-Poisson mixture prior via MLE --------------
## Marginal likelihood of a 2-component Gamma-Poisson mixture:
##   P(N|E) = p * NB(N; alpha1, beta1/(beta1+E)) + (1-p) * NB(N; alpha2, beta2/(beta2+E))
neg_log_lik <- function(par) {
  a1 <- exp(par[1]); b1 <- exp(par[2])
  a2 <- exp(par[3]); b2 <- exp(par[4])
  p  <- plogis(par[5])

  ll1 <- dnbinom(N, size = a1, prob = b1 / (b1 + E), log = TRUE)
  ll2 <- dnbinom(N, size = a2, prob = b2 / (b2 + E), log = TRUE)

  mix <- p * exp(ll1) + (1 - p) * exp(ll2)
  mix[mix <= 0] <- .Machine$double.eps
  -sum(log(mix))
}

start <- c(log(0.5), log(0.5), log(2), log(2), qlogis(0.7))
fit <- optim(start, neg_log_lik, method = "Nelder-Mead",
             control = list(maxit = 2000))

a1 <- exp(fit$par[1]); b1 <- exp(fit$par[2])
a2 <- exp(fit$par[3]); b2 <- exp(fit$par[4])
p  <- plogis(fit$par[5])

cat("Fitted GPS mixture prior:\n")
cat(sprintf("  Component 1: alpha=%.3f beta=%.3f  | Component 2: alpha=%.3f beta=%.3f | mix weight=%.3f\n",
            a1, b1, a2, b2, p))
cat(sprintf("  Convergence: %s (code %d)\n", ifelse(fit$convergence == 0, "OK", "check"), fit$convergence))

## --- 2. Posterior shrinkage: EBGM + 90% credibility interval ---------------
## Posterior mixing weight for component 1 given the observed N_ij
posterior_ebgm <- function(n, e, a1, b1, a2, b2, p) {
  ll1 <- dnbinom(n, size = a1, prob = b1 / (b1 + e))
  ll2 <- dnbinom(n, size = a2, prob = b2 / (b2 + e))
  w1 <- (p * ll1) / (p * ll1 + (1 - p) * ll2)
  w1[is.nan(w1)] <- p

  post_a1 <- a1 + n; post_b1 <- b1 + e
  post_a2 <- a2 + n; post_b2 <- b2 + e

  ebgm <- w1 * (post_a1 / post_b1) + (1 - w1) * (post_a2 / post_b2)

  # credibility interval via mixture quantiles (Monte Carlo, vectorised-lite)
  eb05 <- numeric(length(n)); eb95 <- numeric(length(n))
  for (i in seq_along(n)) {
    draws <- c(rgamma(4000 * w1[i], post_a1[i], post_b1[i]),
               rgamma(4000 * (1 - w1[i]), post_a2[i], post_b2[i]))
    if (length(draws) < 10) draws <- rgamma(4000, post_a1[i], post_b1[i])
    eb05[i] <- quantile(draws, 0.05, na.rm = TRUE)
    eb95[i] <- quantile(draws, 0.95, na.rm = TRUE)
  }
  list(ebgm = ebgm, eb05 = eb05, eb95 = eb95)
}

post <- posterior_ebgm(N, E, a1, b1, a2, b2, p)

df$EBGM <- round(post$ebgm, 3)
df$EB05 <- round(post$eb05, 3)
df$EB95 <- round(post$eb95, 3)

## Standard MGPS signal criterion: EB05 > 2
df$gps_signal_flag <- df$EB05 > 2

df <- df[order(-df$EBGM), ]
write.csv(df, "data/processed/ebgm_results.csv", row.names = FALSE)

cat(sprintf("\nGPS/EBGM shrinkage complete for %d drug-event pairs\n", nrow(df)))
cat(sprintf("%d pairs flagged by EB05 > 2 criterion\n", sum(df$gps_signal_flag)))
cat("Top 5 by EBGM:\n")
print(head(df[, c("drug","event","N_ij","EBGM","EB05","EB95","gps_signal_flag")], 5))
