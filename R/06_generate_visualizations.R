## =============================================================================
## 06_generate_visualizations.R
##
## Produces the standard pharmacovigilance signal-detection visualizations:
##   1. Drug x Event PRR heatmap
##   2. "Eye plot" (EBGM vs N_ij, MGPS-style scatter with EB05/EB95 whiskers)
##   3. Forest plot of ROR with 95% CI for top prioritized signals
##
## Input : data/processed/*.csv, reports/prioritized_signal_report.csv
## Output: reports/figures/*.png
## =============================================================================

suppressWarnings(suppressMessages({
  library(ggplot2)
}))

dir.create("reports/figures", recursive = TRUE, showWarnings = FALSE)

disp <- read.csv("data/processed/disproportionality_results.csv", stringsAsFactors = FALSE)
ranked <- read.csv("reports/prioritized_signal_report.csv", stringsAsFactors = FALSE)

theme_pv <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

## --- 1. Heatmap of PRR across all drug-event pairs -------------------------
disp$PRR_capped <- pmin(disp$PRR, 7)   # cap for color scale readability

p1 <- ggplot(disp, aes(x = event, y = drug, fill = PRR_capped)) +
  geom_tile(color = "white", linewidth = 0.3) +
  scale_fill_gradient2(low = "#f7fbff", mid = "#6baed6", high = "#08306b",
                        midpoint = 3, name = "PRR\n(capped at 7)") +
  labs(title = "Proportional Reporting Ratio (PRR) Heatmap",
       subtitle = "Drug x Adverse Event | synthetic demo data",
       x = "Adverse Event", y = "Drug") +
  theme_pv

ggsave("reports/figures/prr_heatmap.png", p1, width = 11, height = 7, dpi = 150)

## --- 2. Eye plot: EBGM vs N with EB05-EB95 whiskers ------------------------
ranked$flag_label <- ifelse(ranked$is_ground_truth, "Seeded true signal",
                       ifelse(ranked$consensus_flag, "Consensus signal", "Background"))

p2 <- ggplot(ranked, aes(x = N_ij, y = EBGM, color = flag_label)) +
  geom_errorbar(aes(ymin = EB05, ymax = EB95), width = 0, alpha = 0.4) +
  geom_point(aes(size = flag_label != "Background"), alpha = 0.85) +
  geom_hline(yintercept = 2, linetype = "dashed", color = "grey40") +
  scale_x_log10() +
  scale_color_manual(values = c("Seeded true signal" = "#d62728",
                                  "Consensus signal" = "#ff7f0e",
                                  "Background" = "#a6bddb")) +
  scale_size_manual(values = c(`TRUE` = 3, `FALSE` = 1.5), guide = "none") +
  labs(title = "GPS Eye Plot: EBGM vs Report Count",
       subtitle = "Whiskers = EB05-EB95 90% credibility interval | dashed line = EB05>2 threshold",
       x = "N (reports, log scale)", y = "EBGM (shrunk relative reporting ratio)",
       color = NULL) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 14), legend.position = "top")

ggsave("reports/figures/eye_plot.png", p2, width = 9, height = 6.5, dpi = 150)

## --- 3. Forest plot of ROR (95% CI) for top 10 prioritized signals ---------
top10 <- head(ranked, 10)
top10$label <- paste(top10$drug, top10$event, sep = " – ")
top10 <- merge(top10, disp[, c("drug","event","ROR","ROR_lower95","ROR_upper95")],
               by = c("drug","event"))
top10 <- top10[order(top10$borda_score), ]
top10$label <- factor(top10$label, levels = top10$label)

p3 <- ggplot(top10, aes(x = ROR, y = label)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey50") +
  geom_errorbarh(aes(xmin = ROR_lower95, xmax = ROR_upper95), height = 0.2, color = "#08306b") +
  geom_point(size = 3, color = "#08306b") +
  scale_x_log10() +
  labs(title = "Top 10 Prioritized Signals: Reporting Odds Ratio (95% CI)",
       subtitle = "Log scale | dashed line = null (ROR = 1)",
       x = "ROR (log scale)", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 13))

ggsave("reports/figures/forest_plot_top10.png", p3, width = 9, height = 5.5, dpi = 150)

cat("Saved figures:\n")
cat("  reports/figures/prr_heatmap.png\n")
cat("  reports/figures/eye_plot.png\n")
cat("  reports/figures/forest_plot_top10.png\n")
