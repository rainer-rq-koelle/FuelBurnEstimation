#!/usr/bin/env Rscript
# Extract SAM_IDs of flights with orphaned descent level segments

library(arrow)
library(dplyr)
library(readr)

cat("Extracting orphaned flight identifiers...\n")

# Read harmonized milestones
milestones <- read_parquet("data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet")

# Read original canonical to get SAM_ID mapping
canonical_old <- read_parquet("data-derived/canonical-milestones-eur-2025-summer.parquet")

# Get SAM_ID mapping (UID in harmonized = UID in old schema)
# Need to extract SAM_ID from UID or SOURCE field

# Find flights with orphaned descent segments
orphan_data <- milestones %>%
  filter(MST == "LVL_START", ALT < 10000) %>%
  arrange(UID, TIME) %>%
  group_by(UID) %>%
  slice(1) %>%  # One row per flight
  ungroup()

# For each, check if there's a LVL_END after
orphan_flights <- orphan_data %>%
  rowwise() %>%
  mutate(
    has_end = {
      later_msts <- milestones$MST[milestones$UID == UID & milestones$TIME > TIME]
      "LVL_END" %in% later_msts
    }
  ) %>%
  ungroup() %>%
  filter(!has_end)

cat(sprintf("Found %d flights with orphaned descent segments\n", nrow(orphan_flights)))

# Create output with details
output <- orphan_flights %>%
  select(UID, TIME, ALT, PHASE) %>%
  mutate(
    orphan_altitude_ft = ALT,
    orphan_phase = PHASE
  ) %>%
  select(UID, orphan_altitude_ft, orphan_phase, TIME)

# Write to CSV
write_csv(output, "notes/orphaned-descent-flights.csv")
cat("✓ Saved: notes/orphaned-descent-flights.csv\n")

cat(sprintf("\nTotal: %d flights\n", nrow(output)))
cat(sprintf("Mean altitude: %.0f ft\n", mean(output$orphan_altitude_ft, na.rm = TRUE)))
cat(sprintf("Median altitude: %.0f ft\n", median(output$orphan_altitude_ft, na.rm = TRUE)))
