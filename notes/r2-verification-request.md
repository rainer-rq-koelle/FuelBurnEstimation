# R2 Verification Request

This document describes the verification workflow for cross-machine data handover via Cloudflare R2.

## Verification Commands

### 1. Remote Check (R2 Bucket Status)

Check what's currently available in R2:

```sh
Rscript scripts/r2-list-files.R
```

**Expected result**: Lists all files currently in R2 bucket with sizes and timestamps.

**Status**: ✓ Should pass immediately (files uploaded from Windows)

### 2. Local Data Store Check

Verify local data store integrity:

```sh
Rscript scripts/00-check-data-store.R
```

**Expected result**: 
- Windows: ✓ All checks pass (local files exist)
- Mac: May report missing files until download completes

### 3. Sync/Download from R2

Download authoritative dataset from R2:

```sh
Rscript scripts/r2-download-data-store.R
```

**Expected result (current state)**:
- ⚠️ "Authoritative manifest not available" until proper artifacts uploaded
- Downloads available files but warns about missing authoritative manifest
- Creates local copies of available data

**Expected result (after authoritative manifest published)**:
- ✓ Downloads all files referenced in authoritative manifest
- ✓ Verifies checksums/sizes against manifest
- ✓ Creates handover summary showing successful sync

## Authoritative Manifest Requirements

For full cross-machine handover, we need:

1. **Authoritative manifest** (`manifest/authoritative-manifest.json`):
   - SHA256 checksums for all data files
   - Expected file sizes
   - Data vintage/version tags
   - Required vs optional file markers

2. **Signed handover** (`handover/handover-YYYY-MM-DD-signed.txt`):
   - Source machine verification signature
   - Timestamp and checksums
   - Data processing provenance

## Current Status

### Windows → R2 ✓
- EUR raw canonical: 10.03 MB ✓
- EUR harmonized: 11.68 MB ✓
- Basic manifest: CSV format ✓
- Basic handover: TXT format ✓

### Missing for Full Handover
- ⚠️ Authoritative manifest with checksums
- ⚠️ Signed handover verification
- ⚠️ CHN data artifacts (optional)

## Next Steps

1. Run verification commands on Windows (source machine)
2. Upload authoritative manifest to R2
3. Run verification commands on Mac (destination machine)
4. Verify handover completeness

## Test Scenario

**Windows (source):**
```sh
# Verify local data
Rscript scripts/00-check-data-store.R

# Check R2 remote
Rscript scripts/r2-list-files.R

# Upload if needed
Rscript scripts/r2-upload-data-store.R
```

**Mac (destination):**
```sh
# Check what's available in R2
Rscript scripts/r2-list-files.R

# Download data store
Rscript scripts/r2-download-data-store.R

# Verify local data
Rscript scripts/00-check-data-store.R
```

**Success criteria:**
- ✓ Both machines see same files in R2
- ✓ Both machines have valid local data stores
- ✓ Manifests match across machines
- ✓ Handover files track both machines
