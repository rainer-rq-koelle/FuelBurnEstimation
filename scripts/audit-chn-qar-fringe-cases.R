# Targeted causal diagnostics against the unmodified packaged helper.
# Usage: Rscript scripts/audit-chn-qar-fringe-cases.R <restricted-run-directory>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
run <- normalizePath(args[[1]], mustWork = TRUE)
store <- normalizePath(Sys.getenv("FUELBURN_DATA_STORE", ".fuelburn-data-store"), mustWork = TRUE)
stopifnot(startsWith(run, paste0(store, "/")))
suppressPackageStartupMessages({library(dplyr); library(readr); library(purrr)})
reference <- list.files(file.path(run, "helper-reference"), "^canonical-fuel-milestones[.]R$", recursive = TRUE, full.names = TRUE)
stopifnot(length(reference) == 1L)
source(reference)
out <- file.path(run, "evidence")
cases <- read_csv(file.path(run, "requested-cases.csv"), col_types = cols(.default = "c"))
controls <- read_csv(file.path(run, "control-cases.csv"), col_types = cols(.default = "c"))
metrics <- read_csv(file.path(out, "case-metrics.csv"), show_col_types = FALSE)
airport <- tibble(ICAO = c("ZBAA", "ZSSS", "ZLXY", "ZGGG", "ZPPP"),
                  LAT = c(40.0801, 31.1979, 34.4471, 23.3924, 24.9928),
                  LON = c(116.5846, 121.3364, 108.7514, 113.2988, 102.7412))

# A non-empty set of short candidate runs is distinct from no candidates at all.
synthetic <- map_dfr(list(list("below_altitude_gate", 2000, 6L),
                         list("all_candidates_shorter_than_10s", 5000, 6L),
                         list("retained_20s_level", 5000, 21L)), function(test) {
  n <- test[[3]]
  tr <- tibble(SOURCE_UID = "synthetic", TIME = as.POSIXct("2025-01-01", tz = "UTC") + seq_len(n) - 1,
               ALT_FT = rep(test[[2]], n), DIST_FLOWN_NM = seq_len(n) / 10, TOT_FUEL_KG = seq_len(n))
  err <- NA_character_
  seg <- tryCatch(fuel_level_segment_candidates(tr), error = function(e) {err <<- conditionMessage(e); NULL})
  tibble(test = test[[1]], points = n, elapsed_sec = n - 1L,
         result_rows = if (is.null(seg)) NA_integer_ else nrow(seg), error = err)
})
stopifnot(synthetic$result_rows[1] == 0L, !is.na(synthetic$error[2]), synthetic$result_rows[3] == 1L)
write_csv(synthetic, file.path(out, "synthetic-level-reproduction.csv"))

# Hold source altitude, phase codes, fuel and clock fixed. A speed-derived path
# is a diagnostic intervention only, not an adopted source correction.
zero_path <- map_dfr(cases$SOURCE_UID, function(uid) {
  met <- metrics |> filter(SOURCE_UID == uid)
  if (met$zero_coordinate_rows != met$rows) return(tibble())
  cc <- cases |> filter(SOURCE_UID == uid)
  tr <- fuel_read_chn_qar_csv(cc$path, fuel_flow_unit = "auto")
  before <- fuel_chn_milestones(tr, airport)
  trial <- tr
  trial$DISTANCE_NM <- trial$GS * trial$DT_SEC / 3600
  trial$DIST_FLOWN_NM <- cumsum(trial$DISTANCE_NM)
  after <- fuel_chn_milestones(trial, airport)
  tibble(case = cc$case, SOURCE_UID = uid, source_phase12_rows = sum(tr$FLIGHT_PHASE_RAW == "12", na.rm = TRUE),
         original_path_nm = max(tr$DIST_FLOWN_NM), intervention_path_nm = max(trial$DIST_FLOWN_NM),
         original_ALTO = "ALTO" %in% before$MST, original_ALDT = "ALDT" %in% before$MST,
         intervention_ALTO = "ALTO" %in% after$MST, intervention_ALDT = "ALDT" %in% after$MST,
         interpretation = "Distance-only intervention; assumes GS in knots; no canonical release generated")
})
stopifnot(nrow(zero_path) == 2L, all(!zero_path$original_ALDT), all(zero_path$intervention_ALDT))
write_csv(zero_path, file.path(out, "zero-distance-landing-intervention.csv"))

