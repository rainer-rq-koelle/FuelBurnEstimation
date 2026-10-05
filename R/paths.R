# Project paths and local data locations.

fuelburn_paths <- function() {
  reference_project <- Sys.getenv(
    "FUELBURN_2025_PROJECT",
    unset = here::here("..", "paper-2025-ICNS-CHN-EUR-fuelburn")
  )

  tibble::tibble(
    name = c("project", "data_raw", "data_derived", "reference_2025", "reference_2025_data"),
    path = c(
      here::here(),
      here::here("data-raw"),
      here::here("data-derived"),
      reference_project,
      file.path(reference_project, "data")
    )
  )
}

fuelburn_path <- function(name) {
  paths <- fuelburn_paths()
  out <- paths$path[paths$name == name]

  if (length(out) != 1) {
    stop("Unknown path name: ", name, call. = FALSE)
  }

  out
}
