#!/usr/bin/env Rscript
# Check FuelBurnEstimation data store integrity and create manifest
#
# This script:
# - Validates OneDrive data store structure
# - Checks for expected raw and derived data files
# - Validates parquet file integrity
# - Creates manifest files for handover tracking
# - Reports sync status and data quality

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
  library(here)
})

message("FuelBurnEstimation Data Store Checker")
message("=====================================\n")

# Get data store location
data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = "")

if (data_store == "") {
  stop(
    "FUELBURN_DATA_STORE not set.\n",
    "Create .Renviron from .Renviron.example and set the OneDrive path.",
    call. = FALSE
  )
}

message("Data store: ", data_store)
message("Timestamp: ", Sys.time())
message("Machine: ", Sys.info()["nodename"])
message("User: ", Sys.info()["user"])
message("\n")

# Check folder structure
expected_dirs <- c(
  "raw",
  "raw/eur",
  "raw/chn",
  "derived",
  "derived/eur",
  "derived/chn",
  "handover",
  "manifest"
)

dir_status <- tibble::tibble(
  directory = expected_dirs,
  path = file.path(data_store, expected_dirs),
  exists = dir.exists(path),
  status = ifelse(exists, "✓", "✗")
)

message("Folder Structure:")
for (i in seq_len(nrow(dir_status))) {
  message(sprintf("  %s %s", dir_status$status[i], dir_status$directory[i]))
}

missing_dirs <- dir_status$directory[!dir_status$exists]
if (length(missing_dirs) > 0) {
  warning("Missing directories: ", paste(missing_dirs, collapse = ", "))
}

message("\n")

# Expected data files
expected_files <- tibble::tribble(
  ~file_path, ~type, ~required,
  "raw/eur/EUR-canonical-milestones-summer2025.parquet", "EUR raw", TRUE,
  "derived/eur/canonical-milestones-eur-2026-harmonized.parquet", "EUR harmonized", TRUE,
  "raw/chn/CHN-canonical-milestones.parquet", "CHN raw", FALSE,
  "derived/chn/CHN-canonical-milestones-harmonized.parquet", "CHN harmonized", FALSE
) |>
  mutate(
    full_path = file.path(data_store, file_path),
    exists = file.exists(full_path),
    size_mb = ifelse(exists, round(file.info(full_path)$size / 1024^2, 2), NA_real_),
    modified = ifelse(exists, as.character(file.info(full_path)$mtime), NA_character_),
    status = case_when(
      exists ~ "✓",
      required ~ "✗ MISSING",
      TRUE ~ "○ optional"
    )
  )

message("Data Files:")
for (i in seq_len(nrow(expected_files))) {
  row <- expected_files[i, ]
  if (row$exists) {
    message(sprintf(
      "  %s %s (%s MB, modified: %s)",
      row$status, row$type, row$size_mb, row$modified
    ))
  } else {
    message(sprintf("  %s %s", row$status, row$type))
  }
}

missing_required <- expected_files |>
  filter(required & !exists)

if (nrow(missing_required) > 0) {
  stop(
    "\nMissing required files:\n",
    paste("  -", missing_required$file_path, collapse = "\n"),
    call. = FALSE
  )
}

message("\n")

# Validate parquet files
message("Validating Data Integrity:")

validate_parquet <- function(path, name) {
  tryCatch({
    df <- arrow::read_parquet(path)
    message(sprintf("  ✓ %s: %s rows, %s columns",
                    name,
                    format(nrow(df), big.mark = ","),
                    ncol(df)))

    # Return summary
    tibble::tibble(
      file = name,
      path = path,
      valid = TRUE,
      rows = nrow(df),
      columns = ncol(df),
      error = NA_character_
    )
  }, error = function(e) {
    message(sprintf("  ✗ %s: %s", name, e$message))
    tibble::tibble(
      file = name,
      path = path,
      valid = FALSE,
      rows = NA_integer_,
      columns = NA_integer_,
      error = e$message
    )
  })
}

file_checks <- expected_files |>
  filter(exists) |>
  rowwise() |>
  do({
    validate_parquet(.$full_path, .$type)
  }) |>
  ungroup()

invalid_files <- file_checks |>
  filter(!valid)

if (nrow(invalid_files) > 0) {
  warning("\nInvalid parquet files detected:\n",
          paste("  -", invalid_files$file, collapse = "\n"))
}

message("\n")

# Create manifest
manifest_dir <- file.path(data_store, "manifest")
manifest_file <- file.path(manifest_dir, sprintf("data-store-manifest-%s.csv",
                                                   format(Sys.Date(), "%Y-%m-%d")))

manifest <- expected_files |>
  select(file_path, type, required, exists, size_mb, modified) |>
  mutate(
    check_timestamp = as.character(Sys.time()),
    machine = Sys.info()["nodename"],
    user = Sys.info()["user"]
  )

readr::write_csv(manifest, manifest_file)
message("Manifest written: ", manifest_file)

# Create handover summary
handover_file <- file.path(data_store, "handover",
                           sprintf("handover-%s.txt", format(Sys.Date(), "%Y-%m-%d")))

handover_text <- sprintf(
  "FuelBurnEstimation Data Store Handover
========================================

Check Date: %s
Machine: %s
User: %s
Data Store: %s

Folder Structure: %s/%s directories OK
Data Files: %s/%s present (%s required)
Data Integrity: %s/%s files valid

EUR Raw Data:
  %s
  Size: %s MB
  Modified: %s

EUR Harmonized Data:
  %s
  Size: %s MB
  Modified: %s

Next Steps:
- Verify OneDrive sync status on all machines
- Run scripts/03-audit-eur-canonical-milestones.R for validation
- Run scripts/04-harmonize-eur-milestones.R to regenerate harmonized data
- Check manifest/%s for detailed file inventory

---
Generated by scripts/00-check-data-store.R
",
  Sys.time(),
  Sys.info()["nodename"],
  Sys.info()["user"],
  data_store,
  sum(dir_status$exists), nrow(dir_status),
  sum(expected_files$exists), nrow(expected_files), sum(expected_files$required),
  sum(file_checks$valid), nrow(file_checks),
  ifelse(expected_files$exists[1], expected_files$file_path[1], "MISSING"),
  ifelse(expected_files$exists[1], expected_files$size_mb[1], "N/A"),
  ifelse(expected_files$exists[1], expected_files$modified[1], "N/A"),
  ifelse(expected_files$exists[2], expected_files$file_path[2], "MISSING"),
  ifelse(expected_files$exists[2], expected_files$size_mb[2], "N/A"),
  ifelse(expected_files$exists[2], expected_files$modified[2], "N/A"),
  basename(manifest_file)
)

writeLines(handover_text, handover_file)
message("Handover summary: ", handover_file)

message("\n✓ Data store check complete!")

if (all(dir_status$exists) && all(expected_files$exists[expected_files$required]) && all(file_checks$valid)) {
  message("✓ All checks passed - data store ready for analysis")
} else {
  warning("⚠ Some checks failed - review output above")
}
