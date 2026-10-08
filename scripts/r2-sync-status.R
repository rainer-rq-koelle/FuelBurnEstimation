#!/usr/bin/env Rscript
# Compare local data cache with the authoritative R2 manifest.

suppressPackageStartupMessages({
  library(dplyr)
  library(here)
})

source(here("R", "r2-storage.R"))

message("FuelBurnEstimation R2 Sync Status")
message("=================================\n")

data_store <- r2_data_store()
r2_ensure_data_store_dirs(data_store)

message("R2 bucket: ", r2_bucket())
message("Local data store: ", data_store)
message("Timestamp: ", Sys.time())
message("")

manifest <- tryCatch(
  r2_download_current_manifest(data_store),
  error = function(e) {
    stop(
      "Authoritative manifest is not available yet.\n",
      "Run scripts/r2-publish-manifest.R on a maintainer machine after uploading required artifacts.\n",
      "Underlying error: ", e$message,
      call. = FALSE
    )
  }
)

status <- r2_manifest_status(manifest, data_store)

message("Summary:")
print(status |> count(sync_status, required, name = "n"), n = Inf)

message("\nArtifacts:")
print(
  status |>
    select(key, required, version, sync_status, local_size_bytes, remote_size_bytes, modified_utc),
  n = Inf
)

status_file <- file.path(data_store, "handover", sprintf("r2-sync-status-%s.csv", format(Sys.time(), "%Y%m%d-%H%M%S")))
readr::write_csv(status, status_file)
message("\nStatus written: ", status_file)

if (all(status$sync_status == "current")) {
  message("\n✓ Local cache matches authoritative manifest")
  quit(status = 0)
}

message("\n⚠ Local cache is missing or differs from authoritative manifest")
quit(status = 2)
