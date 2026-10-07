#!/usr/bin/env Rscript
# Test EUR canonical milestone import in FuelBurnEstimation environment

library(arrow)
library(dplyr)
library(here)

message("Testing EUR canonical milestone import...")
message("Working directory: ", here())

# Read canonical EUR data from a local, machine-specific path.
# Prefer an explicit environment variable so Windows/macOS/Linux machines can
# keep restricted data outside Git and still run the same script.
eur_file <- Sys.getenv(
  "FUELBURN_EUR_CANONICAL_MILESTONES",
  unset = here("data-derived", "canonical-milestones-eur-2025-summer.parquet")
)

if (!file.exists(eur_file)) {
  stop(
    "Canonical file not found: ", eur_file, "\n",
    "Set FUELBURN_EUR_CANONICAL_MILESTONES to the local EUR canonical parquet, ",
    "or place a local copy at data-derived/canonical-milestones-eur-2025-summer.parquet.",
    call. = FALSE
  )
}

message("\nFile found: ", eur_file)
message("Size: ", round(file.info(eur_file)$size / 1024^2, 1), " MB")

# Read data
eur <- read_parquet(eur_file)

uid_col <- dplyr::case_when(
  "UID" %in% names(eur) ~ "UID",
  "SOURCE_UID" %in% names(eur) ~ "SOURCE_UID",
  TRUE ~ NA_character_
)

fuel_col <- dplyr::case_when(
  "TOT_FUEL" %in% names(eur) ~ "TOT_FUEL",
  "TOT_FUEL_KG" %in% names(eur) ~ "TOT_FUEL_KG",
  TRUE ~ NA_character_
)

missing_required <- c(
  if (is.na(uid_col)) "UID or SOURCE_UID",
  if (is.na(fuel_col)) "TOT_FUEL or TOT_FUEL_KG",
  setdiff(c("TYPE", "ADEP", "ADES"), names(eur))
)

if (length(missing_required) > 0) {
  stop(
    "EUR canonical file is missing required columns: ",
    paste(missing_required, collapse = ", "),
    call. = FALSE
  )
}

n_flights <- dplyr::n_distinct(eur[[uid_col]])

message("\nEUR Canonical Milestones (Summer 2025):")
message("  Flight id column: ", uid_col)
message("  Fuel column: ", fuel_col)
message("  Flights: ", n_flights)
message("  Milestone events: ", nrow(eur))
message("  Avg milestones/flight: ", round(nrow(eur) / n_flights, 1))

message("\nAircraft types:")
print(table(eur$TYPE) %>% sort(decreasing = TRUE) %>% head(10))

message("\nRoutes (top 10):")
routes <- eur %>%
  distinct(.data[[uid_col]], ADEP, ADES) %>%
  count(ADEP, ADES, sort = TRUE) %>%
  head(10)
print(routes)

message("\nFuel burn summary:")
fuel_summary <- eur %>%
  group_by(.data[[uid_col]]) %>%
  slice_max(.data[[fuel_col]], n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  summarise(
    min_fuel = min(.data[[fuel_col]], na.rm = TRUE),
    median_fuel = median(.data[[fuel_col]], na.rm = TRUE),
    mean_fuel = mean(.data[[fuel_col]], na.rm = TRUE),
    max_fuel = max(.data[[fuel_col]], na.rm = TRUE)
  )
print(fuel_summary)

message("\nEUR canonical data successfully imported!")
message("Ready for profile classification and lookup table generation.")
