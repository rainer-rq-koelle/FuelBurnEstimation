#' Cloudflare R2 Storage Helpers
#'
#' Functions for uploading, downloading, and managing data artifacts in
#' Cloudflare R2 (S3-compatible object storage).
#'
#' Required environment variables (set in .Renviron):
#' - R2_ACCESS_KEY_ID
#' - R2_SECRET_ACCESS_KEY
#' - R2_ENDPOINT
#' - R2_BUCKET

#' Get configured R2 client
#'
#' @return paws S3 client configured for R2
#' @export
r2_client <- function() {

  if (!requireNamespace("paws.storage", quietly = TRUE)) {
    stop(
      "Package 'paws.storage' is required for R2 operations.\n",
      "Install with: install.packages('paws.storage')",
      call. = FALSE
    )
  }

  # Get credentials from environment
  access_key <- Sys.getenv("R2_ACCESS_KEY_ID", unset = "")
  secret_key <- Sys.getenv("R2_SECRET_ACCESS_KEY", unset = "")
  endpoint <- Sys.getenv("R2_ENDPOINT", unset = "")

  if (access_key == "" || secret_key == "" || endpoint == "") {
    stop(
      "R2 credentials not configured.\n",
      "Set R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, and R2_ENDPOINT in .Renviron",
      call. = FALSE
    )
  }

  # Create S3 client pointing to R2
  paws.storage::s3(
    config = list(
      credentials = list(
        creds = list(
          access_key_id = access_key,
          secret_access_key = secret_key
        )
      ),
      endpoint = endpoint,
      region = "auto"
    )
  )
}

#' Get configured R2 bucket name
#'
#' @return Bucket name from R2_BUCKET environment variable
#' @export
r2_bucket <- function() {
  bucket <- Sys.getenv("R2_BUCKET", unset = "")
  if (bucket == "") {
    stop("R2_BUCKET not set in .Renviron", call. = FALSE)
  }
  bucket
}

#' Standard local data-store layout
#'
#' @return Character vector of relative directories
#' @export
r2_data_store_dirs <- function() {
  c(
    "raw/eur",
    "raw/chn",
    "derived/eur",
    "derived/chn",
    "manifest",
    "manifest/archive",
    "handover"
  )
}

#' Registered shared artifacts
#'
#' @return Tibble describing artifacts controlled by the starter manifest
#' @export
r2_artifact_registry <- function() {
  tibble::tribble(
    ~key, ~source, ~stage, ~required, ~version, ~produced_by_script, ~input_artifacts, ~description,
    "raw/eur/EUR-canonical-milestones-summer2025.parquet",
    "EUR/PRU", "raw", TRUE, "summer2025", "external-pru-source", "",
    "EUR compact raw canonical milestones with compound MST labels",

    "raw/eur/EUR-canonical-milestones-expanded-summer2025.parquet",
    "EUR/PRU", "raw", TRUE, "summer2025-expanded", "external-pru-source", "",
    "EUR expanded raw canonical milestones with single MST roles and distance fields",

    "derived/eur/canonical-milestones-eur-2026-harmonized.parquet",
    "EUR/PRU", "derived", TRUE, "2026-harmonized", "scripts/04-harmonize-eur-milestones.R",
    "raw/eur/EUR-canonical-milestones-expanded-summer2025.parquet",
    "EUR harmonized milestones in the 2026 convention",

    "derived/eur/level-segments-eur-2026.parquet",
    "EUR/PRU", "derived", TRUE, "2026-level-segments", "scripts/05-build-eur-level-segments.R",
    "raw/eur/EUR-canonical-milestones-expanded-summer2025.parquet",
    "EUR level-segment intervals reconstructed from LVL-bearing PRU milestones",

    "derived/eur/level-segment-duration-summary-eur-2026.csv",
    "EUR/PRU", "derived", TRUE, "2026-level-segments", "scripts/05-build-eur-level-segments.R",
    "derived/eur/level-segments-eur-2026.parquet",
    "EUR level-segment duration and quality summary",

    "raw/chn/CHN-canonical-milestones.parquet",
    "CHN/QAR", "raw", FALSE, "pending", "scripts/prepare-chn-qar-canonical.R", "",
    "CHN raw canonical milestones",

    "derived/chn/CHN-canonical-milestones-harmonized.parquet",
    "CHN/QAR", "derived", FALSE, "pending", "pending", "raw/chn/CHN-canonical-milestones.parquet",
    "CHN harmonized milestones"
  )
}

#' Local data-store root
#'
#' @return Local data-store path from FUELBURN_DATA_STORE
#' @export
r2_data_store <- function() {
  data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = "")
  if (data_store == "") {
    stop(
      "FUELBURN_DATA_STORE not set.\n",
      "Set it in .Renviron to your local data store path.",
      call. = FALSE
    )
  }
  path.expand(data_store)
}

