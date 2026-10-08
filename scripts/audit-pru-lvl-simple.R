#!/usr/bin/env Rscript
# Simple PRU LVL completeness audit

library(arrow)
library(dplyr)
library(readr)
library(here)

cat("=== PRU LVL COMPLETENESS AUDIT ===\n\n")

# Read data
raw <- read_parquet(here("data-store/raw/eur/EUR-canonical-milestones-summer2025.parquet"))
harm <- read_parquet(here("data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet"))

# Count source LVL per flight (standalone only, not compound)
source_counts <- raw %>%
  filter(MST == "LVL") %>%
  count(UID, name = "source_lvl")

# Count harmonized START/END per flight
harm_counts <- harm %>%
  filter(MST %in% c("LVL_START", "LVL_END")) %>%
  count(UID, MST) %>%
  tidyr::pivot_wider(names_from = MST, values_from = n, values_fill = 0)

# Combine
audit <- source_counts %>%
  left_join(harm_counts, by = "UID") %>%
  mutate(
    LVL_START = coalesce(LVL_START, 0L),
    LVL_END = coalesce(LVL_END, 0L),
    source_paired = source_lvl %% 2 == 0,
    harm_balanced = LVL_START == LVL_END,
    starts_match = LVL_START == source_lvl,
    ends_added = LVL_END - floor(source_lvl / 2),
    completion_status = case_when(
      source_paired & harm_balanced ~ "already_paired",
      !source_paired & harm_balanced ~ "completed",
      !source_paired & !harm_balanced ~ "still_orphaned",
      TRUE ~ "other"
    )
  )

cat("=== RESULTS ===\n\n")

cat("1. CONSISTENCY CHECK\n")
cat("Starts match source LVL count:", sum(audit$starts_match), "/", nrow(audit), "\n")
cat(if_else(mean(audit$starts_match) == 1, "✓ PASS\n\n", "✗ MISMATCH\n\n"))

cat("2. SOURCE PAIRING\n")
print(table(Source_Paired = audit$source_paired))
cat("\n")

cat("3. COMPLETION STATUS\n")
print(table(Status = audit$completion_status))
cat("\n")

cat("4. IMPLICIT ENDS ADDED\n")
cat("Total implicit ENDs:", sum(audit$ends_added), "\n")
cat("Flights with implicit ENDs:", sum(audit$ends_added > 0), "\n\n")

# Save
write_csv(audit, here("notes/pru-lvl-audit-simple.csv"))
cat("✓ Saved: notes/pru-lvl-audit-simple.csv\n")
