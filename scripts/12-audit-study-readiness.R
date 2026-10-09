#!/usr/bin/env Rscript
# Read-only audit of the local release. Writes aggregate diagnostics only;
# never repairs, uploads, or changes a production artifact.
suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(here)
})

store <- Sys.getenv("FUELBURN_DATA_STORE", unset = here(".fuelburn-data-store"))
audit_dir <- here("outputs", "study-design")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
manifest <- read_csv(file.path(store, "manifest", "current-artifacts.csv"),
                     show_col_types = FALSE)
release_audit <- manifest |>
  mutate(local_exists = file.exists(file.path(store, key)),
         local_sha256 = vapply(file.path(store, key), function(p) {
           if (!file.exists(p)) return(NA_character_)
           digest::digest(file = p, algo = "sha256")
         }, character(1)),
         hash_matches = local_exists & !is.na(local_sha256) & local_sha256 == sha256) |>
  select(key, required, version, local_exists, hash_matches)
write_csv(release_audit, file.path(audit_dir, "release-integrity.csv"))
if (any(release_audit$required & !release_audit$hash_matches)) {
  stop("A required artifact is absent or differs from the manifest; inspect release-integrity.csv.")
}

type_map <- c("A320-NEO" = "A20N", "A321-NEO" = "A21N",
              "A330-200" = "A332", "A330-300" = "A333",
              "A350-900" = "A359", "B737-700" = "B737",
              "B737-800" = "B738", "B777-300ER" = "B77W",
              "B787-9" = "B789")
# B737-MAX is deliberately unresolved: the variant cannot be assumed.
normalise_type <- function(x) {
  result <- unname(type_map[x])
  ifelse(is.na(result), x, result)
}
safe_median <- function(x) if (any(is.finite(x))) median(x[is.finite(x)]) else NA_real_
time_union <- function(start, end) {
  ok <- is.finite(start) & is.finite(end) & end > start
  start <- start[ok]; end <- end[ok]
  if (!length(start)) return(0)
  ord <- order(start, end); start <- start[ord]; end <- end[ord]
  previous_end <- c(-Inf, head(cummax(end), -1))
  sum(pmax(0, end - pmax(start, previous_end)))
}