#' Ensure local data-store folder skeleton exists
#'
#' @param data_store Local data-store root
#' @return Invisible TRUE
#' @export
r2_ensure_data_store_dirs <- function(data_store = r2_data_store()) {
  purrr::walk(file.path(data_store, r2_data_store_dirs()), dir.create, recursive = TRUE, showWarnings = FALSE)
  invisible(TRUE)
}

#' Create a local manifest for registered artifacts
#'
#' @param data_store Local data-store root
#' @param require_required Stop if required artifacts are missing
#' @param include_optional Include optional artifacts when present
#' @return Manifest tibble
#' @export
r2_build_manifest <- function(
  data_store = r2_data_store(),
  require_required = TRUE,
  include_optional = TRUE
) {
  registry <- r2_artifact_registry()
  if (!include_optional) {
    registry <- dplyr::filter(registry, .data$required)
  }

  registry <- registry |>
    dplyr::mutate(
      local_path = file.path(data_store, .data$key),
      exists = file.exists(.data$local_path)
    )

  missing_required <- registry |>
    dplyr::filter(.data$required & !.data$exists)

  if (require_required && nrow(missing_required) > 0) {
    stop(
      "Cannot build authoritative manifest; missing required artifact(s):\n",
      paste("  -", missing_required$key, collapse = "\n"),
      call. = FALSE
    )
  }

  existing <- registry |>
    dplyr::filter(.data$exists)

  if (nrow(existing) == 0) {
    return(tibble::tibble(
      key = character(),
      source = character(),
      stage = character(),
      required = logical(),
      version = character(),
      status = character(),
      size_bytes = numeric(),
      modified_utc = character(),
      sha256 = character(),
      produced_by_script = character(),
      input_artifacts = character(),
      description = character(),
      manifest_created_utc = character(),
      manifest_machine = character(),
      manifest_user = character()
    ))
  }

  sizes <- as.numeric(file.info(existing$local_path)$size)
  modified <- format(
    as.POSIXct(file.info(existing$local_path)$mtime, tz = "UTC"),
    "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  hashes <- unname(as.character(tools::sha256sum(existing$local_path)))

  existing |>
    dplyr::transmute(
      key = .data$key,
      source = .data$source,
      stage = .data$stage,
      required = .data$required,
      version = .data$version,
      status = "current",
      size_bytes = sizes,
      modified_utc = modified,
      sha256 = hashes,
      produced_by_script = .data$produced_by_script,
      input_artifacts = .data$input_artifacts,
      description = .data$description,
      manifest_created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      manifest_machine = unname(Sys.info()[["nodename"]]),
      manifest_user = unname(Sys.info()[["user"]])
    ) |>
    dplyr::arrange(.data$key)
}

#' Write current manifest locally
#'
#' @param manifest Manifest tibble
#' @param data_store Local data-store root
#' @return Path to current manifest
#' @export
r2_write_manifest <- function(manifest, data_store = r2_data_store()) {
  r2_ensure_data_store_dirs(data_store)
  current_path <- file.path(data_store, "manifest", "current-artifacts.csv")
  archive_path <- file.path(
    data_store,
    "manifest",
    "archive",
    sprintf("artifacts-%s.csv", format(Sys.time(), "%Y%m%d-%H%M%S"))
  )
  readr::write_csv(manifest, current_path)
  readr::write_csv(manifest, archive_path)
  current_path
}

#' Download current authoritative manifest from R2
#'
#' @param data_store Local data-store root
#' @return Manifest tibble
#' @export
r2_download_current_manifest <- function(data_store = r2_data_store()) {
  local_path <- file.path(data_store, "manifest", "current-artifacts.csv")
  r2_download("manifest/current-artifacts.csv", local_path, overwrite = TRUE)
  readr::read_csv(local_path, show_col_types = FALSE)
}

#' Compare local cache with authoritative manifest
#'
#' @param manifest Authoritative manifest tibble
#' @param data_store Local data-store root
#' @return Status tibble
#' @export
r2_manifest_status <- function(manifest, data_store = r2_data_store()) {
  required_cols <- c("key", "status", "sha256", "size_bytes", "modified_utc")
  missing_cols <- setdiff(required_cols, names(manifest))
  if (length(missing_cols) > 0) {
    stop(
      "Manifest is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  current_manifest <- manifest |>
    dplyr::filter(.data$status == "current") |>
    dplyr::mutate(local_path = file.path(data_store, .data$key))

  current_manifest$local_exists <- file.exists(current_manifest$local_path)
  current_manifest$local_sha256 <- NA_character_
  current_manifest$local_size_bytes <- NA_real_

  if (any(current_manifest$local_exists)) {
    local_paths <- current_manifest$local_path[current_manifest$local_exists]
    current_manifest$local_sha256[current_manifest$local_exists] <- unname(as.character(tools::sha256sum(local_paths)))
    current_manifest$local_size_bytes[current_manifest$local_exists] <- as.numeric(file.info(local_paths)$size)
  }

  current_manifest |>
    dplyr::mutate(
      sync_status = dplyr::case_when(
        !.data$local_exists ~ "missing-local",
        .data$local_sha256 != .data$sha256 ~ "stale-local",
        TRUE ~ "current"
      )
    ) |>
    dplyr::select(
      key,
      source,
      stage,
      required,
      version,
      sync_status,
      local_exists,
      local_size_bytes,
      remote_size_bytes = size_bytes,
      modified_utc,
      local_sha256,
      remote_sha256 = sha256,
      produced_by_script,
      input_artifacts
    ) |>
    dplyr::arrange(dplyr::desc(.data$required), .data$key)
}

#' Upload file to R2
#'
#' @param local_path Local file path
#' @param r2_path Path in R2 bucket (e.g., "raw/eur/file.parquet")
#' @param bucket Bucket name (defaults to R2_BUCKET env var)
#' @return Invisible TRUE on success
#' @export
r2_upload <- function(local_path, r2_path, bucket = r2_bucket()) {

  if (!file.exists(local_path)) {
    stop("Local file not found: ", local_path, call. = FALSE)
  }

  client <- r2_client()

  message(sprintf("Uploading %s → r2://%s/%s",
                  basename(local_path), bucket, r2_path))

  size_mb <- round(file.info(local_path)$size / 1024^2, 2)
  message(sprintf("  Size: %s MB", size_mb))

  # Upload file
  client$put_object(
    Bucket = bucket,
    Key = r2_path,
    Body = local_path
  )

  message("  ✓ Upload complete")
  invisible(TRUE)
}

#' Download file from R2
#'
#' @param r2_path Path in R2 bucket
#' @param local_path Local destination path
#' @param bucket Bucket name (defaults to R2_BUCKET env var)
#' @param overwrite Overwrite existing local file (default: FALSE)
#' @return Invisible TRUE on success
#' @export
r2_download <- function(r2_path, local_path, bucket = r2_bucket(), overwrite = FALSE) {

  if (file.exists(local_path) && !overwrite) {
    stop(
      "Local file already exists: ", local_path, "\n",
      "Set overwrite = TRUE to replace it",
      call. = FALSE
    )
  }

  client <- r2_client()

  message(sprintf("Downloading r2://%s/%s → %s",
                  bucket, r2_path, basename(local_path)))

  # Create parent directory if needed
  dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)

  # Download file
  tryCatch({
    obj <- client$get_object(
      Bucket = bucket,
      Key = r2_path
    )

    # Write body to file
    writeBin(obj$Body, local_path)

    size_mb <- round(file.info(local_path)$size / 1024^2, 2)
    message(sprintf("  ✓ Download complete (%s MB)", size_mb))

    invisible(TRUE)

  }, error = function(e) {
    if (grepl("NoSuchKey", e$message)) {
      stop("File not found in R2: ", r2_path, call. = FALSE)
    } else {
      stop("Download failed: ", e$message, call. = FALSE)
    }
  })
}

#' List files in R2 bucket
#'
#' @param prefix Filter by prefix (e.g., "raw/eur/")
#' @param bucket Bucket name (defaults to R2_BUCKET env var)
#' @return Data frame with Key, Size, LastModified columns
#' @export
r2_list <- function(prefix = "", bucket = r2_bucket()) {

  client <- r2_client()

  result <- client$list_objects_v2(
    Bucket = bucket,
    Prefix = prefix
  )

  if (length(result$Contents) == 0) {
    message("No files found in r2://", bucket, "/", prefix)
    return(tibble::tibble(
      Key = character(),
      Size = numeric(),
      LastModified = character()
    ))
  }

  # Convert to data frame
  files <- purrr::map_dfr(result$Contents, function(obj) {
    tibble::tibble(
      Key = obj$Key,
      Size = obj$Size,
      LastModified = as.character(obj$LastModified)
    )
  })

  files <- files |>
    dplyr::mutate(
      Size_MB = round(Size / 1024^2, 2)
    ) |>
    dplyr::arrange(Key)

  files
}

#' Check if file exists in R2
#'
#' @param r2_path Path in R2 bucket
#' @param bucket Bucket name (defaults to R2_BUCKET env var)
#' @return Logical
#' @export
r2_exists <- function(r2_path, bucket = r2_bucket()) {

  client <- r2_client()

  tryCatch({
    client$head_object(
      Bucket = bucket,
      Key = r2_path
    )
    TRUE
  }, error = function(e) {
    if (grepl("404|NotFound", e$message)) {
      FALSE
    } else {
      stop("Error checking R2 file: ", e$message, call. = FALSE)
    }
  })
}

#' Delete file from R2
#'
#' @param r2_path Path in R2 bucket
#' @param bucket Bucket name (defaults to R2_BUCKET env var)
#' @return Invisible TRUE on success
#' @export
r2_delete <- function(r2_path, bucket = r2_bucket()) {

  client <- r2_client()

  message(sprintf("Deleting r2://%s/%s", bucket, r2_path))

  client$delete_object(
    Bucket = bucket,
    Key = r2_path
  )

  message("  ✓ Deleted")
  invisible(TRUE)
}
