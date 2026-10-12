#!/usr/bin/env Rscript
# W2 — Create Phase-Specific Eligibility Flags
# Based on W2 diagnostic findings

library(arrow)
library(dplyr)
library(readr)

cat("Creating CHN phase-specific eligibility flags...\n")

# Load data
milestones <- read_parquet("data-store/processed/chn/CHN-canonical-milestones-summer2025.parquet")
phase_summaries <- read_parquet("data-store/processed/chn/CHN-phase-summaries-summer2025.parquet")

# Identify flights with key milestones
milestone_presence <- milestones %>%
  mutate(
    has_ATOT = MST == "ATOT",
    has_TOC = MST == "TOC",
    has_TOD = MST == "TOD",
    has_ALDT = MST == "ALDT"
  ) %>%
  group_by(SOURCE_UID) %>%
  summarise(
    ATOT_present = any(has_ATOT),
    TOC_present = any(has_TOC),
    TOD_present = any(has_TOD),
    ALDT_present = any(has_ALDT),
    .groups = "drop"
  )

# Create phase-level eligibility
phase_eligibility <- phase_summaries %>%
  rename(FUEL_BURNT_KG = FUEL_KG) %>%
  left_join(milestone_presence, by = "SOURCE_UID") %>%
  mutate(
    # Time eligibility: has valid duration
    time_eligible = !is.na(DURATION_MIN) & DURATION_MIN > 0 & is.finite(DURATION_MIN),

    # Fuel eligibility: has valid fuel burn
    fuel_eligible = !is.na(FUEL_BURNT_KG) & is.finite(FUEL_BURNT_KG),

    # Distance eligibility: INVALID per W2 findings (coordinate issues)
    distance_eligible = FALSE,
    distance_ineligible_reason = "W2_coordinate_error",

    # Phase-specific eligibility based on boundary milestones
    phase_boundary_eligible = case_when(
      # ALDT-independent phases (bounded by ATOT/TOC/TOD only)
      PHASE %in% c("TAXI_OUT", "TAKE_OFF_ROLL", "LTO_CLIMB_OUT") ~ ATOT_present,
      PHASE == "CLIMB" ~ ATOT_present & TOC_present,
      PHASE == "CRUISE" ~ TOC_present & TOD_present,
      PHASE == "DESCENT" ~ TOD_present,  # Can use ALTO even if ALDT missing

      # ALDT-dependent phases
      PHASE == "LTO_APPROACH_LANDING" ~ TOD_present & ALDT_present,
      PHASE == "RUNWAY_EXIT" ~ ALDT_present,
      PHASE == "TAXI_IN" ~ ALDT_present,

      TRUE ~ FALSE
    ),

    # Overall phase eligibility for time/fuel analyses
    phase_time_fuel_eligible = time_eligible & fuel_eligible & phase_boundary_eligible,

    # Flag ALDT dependency
    aldt_dependent = PHASE %in% c("LTO_APPROACH_LANDING", "RUNWAY_EXIT", "TAXI_IN"),

    # Eligibility notes
    eligibility_note = case_when(
      !phase_boundary_eligible & aldt_dependent & !ALDT_present ~ "missing_ALDT",
      !phase_boundary_eligible & !ATOT_present ~ "missing_ATOT",
      !phase_boundary_eligible & !TOC_present ~ "missing_TOC",
      !phase_boundary_eligible & !TOD_present ~ "missing_TOD",
      !time_eligible ~ "invalid_duration",
      !fuel_eligible ~ "invalid_fuel",
      TRUE ~ "ok"
    )
  ) %>%
  select(
    SOURCE_UID, source_batch, TYPE, PHASE, FROM_MST, TO_MST,
    DURATION_MIN, FUEL_BURNT_KG, DISTANCE_NM,
    time_eligible, fuel_eligible, distance_eligible, distance_ineligible_reason,
    phase_boundary_eligible, aldt_dependent,
    phase_time_fuel_eligible, eligibility_note,
    ATOT_present, TOC_present, TOD_present, ALDT_present
  )

# Summary by phase
phase_eligibility_summary <- phase_eligibility %>%
  group_by(PHASE, aldt_dependent) %>%
  summarise(
    total_records = n(),
    time_fuel_eligible = sum(phase_time_fuel_eligible),
    pct_eligible = 100 * time_fuel_eligible / total_records,
    missing_ALDT = sum(eligibility_note == "missing_ALDT"),
    .groups = "drop"
  ) %>%
  arrange(desc(aldt_dependent), PHASE)

cat("\nPhase Eligibility Summary:\n")
print(phase_eligibility_summary)

# Flight-level summary
flight_eligibility <- phase_eligibility %>%
  group_by(SOURCE_UID) %>%
  summarise(
    source_batch = first(source_batch),
    TYPE = first(TYPE),
    total_phases = n(),
    eligible_phases = sum(phase_time_fuel_eligible),
    has_ALDT = first(ALDT_present),

    # Airborne eligibility (CLIMB + CRUISE + DESCENT)
    airborne_eligible = all(phase_time_fuel_eligible[PHASE %in% c("CLIMB", "CRUISE", "DESCENT")]),

    # Descent eligible (needs ALDT for approach, but DESCENT phase itself doesn't)
    descent_phase_eligible = any(phase_time_fuel_eligible[PHASE == "DESCENT"]),
    approach_eligible = any(phase_time_fuel_eligible[PHASE == "LTO_APPROACH_LANDING"]),

    .groups = "drop"
  )

flight_summary <- flight_eligibility %>%
  summarise(
    total_flights = n(),
    airborne_eligible = sum(airborne_eligible),
    descent_phase_eligible = sum(descent_phase_eligible),
    approach_eligible = sum(approach_eligible),
    has_ALDT = sum(has_ALDT)
  )

cat("\nFlight-Level Eligibility Summary:\n")
print(flight_summary)

# Save outputs
output_dir <- "notes/results/W2/W2-2026-10-09-001"
write_csv(phase_eligibility, file.path(output_dir, "phase-eligibility-flags.csv"))
write_csv(phase_eligibility_summary, file.path(output_dir, "phase-eligibility-summary.csv"))
write_csv(flight_eligibility, file.path(output_dir, "flight-eligibility-flags.csv"))
write_csv(flight_summary, file.path(output_dir, "flight-eligibility-summary.csv"))

cat("\n✓ Eligibility flags created\n")
cat("  - phase-eligibility-flags.csv (54,131 phase records)\n")
cat("  - flight-eligibility-flags.csv (6,421 flights)\n")
cat("  - Summary files created\n")
