#!/usr/bin/env Rscript
# Audit EUR canonical milestones against the enriched 2026 convention.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(here)
  library(readr)
  library(stringr)
  library(tidyr)
})

source(here("R", "eur-level-segments.R"))

message("Auditing EUR canonical milestones...")
message("Working directory: ", here())

data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = "")
default_eur_file <- if (data_store != "") {
  expanded_file <- file.path(path.expand(data_store), "raw/eur/EUR-canonical-milestones-expanded-summer2025.parquet")
  compact_file <- file.path(path.expand(data_store), "raw/eur/EUR-canonical-milestones-summer2025.parquet")
  if (file.exists(expanded_file)) expanded_file else compact_file
} else {
  here("data-derived", "canonical-milestones-eur-2025-summer.parquet")
}

eur_file <- Sys.getenv(
  "FUELBURN_EUR_CANONICAL_MILESTONES",
  unset = default_eur_file
)

audit_dir <- Sys.getenv(
  "FUELBURN_EUR_MILESTONE_AUDIT_DIR",
  unset = here("data-derived", "eur-canonical-milestone-audit")
)

if (!file.exists(eur_file)) {
  stop(
    "Canonical file not found: ", eur_file, "\n",
    "Set FUELBURN_EUR_CANONICAL_MILESTONES to the local EUR canonical parquet, ",
    "or place a local copy at data-derived/canonical-milestones-eur-2025-summer.parquet.",
    call. = FALSE
  )
}

dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

eur <- arrow::read_parquet(eur_file) |>
  as_tibble()

pick_col <- function(data, candidates, required = TRUE) {
  out <- candidates[candidates %in% names(data)][1]
  if (is.na(out) && required) {
    stop(
      "Missing required column. Expected one of: ",
      paste(candidates, collapse = ", "),
      call. = FALSE
    )
  }
  out
}

uid_col <- pick_col(eur, c("SOURCE_UID", "UID"))
mst_col <- pick_col(eur, c("MST", "milestone"))
time_col <- pick_col(eur, c("TIME", "timestamp"), required = FALSE)
row_col <- pick_col(eur, c("ROW_ID", "row_id"), required = FALSE)
alt_col <- pick_col(eur, c("ALT_FT", "ALT", "altitude_ft"), required = FALSE)
dist_col <- pick_col(eur, c("DIST_FLOWN_NM", "DIST_FLOWN", "distance_flown_nm"), required = FALSE)
phase_col <- pick_col(eur, c("FLIGHT_PHASE_RAW", "PHASE", "phase"), required = FALSE)
fuel_col <- pick_col(eur, c("TOT_FUEL_KG", "TOT_FUEL"), required = FALSE)

required_for_derivation <- c(dist_col, alt_col, time_col, row_col)

message("\nInput file: ", eur_file)
message("Output directory: ", audit_dir)
message("Rows: ", nrow(eur))
message("Flights: ", dplyr::n_distinct(eur[[uid_col]]))
message("UID column: ", uid_col)
message("Milestone column: ", mst_col)
message("Distance column: ", ifelse(is.na(dist_col), "<missing>", dist_col))
message("Altitude column: ", ifelse(is.na(alt_col), "<missing>", alt_col))
message("Phase column: ", ifelse(is.na(phase_col), "<missing>", phase_col))
message("Fuel column: ", ifelse(is.na(fuel_col), "<missing>", fuel_col))

label_counts <- eur |>
  count(MST = .data[[mst_col]], sort = TRUE)

readr::write_csv(label_counts, file.path(audit_dir, "milestone-label-counts.csv"))

phase_values <- if (!is.na(phase_col)) eur[[phase_col]] else rep(NA_character_, nrow(eur))

raw_token_counts <- eur |>
  mutate(MST_RAW_TOKEN = .data[[mst_col]]) |>
  tidyr::separate_longer_delim(MST_RAW_TOKEN, delim = "/") |>
  count(MST_RAW_TOKEN, sort = TRUE)

