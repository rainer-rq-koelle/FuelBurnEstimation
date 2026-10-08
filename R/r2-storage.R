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
