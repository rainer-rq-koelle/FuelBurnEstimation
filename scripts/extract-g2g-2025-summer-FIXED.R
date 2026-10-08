#!/usr/bin/env Rscript
# FIXED G2G Extraction - Summer 2025
#
# FIX: Two-stage extraction using SAM_ID to ensure complete flights
# Previously: LOBT filter at segment level was cutting off late segments
# Now: Get flight SAM_IDs first, then get ALL segments for those flights

library(tidyverse)
library(arrow)
library(DBI)

# Connect to PRU_PROD
# Assuming db-connection-setup.R exists in parent project
source("C:/Users/rkoelle/dev/RProjects/xx-test-gotcha/R/db-connection-setup.R")

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  FIXED G2G Extraction - Summer 2025 (Jun-Aug)               ║\n")
cat("║  Two-stage SAM_ID-based extraction                          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# EUR route pairs
eur_pairs <- tibble::tribble(
  ~ADEP,  ~ADES,
  # SHORT
  "EDDF", "EDDM",
  "EDDM", "EDDF",
  "EDDF", "LSZH",
  "LSZH", "EDDF",
  # MEDIUM
  "EDDF", "EGLL",
  "EGLL", "EDDF",
  "EDDM", "EGLL",
  "EGLL", "EDDM",
  "EDDF", "LIRF",
  "LIRF", "EDDF",
  # MEDIUM-LONG
  "EGLL", "LEBL",
  "LEBL", "EGLL",
  "EDDF", "LEBL",
  "LEBL", "EDDF",
  "EHAM", "LEBL",
  "LEBL", "EHAM",
  "LEMD", "LFPG",
  "LFPG", "LEMD",
  # LONG
  "EDDM", "LTFM",
  "LTFM", "EDDM",
  "EDDF", "LGAV",
  "LGAV", "EDDF"
)

# Period
wef <- "2025-06-01"
til <- "2025-09-01"

cat("\n=== Study Period ===\n")
cat(sprintf("From: %s (inclusive)\n", wef))
cat(sprintf("To:   %s (exclusive)\n", til))
cat(sprintf("Duration: 92 days (Jun-Aug)\n\n"))

# Connect
cat("=== Connecting to PRU_PROD ===\n")
con <- get_con_prod()

# ============================================================================
# STAGE 1: Get SAM_IDs of flights in period (using LOBT for flight selection)
# ============================================================================

cat("\n=== STAGE 1: Selecting Flights by LOBT ===\n")

adep_list <- unique(c(eur_pairs$ADEP, eur_pairs$ADES))
adep_sql <- paste0("'", adep_list, "'", collapse = ", ")

# Get flight identifiers only
flight_selection_query <- sprintf("
  SELECT DISTINCT SAM_ID, LOBT, ADEP, ADES, AIRCRAFT_TYPE
  FROM PRUPROD.PRU_G2G_FB_V4
  WHERE LOBT >= TO_DATE('%s', 'YYYY-MM-DD')
    AND LOBT <  TO_DATE('%s', 'YYYY-MM-DD')
    AND ADEP IN (%s)
    AND ADES IN (%s)
", wef, til, adep_sql, adep_sql)

cat("Querying for flight identifiers...\n")
selected_flights <- DBI::dbGetQuery(con, flight_selection_query) |>
  tibble::tibble() |>
  inner_join(eur_pairs, by = c("ADEP", "ADES"))

cat(sprintf("✓ Selected %s flights for period\n",
            format(nrow(selected_flights), big.mark = ",")))

# ============================================================================
# STAGE 2: Get ALL segments for selected flights (no TIME_OVER filter!)
# ============================================================================

cat("\n=== STAGE 2: Extracting ALL Segments for Selected Flights ===\n")

# Create SAM_ID list for IN clause
sam_ids <- selected_flights$SAM_ID
sam_id_chunks <- split(sam_ids, ceiling(seq_along(sam_ids) / 1000))  # Oracle IN limit

cat(sprintf("Extracting segments in %d chunks (1000 SAM_IDs per chunk)...\n",
            length(sam_id_chunks)))

all_segments <- list()

for (i in seq_along(sam_id_chunks)) {
  sam_id_sql <- paste0("'", sam_id_chunks[[i]], "'", collapse = ", ")

  segment_query <- sprintf("
    SELECT
      SAM_ID,
      LOBT,
      AIRCRAFT_TYPE,
      ADEP,
      ADES,
      TIME_OVER,
      ALTITUDE_FT,
      LAT,
      LON,
      DISTANCE_NM,
      FUEL_BURNT_KG,
      CO2,
      NOX,
      SOX,
      FIR_ID,
      AUA_ID,
      FLIGHT_PHASE,
      MILESTONE,
      AIRCRAFT_OPERATOR,
      RULE_NAME,
      AO_GRP_CODE,
      AO_ISO_CTRY_CODE
    FROM PRUPROD.PRU_G2G_FB_V4
    WHERE SAM_ID IN (%s)
  ", sam_id_sql)

  chunk_data <- DBI::dbGetQuery(con, segment_query) |> tibble::tibble()
  all_segments[[i]] <- chunk_data

  cat(sprintf("  Chunk %d/%d: %s segments\n",
              i, length(sam_id_chunks),
              format(nrow(chunk_data), big.mark = ",")))
}

DBI::dbDisconnect(con)

# Combine all chunks
eur_segments <- bind_rows(all_segments)

cat(sprintf("\n✓ Extracted %s total segments for %s flights\n",
            format(nrow(eur_segments), big.mark = ","),
            format(n_distinct(eur_segments$SAM_ID), big.mark = ",")))

# ============================================================================
# Verification: Check for segments outside LOBT period
# ============================================================================

cat("\n=== VERIFICATION: Checking TIME_OVER vs LOBT ===\n")

eur_segments_dated <- eur_segments |>
  mutate(
    flight_date = as.Date(LOBT),
    segment_date = as.Date(TIME_OVER),
    date_diff = as.numeric(segment_date - flight_date)
  )

date_summary <- eur_segments_dated |>
  summarise(
    total_segments = n(),
    same_day = sum(date_diff == 0, na.rm = TRUE),
    next_day = sum(date_diff == 1, na.rm = TRUE),
    two_days = sum(date_diff == 2, na.rm = TRUE),
    other = sum(abs(date_diff) > 2, na.rm = TRUE)
  )

cat("\nSegments by date relationship to LOBT:\n")
print(date_summary)

# Check if we captured segments beyond LOBT filter
segments_beyond <- eur_segments_dated |>
  filter(segment_date >= as.Date(til))

if (nrow(segments_beyond) > 0) {
  cat(sprintf("\n✓ CAPTURED %s segments with TIME_OVER >= %s\n",
              format(nrow(segments_beyond), big.mark = ","), til))
  cat("  (These would have been LOST with LOBT-only filtering!)\n")

  # Check for LVL_END markers in rescued segments
  rescued_lvl_end <- segments_beyond |>
    filter(!is.na(MILESTONE), grepl("LVL", MILESTONE))

  if (nrow(rescued_lvl_end) > 0) {
    cat(sprintf("  Including %s LVL-related milestones!\n",
                format(nrow(rescued_lvl_end), big.mark = ",")))
  }
}

# ============================================================================
# Apply fuel burn correction
# ============================================================================

cat("\n=== Applying 20%% Take-Off Fuel Correction ===\n")

eur_corrected <- eur_segments |>
  mutate(
    FUEL_BURNT_KG_ORIGINAL = FUEL_BURNT_KG,
    FUEL_BURNT_KG = if_else(
      FLIGHT_PHASE %in% c("Take-Off", "Takeoff", "Take-off", "TAKEOFF"),
      FUEL_BURNT_KG * 0.8,
      FUEL_BURNT_KG
    ),
    CO2_ORIGINAL = CO2,
    CO2 = if_else(
      FLIGHT_PHASE %in% c("Take-Off", "Takeoff", "Take-off", "TAKEOFF"),
      CO2 * 0.8,
      CO2
    )
  )

# ============================================================================
# Create outputs
# ============================================================================

cat("\n=== Creating Output Files ===\n")

# Flight metadata
flight_metadata <- eur_corrected |>
  group_by(SAM_ID) |>
  summarise(
    region = "EUR",
    ADEP = first(ADEP),
    ADES = first(ADES),
    LOBT = first(LOBT),
    flight_date = as.Date(first(LOBT)),
    AIRCRAFT_TYPE = first(AIRCRAFT_TYPE),
    AIRCRAFT_OPERATOR = first(AIRCRAFT_OPERATOR),
    RULE_NAME = first(RULE_NAME),
    AO_ISO_CTRY_CODE = first(AO_ISO_CTRY_CODE),
    total_fuel_kg = sum(FUEL_BURNT_KG, na.rm = TRUE),
    total_fuel_kg_original = sum(FUEL_BURNT_KG_ORIGINAL, na.rm = TRUE),
    total_distance_nm = sum(DISTANCE_NM, na.rm = TRUE),
    total_co2_kg = sum(CO2, na.rm = TRUE),
    n_segments = n(),
    .groups = "drop"
  )

# Segment details
segment_details <- eur_corrected |>
  mutate(region = "EUR") |>
  select(
    SAM_ID, region, TIME_OVER, ALTITUDE_FT, LAT, LON,
    DISTANCE_NM, FUEL_BURNT_KG, FUEL_BURNT_KG_ORIGINAL,
    CO2, CO2_ORIGINAL, NOX, SOX, FIR_ID, AUA_ID,
    FLIGHT_PHASE, MILESTONE
  )

# Save
out_dir <- "data"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

write_parquet(flight_metadata, file.path(out_dir, "g2g-flight-metadata-2025-summer-FIXED.parquet"))
write_parquet(segment_details, file.path(out_dir, "g2g-segment-details-2025-summer-FIXED.parquet"))

cat("\n✓ Files written:\n")
cat("  - data/g2g-flight-metadata-2025-summer-FIXED.parquet\n")
cat("  - data/g2g-segment-details-2025-summer-FIXED.parquet\n")

# ============================================================================
# Summary
# ============================================================================

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  EXTRACTION COMPLETE                                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

cat("\nFinal Summary:\n")
cat(sprintf("  Flights: %s\n", format(nrow(flight_metadata), big.mark = ",")))
cat(sprintf("  Segments: %s\n", format(nrow(segment_details), big.mark = ",")))
cat(sprintf("  Avg segments/flight: %.1f\n", nrow(segment_details) / nrow(flight_metadata)))

cat("\nNext: Convert to canonical milestones and check LVL pairing!\n")
