# W2 CHN Data Validation — Findings Summary

**Run ID:** W2-2026-10-09-001  
**Completed:** 2026-10-12T16:00:00Z  
**Worker:** Claude Sonnet 4.5

## Critical Findings

### 1. Distance Calculation — Cause Unknown

**Observation:** 9,573 of 52,171 non-zero-duration phase records (18.3%) show implied speed >700kt.

**Examples:** TAXI_OUT 7,660 NM in 0.033 min → 13.7M kt implied speed.

**Code inspection:** Helper functions (`R/canonical-fuel-milestones.R` lines 669, 724, 991) calculate phase distance as `END_DIST_FLOWN_NM - START_DIST_FLOWN_NM` (cumulative difference), which is the correct increment calculation.

**Cause:** Unknown until source QAR coordinate records and batch-producer versions are checked. Hypotheses include coordinate scaling errors, large gaps, or unit misinterpretation in upstream processing, but root cause cannot be determined from processed data alone.

**Impact:**  
- ❌ ALL distance-dependent metrics invalid (kg/NM, stage-length context)
- ✅ Time/fuel metrics unaffected (duration/fuel calculations independent of coordinates)

### 2. Missing ALDT — Batch/Type Pattern

**Observation:** 1,190 flights (18.5%) missing ALDT milestone.

**Patterns:**
- By batch: output4 (70%), output14 (50%), output1/2/13 (37-45%)
- By type: C919 (100%, n=587), B737-MAX (100%, n=22), B737-800/700 (33-40%)
- By route: ZSSS-ZPPP (97.5%)

**Impact:**  
- ⚠️ ALDT-dependent phases (LTO_APPROACH_LANDING, TAXI_IN, RUNWAY_EXIT) have 18.5% exclusion
- ⚠️ Limits DESCENT phase presence to 5,226 flights (81.4%)

### 3. Fuel Integration — Plausibility Checks

**Observation:** All aircraft types show burn rates within expected ranges:
- Narrow-body: 2,400-3,200 kg/h (expected 2,000-3,500 kg/h)
- Wide-body: 5,300-7,000 kg/h (expected 5,000-8,000 kg/h)

**Note:** These are plausibility checks against aircraft-type references, not independent fuel integration validation.

## Phase-Specific Eligibility

**Flight-Level Summary (corrected):**
- Total flights: 6,421
- Has CLIMB: 6,398 (99.6%)
- Has CRUISE: 6,399 (99.7%)
- Has DESCENT: 5,226 (81.4%) — limited by missing TOD/ALDT
- **Airborne eligible (CLIMB+CRUISE+DESCENT all present and valid): 5,226 flights (81.4%)**

**Phase-Level Eligibility:**

| Phase | ALDT-Dependent | Eligible | Total | % Eligible |
|-------|----------------|----------|-------|------------|
| CLIMB | No | 6,398 | 6,398 | 100% |
| CRUISE | No | 5,226 | 6,399 | 81.7% |
| DESCENT | No | 5,226 | 5,226 | 100% |
| LTO_APPROACH_LANDING | Yes | 5,218 | 5,231 | 99.8% |
| TAXI_IN | Yes | 5,231 | 6,421 | 81.5% |
| TAXI_OUT | No | 6,392 | 6,421 | 99.5% |
| LTO_CLIMB_OUT | No | 5,653 | 6,398 | 88.4% |
| TAKE_OFF_ROLL | No | 6,420 | 6,420 | 100% |
| RUNWAY_EXIT | Yes | 5,217 | 5,217 | 100% |

**Distance eligibility:** 0 flights (0%) — all invalid pending coordinate investigation.

**Explanation of 5,226:** Airborne eligibility requires CLIMB, CRUISE, and DESCENT all present AND eligible. DESCENT rows were emitted for only 5,226 flights despite 6,399 TOD milestones and 5,231 ALDT milestones existing in the data. The 1,173-flight gap between TOD milestones (6,399) and DESCENT rows (5,226) is unexplained and requires investigation. DESCENT row presence becomes the limiting factor for airborne eligibility.

## Batch Producer Version

**Status:** UNKNOWN

Processing summaries (`data-incoming/.../outputN/PROCESSING-SUMMARY.txt`) show processing dates 2026-10-08 but no helper version identifier. Git history suggests likely commit 68b9f8b (2026-10-08) "Handle CHN flights without level segments" or later, but exact version per batch cannot be confirmed without CAUC documentation.

## Outputs

**Aggregate summaries (in GitHub):**
- 11 diagnostic CSVs (speed, ALDT, fuel analyses)
- 3 corrected eligibility summaries
- Validation script, eligibility script
- This summary, corrected worker handoff

**Flight-level flags (local package, pending R2 upload):**
- `local-package/phase-eligibility-flags.csv` (54,131 phase records)
- `local-package/flight-eligibility-flags.csv` (6,421 flights)
- Proposed R2 location: `derived/chn/study-runs/W2-2026-10-09-001/`

**R2 upload status:** PENDING (credentials unavailable)

## Data Delivery Status

**NOT COMPLETE** — Flight-level eligibility flags exist locally but have not been uploaded to R2 and verified. Data delivery is PENDING upload and hash verification. W3 cannot retrieve the required flags until R2 upload completes.

## Recommendations

**Immediate:** Mark distance metrics invalid in all documentation. Use 5,226 airborne-eligible flights for time/fuel analyses.

**CAUC investigation:** Check source QAR coordinate records and batch-producer versions to diagnose distance anomaly root cause.

**R2 upload:** When credentials available, upload phase/flight eligibility parquets, verify stored hashes, complete data delivery.
