#!/usr/bin/env Rscript
# Derive EUR level-segment intervals from harmonized milestones

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
  library(here)
})

source(here("R", "level-off-milestones.R"))

message("EUR Level-Segment Derivation")
message("============================\n")

# Input: harmonized milestones
harm_file <- Sys.getenv(
  "FUELBURN_EUR_HARMONIZED_MILESTONES",
  unset = here("data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet")
)

if (!file.exists(harm_file)) {
  stop("Harmonized milestones not found: ", harm_file, call. = FALSE)
}

message("Reading harmonized milestones...")
eur_harm <- arrow::read_parquet(harm_file)
message("  Rows: ", format(nrow(eur_harm), big.mark = ","))
message("  Flights: ", format(n_distinct(eur_harm$UID), big.mark = ","))

# Derive level segments
message("\nDeriving level-segment intervals...")
level_segments <- derive_level_segments(
  eur_harm,
  uid_col = "UID",
  mst_col = "MST",
  time_col = "TIME",
  alt_col = "ALT",
  fuel_col = "TOT_FUEL",
  phase_col = "PHASE"
)

message("  Level segments derived: ", format(nrow(level_segments), big.mark = ","))
message("  Flights with level segments: ", format(n_distinct(level_segments$UID), big.mark = ","))

# QC summary
qc_summary <- level_segments %>%
  summarise(
    total = n(),
    with_end = sum(has_end),
    orphaned = sum(qc_orphaned),
    ok = sum(qc_flag == "ok"),
    zero_duration = sum(qc_zero_duration, na.rm = TRUE),
    negative_duration = sum(qc_negative_duration, na.rm = TRUE),
    excessive_alt_change = sum(qc_excessive_altitude_change, na.rm = TRUE)
  )

message("\n=== QC Summary ===")
message("  Total segments: ", format(qc_summary$total, big.mark = ","))
message("  With END marker: ", format(qc_summary$with_end, big.mark = ","))
message("  Orphaned (no END): ", format(qc_summary$orphaned, big.mark = ","))
message("  QC OK: ", format(qc_summary$ok, big.mark = ","))
message("  Zero duration: ", qc_summary$zero_duration)
message("  Negative duration: ", qc_summary$negative_duration)
message("  Excessive alt change: ", qc_summary$excessive_alt_change)

# Duration summary (excluding orphaned)
valid_segments <- level_segments %>%
  filter(has_end, !qc_negative_duration)

if (nrow(valid_segments) > 0) {
  message("\n=== Duration Summary (Valid Segments) ===")
  message("  Valid segments: ", format(nrow(valid_segments), big.mark = ","))
  message("  Mean duration: ", round(mean(valid_segments$duration_sec, na.rm = TRUE), 1), " sec")
  message("  Median duration: ", round(median(valid_segments$duration_sec, na.rm = TRUE), 1), " sec")
  message("  Min duration: ", round(min(valid_segments$duration_sec, na.rm = TRUE), 1), " sec")
  message("  Max duration: ", round(max(valid_segments$duration_sec, na.rm = TRUE), 1), " sec")
}

# Detailed summary statistics
message("\nGenerating detailed summaries...")
duration_summary <- summarize_level_segments(level_segments)

# Output paths
data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = here("data-store"))
output_dir <- file.path(data_store, "derived/eur")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

segments_file <- file.path(output_dir, "level-segments-eur-2026.parquet")
summary_file <- file.path(output_dir, "level-segment-duration-summary-eur-2026.csv")
qc_file <- file.path(output_dir, "level-segment-qc-eur-2026.csv")

# Write level-segment intervals
message("\nWriting level-segment intervals...")
arrow::write_parquet(level_segments, segments_file)
message("  Written: ", segments_file)
message("  Size: ", round(file.info(segments_file)$size / 1024^2, 2), " MB")

# Write duration summary
readr::write_csv(duration_summary, summary_file)
message("  Written: ", summary_file)

# Write QC detail
qc_detail <- level_segments %>%
  group_by(qc_flag, phase_context, altitude_band) %>%
  summarise(
    count = n(),
    mean_duration_sec = mean(duration_sec, na.rm = TRUE),
    mean_altitude_ft = mean(mean_altitude_ft, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(count))

readr::write_csv(qc_detail, qc_file)
message("  Written: ", qc_file)

message("\n✓ EUR level-segment derivation complete")
message("\nNext steps:")
message("  1. Inspect outputs in data-store/derived/eur/")
message("  2. Run: Rscript scripts/00-check-data-store.R")
message("  3. Upload to R2: Rscript scripts/r2-upload-data-store.R")
