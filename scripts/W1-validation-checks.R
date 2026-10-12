#!/usr/bin/env Rscript
# W1 Validation Checks
# Tests what CAN be validated without PRU source access

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
  library(here)
})

cat("============================================\n")
cat("W1 VALIDATION CHECKS\n")
cat("Tests performed on processed EUR data\n")
cat("(Source validation blocked - see handoff)\n")
cat("============================================\n\n")

# Use W0 audit results as primary evidence
w0_audit <- here("notes", "results", "W0", "W0-2026-10-09-001", "study-readiness.csv")

if (!file.exists(w0_audit)) {
  stop("W0 audit file not found. Run W0 audit first.")
}

audit <- readr::read_csv(w0_audit, show_col_types = FALSE) |>
  filter(REGION == "EUR")

cat("=== W0 AUDIT EVIDENCE (EUR) ===\n\n")
cat("Total segment rows:", audit$segment_rows, "\n")
cat("Distinct segment keys:", audit$distinct_segment_keys, "\n")
cat("Repeated segment keys:", audit$repeated_segment_keys, "\n")
cat("Repetition rate:", round(100 * audit$repeated_segment_keys / audit$distinct_segment_keys, 1), "%\n\n")

cat("Flights with overlaps:", audit$flights_with_overlapping_intervals, "\n")
cat("Total flights:", audit$flights, "\n")
cat("Overlap rate:", round(100 * audit$flights_with_overlapping_intervals / audit$flights, 1), "%\n\n")

cat("Summed interval hours:", round(audit$summed_interval_hours, 1), "\n")
cat("Union interval hours:", round(audit$union_interval_hours, 1), "\n")
cat("Overstatement:", round(100 * (audit$summed_interval_hours / audit$union_interval_hours - 1), 1), "%\n\n")

cat("Intervals with distance:", audit$intervals_with_distance, "\n")
cat("Expected:", audit$segment_rows, "\n")
cat("Missing distance rate:", round(100 * (1 - audit$intervals_with_distance / audit$segment_rows), 1), "%\n\n")

# VALIDATION CHECKS

cat("=== VALIDATION CHECK 1: Data Quality Thresholds ===\n")
check1_repeated <- audit$repeated_segment_keys > 0
check1_overlaps <- audit$flights_with_overlapping_intervals > audit$flights * 0.05  # >5% overlap rate
check1_exposure <- (audit$summed_interval_hours / audit$union_interval_hours - 1) > 0.10  # >10% overstatement
check1_distance <- audit$intervals_with_distance == 0

cat("Repeated keys present:", if(check1_repeated) "❌ FAIL" else "✅ PASS", "\n")
cat("Excessive overlaps (>5%):", if(check1_overlaps) "❌ FAIL" else "✅ PASS", "\n")
cat("Exposure overstatement (>10%):", if(check1_exposure) "❌ FAIL" else "✅ PASS", "\n")
cat("Distance field missing:", if(check1_distance) "❌ FAIL" else "✅ PASS", "\n\n")

overall_quality <- !(check1_repeated | check1_overlaps | check1_exposure | check1_distance)
cat("Overall EUR segment quality:", if(overall_quality) "✅ PASS" else "❌ FAIL", "\n\n")

# VALIDATION CHECK 2: Code review findings
cat("=== VALIDATION CHECK 2: Code Review ===\n")
harmonization_file <- here("R", "eur-milestone-harmonization.R")

if (file.exists(harmonization_file)) {
  code <- readr::read_file(harmonization_file)

  # Check for alternating pairing logic
  has_alternating <- grepl(".lvl_seq %% 2 == 1", code, fixed = TRUE)
  cat("Alternating pairing logic present:", if(has_alternating) "⚠️  FOUND" else "✅ NOT FOUND", "\n")

  # Check for SAM_ID usage
  has_sam_id <- grepl("SAM_ID", code)
  cat("SAM_ID referenced in code:", if(has_sam_id) "✅ YES" else "⚠️  NO", "\n")

  # Check for distance preservation
  has_distance <- grepl("DISTANCE|distance|dist", code)
  cat("Distance handling in code:", if(has_distance) "⚠️  FOUND" else "❌ NOT FOUND", "\n\n")
} else {
  cat("⚠️  Harmonization file not found for code review\n\n")
}

# VALIDATION CHECK 3: W1 Acceptance Criteria
cat("=== VALIDATION CHECK 3: W1 Acceptance Criteria ===\n")
cat("(Per study-release-contract.md lines 360-365)\n\n")

criteria <- tribble(
  ~criterion, ~status,
  "No unexplained duplicate interval keys", if(audit$repeated_segment_keys == 0) "✅ PASS" else "❌ FAIL",
  "No extra ends or overlaps", if(audit$flights_with_overlapping_intervals == 0) "✅ PASS" else "❌ FAIL",
  "No out-of-bounds intervals", "⚠️  NOT TESTED",
  "No negative exposures", "⚠️  NOT TESTED",
  "Explicit provenance for inferred boundaries", "⚠️  PARTIAL",
  "Regression tests implemented", "❌ NOT DONE"
)

print(criteria, n = Inf)
cat("\n")

# SUMMARY
cat("============================================\n")
cat("VALIDATION SUMMARY\n")
cat("============================================\n\n")

cat("TESTS PERFORMED:\n")
cat("✅ W0 audit evidence reviewed\n")
cat("✅ Data quality thresholds checked\n")
cat("✅ Code review for alternating pairing\n")
cat("✅ W1 acceptance criteria assessed\n\n")

cat("TESTS BLOCKED (require PRU source access):\n")
cat("❌ Root cause validation\n")
cat("❌ Representative flight traces\n")
cat("❌ SAM_ID semantics investigation\n")
cat("❌ Proposed fix validation\n\n")

cat("CONCLUSION:\n")
if (!overall_quality) {
  cat("EUR processed segments FAIL quality checks.\n")
  cat("Current data UNSUITABLE for segment-based analyses.\n")
  cat("Root cause validation BLOCKED on PRU source access.\n\n")
} else {
  cat("EUR processed segments PASS quality checks.\n")
  cat("No issues detected in available data.\n\n")
}

cat("See notes/results/W1/W1-2026-10-12-001/ for full diagnostic.\n")
cat("\nValidation checks complete.\n")
