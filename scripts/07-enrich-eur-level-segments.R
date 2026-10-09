#!/usr/bin/env Rscript
# Enrich EUR Level Segments with LEVEL_CONTEXT_PHASE
#
# Adds phase context categorization to level segments

library(arrow)
library(dplyr)
library(readr)

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  EUR Level Segment Enrichment                               ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Load level segments
segments_file <- "data-store/derived/eur/level-segments-eur-2026.parquet"

if (!file.exists(segments_file)) {
  stop("Level segments file not found: ", segments_file, call. = FALSE)
}

cat("Loading:", segments_file, "\n")
level_segments <- read_parquet(segments_file)

cat(sprintf("  Rows: %s\n", format(nrow(level_segments), big.mark = ",")))
cat(sprintf("  Flights: %s\n", format(n_distinct(level_segments$UID), big.mark = ",")))
cat("  Columns:", paste(names(level_segments), collapse = ", "), "\n\n")

# ============================================================================
# Add LEVEL_CONTEXT_PHASE
# ============================================================================

cat("Adding LEVEL_CONTEXT_PHASE (phase categorization)...\n")

segments_enriched <- level_segments %>%
  mutate(
    LEVEL_CONTEXT_PHASE = case_when(
      # Use start_phase if available
      !is.na(start_phase) & start_phase == "CLIMB" ~ "CLIMB",
      !is.na(start_phase) & start_phase == "DESCENT" ~ "DESCENT",
      !is.na(start_phase) & start_phase == "CRUISE" ~ "ENROUTE",

      # Fallback: Use altitude-based heuristic
      # Enroute: above FL200
      start_alt >= 20000 ~ "ENROUTE",

      # Climb: ascending segments below cruise altitude
      !is.na(end_alt) & end_alt > start_alt ~ "CLIMB",

      # Descent: descending segments
      !is.na(end_alt) & end_alt < start_alt ~ "DESCENT",

      # Default: classify by altitude
      start_alt >= 15000 ~ "ENROUTE",
      start_alt < 10000 ~ "TERMINAL",

      # Middle range
      TRUE ~ "INTERMEDIATE"
    )
  )

# Summary by phase
phase_summary <- segments_enriched %>%
  count(LEVEL_CONTEXT_PHASE, sort = TRUE)

cat("  ✓ LEVEL_CONTEXT_PHASE distribution:\n")
for (i in 1:nrow(phase_summary)) {
  cat(sprintf("    %s: %s\n",
              phase_summary$LEVEL_CONTEXT_PHASE[i],
              format(phase_summary$n[i], big.mark = ",")))
}

# ============================================================================
# Add MST_GROUP and MST_METHOD for consistency with milestones
# ============================================================================

cat("\nAdding MST_GROUP and MST_METHOD for consistency...\n")

segments_enriched <- segments_enriched %>%
  mutate(
    MST_GROUP = "level_segment",
    MST_METHOD = "derived_interval"
  )

cat("  ✓ Added MST_GROUP and MST_METHOD\n")

# ============================================================================
# Save enriched level segments
# ============================================================================

cat("\nSaving enriched level segments...\n")

output_file <- "data-store/derived/eur/level-segments-eur-2026-ENRICHED.parquet"
write_parquet(segments_enriched, output_file)

cat(sprintf("✓ Saved: %s\n", output_file))
cat(sprintf("  Size: %.2f MB\n", file.size(output_file) / 1024 / 1024))

# ============================================================================
# Summary
# ============================================================================

cat("\n=== Enrichment Summary ===\n")
cat(sprintf("  Total segments: %s\n", format(nrow(segments_enriched), big.mark = ",")))
cat(sprintf("  Columns added: %d\n", ncol(segments_enriched) - ncol(level_segments)))
cat(sprintf("  New columns: %s\n",
            paste(setdiff(names(segments_enriched), names(level_segments)), collapse = ", ")))

cat("\n✓ EUR level segments enriched!\n")
cat("\nNext: Create harmonized analytical datasets\n")
