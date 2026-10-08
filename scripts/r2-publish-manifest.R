#!/usr/bin/env Rscript
# Publish authoritative manifest for registered R2 artifacts.

suppressPackageStartupMessages({
  library(dplyr)
  library(here)
})

source(here("R", "r2-storage.R"))

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args
if (any(args %in% c("-h", "--help", "help"))) {
  cat(
    paste(
      "Usage:",
      "  Rscript scripts/r2-publish-manifest.R [--dry-run]",
      "",
      "Publishes manifest/current-artifacts.csv and an archived manifest copy.",
      "Refuses to publish when required registered artifacts are missing locally.",
      sep = "\n"
    ),
    "\n"
  )
  quit(status = 0)
}

unknown_args <- setdiff(args, "--dry-run")
if (length(unknown_args) > 0) {
  stop("Unknown argument(s): ", paste(unknown_args, collapse = ", "), call. = FALSE)
}

data_store <- r2_data_store()
r2_ensure_data_store_dirs(data_store)

message("Publishing R2 authoritative manifest")
message("====================================\n")
message("Local data store: ", data_store)
message("R2 bucket: ", r2_bucket())
message("Dry run: ", dry_run)
message("")

manifest <- r2_build_manifest(data_store, require_required = TRUE, include_optional = TRUE)
manifest_path <- r2_write_manifest(manifest, data_store)

message("Manifest contents:")
print(manifest |> select(key, source, stage, required, version, size_bytes, sha256), n = Inf)
message("")
message("Local manifest: ", manifest_path)

if (dry_run) {
  message("\nDry run complete. No R2 objects changed.")
  quit(status = 0)
}

r2_upload(manifest_path, "manifest/current-artifacts.csv")

archive_key <- file.path(
  "manifest",
  "archive",
  sprintf("artifacts-%s.csv", format(Sys.time(), "%Y%m%d-%H%M%S"))
)
r2_upload(manifest_path, archive_key)

message("\n✓ Authoritative manifest published")
message("  current: manifest/current-artifacts.csv")
message("  archive: ", archive_key)
