# China-Europe Report: Fuel Burn Data Request

**Superseded note:** This request note is retained as project history for the QAR exchange. It was superseded during the report run by the implemented fuel-burn workflow documented in `../80-study-fuel-burn-technical-note.qmd` and by the final topic-study inputs under `../data/fuel-burn-study/topic-study/`. Use it only to recall the original data request and assumptions.

**To:** Lingling / China Eastern Airlines  
**From:** China-Europe Report Team  
**Date:** 2025-05-29  
**Topic:** QAR Data Processing for Fuel Burn Comparison Chapter

---

## Background

We are developing a fuel burn comparison section for the third edition of the China-Europe operational performance comparison report. The section will compare flight phase fuel consumption patterns between representative Chinese and European city pairs.

Based on the available China Eastern Airlines July 2025 data you mentioned, we have identified optimal airport pairs that match our European comparison routes by distance band.

## Data Request

### Airport Pairs Needed

Please extract and process QAR data for the following route pairs:

| Distance Band | Route Pair | Great Circle Distance | Expected Monthly Flights |
|---------------|------------|----------------------|--------------------------|
| **Short** | ZBAA-ZSSS / ZSSS-ZBAA | 1,076 km / 581 NM | ~1,000 |
| | *(Beijing Capital ⟷ Shanghai Hongqiao)* | | |
| **Medium** | ZLXY-ZSSS / ZSSS-ZLXY | 1,229 km / 664 NM | ~700 |
| | *(Xi'an Xianyang ⟷ Shanghai Hongqiao)* | | |
| **Medium (fallback)** | ZGGG-ZSSS / ZSSS-ZGGG | 1,176 km / 635 NM | ~790 |
| | *(Guangzhou ⟷ Shanghai Hongqiao)* | | |
| **Long** | ZPPP-ZSSS / ZSSS-ZPPP | 1,925 km / 1,039 NM | ~500 |
| | *(Kunming ⟷ Shanghai Hongqiao)* | | |

### Priority

Please process:
1. ✅ **Short band:** ZBAA-ZSSS / ZSSS-ZBAA (highest priority)
2. ✅ **Medium band:** ZLXY-ZSSS / ZSSS-ZLXY (preferred)
   - If ZLXY data is difficult to extract or has coverage issues, please use **ZGGG-ZSSS / ZSSS-ZGGG** as the medium-band fallback
3. ✅ **Long band:** ZPPP-ZSSS / ZSSS-ZPPP

### Time Period

- **Preferred:** July 2025 (to match European summer sample)
- **Alternative:** Any representative month from 2025 with good coverage

### QAR File Requirements

Each QAR CSV file should contain:

**Required columns:**
- `TIME` - timestamp (HH:MM:SS format)
- `LATP`, `LONP` - latitude, longitude
- `ALT_STD` - standard altitude (feet)
- `FF1C`, `FF2C` - fuel flow per engine (kg/h)

**Optional but helpful:**
- `FF3C`, `FF4C` - additional engines (if 3/4-engine aircraft)
- `FLIGHT_PHASE` - raw phase code from QAR system
- `IASC` - indicated airspeed (knots)
- `GS` - ground speed (knots)

**File organization:**
- One CSV file per flight
- Standard China Eastern filename convention

---

## Processing Script Provided

We have prepared a **standalone R script** that will process your QAR files and generate the standardized outputs needed for the report chapter.

### Script: `HELPER-FOR-LINGLING-fuel-burn-processing.R`

**What it does:**
1. Reads all QAR CSV files from a folder (or ZIP file)
2. Detects flight phases using harmonized ICAO methodology
3. Calculates fuel burn per phase
4. Detects and corrects fuel flow spikes
5. Measures climb/descent smoothness
6. Generates altitude profile plots
7. Produces standardized output files

### How to Run

**Option 1: Command line**
```bash
Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R <input_folder> <output_folder>
```

**Example:**
```bash
Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R ./qar-july-2025 ./output-fuel-burn
```

**Option 2: Interactive mode (RStudio)**
```r
source("HELPER-FOR-LINGLING-fuel-burn-processing.R")
# Follow prompts to enter paths
```

**Option 3: R Console with manual paths**
```r
source("HELPER-FOR-LINGLING-fuel-burn-processing.R")
# Script will ask for input/output paths interactively
```

### Prerequisites

The script will automatically install required R packages:
- `arrow` (for efficient data handling)
- `dplyr` (data manipulation)
- `readr` (CSV reading)
- `purrr` (iteration)
- `data.table` (fast CSV reading)
- `zoo` (time series smoothing)

All packages are available from standard CRAN repository.

### Input Preparation

You can provide QAR files as:
1. ✅ Folder with CSV files
2. ✅ ZIP file containing CSV files
3. ✅ Folder containing multiple ZIP files (nested extraction supported)

The script will recursively find all CSV files.

---

## Expected Outputs

After processing, the output folder will contain:

### Main Outputs (for report integration)

1. **`CHN-canonical-milestones.parquet`** / **`.csv`**
   - Flight milestone snapshots (takeoff, top of climb, top of descent, etc.)
   - Used for detailed phase analysis

2. **`CHN-phase-summaries.csv`**
   - Fuel burn per flight phase
   - Columns: `SOURCE_UID`, `FLTID`, `ADEP`, `ADES`, `TYPE`, `PHASE`, `DURATION_MIN`, `FUEL_KG`, `DISTANCE_NM`

3. **`CHN-phase-level-descriptors.csv`**
   - Climb/descent smoothness metrics
   - Level time, level share, vertical rate statistics

### Quality Control Outputs

4. **`CHN-qar-fuel-flow-qc.csv`**
   - Fuel flow spike detection report
   - Shows raw vs. cleaned fuel totals per flight

5. **`CHN-flight-phase-code-diagnostics.csv`**
   - Maps raw `FLIGHT_PHASE` codes to harmonized phases
   - Helps verify phase detection accuracy

6. **`profile-plots/*.png`**
   - Altitude profile visualizations (sample flights)
   - Useful for visual verification of milestone detection

7. **`PROCESSING-SUMMARY.txt`**
   - Processing statistics
   - Route pair coverage summary
   - File inventory

---

## What to Send Back

Please send the **entire output folder** (ZIP it if convenient):
- All CSV and parquet files
- The `profile-plots` subfolder
- The `PROCESSING-SUMMARY.txt`

This will allow us to:
1. Integrate the data into the report chapter
2. Verify data quality
3. Generate comparison visualizations
4. Include Chinese flight phase fuel burn patterns alongside European comparators

---

## Timeline

Please process and send the data at your earliest convenience. We will integrate it into the fuel burn chapter and share a draft section for your review.

---

## Questions or Issues?

If you encounter any issues:
1. Check `PROCESSING-SUMMARY.txt` for error messages
2. Review a few `profile-plots/*.png` to verify milestone detection looks reasonable
3. Contact us with:
   - The error message or issue description
   - A sample QAR filename
   - The `PROCESSING-SUMMARY.txt` file

We can help troubleshoot or adjust the processing script if needed.

---

## Technical Background

The processing methodology is documented in the report's technical note (Chapter 80). Key points:

- **Phase detection:** Uses ICAO vertical flight efficiency convention (GANP/PEG methodology)
- **Top of climb/descent:** Detected from altitude profile smoothing + vertical rate analysis
- **Fuel flow QC:** Isolated spikes are detected and smoothed (raw values preserved for audit)
- **Harmonization:** Chinese QAR and European G2G data processed to common "milestone" format

This ensures the Chinese and European fuel burn data are directly comparable.

---

## Summary

**What we need:**
- QAR data for ZBAA-ZSSS, ZLXY-ZSSS (or ZGGG-ZSSS), ZPPP-ZSSS and reverse directions
- July 2025 or representative month

**What we provide:**
- Ready-to-run processing script
- Automated quality control
- Standardized outputs

**What you do:**
1. Extract QAR files for the requested routes
2. Run the provided script
3. Send back the output folder

Thank you for your collaboration on this important comparison work!

---

**Report Team Contact:**  
[Insert contact details here]
