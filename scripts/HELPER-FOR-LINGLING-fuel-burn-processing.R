################################################################################
# FUEL BURN QAR PROCESSING HELPER SCRIPT
# For: Lingling / China Eastern Airlines
# Purpose: Process QAR files for CHN-EUR comparison report fuel burn section
################################################################################
#
# WHAT THIS SCRIPT DOES:
# ----------------------
# Processes one-file-per-flight QAR CSV data and produces standardized outputs
# for the China-Europe fuel burn comparison chapter.
#
# REQUIRED INPUT DATA:
# -------------------
# QAR CSV files for the following airport pairs (July 2025 or representative month):
#   • Short band:  ZBAA-ZSSS / ZSSS-ZBAA  (Beijing Capital - Shanghai Hongqiao)
#   • Medium band: ZLXY-ZSSS / ZSSS-ZLXY  (Xi'an - Shanghai Hongqiao)
#                  [If ZLXY difficult: ZGGG-ZSSS / ZSSS-ZGGG as fallback]
#   • Long band:   ZPPP-ZSSS / ZSSS-ZPPP  (Kunming - Shanghai Hongqiao)
#
# Each QAR CSV file should contain:
#   • TIME (HH:MM:SS format)
#   • LATP, LONP (latitude, longitude)
#   • ALT_STD (altitude in feet)
#   • FF1C, FF2C (fuel flow per engine in kg/h)
#   • Optional: FF3C, FF4C (if 4-engine aircraft)
#   • Optional: FLIGHT_PHASE (raw phase code)
#   • Optional: IASC, GS (indicated airspeed, ground speed)
#
# HOW TO RUN:
# -----------
# 1. Put all QAR CSV files in one folder (or ZIP file)
# 2. Open R or RStudio
# 3. Run this script:
#
#    Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R <input_folder_or_zip> <output_folder>
#
# EXAMPLE:
#    Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R "./qar-files" "./output"
#
# Or from R console:
#    source("HELPER-FOR-LINGLING-fuel-burn-processing.R")
#    # Then follow prompts or modify paths below
#
# OUTPUTS:
# --------
# The script creates these files in the output folder:
#   • CHN-canonical-milestones.parquet  (milestone snapshots)
#   • CHN-phase-summaries.csv           (fuel burn per phase)
#   • CHN-phase-level-descriptors.csv   (climb/descent smoothness)
#   • CHN-qar-fuel-flow-qc.csv          (quality control report)
#   • CHN-flight-phase-code-diagnostics.csv
#   • profile-plots/*.png               (altitude profile visualizations)
#
# Send the output folder back for integration into the report chapter.
#
################################################################################

# STEP 1: Load required R packages ============================================

cat("Loading required packages...\n")

required_packages <- c("arrow", "dplyr", "readr", "purrr", "data.table", "zoo")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("Installing missing package:", pkg, "\n")
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
  library(pkg, character.only = TRUE)
}

cat("All packages loaded successfully.\n\n")

# STEP 2: Source the canonical fuel milestone functions =======================

# These functions are in the report repository: R/canonical-fuel-milestones.R
# Copy the content here for standalone operation:

source_canonical_functions <- function() {
  # Check if we're in the project directory structure
  canonical_path <- file.path("R", "canonical-fuel-milestones.R")
  if (file.exists(canonical_path)) {
    source(canonical_path)
    return(TRUE)
  }

  # Check parent directory
  canonical_path <- file.path("..", "R", "canonical-fuel-milestones.R")
  if (file.exists(canonical_path)) {
    source(canonical_path)
    return(TRUE)
  }

  # If not found, the functions need to be bundled
  stop(
    paste(
      "ERROR: Cannot find R/canonical-fuel-milestones.R",
      "",
      "This helper script needs the canonical fuel milestone functions.",
      "Please ensure R/canonical-fuel-milestones.R is in the expected location,",
      "or contact the report team for the complete helper package.",
      sep = "\n"
    ),
    call. = FALSE
  )
}

