#!/usr/bin/env Rscript
# Read-only pilot assessment of PRU G2G phase, FIR, and LVL records.
# Uses three fixed flight dates so results are reproducible and bounded.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
})

data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = ".fuelburn-data-store")
segment_path <- file.path(data_store, "raw/eur/g2g-segment-details-2025-summer-FIXED.parquet")
metadata_path <- file.path(data_store, "raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet")
output_dir <- "notes/results/W1/W1-2026-10-12-002-G2G-pilot"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(segment_path) || !file.exists(metadata_path)) {
  stop("Required local G2G parquet input is missing.", call. = FALSE)
}

pilot_dates <- as.Date(c("2025-06-11", "2025-06-27", "2025-08-13"))
segments <- arrow::read_parquet(segment_path)
metadata <- arrow::read_parquet(metadata_path) |>
  select(SAM_ID, flight_date, ADEP, ADES, AIRCRAFT_TYPE)

required <- c("SAM_ID", "TIME_OVER", "ALTITUDE_FT", "DISTANCE_NM", "FUEL_BURNT_KG",
              "FUEL_BURNT_KG_ORIGINAL", "FIR_ID", "AUA_ID", "FLIGHT_PHASE", "MILESTONE")
missing <- setdiff(required, names(segments))
if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "), call. = FALSE)

pilot <- segments |>
  left_join(metadata, by = "SAM_ID") |>
  filter(flight_date %in% pilot_dates) |>
  arrange(SAM_ID, TIME_OVER) |>
  group_by(SAM_ID) |>
  mutate(
    prev_time = lag(TIME_OVER),
    dt_sec = as.numeric(difftime(TIME_OVER, prev_time, units = "secs")),
    prev_alt = lag(ALTITUDE_FT),
    vertical_rate_fpm = abs(ALTITUDE_FT - prev_alt) / dt_sec * 60,
    prev_phase = lag(FLIGHT_PHASE),
    prev_fir = lag(FIR_ID),
    phase_change = !is.na(prev_phase) & !is.na(FLIGHT_PHASE) & prev_phase != FLIGHT_PHASE,
    fir_change = !is.na(prev_fir) & !is.na(FIR_ID) & prev_fir != FIR_ID,
    fir_tag = grepl("(^|/)FIR($|/)", coalesce(MILESTONE, "")),
    lvl_tag = grepl("(^|/)LVL($|/)", coalesce(MILESTONE, "")),
    lvl_compound = lvl_tag & grepl("/", coalesce(MILESTONE, ""))
  ) |>
  ungroup()

if (!nrow(pilot)) stop("No rows found on the selected pilot dates.", call. = FALSE)

# Basic input and per-day inventory.
daily_inventory <- pilot |>
  group_by(flight_date) |>
  summarise(
    flights = n_distinct(SAM_ID), rows = n(),
    duplicate_flight_time_keys = sum(duplicated(paste(SAM_ID, TIME_OVER))),
    missing_time = sum(is.na(TIME_OVER)), missing_altitude = sum(is.na(ALTITUDE_FT)),
    missing_distance = sum(is.na(DISTANCE_NM)), missing_adjusted_fuel = sum(is.na(FUEL_BURNT_KG)),
    missing_original_fuel = sum(is.na(FUEL_BURNT_KG_ORIGINAL)), missing_fir = sum(is.na(FIR_ID)),
    .groups = "drop"
  )

# Label incidence and odd/even counts include flights with zero LVL labels.
flight_inventory <- pilot |>
  group_by(SAM_ID, flight_date) |>
  summarise(rows = n(), lvl_count = sum(lvl_tag), lvl_compound_count = sum(lvl_compound),
            .groups = "drop")
lvl_by_flight <- flight_inventory |>
  group_by(flight_date) |>
  summarise(
    flights = n(), flights_with_lvl = sum(lvl_count > 0),
    flights_odd_lvl = sum(lvl_count %% 2 == 1), flights_even_lvl = sum(lvl_count > 0 & lvl_count %% 2 == 0),
    flights_single_lvl = sum(lvl_count == 1), lvl_rows = sum(lvl_count),
    compound_lvl_rows = sum(lvl_compound_count), .groups = "drop"
  )

lvl_events <- pilot |>
  filter(lvl_tag) |>
  arrange(SAM_ID, TIME_OVER) |>
  group_by(SAM_ID, flight_date) |>
  mutate(event_no = row_number(), next_time = lead(TIME_OVER), next_alt = lead(ALTITUDE_FT),
         pair_duration_sec = as.numeric(difftime(next_time, TIME_OVER, units = "secs")),
         pair_altitude_change_ft = next_alt - ALTITUDE_FT) |>
  ungroup()

lvl_pair_diagnostic <- lvl_events |>
  filter(event_no %% 2 == 1, !is.na(pair_duration_sec)) |>
  group_by(flight_date) |>
  summarise(
    naive_adjacent_pairs = n(), median_pair_duration_sec = median(pair_duration_sec),
    p05_pair_duration_sec = quantile(pair_duration_sec, .05),
    p95_pair_duration_sec = quantile(pair_duration_sec, .95),
    pairs_abs_altitude_change_gt_1000ft = sum(abs(pair_altitude_change_ft) > 1000),
    pairs_same_altitude = sum(pair_altitude_change_ft == 0), .groups = "drop"
  )