token_counts <- eur |>
  mutate(MST_CANONICAL_TOKEN = canonicalize_eur_milestone_tokens(.data[[mst_col]], phase_values)) |>
  tidyr::separate_longer_delim(MST_CANONICAL_TOKEN, delim = "/") |>
  count(MST_CANONICAL_TOKEN, sort = TRUE)

readr::write_csv(raw_token_counts, file.path(audit_dir, "milestone-token-counts-raw.csv"))
readr::write_csv(token_counts, file.path(audit_dir, "milestone-token-counts-canonicalized.csv"))

target_labels <- tibble::tribble(
  ~source_label, ~canonical_label, ~family, ~recommended_action,
  "D40", "D040", "distance", "rename existing label",
  "A40", "A040", "distance", "rename existing label",
  "D100", "D100", "distance", "keep existing label",
  "A100", "A100", "distance", "keep existing label",
  "D200", "D200", "distance", "derive if distance coverage supports it",
  "A200", "A200", "distance", "derive if distance coverage supports it",
  "FL100", "D_FL100/A_FL100", "flight_level", "inspect phase context before direction-aware mapping",
  "D_FL075", "D_FL075", "flight_level", "derive first upward crossing",
  "D_FL100", "D_FL100", "flight_level", "derive first upward crossing",
  "D_FL180", "D_FL180", "flight_level", "derive first upward crossing",
  "A_FL180", "A_FL180", "flight_level", "derive last downward crossing",
  "A_FL100", "A_FL100", "flight_level", "derive last downward crossing",
  "A_FL075", "A_FL075", "flight_level", "derive last downward crossing",
  "LVL", "LVL_START/LVL_END", "level_segment", "reconstruct paired level segment boundaries",
  "LVL_START", "LVL_START", "level_segment", "keep if already present",
  "LVL_END", "LVL_END", "level_segment", "keep if already present"
)

label_audit <- target_labels |>
  left_join(raw_token_counts, by = c("source_label" = "MST_RAW_TOKEN")) |>
  rename(source_n = n) |>
  mutate(canonical_lookup_label = if_else(str_detect(.data$canonical_label, "/"), NA_character_, .data$canonical_label)) |>
  left_join(token_counts, by = c("canonical_lookup_label" = "MST_CANONICAL_TOKEN")) |>
  rename(canonical_token_n = n) |>
  mutate(
    source_n = tidyr::replace_na(.data$source_n, 0L),
    canonical_token_n = tidyr::replace_na(.data$canonical_token_n, 0L),
    source_present = .data$source_n > 0,
    canonical_token_present = .data$canonical_token_n > 0
  ) |>
  select(-canonical_lookup_label) |>
  arrange(family, source_label)

readr::write_csv(label_audit, file.path(audit_dir, "milestone-convention-audit.csv"))

message("\nMilestone convention audit:")
print(label_audit, n = Inf)

if (!is.na(phase_col)) {
  fl100_phase_context <- eur |>
    filter(has_milestone_token(.data[[mst_col]], "FL100")) |>
    mutate(
      inferred_direction = case_when(
        str_detect(str_to_lower(.data[[phase_col]]), "climb") ~ "candidate_D_FL100",
        str_detect(str_to_lower(.data[[phase_col]]), "descent|approach") ~ "candidate_A_FL100",
        TRUE ~ "review"
      )
    ) |>
    count(
      phase = .data[[phase_col]],
      inferred_direction,
      sort = TRUE
    )
} else {
  fl100_phase_context <- tibble(
    phase = character(),
    inferred_direction = character(),
    n = integer()
  )
}

readr::write_csv(fl100_phase_context, file.path(audit_dir, "fl100-phase-context.csv"))

order_cols <- c(uid_col, row_col, time_col)
order_cols <- order_cols[!is.na(order_cols)]

