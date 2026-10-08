# Mac Verification Request

Hi! We've set up Cloudflare R2 for cross-machine data sharing. Could you verify the workflow from a clean local cache?

## Setup (One-Time)

1. **Pull latest code:**
   ```sh
   cd /path/to/FuelBurnEstimation
   git pull
   ```

2. **Configure `.Renviron`:**
   ```sh
   cp .Renviron.example .Renviron
   # Edit .Renviron with your favorite editor
   ```

3. **Set these variables in `.Renviron`:**
   ```r
   # Local cache directory (NOT OneDrive - just a normal local folder)
   FUELBURN_DATA_STORE=/Users/<you>/RProjects/FuelBurnEstimation/data-store
   
   # R2 credentials (get from Windows team or Cloudflare dashboard)
   R2_ACCESS_KEY_ID=9177e8163e24e0eed0124ae10bb9bc98
   R2_SECRET_ACCESS_KEY=106b56250d9e99e68c758a07f4b78d1027a1002ecd91483611c2a52e22c7a7c7
   R2_ENDPOINT=https://a861206fbbb4aa25c26a4812f360674d.r2.cloudflarestorage.com
   R2_BUCKET=paper-fuel-burn-estimation
   ```

4. **Install required R package:**
   ```sh
   Rscript -e "install.packages('paws.storage')"
   ```

## Verification Commands

Run these three commands in order:

```sh
# 1. Check R2 bucket is reachable
Rscript scripts/r2-list-files.R

# 2. Download data from R2
Rscript scripts/r2-download-data-store.R

# 3. Validate local cache
Rscript scripts/00-check-data-store.R
```

## Expected Results

### 1. `r2-list-files.R`

**Should show:**
- ✓ Bucket is reachable
- ✓ Lists 4 files:
  - `derived/eur/canonical-milestones-eur-2026-harmonized.parquet` (11.7 MB)
  - `handover/handover-2026-10-07.txt` (~0 MB)
  - `manifest/data-store-manifest-2026-10-07.csv` (~0 MB)
  - `raw/eur/EUR-canonical-milestones-summer2025.parquet` (10.0 MB)
- ✓ Total: 4 files, ~21.71 MB

### 2. `r2-download-data-store.R`

**Should show:**
- ✓ Downloads EUR raw canonical milestones (10.03 MB)
- ✓ Downloads EUR harmonized milestones (11.68 MB)
- ✓ "CHN raw" reported as "✗ not in R2" (expected - optional)
- ✓ "CHN harmonized" reported as "✗ not in R2" (expected - optional)
- ✓ Manifest and handover files downloaded
- ✓ Final message: "Download complete: 2/2 files downloaded from R2"

### 3. `00-check-data-store.R`

**Should show:**
- ✓ Folder structure: 8/8 directories OK
- ✓ EUR raw: 10.03 MB, **431,901 rows, 15 columns**
- ✓ EUR harmonized: 11.68 MB, **554,212 rows, 17 columns**
- ✓ Final message: **"All checks passed - data store ready for analysis"**

## What to Report Back

Please report:

1. **OS**: macOS version (e.g., "macOS 14.1 Sonoma")

2. **Run environment**: Terminal, RStudio, or both?

3. **FUELBURN_DATA_STORE path** (redact username if sensitive):
   ```
   Example: /Users/<redacted>/RProjects/FuelBurnEstimation/data-store
   ```

4. **Command results**: Did all three commands complete successfully?
   - [ ] `r2-list-files.R` - showed 4 files, 21.71 MB?
   - [ ] `r2-download-data-store.R` - downloaded 2/2 files?
   - [ ] `00-check-data-store.R` - "All checks passed"?

5. **Row/column counts matched?**
   - [ ] EUR raw: 431,901 rows, 15 columns?
   - [ ] EUR harmonized: 554,212 rows, 17 columns?

6. **Security check**:
   - [ ] No R2 credentials appeared in console output?
   - [ ] `.Renviron` file NOT committed to git?
   - [ ] Git status shows `.Renviron` as untracked or ignored?

## Troubleshooting

**If `r2-list-files.R` fails:**
- Check R2 credentials in `.Renviron`
- Verify `paws.storage` package is installed
- Check internet connectivity

**If downloads fail:**
- Check `FUELBURN_DATA_STORE` path exists and is writable
- Verify R2 bucket name matches exactly

**If validation fails:**
- Re-run download with: `Rscript scripts/r2-download-data-store.R`
- Check disk space (need ~25 MB free)

## Success Criteria

✅ All three scripts run without errors  
✅ Row/column counts match expected values  
✅ No credentials exposed in output  
✅ Local cache at non-OneDrive location  

Once verified, both Windows and Mac can work independently and sync via R2! 🎉
