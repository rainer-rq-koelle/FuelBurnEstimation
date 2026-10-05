library(arrow)
library(dplyr)
library(readr)
library(purrr)

project_path <- function(...) {
  if (requireNamespace("here", quietly = TRUE)) {
    here::here(...)
  } else {
    file.path(getwd(), ...)
  }
}

source(project_path("R", "canonical-fuel-milestones.R"))

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  input_path <- project_path("data", "input", "chn-qar")
  output_dir <- project_path("data", "output", "chn-canonical")
  airport_meta_path <- project_path("data", "reference", "airport-meta-icao-lat-lon.csv")
  message("No command-line arguments supplied.")
  message("Using project defaults:")
  message("  Input:        ", input_path)
  message("  Output:       ", output_dir)
  message("  Airport meta: ", airport_meta_path)
} else if (length(args) >= 2) {
  input_path <- path.expand(args[[1]])
  output_dir <- args[[2]]
  airport_meta_path <- if (length(args) >= 3) {
    path.expand(args[[3]])
  } else {
    project_path("data", "reference", "airport-meta-icao-lat-lon.csv")
  }
} else {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/prepare-chn-qar-canonical.R",
      "or",
      "Rscript scripts/prepare-chn-qar-canonical.R <qar_zip_or_directory> <output_directory> [airport_meta_csv_or_parquet]",
      sep = "\n"
    ),
    call. = FALSE
  )
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

if (dir.exists(input_path)) {
  qar_dir <- input_path
} else if (file.exists(input_path) && grepl("\\.zip$", input_path, ignore.case = TRUE)) {
  qar_dir <- file.path(tempdir(), "chn-qar-input")
  dir.create(qar_dir, recursive = TRUE, showWarnings = FALSE)
  unzip(input_path, exdir = qar_dir)
} else {
  stop("Input path must be a directory or ZIP file: ", input_path, call. = FALSE)
}

if (grepl("\\.csv$", airport_meta_path, ignore.case = TRUE)) {
  airport_meta <- readr::read_csv(airport_meta_path, show_col_types = FALSE)
} else {
  airport_meta <- arrow::read_parquet(airport_meta_path)
}

required_airport_cols <- c("ICAO", "LAT", "LON")
if (!all(required_airport_cols %in% names(airport_meta))) {
  stop("Airport metadata must contain columns: ICAO, LAT, LON", call. = FALSE)
}

qar_files <- list.files(qar_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
if (length(qar_files) == 0) {
  zip_files <- list.files(qar_dir, pattern = "\\.zip$", recursive = TRUE, full.names = TRUE)
  if (length(zip_files) > 0) {
    zip_extract_dir <- file.path(tempdir(), "chn-qar-nested-zips")
    dir.create(zip_extract_dir, recursive = TRUE, showWarnings = FALSE)
    walk(zip_files, unzip, exdir = zip_extract_dir)
    qar_files <- list.files(zip_extract_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  }
}

if (length(qar_files) == 0) {
  stop(
    paste(
      "No CSV files found.",
      "Put one-file-per-flight QAR CSV files, or a ZIP containing CSV files, under:",
      qar_dir,
      sep = "\n"
    ),
    call. = FALSE
  )
}

message("Found ", length(qar_files), " QAR CSV files.")

trajectories <- map(qar_files, \(path) {
  message("Reading ", basename(path))
  fuel_read_chn_qar_csv(path)
})

milestones <- map(trajectories, fuel_chn_milestones, airport_meta = airport_meta) |>
  bind_rows()

phases <- fuel_phase_summaries(milestones)
level_descriptors <- fuel_level_descriptors(bind_rows(trajectories), phases)
phase_code_diagnostics <- fuel_phase_code_diagnostics(trajectories, phases)

qc <- map_dfr(trajectories, \(x) {
  x |>
    summarise(
      SOURCE_UID = first(.data$SOURCE_UID),
      FLTID = first(.data$FLTID),
      ADEP = first(.data$ADEP),
      ADES = first(.data$ADES),
      TYPE = first(.data$TYPE),
      rows = n(),
      spike_rows = sum(.data$FF_SPIKE_FLAG, na.rm = TRUE),
      spike_share = .data$spike_rows / .data$rows,
      total_fuel_kg_raw = max(.data$TOT_FUEL_KG_ORIGINAL, na.rm = TRUE),
      total_fuel_kg_clean = max(.data$TOT_FUEL_KG, na.rm = TRUE),
      fuel_delta_kg = .data$total_fuel_kg_raw - .data$total_fuel_kg_clean
    )
})

write_parquet(milestones, file.path(output_dir, "CHN-canonical-milestones.parquet"))
write_csv(milestones, file.path(output_dir, "CHN-canonical-milestones.csv"))
write_parquet(phases, file.path(output_dir, "CHN-phase-summaries.parquet"))
write_csv(phases, file.path(output_dir, "CHN-phase-summaries.csv"))
write_csv(level_descriptors, file.path(output_dir, "CHN-phase-level-descriptors.csv"))
write_csv(phase_code_diagnostics, file.path(output_dir, "CHN-flight-phase-code-diagnostics.csv"))
write_csv(qc, file.path(output_dir, "CHN-qar-fuel-flow-qc.csv"))

profile_dir <- file.path(output_dir, "profile-plots")
dir.create(profile_dir, recursive = TRUE, showWarnings = FALSE)
walk(head(trajectories, 12), \(trj) {
  source_uid <- unique(trj$SOURCE_UID)[1]
  fuel_plot_annotated_profile(
    trj,
    milestones,
    file.path(profile_dir, paste0(source_uid, ".png"))
  )
})

message("Wrote outputs to ", output_dir)
message("Flights: ", n_distinct(milestones$SOURCE_UID))
message("Milestone rows: ", nrow(milestones))
message("Phase rows: ", nrow(phases))
message("Annotated profile plots: ", profile_dir)
