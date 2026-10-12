#!/usr/bin/env Rscript
# Complete EUR FIXED Data Verification Pipeline
# v2 - Fixed PHASE column name

library(arrow)
library(dplyr)
library(readr)

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  EUR FIXED Data Verification Pipeline                       ║\n")
cat("║  Autonomous execution - safe for remote disconnect          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

start_time <- Sys.time()

# STEP 1: Convert to canonical
cat("\n=== STEP 1: Converting FIXED Data to Canonical Format ===\n")
cat(sprintf("Started: %s\n", Sys.time()))

meta_fixed <- read_parquet("data-store/raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet")
seg_fixed <- read_parquet("data-store/raw/eur/g2g-segment-details-2025-summer-FIXED.parquet")

cat(sprintf("✓ Loaded: %s flights, %s segments\n",
            format(nrow(meta_fixed), big.mark = ","),
            format(nrow(seg_fixed), big.mark = ",")))

source("R/canonical-fuel-milestones.R")
eur_milestones_fixed <- fuel_eur_milestones(segments = seg_fixed, flight_metadata = meta_fixed)

cat(sprintf("✓ Created %s canonical milestones\n", format(nrow(eur_milestones_fixed), big.mark = ",")))

canonical_out <- "data-store/raw/eur/EUR-canonical-milestones-summer2025-FIXED.parquet"
write_parquet(eur_milestones_fixed, canonical_out)
cat(sprintf("✓ Saved: %s\n", canonical_out))

# STEP 2: Harmonize
cat("\n=== STEP 2: Harmonizing Milestones ===\n")
cat(sprintf("Started: %s\n", Sys.time()))

source("R/eur-milestone-harmonization.R")

# FIXED: Column is FLIGHT_PHASE_RAW, not PHASE
harmonized_fixed <- harmonize_eur_milestones(
  df = eur_milestones_fixed,
  uid_col = "SOURCE_UID",
  mst_col = "MST",
  phase_col = "FLIGHT_PHASE_RAW"
)

cat(sprintf("✓ Harmonized: %s records\n", format(nrow(harmonized_fixed), big.mark = ",")))

lvl_summary <- harmonized_fixed %>% filter(grepl("LVL", MST)) %>% count(MST) %>% arrange(desc(n))
cat("\nLVL Marker Counts:\n")
print(lvl_summary, n = Inf)

harmonized_out <- "data-derived/eur/EUR-harmonized-milestones-summer2025-FIXED.parquet"
dir.create(dirname(harmonized_out), recursive = TRUE, showWarnings = FALSE)
write_parquet(harmonized_fixed, harmonized_out)
cat(sprintf("✓ Saved: %s\n", harmonized_out))

# STEP 3: Derive level segments
cat("\n=== STEP 3: Deriving Level Segments ===\n")
cat(sprintf("Started: %s\n", Sys.time()))

source("R/level-off-milestones.R")

level_results <- derive_level_segments(
  df = harmonized_fixed,
  uid_col = "SOURCE_UID",
  start_marker = "LVL_START",
  end_marker = "LVL_END"
)

cat(sprintf("✓ Derived %s level segments\n", format(nrow(level_results$intervals), big.mark = ",")))

write_parquet(level_results$intervals, "data-derived/eur/EUR-level-segments-summer2025-FIXED.parquet")
write_csv(level_results$duration_summary, "data-derived/eur/EUR-level-duration-summary-FIXED.csv")
write_csv(level_results$qc_detail, "data-derived/eur/EUR-level-qc-detail-FIXED.csv")

cat("✓ Saved all outputs\n")

# STEP 4: Orphan rate analysis
cat("\n=== STEP 4: Orphan Rate Analysis ===\n")
cat(sprintf("Started: %s\n", Sys.time()))

orphaned_fixed <- level_results$qc_detail %>% filter(orphaned_no_end) %>% distinct(SOURCE_UID)
total_flights_fixed <- n_distinct(harmonized_fixed$SOURCE_UID)
orphan_rate_fixed <- 100 * nrow(orphaned_fixed) / total_flights_fixed

cat(sprintf("\nFIXED Data:\n"))
cat(sprintf("  Total flights: %s\n", format(total_flights_fixed, big.mark = ",")))
cat(sprintf("  Orphaned: %s\n", format(nrow(orphaned_fixed), big.mark = ",")))
cat(sprintf("  Orphan rate: %.1f%%\n", orphan_rate_fixed))

# Compare with OLD
old_qc <- read_csv("data-derived/eur/EUR-level-qc-detail.csv", show_col_types = FALSE)
orphaned_old <- old_qc %>% filter(orphaned_no_end) %>% distinct(SOURCE_UID)
total_flights_old <- n_distinct(old_qc$SOURCE_UID)
orphan_rate_old <- 100 * nrow(orphaned_old) / total_flights_old

cat(sprintf("\nOLD Data:\n"))
cat(sprintf("  Total flights: %s\n", format(total_flights_old, big.mark = ",")))
cat(sprintf("  Orphaned: %s\n", format(nrow(orphaned_old), big.mark = ",")))
cat(sprintf("  Orphan rate: %.1f%%\n", orphan_rate_old))

improvement <- orphan_rate_old - orphan_rate_fixed
pct_reduction <- 100 * improvement / orphan_rate_old

cat(sprintf("\n🎯 IMPROVEMENT:\n"))
cat(sprintf("  Absolute: %.1f pp\n", improvement))
cat(sprintf("  Relative: %.1f%% reduction\n", pct_reduction))

# STEP 5: Report
cat("\n=== STEP 5: Creating Report ===\n")

report <- sprintf("# EUR FIXED Verification Report

**Date:** %s  
**Orphan Rate:** %.1f%% (was %.1f%%)  
**Improvement:** %.1f pp (%.1f%% reduction)

## Summary
- FIXED: %s flights, %s orphaned (%.1f%%)
- OLD: %s flights, %s orphaned (%.1f%%)
- **Rescued:** %s flights from artificial orphaning!

## Result
%s

---
*Duration: %.1f minutes*
",
Sys.time(),
orphan_rate_fixed, orphan_rate_old,
improvement, pct_reduction,
format(total_flights_fixed, big.mark = ","), format(nrow(orphaned_fixed), big.mark = ","), orphan_rate_fixed,
format(total_flights_old, big.mark = ","), format(nrow(orphaned_old), big.mark = ","), orphan_rate_old,
format(nrow(orphaned_old) - nrow(orphaned_fixed), big.mark = ","),
ifelse(orphan_rate_fixed < 20, "✅ SUCCESS - LOBT filter bug fixed!", "⚠️ Review needed"),
as.numeric(difftime(Sys.time(), start_time, units = "mins"))
)

writeLines(report, "notes/EUR-FIXED-Verification-Report.md")

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  VERIFICATION COMPLETE                                       ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")
cat(sprintf("\n📊 RESULT: %.1f%% orphan rate (was %.1f%%) = %.1f%% reduction!\n",
            orphan_rate_fixed, orphan_rate_old, pct_reduction))
cat("\n✓ Report: notes/EUR-FIXED-Verification-Report.md\n")
