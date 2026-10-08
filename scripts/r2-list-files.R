#!/usr/bin/env Rscript
# List files in Cloudflare R2 bucket

suppressPackageStartupMessages({
  library(here)
})

source(here("R", "r2-storage.R"))

message("R2 Bucket Contents")
message("==================\n")
message("Bucket: ", r2_bucket())
message("Timestamp: ", Sys.time())
message("\n")

files <- r2_list()

if (nrow(files) == 0) {
  message("Bucket is empty.")
  message("\nUpload files with: Rscript scripts/r2-upload-data-store.R")
} else {
  message("Files in bucket:\n")
  print(files)

  total_mb <- sum(files$Size_MB)
  message("\nTotal: ", nrow(files), " files, ", round(total_mb, 2), " MB")
}