source_canonical_functions()
cat("Fuel burn processing functions loaded.\n\n")

# STEP 3: Define airport metadata =============================================

# Airport coordinates for the study pairs
airport_meta <- tibble::tribble(
  ~ICAO,    ~NAME,                    ~LAT,      ~LON,
  "ZBAA",   "Beijing Capital",        40.0801,   116.5846,
  "ZSSS",   "Shanghai Hongqiao",      31.1979,   121.3364,
  "ZLXY",   "Xi'an Xianyang",         34.4471,   108.7514,
  "ZGGG",   "Guangzhou Baiyun",       23.3924,   113.2988,
  "ZPPP",   "Kunming Changshui",      24.9928,   102.7412
)

cat("Airport metadata defined for study pairs.\n")
print(airport_meta)
cat("\n")

# STEP 4: Get input/output paths ==============================================

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  cat("========================================\n")
  cat("INTERACTIVE MODE\n")
  cat("========================================\n")
  cat("Please provide paths:\n\n")

  cat("1. Input path (folder or ZIP file with QAR CSV files):\n")
  input_path <- readline(prompt = "   Path: ")
  if (input_path == "") {
    input_path <- "./qar-input"
    cat("   Using default: ", input_path, "\n")
  }

  cat("\n2. Output folder (where results will be saved):\n")
  output_dir <- readline(prompt = "   Path: ")
  if (output_dir == "") {
    output_dir <- "./qar-output"
    cat("   Using default: ", output_dir, "\n")
  }
  cat("\n")

} else if (length(args) >= 2) {
  input_path <- path.expand(args[[1]])
  output_dir <- args[[2]]
  cat("Command-line mode:\n")
  cat("  Input:  ", input_path, "\n")
  cat("  Output: ", output_dir, "\n\n")
} else {
  cat(
    paste(
      "USAGE:",
      "  Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R <input_path> <output_folder>",
      "",
      "  <input_path>: Folder or ZIP file containing QAR CSV files",
      "  <output_folder>: Where to save processed results",
      "",
      "EXAMPLE:",
      "  Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R ./qar-files ./output",
      "",
      "Or run without arguments for interactive mode.",
      "",
      sep = "\n"
    )
  )
  quit(status = 1)
}

# STEP 5: Find and validate QAR files ==========================================

cat("========================================\n")
cat("FINDING QAR FILES\n")
cat("========================================\n")

if (!file.exists(input_path)) {
  stop("ERROR: Input path does not exist: ", input_path, call. = FALSE)
}

# Handle directory input
if (dir.exists(input_path)) {
  qar_dir <- input_path
  cat("Input is a directory.\n")
}

# Handle ZIP input
if (file.exists(input_path) && grepl("\\.zip$", input_path, ignore.case = TRUE)) {
  cat("Input is a ZIP file. Extracting...\n")
  qar_dir <- file.path(tempdir(), "qar-extraction")
  dir.create(qar_dir, recursive = TRUE, showWarnings = FALSE)
  unzip(input_path, exdir = qar_dir)
  cat("Extracted to temporary directory.\n")
}

# Find CSV files
qar_files <- list.files(qar_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)

