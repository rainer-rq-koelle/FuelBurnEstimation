#!/usr/bin/env Rscript
# Apply the 2026 enriched milestone convention to EUR canonical data.
#
# This script:
# 1. Renames distance milestones (F40→D040, L40→A040, F100→D100, L100→A100)
# 2. Maps FL100 to direction-aware D_FL100/A_FL100 based on phase
# 3. Derives new FL crossing milestones (D_FL075, D_FL180, A_FL075, A_FL180)
# 4. Reconstructs LVL events into paired LVL_START/LVL_END milestones

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(here)
  library(readr)
  library(stringr)
  library(purrr)
})

source(here("R", "eur-milestone-harmonization.R"))

message("Harmonizing EUR canonical milestones to 2026 convention...")
message("Working directory: ", here())

# Input/output paths
eur_file <- Sys.getenv(
  "FUELBURN_EUR_CANONICAL_MILESTONES",
  unset = here("data-derived", "canonical-milestones-eur-2025-summer.parquet")
)

output_file <- Sys.getenv(
  "FUELBURN_EUR_HARMONIZED_MILESTONES",
  unset = here("data-derived", "canonical-milestones-eur-2026-harmonized.parquet")
)

summary_dir <- here("data-derived", "eur-harmonization-summary")
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

# Check input file
if (!file.exists(eur_file)) {
  stop(
    "Canonical file not found: ", eur_file, "\n",
    "Set FUELBURN_EUR_CANONICAL_MILESTONES to the local EUR canonical parquet.",
    call. = FALSE
  )
}

message("\nInput: ", eur_file)
message("Output: ", output_file)
message("Summary directory: ", summary_dir)

# Load EUR data
eur <- arrow::read_parquet(eur_file) |>
  as_tibble()

message("\nOriginal data:")
message("  Rows: ", nrow(eur))
message("  Flights: ", n_distinct(eur$UID))
message("  Unique milestones: ", n_distinct(eur$MST))
message("  Available columns: ", paste(names(eur), collapse = ", "))

# Determine available ordering columns (standardized convention)
order_cols <- c("UID")
if ("ROW_ID" %in% names(eur)) {
  order_cols <- c(order_cols, "ROW_ID")
} else if ("TIME" %in% names(eur)) {
  order_cols <- c(order_cols, "TIME")
}

message("\nUsing ordering columns: ", paste(order_cols, collapse = ", "))

# Capture original milestone distribution
original_counts <- eur |>
  count(MST, sort = TRUE) |>
  mutate(source = "original")

# Apply harmonization
eur_harmonized <- harmonize_eur_milestones(
  eur,
  uid_col = "UID",
  mst_col = "MST",
  alt_col = "ALT",
  phase_col = "PHASE",
  order_cols = order_cols
)

message("\nHarmonized data:")
message("  Rows: ", nrow(eur_harmonized))
message("  Flights: ", n_distinct(eur_harmonized$UID))
message("  Unique milestones: ", n_distinct(eur_harmonized$MST))

# Capture harmonized milestone distribution
harmonized_counts <- eur_harmonized |>
  count(MST, sort = TRUE) |>
  mutate(source = "harmonized")

# Compare before/after
comparison <- bind_rows(
  original_counts,
  harmonized_counts
) |>
  tidyr::pivot_wider(
    names_from = source,
    values_from = n,
    values_fill = 0
  ) |>
  mutate(
    delta = harmonized - original,
    status = case_when(
      original > 0 & harmonized == 0 ~ "removed",
      original == 0 & harmonized > 0 ~ "added",
      original > 0 & harmonized > 0 & delta != 0 ~ "modified",
      original == harmonized ~ "unchanged",
      TRUE ~ "other"
    )
  ) |>
  arrange(desc(harmonized))

readr::write_csv(comparison, file.path(summary_dir, "milestone-comparison.csv"))

# Summary by status
status_summary <- comparison |>
  group_by(status) |>
  summarise(
    n_labels = n(),
    original_total = sum(original),
    harmonized_total = sum(harmonized),
    .groups = "drop"
  )

readr::write_csv(status_summary, file.path(summary_dir, "harmonization-status-summary.csv"))

message("\nHarmonization status summary:")
print(status_summary, n = Inf)

# Highlight key transformations
key_transformations <- comparison |>
  filter(status %in% c("removed", "added", "modified")) |>
  select(MST, original, harmonized, delta, status)

readr::write_csv(key_transformations, file.path(summary_dir, "key-transformations.csv"))

message("\nKey transformations (top 50):")
print(key_transformations, n = 50)

# Check for FL100_REVIEW (ambiguous cases)
fl100_review <- eur_harmonized |>
  filter(MST == "FL100_REVIEW")

if (nrow(fl100_review) > 0) {
  warning(
    "Found ", nrow(fl100_review), " FL100 events with ambiguous phase context. ",
    "Review data-derived/eur-harmonization-summary/fl100-review-cases.csv"
  )
  readr::write_csv(fl100_review, file.path(summary_dir, "fl100-review-cases.csv"))
}

# Write harmonized output
message("\nWriting harmonized milestones to parquet...")
arrow::write_parquet(eur_harmonized, output_file)

# Verification: sample harmonized milestone labels
canonical_labels <- c(
  "D040", "D100", "A040", "A100",
  "D_FL075", "D_FL100", "D_FL180",
  "A_FL075", "A_FL100", "A_FL180",
  "LVL_START", "LVL_END"
)

canonical_verification <- eur_harmonized |>
  filter(MST %in% canonical_labels) |>
  count(MST, sort = TRUE) |>
  mutate(expected = MST %in% canonical_labels)

readr::write_csv(canonical_verification, file.path(summary_dir, "canonical-label-verification.csv"))

message("\nCanonical label verification:")
print(canonical_verification, n = Inf)

message("\nWrote summary files:")
for (path in sort(list.files(summary_dir, pattern = "\\.csv$", full.names = TRUE))) {
  message("  ", path)
}

message("\nEUR milestone harmonization complete.")
message("Harmonized data: ", output_file)