eur_ordered <- eur |>
  arrange(across(all_of(order_cols))) |>
  group_by(.data[[uid_col]]) |>
  mutate(
    .row_in_flight = row_number(),
    .prev_dist = if (!is.na(dist_col)) lag(.data[[dist_col]]) else NA_real_,
    .prev_alt = if (!is.na(alt_col)) lag(.data[[alt_col]]) else NA_real_
  ) |>
  ungroup()

if (!is.na(dist_col)) {
  distance_by_flight <- eur_ordered |>
    group_by(.data[[uid_col]]) |>
    summarise(
      n_points = n(),
      dist_first_nm = first(.data[[dist_col]]),
      dist_last_nm = last(.data[[dist_col]]),
      dist_min_nm = suppressWarnings(min(.data[[dist_col]], na.rm = TRUE)),
      dist_max_nm = suppressWarnings(max(.data[[dist_col]], na.rm = TRUE)),
      dist_monotonic_violations = sum(
        !is.na(.prev_dist) & !is.na(.data[[dist_col]]) &
          (.data[[dist_col]] - .prev_dist) < -0.1
      ),
      .groups = "drop"
    ) |>
    mutate(
      total_flown_nm = dist_max_nm,
      can_derive_D040 = dist_max_nm >= 40,
      can_derive_D100 = dist_max_nm >= 100,
      can_derive_D200 = dist_max_nm >= 200,
      can_derive_A040 = total_flown_nm >= 40,
      can_derive_A100 = total_flown_nm >= 100,
      can_derive_A200 = total_flown_nm >= 200,
      distance_ok = dist_monotonic_violations == 0 & is.finite(total_flown_nm)
    )
} else {
  distance_by_flight <- tibble()
}

readr::write_csv(distance_by_flight, file.path(audit_dir, "distance-derivability-by-flight.csv"))

distance_summary <- if (nrow(distance_by_flight) > 0) {
  distance_by_flight |>
    summarise(
      flights = n(),
      flights_distance_ok = sum(distance_ok, na.rm = TRUE),
      flights_with_monotonic_violations = sum(dist_monotonic_violations > 0, na.rm = TRUE),
      can_derive_D040 = sum(can_derive_D040 & distance_ok, na.rm = TRUE),
      can_derive_D100 = sum(can_derive_D100 & distance_ok, na.rm = TRUE),
      can_derive_D200 = sum(can_derive_D200 & distance_ok, na.rm = TRUE),
      can_derive_A040 = sum(can_derive_A040 & distance_ok, na.rm = TRUE),
      can_derive_A100 = sum(can_derive_A100 & distance_ok, na.rm = TRUE),
      can_derive_A200 = sum(can_derive_A200 & distance_ok, na.rm = TRUE),
      median_total_flown_nm = median(total_flown_nm, na.rm = TRUE),
      max_total_flown_nm = max(total_flown_nm, na.rm = TRUE)
    )
} else {
  tibble(note = "No distance column available.")
}

readr::write_csv(distance_summary, file.path(audit_dir, "distance-derivability-summary.csv"))

message("\nDistance derivability summary:")
print(distance_summary)

