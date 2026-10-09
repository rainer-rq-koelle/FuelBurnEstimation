#!/usr/bin/env Rscript
# W1 Diagnostic Smoke Test
# Validates the repeated segment keys and overlap issues identified in W1 diagnostic

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
  library(here)
})

cat("============================================\n")
cat("W1 DIAGNOSTIC SMOKE TEST\n")
cat("============================================\n\n")

cat("Testing EUR Level Segment Issues:\n")
cat("1. Repeated segment keys\n")
cat("2. Overlapping intervals\n")
cat("3. Missing distance field\n\n")

# Load EUR level segments
eur_segs_file <- here("data-store", "processed", "eur", "EUR-level-segments-summer2025.parquet")

if (!file.exists(eur_segs_file)) {
  stop("EUR level segments file not found: ", eur_segs_file)
}

cat("Loading EUR level segments...\n")
eur_segs <- read_parquet(eur_segs_file)
cat("  Loaded:", nrow(eur_segs), "rows\n")
cat("  Columns:", paste(head(names(eur_segs), 15), collapse=", "), "...\n\n")

# TEST 1: Check for repeated segment keys
cat("TEST 1: Repeated Segment Keys\n")
cat("-----------------------------\n")

if ("segment_id" %in% names(eur_segs)) {
  total_rows <- nrow(eur_segs)
  distinct_keys <- n_distinct(eur_segs$segment_id)
  repeated_keys <- total_rows - distinct_keys

  cat("  Total segment rows:", format(total_rows, big.mark=","), "\n")
  cat("  Distinct segment_id:", format(distinct_keys, big.mark=","), "\n")
  cat("  Repeated segment_id:", format(repeated_keys, big.mark=","), "\n")
  cat("  Repetition rate:", round(100 * repeated_keys / distinct_keys, 1), "%\n")

  if (repeated_keys > 0) {
    cat("  ❌ FAIL: Repeated segment keys detected\n")

    # Show top repeated keys
    repeated_examples <- eur_segs |>
      count(segment_id, sort=TRUE) |>
      filter(n > 1) |>
      head(10)

    cat("\n  Top 10 repeated segment_id:\n")
    print(repeated_examples, n=10)
  } else {
    cat("  ✅ PASS: All segment keys unique\n")
  }
} else {
  cat("  ⚠️  WARNING: No segment_id column found\n")
}

cat("\n")

# TEST 2: Check for overlapping intervals
cat("TEST 2: Overlapping Intervals\n")
cat("------------------------------\n")

if (all(c("UID", "start_time", "end_time") %in% names(eur_segs))) {

  # For each flight, check if any segments overlap
  overlap_check <- eur_segs |>
    filter(!is.na(start_time), !is.na(end_time)) |>
    arrange(UID, start_time) |>
    group_by(UID) |>
    mutate(
      prev_end = lag(end_time),
      overlaps = !is.na(prev_end) & start_time < prev_end
    ) |>
    ungroup()

  flights_with_overlaps <- overlap_check |>
    group_by(UID) |>
    summarise(has_overlap = any(overlaps, na.rm=TRUE)) |>
    filter(has_overlap)

  total_flights <- n_distinct(eur_segs$UID)
  overlapping_flights <- nrow(flights_with_overlaps)

  cat("  Total flights:", format(total_flights, big.mark=","), "\n")
  cat("  Flights with overlaps:", format(overlapping_flights, big.mark=","), "\n")
  cat("  Overlap rate:", round(100 * overlapping_flights / total_flights, 1), "%\n")

  if (overlapping_flights > 0) {
    cat("  ❌ FAIL: Overlapping intervals detected\n")

    # Example overlapping segments
    example_flight <- flights_with_overlaps$UID[1]
    example_segs <- overlap_check |>
      filter(UID == example_flight) |>
      select(UID, segment_id, start_time, end_time, prev_end, overlaps) |>
      head(5)

    cat("\n  Example overlapping segments for flight", example_flight, ":\n")
    print(example_segs, n=5)
  } else {
    cat("  ✅ PASS: No overlapping intervals\n")
  }

} else {
  cat("  ⚠️  WARNING: Missing required time columns\n")
}

cat("\n")

# TEST 3: Check for distance field
cat("TEST 3: Distance Field Presence\n")
cat("--------------------------------\n")

distance_cols <- grep("distance|dist|nm", names(eur_segs), ignore.case=TRUE, value=TRUE)

if (length(distance_cols) > 0) {
  cat("  Distance-related columns found:", paste(distance_cols, collapse=", "), "\n")

  # Check how many have non-NA distance
  for (col in distance_cols) {
    non_na <- sum(!is.na(eur_segs[[col]]))
    cat("   ", col, ":", format(non_na, big.mark=","), "non-NA values\n")
  }

  if (any(sapply(distance_cols, function(col) sum(!is.na(eur_segs[[col]])) > 0))) {
    cat("  ✅ PASS: Distance data present\n")
  } else {
    cat("  ❌ FAIL: Distance columns exist but all values are NA\n")
  }
} else {
  cat("  ❌ FAIL: No distance-related columns found\n")
  cat("  Available columns:", paste(names(eur_segs), collapse=", "), "\n")
}

cat("\n")

# TEST 4: Exposure overstatement check
cat("TEST 4: Exposure Overstatement\n")
cat("-------------------------------\n")

if (all(c("UID", "start_time", "end_time", "duration_sec") %in% names(eur_segs))) {

  # Compute summed vs. union duration
  exposure_calc <- eur_segs |>
    filter(!is.na(start_time), !is.na(end_time), !is.na(duration_sec)) |>
    group_by(UID) |>
    summarise(
      summed_duration_h = sum(duration_sec, na.rm=TRUE) / 3600,
      .groups = "drop"
    )

  summed_total <- sum(exposure_calc$summed_duration_h)

  cat("  Summed exposure:", format(round(summed_total, 1), big.mark=","), "hours\n")
  cat("  Expected (from W0 audit): ~20,132 hours\n")
  cat("  Union exposure (from W0 audit): ~12,802 hours\n")
  cat("  Overstatement: ~", round(100 * (summed_total / 12802 - 1), 1), "%\n")

  if (summed_total > 15000) {  # Expected ~20K if overlap issue present
    cat("  ❌ FAIL: Exposure appears inflated (overlaps likely)\n")
  } else {
    cat("  ✅ PASS: Exposure within expected range\n")
  }

} else {
  cat("  ⚠️  WARNING: Cannot compute exposure (missing duration fields)\n")
}

cat("\n")

# SUMMARY
cat("============================================\n")
cat("SMOKE TEST SUMMARY\n")
cat("============================================\n\n")

cat("Expected Results (per W0 audit):\n")
cat("  ❌ Repeated segment keys: 29,631\n")
cat("  ❌ Flights with overlaps: 18,860 (87.7%)\n")
cat("  ❌ Missing distance: all segments\n")
cat("  ❌ Exposure overstatement: ~57%\n\n")

cat("If tests match expected failures, W1 diagnostic is validated.\n")
cat("If tests pass, either:\n")
cat("  a) Wrong data file loaded, OR\n")
cat("  b) Issue already fixed in this data version\n\n")

cat("Next steps:\n")
cat("  1. Review test results above\n")
cat("  2. Compare to W0 audit results\n")
cat("  3. If validated, proceed with W1 full implementation\n")
cat("  4. If not validated, investigate data version mismatch\n\n")

cat("Smoke test complete.\n")