audit_summaries <- list(); flight_tables <- list(); segment_tables <- list()
schema_tables <- list(); event_tables <- list()
for (region in c("EUR", "CHN")) {
  load_product <- function(kind) read_parquet(file.path(
    store, "processed", tolower(region), paste0(region, "-", kind, "-summer2025.parquet")))
  mst <- load_product("canonical-milestones")
  seg <- load_product("level-segments")
  schema_tables[[region]] <- bind_rows(
    tibble(REGION = region, product = "milestones", field = names(mst)),
    tibble(REGION = region, product = "level_segments", field = names(seg)))
  event_tables[[region]] <- mst |> count(MST, name = "rows") |> mutate(REGION = region)

  # Use epoch seconds for durations; timezone labels are recorded separately.
  flight <- mst |>
    group_by(SOURCE_UID) |>
    summarise(TYPE = first(TYPE), ADEP = first(ADEP), ADES = first(ADES),
              first_time = min(as.numeric(TIME)), last_time = max(as.numeric(TIME)),
              TOTAL_FLOWN_NM = safe_median(TOTAL_FLOWN_NM),
              .groups = "drop") |>
    mutate(REGION = region, ICAO_TYPE = normalise_type(TYPE))
  events <- mst |>
    filter(MST %in% c("ATOT", "TOC", "TOD", "ALDT")) |>
    group_by(SOURCE_UID, MST) |>
    summarise(n_event = n(), event_time = if (n() == 1) as.numeric(TIME) else NA_real_,
              event_fuel = if (n() == 1) TOT_FUEL_KG else NA_real_,
              event_dist = if (n() == 1) DIST_FLOWN_NM else NA_real_, .groups = "drop") |>
    pivot_wider(names_from = MST, values_from = c(n_event, event_time, event_fuel, event_dist))
  flight <- left_join(flight, events, by = "SOURCE_UID") |>
    mutate(ordered_airborne = event_time_ATOT < event_time_TOC &
             event_time_TOC < event_time_TOD & event_time_TOD < event_time_ALDT,
           enroute_min = (event_time_TOD - event_time_TOC) / 60,
           enroute_nm = event_dist_TOD - event_dist_TOC,
           enroute_kg = event_fuel_TOD - event_fuel_TOC,
           enroute_implied_kt = enroute_nm / enroute_min * 60)
  flight_tables[[region]] <- flight

  seg_id <- if (region == "EUR") seg$SEGMENT_ID else seg$LEVEL_SEGMENT_ID
  seg_fuel <- if (region == "EUR") seg$FUEL_BURN_KG else seg$FUEL_KG
  seg_dist <- if ("DISTANCE_NM" %in% names(seg)) seg$DISTANCE_NM else rep(NA_real_, nrow(seg))
  timing <- tibble(SOURCE_UID = seg$SOURCE_UID, start = as.numeric(seg$START_TIME),
                   end = as.numeric(seg$END_TIME)) |>
    group_by(SOURCE_UID) |>
    summarise(sum_sec = sum(pmax(0, end - start), na.rm = TRUE),
              union_sec = time_union(start, end), .groups = "drop")
  ids <- tibble(SOURCE_UID = seg$SOURCE_UID, segment_id = seg_id) |> count(SOURCE_UID, segment_id)
  alt_change <- abs(seg$END_ALT_FT - seg$START_ALT_FT)
  implied_kt <- seg_dist / seg$DURATION_SEC * 3600
  # 700 kt is a deliberately broad diagnostic screen, not a validated exclusion rule.
  audit_summaries[[region]] <- tibble(
    REGION = region,
    flights = nrow(flight), milestone_rows = nrow(mst), milestone_columns = ncol(mst),
    segment_rows = nrow(seg), segment_columns = ncol(seg),
    distinct_segment_keys = nrow(ids), repeated_segment_keys = sum(ids$n > 1),
    extra_rows_for_repeated_keys = sum(ids$n - 1),
    flights_with_overlapping_intervals = sum(timing$sum_sec > timing$union_sec + 0.01),
    summed_interval_hours = sum(timing$sum_sec) / 3600,
    union_interval_hours = sum(timing$union_sec) / 3600,
    intervals_alt_change_over_1000ft = sum(alt_change > 1000, na.rm = TRUE),
    intervals_missing_alt = sum(!is.finite(alt_change)),
    intervals_missing_fuel = sum(!is.finite(seg_fuel)),
    intervals_negative_fuel = sum(seg_fuel < 0, na.rm = TRUE),
    intervals_without_positive_duration = sum(!is.finite(seg$DURATION_SEC) | seg$DURATION_SEC <= 0),
    interval_duration_disagrees_with_times = sum(abs(seg$DURATION_SEC -
      as.numeric(difftime(seg$END_TIME, seg$START_TIME, units = "secs"))) > 0.01, na.rm = TRUE),
    intervals_with_distance = sum(is.finite(seg_dist)),
    intervals_implied_speed_over_700kt = if (any(is.finite(implied_kt))) {
      sum(implied_kt > 700 & is.finite(implied_kt))
    } else NA_integer_,
    median_interval_implied_kt = safe_median(implied_kt),
    flights_missing_unique_ATOT = sum(is.na(flight$n_event_ATOT) | flight$n_event_ATOT != 1),
    flights_missing_unique_ALDT = sum(is.na(flight$n_event_ALDT) | flight$n_event_ALDT != 1),
    flights_missing_unique_TOC_TOD = sum(is.na(flight$n_event_TOC) | is.na(flight$n_event_TOD) |
      flight$n_event_TOC != 1 | flight$n_event_TOD != 1),
    flights_strictly_ordered_airborne = sum(flight$ordered_airborne, na.rm = TRUE),
    median_total_flown_nm = safe_median(flight$TOTAL_FLOWN_NM),
    median_enroute_implied_kt = safe_median(flight$enroute_implied_kt),
    flights_enroute_speed_over_700kt = sum(flight$enroute_implied_kt > 700 &
      is.finite(flight$enroute_implied_kt)),
    time_zone_attribute = paste(attr(mst$TIME, "tzone"), collapse = ";"))
  segment_tables[[region]] <- tibble(REGION = region,
    LEVEL_CONTEXT_PHASE = seg$LEVEL_CONTEXT_PHASE,
    START_PHASE = if ("START_PHASE" %in% names(seg)) seg$START_PHASE else NA_character_) |>
    count(REGION, LEVEL_CONTEXT_PHASE, START_PHASE, name = "rows")
}
study_readiness <- bind_rows(audit_summaries)
write_csv(study_readiness, file.path(audit_dir, "study-readiness.csv"))
write_csv(bind_rows(schema_tables), file.path(audit_dir, "actual-schema.csv"))
write_csv(bind_rows(event_tables), file.path(audit_dir, "milestone-coverage.csv"))
write_csv(bind_rows(segment_tables), file.path(audit_dir, "phase-label-provenance.csv"))
type_support <- bind_rows(flight_tables) |>
  count(REGION, ICAO_TYPE, name = "flights") |>
  pivot_wider(names_from = REGION, values_from = flights, values_fill = 0) |>
  arrange(desc(pmin(EUR, CHN)))
write_csv(type_support, file.path(audit_dir, "aircraft-common-support.csv"))
routes <- bind_rows(flight_tables) |> count(REGION, ADEP, ADES, name = "flights")
write_csv(routes, file.path(audit_dir, "route-coverage.csv"))
print(study_readiness, width = Inf)
message("Aggregate diagnostics written to ", audit_dir)
