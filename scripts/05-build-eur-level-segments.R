#!/usr/bin/env Rscript
# Build EUR level-segment interval products from PRU LVL-bearing milestones.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(here)
  library(readr)
  library(stringr)
  library(purrr)
})

source(here("R", "eur-level-segments.R"))

message("Building EUR level-segment interval products...")
message("Working directory: ", here())

data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = "")
default_input <- if (data_store != "") {
  expanded_file <- file.path(path.expand(data_store), "raw/eur/EUR-canonical-milestones-expanded-summer2025.parquet")
  compact_file <- file.path(path.expand(data_store), "raw/eur/EUR-canonical-milestones-summer2025.parquet")
  if (file.exists(expanded_file)) expanded_file else compact_file
} else {
  here("data-derived", "canonical-milestones-eur-2025-summer.parquet")
}

default_segments <- if (data_store != "") {
  file.path(path.expand(data_store), "derived/eur/level-segments-eur-2026.parquet")
} else {
  here("data-derived", "level-segments-eur-2026.parquet")
}

default_summary <- if (data_store != "") {
  file.path(path.expand(data_store), "derived/eur/level-segment-duration-summary-eur-2026.csv")
} else {
  here("data-derived", "level-segment-duration-summary-eur-2026.csv")
}

eur_file <- Sys.getenv("FUELBURN_EUR_CANONICAL_MILESTONES", unset = default_input)
segments_file <- Sys.getenv("FUELBURN_EUR_LEVEL_SEGMENTS", unset = default_segments)
summary_file <- Sys.getenv("FUELBURN_EUR_LEVEL_SEGMENT_SUMMARY", unset = default_summary)

if (!file.exists(eur_file)) {
  stop(
    "Canonical file not found: ", eur_file, "\n",
    "Run scripts/r2-download-data-store.R or set FUELBURN_EUR_CANONICAL_MILESTONES.",
    call. = FALSE
  )
}

dir.create(dirname(segments_file), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(summary_file), recursive = TRUE, showWarnings = FALSE)

message("\nInput: ", eur_file)
message("Segments output: ", segments_file)
message("Summary output: ", summary_file)

eur <- arrow::read_parquet(eur_file) |>
  as_tibble()

mst_col <- c("MST", "milestone")[c("MST", "milestone") %in% names(eur)][1]
uid_col <- c("UID", "SOURCE_UID")[c("UID", "SOURCE_UID") %in% names(eur)][1]

message("\nInput data:")
message("  Rows: ", nrow(eur))
message("  Flights: ", n_distinct(eur[[uid_col]]))
message("  LVL-token rows: ", sum(has_milestone_token(eur[[mst_col]], "LVL")))

segments <- build_eur_level_segments(eur)
summary <- summarise_eur_level_segments(segments)

message("\nLevel-segment QC:")
print(segments |> count(quality_flag, phase_context, name = "n_segments"), n = Inf)

message("\nDuration quantiles for paired segments:")
print(
  summary |>
    filter(summary_type == "duration_quantiles") |>
    select(phase_context, n_segments, duration_min_sec, duration_p05_sec, duration_p25_sec,
           duration_p50_sec, duration_p75_sec, duration_p95_sec, duration_max_sec),
  n = Inf
)

message("\nDuration bands:")
print(
  summary |>
    filter(summary_type == "duration_bands") |>
    select(phase_context, duration_band, n_segments),
  n = Inf
)

arrow::write_parquet(segments, segments_file)
readr::write_csv(summary, summary_file)

message("\nWrote:")
message("  ", segments_file)
message("  ", summary_file)
message("\nEUR level-segment products complete.")
