# Mac Verification Request

Hi! We've set up Cloudflare R2 for cross-machine data sharing. Could you verify
the workflow from a clean local cache?

## Setup

1. Pull latest code:

```sh
cd /path/to/FuelBurnEstimation
git pull
```

2. Configure `.Renviron`:

```sh
cp .Renviron.example .Renviron
```

3. Set these variables in `.Renviron`:

```r
# Local cache directory (not OneDrive)
FUELBURN_DATA_STORE=/Users/<you>/RProjects/FuelBurnEstimation/data-store

# R2 credentials (share separately; never commit real credentials)
R2_ACCESS_KEY_ID=<r2-access-key-id>
R2_SECRET_ACCESS_KEY=<r2-secret-access-key>
R2_ENDPOINT=<r2-endpoint-url>
R2_BUCKET=paper-fuel-burn-estimation
```

4. Install the required R package:

```sh
Rscript -e "install.packages('paws.storage')"
```

## Verification Commands

Run these commands in order:

```sh
Rscript scripts/r2-list-files.R
Rscript scripts/r2-sync-status.R
Rscript scripts/r2-download-data-store.R
Rscript scripts/00-check-data-store.R
```

## Expected Results

`r2-list-files.R` should show the R2 bucket and about 22 MB of data artifacts,
including:

- `raw/eur/EUR-canonical-milestones-summer2025.parquet`
- `derived/eur/canonical-milestones-eur-2026-harmonized.parquet`
- `manifest/current-artifacts.csv`

`r2-sync-status.R` should read `manifest/current-artifacts.csv` and report the
required artifacts as either `current` or `missing-local`. If the local cache is
empty, `missing-local` is expected before download.

`r2-download-data-store.R` should download the two required EUR files and verify
their SHA-256 hashes against the authoritative manifest.

`00-check-data-store.R` should show:

- EUR raw: 431,901 rows, 15 columns
- EUR harmonized: 554,212 rows, 17 columns
- Final message: `All checks passed - data store ready for analysis`

## What to Report Back

Please report:

- macOS version.
- Whether you ran from Terminal, RStudio, or both.
- `FUELBURN_DATA_STORE` path, with username redacted if needed.
- Whether all four commands completed successfully.
- Whether the row/column counts matched.
- Whether any credentials appeared in console output.
- Whether `.Renviron` is ignored or untracked in Git.

## Troubleshooting

If `r2-list-files.R` fails, check R2 credentials, internet connectivity, and
that `paws.storage` is installed.

If `r2-sync-status.R` reports `missing-local`, run:

```sh
Rscript scripts/r2-download-data-store.R
```

If validation fails, rerun the download and check that the local cache path is
writable and has at least 25 MB free.
