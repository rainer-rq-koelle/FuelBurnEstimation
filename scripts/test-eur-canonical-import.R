#!/usr/bin/env Rscript
# Test EUR canonical milestone import in FuelBurnEstimation environment

library(arrow)
library(dplyr)
library(here)

message("Testing EUR canonical milestone import...")
message("Working directory: ", here())

# Read canonical EUR data (platform-agnostic path!)
eur_file <- here("data-derived", "canonical-milestones-eur-2025-summer.parquet")

if (!file.exists(eur_file)) {
  stop("Canonical file not found: ", eur_file)
}

message("\n✅ File found: ", eur_file)
message("Size: ", round(file.info(eur_file)$size / 1024^2, 1), " MB")

# Read data
eur <- read_parquet(eur_file)

message("\n📊 EUR Canonical Milestones (Summer 2025):")
message("  Flights: ", length(unique(eur$UID)))
message("  Milestone events: ", nrow(eur))
message("  Avg milestones/flight: ", round(nrow(eur) / length(unique(eur$UID)), 1))

message("\n✈️  Aircraft types:")
print(table(eur$TYPE) %>% sort(decreasing = TRUE) %>% head(10))

message("\n🗺️  Routes (top 10):")
routes <- eur %>%
  distinct(UID, ADEP, ADES) %>%
  count(ADEP, ADES, sort = TRUE) %>%
  head(10)
print(routes)

message("\n⛽ Fuel burn summary:")
fuel_summary <- eur %>%
  group_by(UID) %>%
  slice_max(TOT_FUEL, n = 1) %>%
  ungroup() %>%
  summarise(
    min_fuel = min(TOT_FUEL, na.rm = TRUE),
    median_fuel = median(TOT_FUEL, na.rm = TRUE),
    mean_fuel = mean(TOT_FUEL, na.rm = TRUE),
    max_fuel = max(TOT_FUEL, na.rm = TRUE)
  )
print(fuel_summary)

message("\n✅ EUR canonical data successfully imported!")
message("Ready for profile classification and lookup table generation.")
