#!/usr/bin/env Rscript
# Enrich EUR Canonical Milestones with CHN-compatible metadata
#
# Adds:
# 1. TOTAL_FLOWN_NM - Total trajectory distance per flight
# 2. MST_GROUP - Milestone category
# 3. MST_METHOD - Derivation method
# 4. DIST_REMAINING_NM - Distance remaining to destination (optional)

library(arrow)
library(dplyr)
library(readr)

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  EUR Canonical Milestone Enrichment                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Load FIXED canonical milestones (NEW schema from fuel_eur_milestones)
canonical_file <- "data-store/raw/eur/EUR-canonical-milestones-summer2025-FIXED.parquet"

if (!file.exists(canonical_file)) {
  stop("FIXED canonical file not found: ", canonical_file, call. = FALSE)
}

cat("Loading:", canonical_file, "\n")
eur_canonical <- read_parquet(canonical_file)

cat(sprintf("  Rows: %s\n", format(nrow(eur_canonical), big.mark = ",")))
cat(sprintf("  Flights: %s\n", format(n_distinct(eur_canonical$SOURCE_UID), big.mark = ",")))
cat("  Columns:", paste(names(eur_canonical), collapse = ", "), "\n\n")

# ============================================================================
# Enhancement 1: Add TOTAL_FLOWN_NM
# ============================================================================

cat("Step 1: Adding TOTAL_FLOWN_NM (total trajectory distance)...\n")

eur_enriched <- eur_canonical %>%
  group_by(SOURCE_UID) %>%
  mutate(
    TOTAL_FLOWN_NM = max(DIST_FLOWN_NM, na.rm = TRUE)
  ) %>%
  ungroup()

cat(sprintf("  ✓ Added TOTAL_FLOWN_NM (mean: %.1f NM)\n",
            mean(eur_enriched$TOTAL_FLOWN_NM, na.rm = TRUE)))

# ============================================================================
# Enhancement 2: Add MST_GROUP (milestone category)
# ============================================================================

cat("\nStep 2: Adding MST_GROUP (milestone categorization)...\n")

eur_enriched <- eur_enriched %>%
  mutate(
    MST_GROUP = case_when(
      # Operational profile milestones
      MST %in% c("AOBT", "ERWY", "ATOT", "DLTO", "ALTO", "ALDT", "XRWY", "AIBT") ~ "operational_profile",

      # Level segment boundaries
      MST %in% c("LVL_START", "LVL_END") ~ "level_segment",

      # Cruise bounds
      MST %in% c("TOC", "TOD") ~ "cruise_bounds",

      # Departure-side flow milestones
      MST %in% c("D040", "D100", "D200", "D_FL075", "D_FL100", "D_FL180") ~ "departure_flow",

      # Arrival-side flow milestones
      MST %in% c("A200", "A100", "A040", "A_FL180", "A_FL100", "A_FL075") ~ "arrival_flow",

      # FIR/AUA boundaries
      MST %in% c("FIR", "AUA") ~ "airspace_boundary",

      # Other/unknown
      TRUE ~ "other"
    )
  )

# Summary by group
group_summary <- eur_enriched %>%
  count(MST_GROUP, sort = TRUE)

cat("  ✓ MST_GROUP distribution:\n")
for (i in 1:nrow(group_summary)) {
  cat(sprintf("    %s: %s\n",
              group_summary$MST_GROUP[i],
              format(group_summary$n[i], big.mark = ",")))
}

# ============================================================================
# Enhancement 3: Add MST_METHOD (derivation method)
# ============================================================================

cat("\nStep 3: Adding MST_METHOD (provenance tracking)...\n")

eur_enriched <- eur_enriched %>%
  mutate(
    MST_METHOD = case_when(
      # Operational milestones are derived from trajectory analysis
      MST %in% c("AOBT", "ERWY", "ATOT", "DLTO", "ALTO", "ALDT", "XRWY", "AIBT") ~ "derived_operational",

      # FL crossings are algorithmically derived
      MST %in% c("D_FL075", "D_FL100", "D_FL180", "A_FL180", "A_FL100", "A_FL075") ~ "derived_fl_crossing",

      # Distance milestones are derived from cumulative distance
      MST %in% c("D040", "D100", "D200", "A200", "A100", "A040") ~ "derived_distance",

      # Level segments and cruise bounds come from PRU source
      MST %in% c("LVL_START", "LVL_END", "LVL") ~ "explicit_pru_source",
      MST %in% c("TOC", "TOD") ~ "explicit_pru_source",

      # FIR/AUA from source
      MST %in% c("FIR", "AUA") ~ "explicit_pru_source",

      # Default
      TRUE ~ "derived"
    )
  )

# Summary by method
method_summary <- eur_enriched %>%
  count(MST_METHOD, sort = TRUE)

cat("  ✓ MST_METHOD distribution:\n")
for (i in 1:nrow(method_summary)) {
  cat(sprintf("    %s: %s\n",
              method_summary$MST_METHOD[i],
              format(method_summary$n[i], big.mark = ",")))
}

# ============================================================================
# Optional: Add DIST_REMAINING_NM (can be derived when needed)
# ============================================================================

cat("\nStep 4: Adding DIST_REMAINING_NM (optional)...\n")

eur_enriched <- eur_enriched %>%
  mutate(
    DIST_REMAINING_NM = TOTAL_FLOWN_NM - DIST_FLOWN_NM
  )

cat("  ✓ Added DIST_REMAINING_NM\n")

# ============================================================================
# Save enriched canonical milestones
# ============================================================================

cat("\nSaving enriched canonical milestones...\n")

output_file <- "data-store/raw/eur/EUR-canonical-milestones-summer2025-ENRICHED.parquet"
write_parquet(eur_enriched, output_file)

cat(sprintf("✓ Saved: %s\n", output_file))
cat(sprintf("  Size: %.2f MB\n", file.size(output_file) / 1024 / 1024))

# ============================================================================
# Schema comparison
# ============================================================================

cat("\n=== EUR vs CHN Schema Comparison ===\n")

cat("\nEUR Enriched columns (", length(names(eur_enriched)), "):\n")
cat("  ", paste(names(eur_enriched), collapse = ", "), "\n")

cat("\nCHN Expected columns:\n")
cat("  SOURCE_UID, FLTID, ADEP, ADES, TYPE,\n")
cat("  TIME, LAT, LON, ALT_FT, MST, MST_GROUP, MST_METHOD,\n")
cat("  TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL,\n")
cat("  DIST_FLOWN_NM, TOTAL_FLOWN_NM, DIST_REMAINING_NM,\n")
cat("  DIST_FROM_DEP_NM, DIST_TO_ARR_NM,\n")
cat("  FLIGHT_PHASE_RAW, ROW_ID\n")

cat("\n✓ EUR canonical milestones enriched for CHN compatibility!\n")
cat("\nNext: Enrich level segments with LEVEL_CONTEXT_PHASE\n")
