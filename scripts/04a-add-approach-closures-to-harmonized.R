#!/usr/bin/env Rscript
# Post-processing step: Add approach segment closure markers
#
# This is Step 5 in the EUR harmonization pipeline.
# Run AFTER 04-harmonize-eur-milestones.R
#
# Adds synthetic LVL_END markers (8-second offset) for orphaned approach segments

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(here)
})

source(here("R", "add-approach-closures.R"))

message("\n=== Step 5: Adding Approach Segment Closures ===\n")

# Input from Step 4
harmonized_file <- here("data-derived", "canonical-milestones-eur-2026-harmonized.parquet")

# Check file exists
if (!file.exists(harmonized_file)) {
  stop("Harmonized file not found: ", harmonized_file, "\nRun 04-harmonize-eur-milestones.R first", call. = FALSE)
}

# Load harmonized data
eur_harmonized <- arrow::read_parquet(harmonized_file)

message("Input: ", harmonized_file)
message("  Rows: ", nrow(eur_harmonized))
message("  Flights: ", n_distinct(eur_harmonized$UID))

# Add approach closures
eur_with_closures <- add_approach_segment_closures(
  eur_harmonized,
  uid_col = "UID",
  mst_col = "MST",
  alt_col = "ALT",
  time_col = "TIME",
  offset_seconds = 8
)

message("\nAfter adding closures:")
message("  Rows: ", nrow(eur_with_closures))
message("  Added: ", nrow(eur_with_closures) - nrow(eur_harmonized), " markers")

# Save
arrow::write_parquet(eur_with_closures, harmonized_file)
message("\n✓ Updated: ", harmonized_file)
message("\nApproach closure markers added successfully!")
message("These can be filtered by .milestone_source == 'implicit_approach_closure'")
