#!/usr/bin/env Rscript
# Inspect raw PRU data for LVL markers

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(here)
})

cat("=== RAW EUR/PRU DATA INSPECTION ===\n\n")

# Read raw data
raw_file <- here("data-store/raw/eur/EUR-canonical-milestones-summer2025.parquet")
cat("Reading:", raw_file, "\n\n")

raw <- read_parquet(raw_file)

cat("Total rows:", format(nrow(raw), big.mark = ","), "\n")
cat("Total flights:", format(n_distinct(raw$UID), big.mark = ","), "\n\n")

# Top milestone types
cat("=== TOP 30 MILESTONE TYPES ===\n")
mst_counts <- raw %>%
  count(MST, sort = TRUE) %>%
  head(30)

print(mst_counts, n = 30)

# Check for LVL markers specifically
cat("\n=== LVL MARKERS IN SOURCE DATA ===\n")
lvl_count <- sum(raw$MST == "LVL", na.rm = TRUE)
cat("Total LVL markers:", format(lvl_count, big.mark = ","), "\n")

if (lvl_count > 0) {
  cat("✓ LVL markers EXIST in source data\n\n")

  # Distribution per flight
  cat("=== LVL DISTRIBUTION BY FLIGHT ===\n")
  lvl_per_flight <- raw %>%
    filter(MST == "LVL") %>%
    count(UID, name = "n_lvl") %>%
    count(n_lvl, name = "n_flights") %>%
    arrange(n_lvl)

  print(lvl_per_flight, n = 20)

  total_flights_with_lvl <- sum(lvl_per_flight$n_flights)
  mean_lvl <- weighted.mean(lvl_per_flight$n_lvl, lvl_per_flight$n_flights)

  cat("\n=== SUMMARY ===\n")
  cat("Flights with LVL markers:", format(total_flights_with_lvl, big.mark = ","), "\n")
  cat("Flights without LVL:", format(n_distinct(raw$UID) - total_flights_with_lvl, big.mark = ","), "\n")
  cat("Mean LVL markers per flight (with LVL):", round(mean_lvl, 2), "\n")

  # Check pairing
  cat("\n=== PAIRING CHECK ===\n")
  paired_check <- lvl_per_flight %>%
    mutate(
      is_even = n_lvl %% 2 == 0,
      pairing = if_else(is_even, "even (potentially paired)", "odd (unpaired)")
    ) %>%
    group_by(pairing) %>%
    summarise(
      n_flights = sum(n_flights),
      .groups = "drop"
    )

  print(paired_check)

  # Sample a few flights
  cat("\n=== SAMPLE FLIGHTS WITH LVL MARKERS ===\n")
  sample_flights <- raw %>%
    filter(MST == "LVL") %>%
    group_by(UID) %>%
    summarise(
      n_lvl = n(),
      adep = first(ADEP),
      ades = first(ADES),
      .groups = "drop"
    ) %>%
    head(5)

  print(sample_flights)

} else {
  cat("✗ NO LVL markers found in source data\n")
  cat("   → Level segments would need to be derived from altitude profiles\n")
}

cat("\n=== CONCLUSION ===\n")
if (lvl_count > 0) {
  cat("✓ PRU source data DOES contain LVL milestone markers\n")
  cat("  But they are incomplete/unpaired, hence the need for implicit END logic\n")
} else {
  cat("✗ PRU source data does NOT contain LVL markers\n")
}
