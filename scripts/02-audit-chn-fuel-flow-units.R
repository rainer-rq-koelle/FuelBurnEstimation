library(dplyr)
library(purrr)
library(readr)

source(here::here("R", "setup.R"))

default_archives <- c(
  here::here("..", "paper-2025-ICNS-CHN-EUR-fuelburn", "data", "fuel data-LL.zip"),
  here::here("..", "paper-2025-ICNS-CHN-EUR-fuelburn", "data", "fuel data-lingling0201.zip"),
  here::here("..", "paper-2025-ICNS-CHN-EUR-fuelburn", "data", "0210data-linglingadd milestones and flightphase.zip"),
  here::here("..", "paper-2025-ICNS-CHN-EUR-fuelburn", "data", "0210data2-linglingadd milestones and flightphase.zip")
)

archive_env <- Sys.getenv("CHN_UNIT_QC_ARCHIVES", unset = "")
archives <- if (nzchar(archive_env)) {
  strsplit(archive_env, .Platform$path.sep, fixed = TRUE)[[1]]
} else {
  default_archives
}

archives <- path.expand(archives)
archives <- archives[file.exists(archives)]

if (length(archives) == 0) {
  stop("No CHN QAR archives found. Set CHN_UNIT_QC_ARCHIVES or check the reference data path.", call. = FALSE)
}

limit <- suppressWarnings(as.integer(Sys.getenv("CHN_UNIT_QC_LIMIT", unset = NA_character_)))
output_file <- Sys.getenv(
  "CHN_UNIT_QC_OUTPUT",
  unset = here::here("data-derived", "CHN-fuel-flow-unit-backtest.csv")
)
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

audit_one_file <- function(path, archive_name) {
  tryCatch(
    {
      trj <- fuel_read_chn_qar_csv(path, fuel_flow_unit = "auto")
      fuel_flow_unit_qc(list(trj)) |>
        mutate(
          source_archive = archive_name,
          source_file = basename(path),
          read_status = "ok",
          read_error_class = NA_character_,
          read_error = NA_character_,
          .before = SOURCE_UID
        )
    },
    error = function(e) {
      meta <- fuel_parse_chn_filename(path)
      error_message <- conditionMessage(e)
      error_class <- case_when(
        grepl("no FF\\*C fuel-flow columns", error_message) ~ "no_fuel_flow_columns",
        grepl("no TIME column", error_message) ~ "no_time_column",
        grepl("no ALT_STD column", error_message) ~ "no_altitude_column",
        TRUE ~ "reader_error"
      )
      tibble(
        source_archive = archive_name,
        source_file = basename(path),
        SOURCE_UID = meta$SOURCE_UID[[1]],
        FLTID = meta$FLTID[[1]],
        ADEP = meta$ADEP[[1]],
        ADES = meta$ADES[[1]],
        TYPE = meta$TYPE[[1]],
        read_status = "error",
        read_error_class = error_class,
        read_error = error_message
      )
    }
  )
}

extract_archive <- function(archive) {
  archive_name <- basename(archive)
  extract_dir <- file.path(tempdir(), paste0("chn-unit-qc-", tools::file_path_sans_ext(archive_name)))
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
  unzip(archive, exdir = extract_dir)

  csv_files <- list.files(extract_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  if (!is.na(limit) && limit > 0) {
    csv_files <- head(csv_files, limit)
  }

  message("Auditing ", length(csv_files), " CSV files from ", archive_name)
  map_dfr(csv_files, audit_one_file, archive_name = archive_name)
}

qc <- map_dfr(archives, extract_archive)

write_csv(qc, output_file)

summary_by_archive <- qc |>
  summarise(
    files = n(),
    ok = sum(.data$read_status == "ok", na.rm = TRUE),
    errors = sum(.data$read_status == "error", na.rm = TRUE),
    no_fuel_flow_columns = sum(.data$read_error_class == "no_fuel_flow_columns", na.rm = TRUE),
    kg_h = sum(.data$inferred_unit == "kg/h", na.rm = TRUE),
    lb_h = sum(.data$inferred_unit == "lb/h", na.rm = TRUE),
    review_required = sum(.data$review_required, na.rm = TRUE),
    high_confidence = sum(.data$unit_confidence == "high", na.rm = TRUE),
    medium_confidence = sum(.data$unit_confidence == "medium", na.rm = TRUE),
    low_confidence = sum(.data$unit_confidence == "low", na.rm = TRUE),
    unknown_confidence = sum(.data$unit_confidence == "unknown", na.rm = TRUE),
    .by = source_archive
  ) |>
  arrange(.data$source_archive)

summary_by_unit <- qc |>
  filter(.data$read_status == "ok") |>
  summarise(
    flights = n(),
    median_burn_if_kg = median(.data$burn_if_kg, na.rm = TRUE),
    median_burn_if_lb = median(.data$burn_if_lb, na.rm = TRUE),
    median_selected_total_fuel_kg = median(.data$selected_total_fuel_kg, na.rm = TRUE),
    median_burn_per_nm_if_kg = median(.data$burn_per_nm_if_kg, na.rm = TRUE),
    median_burn_per_nm_if_lb = median(.data$burn_per_nm_if_lb, na.rm = TRUE),
    .by = c(inferred_unit, unit_confidence, unit_flag)
  ) |>
  arrange(.data$inferred_unit, .data$unit_confidence, .data$unit_flag)

message("")
message("Wrote ", output_file)
message("")
message("Summary by archive:")
print(summary_by_archive, n = Inf)
message("")
message("Summary by inferred unit/confidence:")
print(summary_by_unit, n = Inf)

review <- qc |>
  filter(.data$read_status == "ok", .data$review_required) |>
  select(
    source_archive, SOURCE_UID, TYPE, ADEP, ADES,
    inferred_unit, unit_confidence, unit_flag,
    burn_if_kg, burn_if_lb,
    burn_per_nm_if_kg, burn_per_nm_if_lb,
    unit_score_kg, unit_score_lb
  ) |>
  arrange(.data$source_archive, .data$SOURCE_UID)

if (nrow(review) > 0) {
  message("")
  message("Flights requiring review:")
  print(review, n = min(nrow(review), 50))
}