# Observe source support for landing without manufacturing a new ALDT timestamp.
landing <- map_dfr(cases$SOURCE_UID, function(uid) {
  cc <- cases |> filter(SOURCE_UID == uid)
  tr <- suppressWarnings(fuel_read_chn_qar_csv(cc$path, fuel_flow_unit = "auto"))
  p12 <- which(tr$FLIGHT_PHASE_RAW == "12")
  atot <- which(tr$FLIGHT_PHASE_RAW %in% as.character(6:12))[1]
  valid_alt <- is.finite(tr$ALT_FT)
  after_mid <- seq_len(nrow(tr)) > atot & tr$DIST_FLOWN_NM > median(tr$DIST_FLOWN_NM)
  tibble(case = cc$case, SOURCE_UID = uid, phase12_rows = length(p12),
         phase12_min_pressure_alt_ft = if (any(valid_alt[p12])) min(tr$ALT_FT[p12], na.rm = TRUE) else NA_real_,
         phase12_max_pressure_alt_ft = if (any(valid_alt[p12])) max(tr$ALT_FT[p12], na.rm = TRUE) else NA_real_,
         ALTO_eligible_rows = sum(after_mid & tr$ALT_FT <= 3000, na.rm = TRUE),
         final_pressure_alt_ft = tail(tr$ALT_FT, 1), final_gs = tail(tr$GS, 1),
         missing_altitude_rows = sum(!valid_alt), source_rows = nrow(tr))
})
write_csv(landing, file.path(out, "landing-source-support.csv"))

ordering <- map_dfr(cases$case, function(case_id) {
  ms <- read_csv(file.path(out, paste0("case-", case_id, "-event-selection.csv")), show_col_types = FALSE)
  row <- function(mst) {x <- ms$ROW_ID[ms$MST == mst]; if (length(x)) x[1] else NA_integer_}
  tibble(case = case_id, ATOT = row("ATOT"), DLTO = row("DLTO"), TOC = row("TOC"), TOD = row("TOD"),
         ALTO = row("ALTO"), ALDT = row("ALDT"), toc_equals_tod = !is.na(row("TOC")) && row("TOC") == row("TOD"),
         approach_before_cruise_end = !is.na(row("ALTO")) && !is.na(row("TOD")) && row("ALTO") < row("TOD"))
})
write_csv(ordering, file.path(out, "milestone-order-evidence.csv"))

# Configuration sensitivity outside the packaged study airport list. The added
# coordinates come from the existing local legacy airport-reference code; this
# diagnostic table does not alter that file or the bundled configuration.
airport_legacy <- bind_rows(airport, tibble(ICAO = "ZSPD", LAT = 31.1434, LON = 121.8052))
old <- read_csv(file.path(run, "provenance/historical-modern-canonical.csv"), show_col_types = FALSE)
config <- map_dfr(controls$SOURCE_UID[controls$role == "representative_control"], function(uid) {
  cc <- controls |> filter(SOURCE_UID == uid)
  tr <- fuel_read_chn_qar_csv(cc$path, fuel_flow_unit = "auto")
  before <- fuel_chn_milestones(tr, airport)
  after <- fuel_chn_milestones(tr, airport_legacy)
  previous <- old |> filter(SOURCE_UID == uid, MST == "TOD")
  tibble(case = cc$case, SOURCE_UID = uid,
         missing_airport_metadata = !all(c(first(tr$ADEP), first(tr$ADES)) %in% airport$ICAO),
         packaged_TOD_row = before$ROW_ID[before$MST == "TOD"],
         legacy_airport_config_TOD_row = after$ROW_ID[after$MST == "TOD"], historical_TOD_row = previous$ROW_ID,
         interpretation = "Added legacy airport metadata in memory only; no helper or canonical release changed")
})
write_csv(config, file.path(out, "airport-configuration-sensitivity.csv"))

# A three-sample integration fixture makes the boundary shift observable without
# any restricted source values. The helper stores outgoing increments at rows.
flow <- c(1000, 2000, 3000); dt <- c(1, 1, 0); leg <- c(1, 2, 0)
ms <- tibble(SOURCE_UID = "synthetic", FLTID = "synthetic", ADEP = "TEST", ADES = "TEST", TYPE = "TEST",
             MST = c("AOBT", "ERWY", "ATOT"), ROW_ID = 1:3,
             TIME = as.POSIXct("2025-01-01", tz = "UTC") + 0:2,
             TOT_FUEL_KG = cumsum(flow * dt / 3600), TOT_FUEL_KG_ORIGINAL = cumsum(flow * dt / 3600),
             DIST_FLOWN_NM = cumsum(leg))
res <- fuel_phase_summaries(ms) |> filter(PHASE == "TAXI_OUT")
stopifnot(abs(res$FUEL_KG - 2000/3600) < 1e-12, res$DISTANCE_NM == 2)
write_csv(tibble(test = "outgoing_increment_at_snapshot_timestamp", interval_sec = 1,
                 expected_fuel_kg = 1000/3600, observed_fuel_kg = res$FUEL_KG,
                 expected_distance_nm = 1, observed_distance_nm = res$DISTANCE_NM),
          file.path(out, "synthetic-integration-boundary-reproduction.csv"))

# Inspect legacy clocks independently. This does not choose or rewrite source
# timestamps. In legacy files the second clock advances about once per four rows.
clock <- read_csv(file.path(out, "clock-candidate-evidence.csv"), show_col_types = FALSE)
legacy_clock <- clock |> filter(case %in% controls$case[controls$role == "historical_compatibility"])
write_csv(legacy_clock, file.path(out, "legacy-clock-reproduction.csv"))
print(tibble(synthetic_checks = nrow(synthetic) + 1L, zero_path_interventions = nrow(zero_path),
             landing_sources_checked = nrow(landing), legacy_clock_candidates = nrow(legacy_clock)))