# Check for nested ZIPs
if (length(qar_files) == 0) {
  cat("No CSV files found. Checking for nested ZIP files...\n")
  zip_files <- list.files(qar_dir, pattern = "\\.zip$", recursive = TRUE, full.names = TRUE)
  if (length(zip_files) > 0) {
    zip_extract_dir <- file.path(tempdir(), "qar-nested-extraction")
    dir.create(zip_extract_dir, recursive = TRUE, showWarnings = FALSE)
    purrr::walk(zip_files, unzip, exdir = zip_extract_dir)
    qar_files <- list.files(zip_extract_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  }
}

if (length(qar_files) == 0) {
  stop(
    paste(
      "ERROR: No QAR CSV files found in:", qar_dir,
      "",
      "Please ensure:",
      "  • QAR files are in CSV format",
      "  • File names follow China Eastern naming convention",
      "  • Files contain required columns (TIME, LATP, LONP, ALT_STD, FF1C, FF2C)",
      "",
      sep = "\n"
    ),
    call. = FALSE
  )
}

cat("Found", length(qar_files), "QAR CSV files.\n")
cat("Sample files:\n")
print(head(basename(qar_files), 10))
cat("\n")

# STEP 6: Process QAR files ====================================================

cat("========================================\n")
cat("PROCESSING QAR FILES\n")
cat("========================================\n")
cat("This may take several minutes depending on file count...\n\n")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Read all trajectories
trajectories <- purrr::map(qar_files, function(path) {
  cat("  Reading:", basename(path), "\n")
  tryCatch(
    fuel_read_chn_qar_csv(path),
    error = function(e) {
      cat("    WARNING: Failed to read", basename(path), "-", e$message, "\n")
      return(NULL)
    }
  )
})

# Filter out failed reads
trajectories <- purrr::compact(trajectories)

if (length(trajectories) == 0) {
  stop("ERROR: No files could be processed successfully.", call. = FALSE)
}

cat("\nSuccessfully read", length(trajectories), "flights.\n\n")

# Extract milestones
cat("Extracting flight milestones...\n")
milestones <- purrr::map(trajectories, fuel_chn_milestones, airport_meta = airport_meta) |>
  dplyr::bind_rows()

# Calculate phase summaries
cat("Calculating phase summaries...\n")
phases <- fuel_phase_summaries(milestones)

# Calculate level descriptors (smoothness)
cat("Calculating vertical smoothness metrics...\n")
level_descriptors <- fuel_level_descriptors(dplyr::bind_rows(trajectories), phases)

# Diagnostic: phase code agreement
cat("Running phase code diagnostics...\n")
phase_code_diagnostics <- fuel_phase_code_diagnostics(trajectories, phases)

# Quality control: fuel flow spike detection
cat("Running fuel flow quality control...\n")
qc <- purrr::map_dfr(trajectories, function(x) {
  x |>
    dplyr::summarise(
      SOURCE_UID = dplyr::first(.data$SOURCE_UID),
      FLTID = dplyr::first(.data$FLTID),
      ADEP = dplyr::first(.data$ADEP),
      ADES = dplyr::first(.data$ADES),
      TYPE = dplyr::first(.data$TYPE),
      rows = dplyr::n(),
      spike_rows = sum(.data$FF_SPIKE_FLAG, na.rm = TRUE),
      spike_share = .data$spike_rows / .data$rows,
      total_fuel_kg_raw = max(.data$TOT_FUEL_KG_ORIGINAL, na.rm = TRUE),
      total_fuel_kg_clean = max(.data$TOT_FUEL_KG, na.rm = TRUE),
      fuel_delta_kg = .data$total_fuel_kg_raw - .data$total_fuel_kg_clean
    )
})

cat("\nProcessing complete!\n\n")

# STEP 7: Save outputs =========================================================

cat("========================================\n")
cat("SAVING OUTPUTS\n")
cat("========================================\n")

arrow::write_parquet(milestones, file.path(output_dir, "CHN-canonical-milestones.parquet"))
readr::write_csv(milestones, file.path(output_dir, "CHN-canonical-milestones.csv"))
cat("Saved: CHN-canonical-milestones.parquet/.csv\n")

arrow::write_parquet(phases, file.path(output_dir, "CHN-phase-summaries.parquet"))
readr::write_csv(phases, file.path(output_dir, "CHN-phase-summaries.csv"))
cat("Saved: CHN-phase-summaries.csv\n")

readr::write_csv(level_descriptors, file.path(output_dir, "CHN-phase-level-descriptors.csv"))
cat("Saved: CHN-phase-level-descriptors.csv\n")

readr::write_csv(phase_code_diagnostics, file.path(output_dir, "CHN-flight-phase-code-diagnostics.csv"))
cat("Saved: CHN-flight-phase-code-diagnostics.csv\n")

readr::write_csv(qc, file.path(output_dir, "CHN-qar-fuel-flow-qc.csv"))
cat("Saved: CHN-qar-fuel-flow-qc.csv\n")

# Generate profile plots for sample flights
cat("\nGenerating altitude profile plots...\n")
profile_dir <- file.path(output_dir, "profile-plots")
dir.create(profile_dir, recursive = TRUE, showWarnings = FALSE)

purrr::walk(utils::head(trajectories, 12), function(trj) {
  source_uid <- unique(trj$SOURCE_UID)[1]
  fuel_plot_annotated_profile(
    trj,
    milestones,
    file.path(profile_dir, paste0(source_uid, ".png"))
  )
})
cat("Saved profile plots to:", profile_dir, "\n")

# STEP 8: Generate summary report ==============================================

cat("\n========================================\n")
cat("PROCESSING SUMMARY\n")
cat("========================================\n")

summary_stats <- list(
  flights_processed = dplyr::n_distinct(milestones$SOURCE_UID),
  milestone_records = nrow(milestones),
  phase_records = nrow(phases),
  airports = unique(c(phases$ADEP, phases$ADES)),
  aircraft_types = unique(phases$TYPE)
)

cat("Flights processed:     ", summary_stats$flights_processed, "\n")
cat("Milestone records:     ", summary_stats$milestone_records, "\n")
cat("Phase records:         ", summary_stats$phase_records, "\n")
cat("Airports covered:      ", paste(summary_stats$airports, collapse = ", "), "\n")
cat("Aircraft types:        ", paste(summary_stats$aircraft_types, collapse = ", "), "\n")

# Route pair summary
route_summary <- phases |>
  dplyr::mutate(ROUTE_PAIR = paste(.data$ADEP, .data$ADES, sep = "-")) |>
  dplyr::summarise(
    flights = dplyr::n_distinct(.data$SOURCE_UID),
    types = dplyr::n_distinct(.data$TYPE),
    .by = ROUTE_PAIR
  ) |>
  dplyr::arrange(dplyr::desc(flights))

cat("\nRoute pair coverage:\n")
print(route_summary)

# Save summary report
summary_report <- c(
  "FUEL BURN QAR PROCESSING SUMMARY",
  "================================",
  "",
  paste("Processing date:", Sys.time()),
  paste("Input path:", input_path),
  paste("Output directory:", output_dir),
  "",
  "RESULTS:",
  paste("  Flights processed:", summary_stats$flights_processed),
  paste("  Milestone records:", summary_stats$milestone_records),
  paste("  Phase records:", summary_stats$phase_records),
  "",
  "ROUTE PAIRS:",
  capture.output(print(route_summary, row.names = FALSE)),
  "",
  "OUTPUT FILES:",
  "  • CHN-canonical-milestones.parquet/.csv",
  "  • CHN-phase-summaries.parquet/.csv",
  "  • CHN-phase-level-descriptors.csv",
  "  • CHN-flight-phase-code-diagnostics.csv",
  "  • CHN-qar-fuel-flow-qc.csv",
  "  • profile-plots/*.png",
  "",
  "NEXT STEPS:",
  "  1. Review the profile-plots/*.png files to verify milestone detection",
  "  2. Check CHN-qar-fuel-flow-qc.csv for fuel flow spike corrections",
  "  3. Send the entire output folder to the report team for integration",
  "",
  "For questions, contact the China-Europe report coordination team."
)

writeLines(summary_report, file.path(output_dir, "PROCESSING-SUMMARY.txt"))

cat("\n========================================\n")
cat("ALL DONE!\n")
cat("========================================\n")
cat("Output folder:", output_dir, "\n")
cat("Summary saved to: PROCESSING-SUMMARY.txt\n")
cat("\nPlease send this output folder to the report team.\n")