if (!is.na(alt_col)) {
  fl_thresholds <- c(75, 100, 180) * 100

  flight_level_by_flight <- eur_ordered |>
    group_by(.data[[uid_col]]) |>
    summarise(
      n_points = n(),
      alt_min_ft = suppressWarnings(min(.data[[alt_col]], na.rm = TRUE)),
      alt_max_ft = suppressWarnings(max(.data[[alt_col]], na.rm = TRUE)),
      D_FL075 = any(!is.na(.prev_alt) & .prev_alt < fl_thresholds[1] & .data[[alt_col]] >= fl_thresholds[1], na.rm = TRUE),
      D_FL100 = any(!is.na(.prev_alt) & .prev_alt < fl_thresholds[2] & .data[[alt_col]] >= fl_thresholds[2], na.rm = TRUE),
      D_FL180 = any(!is.na(.prev_alt) & .prev_alt < fl_thresholds[3] & .data[[alt_col]] >= fl_thresholds[3], na.rm = TRUE),
      A_FL180 = any(!is.na(.prev_alt) & .prev_alt > fl_thresholds[3] & .data[[alt_col]] <= fl_thresholds[3], na.rm = TRUE),
      A_FL100 = any(!is.na(.prev_alt) & .prev_alt > fl_thresholds[2] & .data[[alt_col]] <= fl_thresholds[2], na.rm = TRUE),
      A_FL075 = any(!is.na(.prev_alt) & .prev_alt > fl_thresholds[1] & .data[[alt_col]] <= fl_thresholds[1], na.rm = TRUE),
      .groups = "drop"
    )
} else {
  flight_level_by_flight <- tibble()
}

readr::write_csv(flight_level_by_flight, file.path(audit_dir, "flight-level-derivability-by-flight.csv"))

flight_level_summary <- if (nrow(flight_level_by_flight) > 0) {
  flight_level_by_flight |>
    summarise(
      flights = n(),
      reaches_FL075 = sum(alt_max_ft >= 7500, na.rm = TRUE),
      reaches_FL100 = sum(alt_max_ft >= 10000, na.rm = TRUE),
      reaches_FL180 = sum(alt_max_ft >= 18000, na.rm = TRUE),
      can_derive_D_FL075 = sum(D_FL075, na.rm = TRUE),
      can_derive_D_FL100 = sum(D_FL100, na.rm = TRUE),
      can_derive_D_FL180 = sum(D_FL180, na.rm = TRUE),
      can_derive_A_FL180 = sum(A_FL180, na.rm = TRUE),
      can_derive_A_FL100 = sum(A_FL100, na.rm = TRUE),
      can_derive_A_FL075 = sum(A_FL075, na.rm = TRUE),
      median_alt_max_ft = median(alt_max_ft, na.rm = TRUE),
      max_alt_ft = max(alt_max_ft, na.rm = TRUE)
    )
} else {
  tibble(note = "No altitude column available.")
}

readr::write_csv(flight_level_summary, file.path(audit_dir, "flight-level-derivability-summary.csv"))

message("\nFlight-level derivability summary:")
print(flight_level_summary)

level_phase_context <- if (!is.na(phase_col)) {
  eur |>
    filter(has_milestone_token(.data[[mst_col]], "LVL")) |>
    count(phase = .data[[phase_col]], sort = TRUE)
} else {
  tibble(note = "No phase column available.")
}

readr::write_csv(level_phase_context, file.path(audit_dir, "level-phase-context.csv"))

manifest <- tibble::tibble(
  item = c(
    "input_file",
    "audit_dir",
    "n_rows",
    "n_flights",
    "uid_col",
    "mst_col",
    "time_col",
    "row_col",
    "alt_col",
    "dist_col",
    "phase_col",
    "fuel_col"
  ),
  value = c(
    eur_file,
    audit_dir,
    as.character(nrow(eur)),
    as.character(dplyr::n_distinct(eur[[uid_col]])),
    uid_col,
    mst_col,
    ifelse(is.na(time_col), "", time_col),
    ifelse(is.na(row_col), "", row_col),
    ifelse(is.na(alt_col), "", alt_col),
    ifelse(is.na(dist_col), "", dist_col),
    ifelse(is.na(phase_col), "", phase_col),
    ifelse(is.na(fuel_col), "", fuel_col)
  )
)

readr::write_csv(manifest, file.path(audit_dir, "audit-manifest.csv"))

message("\nWrote audit files:")
for (path in sort(list.files(audit_dir, pattern = "\\.csv$", full.names = TRUE))) {
  message("  ", path)
}

message("\nEUR canonical milestone audit complete.")