# Row-label summaries: retain both intentional fuel representations.
phase_summary <- pilot |>
  group_by(flight_date, FLIGHT_PHASE) |>
  summarise(rows = n(), flights = n_distinct(SAM_ID),
            fuel_adjusted_kg = sum(FUEL_BURNT_KG, na.rm = TRUE),
            fuel_original_kg = sum(FUEL_BURNT_KG_ORIGINAL, na.rm = TRUE),
            distance_nm = sum(DISTANCE_NM, na.rm = TRUE), .groups = "drop")

fir_summary <- pilot |>
  group_by(flight_date, FIR_ID) |>
  summarise(rows = n(), flights = n_distinct(SAM_ID),
            fuel_adjusted_kg = sum(FUEL_BURNT_KG, na.rm = TRUE),
            fuel_original_kg = sum(FUEL_BURNT_KG_ORIGINAL, na.rm = TRUE),
            distance_nm = sum(DISTANCE_NM, na.rm = TRUE), .groups = "drop")

# Compare assigning each row increment to the current versus preceding state.
# This is a sensitivity diagnostic, not a claim about source interval semantics.
phase_state_sensitivity <- pilot |>
  filter(!is.na(prev_phase)) |>
  group_by(flight_date) |>
  summarise(
    rows_with_preceding_phase = n(), phase_change_rows = sum(phase_change),
    fuel_adjusted_on_phase_change_kg = sum(FUEL_BURNT_KG[phase_change], na.rm = TRUE),
    fuel_original_on_phase_change_kg = sum(FUEL_BURNT_KG_ORIGINAL[phase_change], na.rm = TRUE),
    total_fuel_adjusted_kg = sum(FUEL_BURNT_KG, na.rm = TRUE),
    total_fuel_original_kg = sum(FUEL_BURNT_KG_ORIGINAL, na.rm = TRUE),
    distance_on_phase_change_nm = sum(DISTANCE_NM[phase_change], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(adjusted_fuel_share_on_phase_change = fuel_adjusted_on_phase_change_kg / total_fuel_adjusted_kg,
         original_fuel_share_on_phase_change = fuel_original_on_phase_change_kg / total_fuel_original_kg)

fir_state_sensitivity <- pilot |>
  filter(!is.na(prev_fir)) |>
  group_by(flight_date) |>
  summarise(
    rows_with_preceding_fir = n(), fir_change_rows = sum(fir_change),
    fir_change_rows_with_fir_tag = sum(fir_change & fir_tag),
    fir_tag_rows = sum(fir_tag),
    fuel_adjusted_on_fir_change_kg = sum(FUEL_BURNT_KG[fir_change], na.rm = TRUE),
    fuel_original_on_fir_change_kg = sum(FUEL_BURNT_KG_ORIGINAL[fir_change], na.rm = TRUE),
    total_fuel_adjusted_kg = sum(FUEL_BURNT_KG, na.rm = TRUE),
    total_fuel_original_kg = sum(FUEL_BURNT_KG_ORIGINAL, na.rm = TRUE),
    distance_on_fir_change_nm = sum(DISTANCE_NM[fir_change], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(adjusted_fuel_share_on_fir_change = fuel_adjusted_on_fir_change_kg / total_fuel_adjusted_kg,
         original_fuel_share_on_fir_change = fuel_original_on_fir_change_kg / total_fuel_original_kg,
         share_fir_changes_tagged_same_row = fir_change_rows_with_fir_tag / fir_change_rows)

# Exploratory point-to-point level candidates. Thresholds/gap caps are sensitivities,
# not canonical parameters. Intervals longer than the cap are excluded from candidates.
level_interval_sensitivity <- pilot |>
  filter(!is.na(dt_sec), dt_sec > 0, !is.na(vertical_rate_fpm)) |>
  tidyr::crossing(rate_limit_fpm = c(200, 300, 500), max_gap_min = c(5, 15, 30)) |>
  group_by(flight_date, rate_limit_fpm, max_gap_min) |>
  summarise(
    intervals_tested = n(), candidate_level_intervals = sum(vertical_rate_fpm <= rate_limit_fpm & dt_sec <= max_gap_min * 60),
    candidate_level_minutes = sum(dt_sec[vertical_rate_fpm <= rate_limit_fpm & dt_sec <= max_gap_min * 60]) / 60,
    intervals_over_gap_cap = sum(dt_sec > max_gap_min * 60),
    .groups = "drop"
  )

tables <- list(
  "daily-inventory.csv" = daily_inventory,
  "flight-lvl-inventory.csv" = lvl_by_flight,
  "naive-lvl-pair-diagnostic.csv" = lvl_pair_diagnostic,
  "phase-row-summary.csv" = phase_summary,
  "fir-row-summary.csv" = fir_summary,
  "phase-boundary-sensitivity.csv" = phase_state_sensitivity,
  "fir-boundary-sensitivity.csv" = fir_state_sensitivity,
  "level-interval-sensitivity.csv" = level_interval_sensitivity
)
for (name in names(tables)) readr::write_csv(tables[[name]], file.path(output_dir, name))

message("W1 G2G pilot assessment complete (read-only inputs).")
message("Dates: ", paste(pilot_dates, collapse = ", "))
message("Flights: ", n_distinct(pilot$SAM_ID), "; rows: ", nrow(pilot))
message("Outputs: ", normalizePath(output_dir))
