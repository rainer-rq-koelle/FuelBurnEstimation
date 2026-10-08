#!/usr/bin/env Rscript
# Diagnose LVL_START/LVL_END imbalance

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(here)
})

cat("=== Loading EUR Harmonized Data ===\n")
eur_harm <- read_parquet(here("data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet"))

cat("Total rows:", nrow(eur_harm), "\n")
cat("Flights:", n_distinct(eur_harm$UID), "\n")
cat("Columns:", ncol(eur_harm), "\n\n")

cat("=== Milestone Counts (Top 20) ===\n")
mst_counts <- eur_harm %>%
  count(MST, sort = TRUE) %>%
  head(20)
print(mst_counts)

cat("\n=== LVL Milestone Analysis ===\n")
lvl_counts <- eur_harm %>%
  filter(grepl("LVL", MST)) %>%
  count(MST, sort = TRUE)
print(lvl_counts)

cat("\n=== LVL Distribution by Flight ===\n")
lvl_by_flight <- eur_harm %>%
  filter(MST %in% c("LVL_START", "LVL_END")) %>%
  group_by(UID, MST) %>%
  summarise(n = n(), .groups = "drop") %>%
  pivot_wider(names_from = MST, values_from = n, values_fill = 0) %>%
  mutate(
    has_start = LVL_START > 0,
    has_end = LVL_END > 0,
    balanced = LVL_START == LVL_END,
    diff = LVL_START - LVL_END
  )

cat("Flights with LVL_START:", sum(lvl_by_flight$has_start), "\n")
cat("Flights with LVL_END:", sum(lvl_by_flight$has_end), "\n")
cat("Flights with balanced pairs:", sum(lvl_by_flight$balanced), "\n")
cat("Flights with imbalance:", sum(!lvl_by_flight$balanced), "\n\n")

cat("=== Imbalance Patterns ===\n")
imbalance_summary <- lvl_by_flight %>%
  filter(!balanced) %>%
  count(diff, sort = TRUE)
print(imbalance_summary)

cat("\n=== Sample Imbalanced Flights ===\n")
sample_imbalanced <- lvl_by_flight %>%
  filter(!balanced) %>%
  head(5)
print(sample_imbalanced)

cat("\n=== Checking Original LVL Events ===\n")
original_lvl <- eur_harm %>%
  filter(MST == "LVL") %>%
  nrow()
cat("Original LVL events (should be 0 after harmonization):", original_lvl, "\n")

cat("\n=== Phase Context for LVL Markers ===\n")
if ("PHASE" %in% names(eur_harm)) {
  lvl_phase <- eur_harm %>%
    filter(MST %in% c("LVL_START", "LVL_END")) %>%
    count(MST, PHASE, sort = TRUE)
  print(lvl_phase)
}
