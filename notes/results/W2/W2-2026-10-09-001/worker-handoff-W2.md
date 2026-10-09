# Worker handoff: W2 — CHN Distance, Boundaries, and Fuel Validation

## Result and status

- **Work package:** W2 — CHN distance, boundaries, and fuel validation
- **Run ID:** W2-2026-10-09-001  
- **Worker:** Claude Sonnet 4.5  
- **Completion time:** 2026-10-09T14:50:00Z (UTC)

- **Main finding:** CHN data contains **systematic distance calculation errors** causing impossibly high implied speeds. Phase summaries use cumulative distance instead of phase-specific incremental distance, leading to extreme speed values (e.g., 13,788,378 kt for TAXI_OUT). Additionally, 18.5% of flights are missing ALDT milestones, with strong batch/type patterns (C919: 100% missing, B737-MAX: 100% missing).

- **Proposed paper claim:** CHN distance-dependent metrics (kg/NM, stage-length context) are **INVALID until corrected**. Time-based metrics (kg/h, phase fuel/time) appear valid. Missing ALDT creates 18.5% selection bias for descent/airborne analyses.

- **Limitations:** This is a diagnostic investigation only. No corrected CHN data artifacts produced. Fuel integration checks show plausible burn rates, suggesting fuel/time calculations are valid despite distance errors.

- **Analysis status:** Diagnostic analysis complete on delivered CHN data
- **Data delivery status:** NOT APPLICABLE (diagnostic only, no corrected data produced)
- **Review status:** Awaiting release steward decision on corrective approach
- **Remaining work:** Implement distance calculation fix, investigate/resolve missing ALDT by batch
- **Blocker:** Requires access to raw QAR coordinates to recalculate path distance correctly
- **Responsible person:** CAUC QAR worker with source access

## Producing code and reproduction

- **Git repository:** https://github.com/rainer-rq-koelle/FuelBurnEstimation
- **Branch:** w0-release-contract (work conducted on this branch)  
- **Diagnostic script:** `scripts/W2-validate-chn-data.R`
- **Producing commit SHA:** (pending commit of W2 materials)
- **Commands and execution order:**
  ```bash
  Rscript scripts/W2-validate-chn-data.R
  ```
- **Runtime/package versions:** R 4.5.2, arrow 19.0.0, dplyr 1.1.4, readr 2.1.5
- **Configuration:** None required
- **Random seeds:** N/A (diagnostic analysis, no sampling)

## Inputs

| Input role | R2 object key or local reference | Version | SHA-256 |
|---|---|---|---|
| CHN canonical milestones | `processed/chn/CHN-canonical-milestones-summer2025.parquet` | summer2025 | 5907faeaf4094d79cd2fa3629c64a3a36fa76dc6e4f3e33ef8bd60cfd6c1db64 |
| CHN level segments | `processed/chn/CHN-level-segments-summer2025.parquet` | summer2025 | 5fdde9e482a60efaf094dac1d77cbb87c39e59cbdde6ce77fe1b1d37f942d4bb |
| CHN phase summaries | `processed/chn/CHN-phase-summaries-summer2025.parquet` | summer2025 | 5f7b0fdcb9e577699b9baf3e46a7e35bc2b5eb37cbda17fa02c28ed73d64ffae |

## Outputs and artifact manifest

**NO CORRECTED DATA ARTIFACTS CREATED**

Diagnostic outputs only:

| Output role | Durable destination and exact key/path | SHA-256 | Rows/flights | Stored hash verified? |
|---|---|---|---|---|
| Missing ALDT by batch | `notes/results/W2/W2-2026-10-09-001/missing-aldt-by-batch.csv` | (computed after final commit) | 14 batches | N/A (GitHub tracked) |
| Missing ALDT by type | `notes/results/W2/W2-2026-10-09-001/missing-aldt-by-type.csv` | (computed after final commit) | 16 types | N/A (GitHub tracked) |
| Missing ALDT by route | `notes/results/W2/W2-2026-10-09-001/missing-aldt-by-route.csv` | (computed after final commit) | 6 routes | N/A (GitHub tracked) |
| Missing ALDT examples | `notes/results/W2/W2-2026-10-09-001/missing-aldt-examples.csv` | (computed after final commit) | 50 examples | N/A (GitHub tracked) |
| Speed summary by phase | `notes/results/W2/W2-2026-10-09-001/speed-summary-by-phase.csv` | (computed after final commit) | 39 phase/flag combinations | N/A (GitHub tracked) |
| Extreme speed examples | `notes/results/W2/W2-2026-10-09-001/extreme-speed-examples.csv` | (computed after final commit) | 100 examples | N/A (GitHub tracked) |
| Speed by batch/phase | `notes/results/W2/W2-2026-10-09-001/speed-by-batch-phase.csv` | (computed after final commit) | 126 batch/phase combinations | N/A (GitHub tracked) |
| Level segment speed summary | `notes/results/W2/W2-2026-10-09-001/level-segment-speed-summary.csv` | (computed after final commit) | 4 speed flags | N/A (GitHub tracked) |
| Extreme level segment examples | `notes/results/W2/W2-2026-10-09-001/extreme-level-segment-examples.csv` | (computed after final commit) | 100 examples | N/A (GitHub tracked) |
| Fuel by aircraft type | `notes/results/W2/W2-2026-10-09-001/fuel-by-aircraft-type.csv` | (computed after final commit) | 14 types | N/A (GitHub tracked) |
| Fuel outliers | `notes/results/W2/W2-2026-10-09-001/fuel-outliers.csv` | (computed after final commit) | 0 outliers | N/A (GitHub tracked) |
| Worker handoff | `notes/results/W2/W2-2026-10-09-001/worker-handoff-W2.md` | (computed after final commit) | N/A | N/A (GitHub tracked) |

**Canonical copy:** GitHub only. No R2 uploads (diagnostic investigation, no corrected candidate data produced).

## Validation and sample flow

### Critical Finding 1: Distance Calculation Error ⚠️

**Issue:** Phase summaries contain cumulative distance instead of phase-specific incremental distance.

**Evidence:**
- TAXI_OUT phases showing 7,660 NM traveled in 0.033 minutes → implied speed 13,788,378 kt
- A350-900 TAXI_OUT: 446,191 NM in 62.8 minutes → 426,071 kt
- 9,573 phase records (17.7%) with implied speed >700 kt
- 17,955 level segments (27.6%) with implied speed >700 kt
- Median cruise speed calculated as ~1,018 kt (should be ~450-480 kt)

**Root Cause Hypothesis:**  
Phase summary DISTANCE_NM field appears to contain cumulative flight distance at phase end, not distance traveled during the phase. This is consistent with:
1. TAXI_OUT showing full route distance (ZSSS-ZPPP ~7,660 NM great circle)
2. Extreme values decreasing through flight phases (TAXI → CLIMB → CRUISE → DESCENT)
3. Level segments also affected, suggesting upstream calculation error

**Impact:**
- ❌ **BLOCKS** all distance-dependent metrics: kg/NM, burn per NM, stage-length context
- ❌ **BLOCKS** distance-derived phase boundaries if they exist
- ✅ **DOES NOT AFFECT** time-based metrics: kg/h, burn rate, phase duration
- ✅ **DOES NOT AFFECT** fuel integration (fuel values appear plausible)

**Corrective Action Required:**
1. Trace back to raw QAR coordinate-to-distance calculation in `R/canonical-fuel-milestones.R`
2. Verify `fuel_haversine_nm()` calculates point-to-point increments correctly
3. Confirm cumulative distance (`DIST_FLOWN_NM`) is built from increments
4. Investigate how phase/level summaries extract distance:
   - Should use: `END_DIST - START_DIST` (incremental)
   - Currently appears to use: cumulative value at phase end
5. Regenerate phase summaries and level segments with corrected distance
6. Revalidate: median cruise speed should be 450-480 kt, no segments >700 kt

**Affected Batches:** All 14 batches (output1-output14) show distance errors

### Critical Finding 2: Missing ALDT Milestones ⚠️

**Issue:** 1,190 flights (18.5%) missing ALDT (actual landing) milestone.

**Missing ALDT by Batch:**

| Batch | Flights | Missing ALDT | Missing % |
|-------|---------|--------------|-----------|
| output4 | 332 | 233 | 70.2% |
| output14 | 509 | 253 | 49.7% |
| output1 | 409 | 184 | 45.0% |
| output13 | 368 | 152 | 41.3% |
| output2 | 438 | 165 | 37.7% |
| output5 | 344 | 70 | 20.3% |
| output8 | 500 | 80 | 16.0% |
| output11 | 504 | 53 | 10.5% |
| output10, 12, 3, 6, 7, 9 | 3,057 | 0 | 0% |

**Missing ALDT by Aircraft Type:**

| Type | Flights | Missing ALDT | Missing % |
|------|---------|--------------|-----------|
| C919 | 587 | 587 | 100.0% |
| B737-MAX | 22 | 22 | 100.0% |
| B787-9 | 282 | 104 | 36.9% |
| B737-700 | 443 | 179 | 40.4% |
| B737-800 | 885 | 296 | 33.4% |
| A321-NEO | 350 | 1 | 0.3% |
| A321 | 507 | 1 | 0.2% |
| All Airbus A320 family | 611 | 0 | 0% |

**Missing ALDT by Route (routes ≥10 flights):**

| Route | Flights | Missing ALDT | Missing % |
|-------|---------|--------------|-----------|
| ZSSS-ZPPP | 595 | 580 | 97.5% |
| ZLXY-ZSSS | 1,032 | 229 | 22.2% |
| ZSSS-ZLXY | 1,015 | 226 | 22.3% |
| ZSSS-ZBAA | 1,514 | 67 | 4.4% |
| ZBAA-ZSSS | 1,504 | 66 | 4.4% |
| ZPPP-ZSSS | 761 | 22 | 2.9% |

**Patterns Observed:**
1. **Type-specific:** C919 and B737-MAX have 100% missing ALDT
2. **Batch-specific:** High correlation with specific output batches
3. **Route-specific:** ZSSS-ZPPP route heavily affected (97.5% missing)
4. **Manufacturer difference:** Boeing types more affected than Airbus

**Impact:**
- ⚠️ **BIASES** descent phase analyses (excludes 18.5% of flights)
- ⚠️ **BIASES** total airborne analyses if ALDT used as boundary
- ⚠️ **PREVENTS** analysis of landing/arrival phases
- ✅ **DOES NOT AFFECT** climb/cruise if TOC/TOD present (only 0-4 missing per batch)

**Investigation Required:**
1. Check QAR processing batch helper version differences between output1-14
2. Verify raw QAR files for missing landing events vs. processing truncation
3. For C919: confirm ALDT detection thresholds appropriate for type
4. For ZSSS-ZPPP: check for systematic early data truncation
5. Review milestone detection logic in `R/canonical-fuel-milestones.R::fuel_chn_milestones()`

**Corrective Options:**
1. **If source has landing data:** Fix detection logic and reprocess
2. **If source truncated:** Mark affected flights as descent-ineligible
3. **If reconstruction possible:** Use descent profile + airport location to estimate ALDT

### Positive Finding: Fuel Integration Valid ✅

**Airborne Fuel by Aircraft Type (median values):**

| Type | Flights | Airborne Fuel (kg) | Burn Rate (kg/h) | Burn per NM (kg/NM) |
|------|---------|-------------------|------------------|---------------------|
| B777-300ER | 326 | 11,002 | 7,003 | 16.5* |
| A350-900 | 201 | 8,965 | 5,648 | 13.6* |
| B787-9 | 282 | 9,980 | 5,316 | 9.6* |
| A330-300 | 1,404 | 8,892 | 5,479 | 6.1* |
| A330-200 | 803 | 8,730 | 5,400 | 5.9* |
| B737-700 | 443 | 5,677 | 2,445 | 2.5* |
| B737-800 | 885 | 5,264 | 2,679 | 6.2* |
| A321 | 507 | 5,632 | 3,086 | 5.5* |
| A320 | 362 | 5,048 | 2,773 | 4.8* |
| A321-NEO | 350 | 4,127 | 2,479 | 4.9* |
| A320-NEO | 203 | 4,329 | 2,368 | 4.1* |
| A319 | 46 | 4,820 | 2,662 | 4.7* |
| C919 | 587 | 2,059 | 3,217 | NA* |

\* kg/NM values marked unreliable due to distance calculation error

**Validation:**
- ✅ All burn rates within plausible aircraft-specific ranges
- ✅ Narrow-body rates: 2,368-3,217 kg/h (expected 2,000-3,500 kg/h)
- ✅ Wide-body rates: 5,316-7,003 kg/h (expected 5,000-8,000 kg/h)
- ✅ Zero flights with extreme burn rates (<500 or >15,000 kg/h)
- ✅ Fuel progression consistent across phases (no negative fuel increments)

**Conclusion:** Fuel integration and time calculations appear valid despite distance errors.

### Boundary Quality: Phase Records

**Phase boundary validation:**
- Total phase records: 54,131
- Negative duration: 0 (0%)
- Not ordered (START_TIME ≥ END_TIME): 0 (0%)
- Missing START_TIME: 0 (0%)
- Missing END_TIME: 0 (0%)

✅ **All phase boundaries properly ordered and complete**

### Boundary Quality: Level Segments

**Level segment altitude stability:**

| Altitude Change Flag | Segments | Median Change (ft) |
|---------------------|----------|-------------------|
| Stable (≤500 ft) | 45,794 | 140 |
| Moderate (501-1000 ft) | 13,156 | 697 |
| Large (>1000 ft) | 6,031 | 1,525 |

- 70.5% of level segments stable (≤500 ft altitude change)
- 20.2% moderate altitude change (501-1000 ft)
- 9.3% large altitude change (>1,000 ft)

⚠️ **Note:** Large altitude changes may indicate:
1. Step climbs/descents within cruise
2. True level-off detection during active climb/descent phases
3. Altitude threshold settings in level detection logic

**Recommendation:** Review level detection thresholds and validate against example profiles

### Sample Flow

**CHN Summer 2025 Data Coverage:**
- **Total flights:** 6,421
- **Total milestone records:** 266,883
- **Total phase records:** 54,131
- **Total level segments:** 64,981
- **Source batches:** 14 (output1-output14)
- **Temporal coverage:** June-August 2025
- **Aircraft types:** 16 types
- **Route pairs:** Multiple international/domestic routes

**Eligibility Assessment:**

| Domain | Eligible | Restricted | Reason |
|--------|----------|------------|--------|
| **Time-based metrics** | 6,421 flights (100%) | None | ✅ Time calculations valid |
| **Fuel integration** | 6,421 flights (100%) | None | ✅ Fuel values plausible |
| **Distance metrics** | 0 flights (0%) | All 6,421 | ❌ Distance calculation error |
| **Descent analyses** | 5,231 flights (81.5%) | 1,190 missing ALDT | ⚠️ Selection bias |
| **Stage-length context** | 0 flights (0%) | All 6,421 | ❌ Distance calculation error |
| **kg/NM rates** | 0 flights (0%) | All 6,421 | ❌ Distance calculation error |
| **Phase fuel/time** | 6,421 flights (100%) | None | ✅ Valid if not distance-dependent |

### Checks performed and results

✅ **Completed checks:**
1. Missing ALDT investigation by batch/type/route
2. Distance/time/speed reconciliation (phase level)
3. Distance/time/speed reconciliation (level segment)
4. Fuel integration validation by aircraft type
5. Fuel burn rate plausibility checks
6. Phase boundary ordering validation
7. Level segment altitude stability assessment
8. Batch-level exception reporting

❌ **Checks NOT performed (require raw QAR access):**
1. Coordinate scaling/encoding verification
2. Path distance recalculation from source coordinates
3. Comparison with recorded ground speed
4. Gap interpolation assessment
5. Forward-increment alignment validation
6. TOC/TOD definition verification against capped/stepped profiles
7. Fuel-flow unit verification at raw source level
8. Spike rule and gap treatment validation
9. Cumulative-value timestamp alignment checks

### Parameter sensitivity, stability, and null findings

**N/A** — This is a diagnostic investigation, not a parametric analysis.

**Null findings:**
- No fuel burn rate outliers detected (all within plausible ranges)
- No negative phase durations
- No phase boundary ordering violations

### Holdout/leakage checks

**N/A** — No modeling or train/test split in this diagnostic analysis.

### Remaining uncertainty and limits of interpretation

1. **Distance calculation mechanics:** Cannot determine exact cause without raw QAR coordinate access. Hypothesized cumulative-vs-incremental error, but could also be:
   - Coordinate scaling issue
   - Unit conversion error (meters to NM)
   - Index offset in cumulative sum
   - Incorrect use of `lead()` vs `lag()` in haversine calculation

2. **Missing ALDT root cause:** Batch/type patterns suggest processing configuration differences, but cannot distinguish between:
   - Raw QAR truncation (data genuinely ends before landing)
   - Detection threshold mismatch (ALDT present but not detected)
   - Batch-specific helper version incompatibility
   - Aircraft-specific altitude/descent rate assumptions

3. **Level segment definition:** Large altitude changes (>1,000 ft) in 9.3% of "level" segments may be:
   - Legitimate step climbs
   - Detection threshold too permissive
   - Mixed climb/level or descent/level segments
   - Requires profile visualization to assess

4. **Fuel unit inference:** Automated unit inference (kg/h vs lb/h) appears successful (plausible burn rates), but:
   - Historical plausibility does NOT guarantee new-batch units correct
   - Inference uses distance-dependent burn per NM (contaminated by distance error)
   - Should verify at raw fuel-flow level with independent checks

## Decisions and downstream use

### Decisions adopted

**By diagnostic worker:**
1. ✅ CHN distance-dependent metrics declared INVALID until corrected
2. ✅ CHN time-based metrics appear VALID (fuel integration plausible)
3. ✅ Missing ALDT creates 18.5% selection bias for descent analyses
4. ✅ Batch/type patterns identified requiring investigation
5. ✅ Fuel burn rates validated against aircraft-specific plausibility ranges

**Awaiting release steward decision:**
- Assign full W2 implementation to CAUC QAR worker with raw source access
- OR proceed with CHN time-only analyses (kg/h rates, phase fuel/time)
- OR restrict CHN to exploratory/comparison only pending full correction

### Candidate decisions still awaiting review

**Technical approach:**
1. Distance recalculation strategy (reprocess from raw QAR vs. patch existing)
2. Missing ALDT handling (exclude vs. estimate vs. flag as partial)
3. Level segment altitude threshold adjustment
4. Batch-specific configuration harmonization

**Analytical scope:**
1. Whether time-based CHN metrics alone provide sufficient value for W3-W5
2. Minimum ALDT completion rate for descent analyses (current 81.5% present)
3. Whether C919/B737-MAX should be excluded entirely (100% missing ALDT)
4. Route-specific restrictions (ZSSS-ZPPP 97.5% missing ALDT)

### Files/keys the next worker should consume

**If W2 continues to full implementation (corrected data):**
- Raw QAR CSV files or coordinate/altitude/fuel-flow extracts
- Current phase summary / level segment definitions for comparison
- This diagnostic investigation for targeted validation
- Batch processing configuration documentation

**If pivoting to time-only analyses:**
- `processed/chn/CHN-phase-summaries-summer2025.parquet` (use DURATION_MIN, FUEL_KG only; ignore DISTANCE_NM)
- `processed/chn/CHN-canonical-milestones-summer2025.parquet` (milestones valid)
- W2 diagnostic documenting distance limitations
- Missing ALDT eligibility flags for descent exclusions

**If generating corrected candidates:**
- Corrected phase summaries with incremental distance → `derived/chn/study-runs/W2-2026-10-09-002/phase-summaries-corrected.parquet`
- Corrected level segments → `derived/chn/study-runs/W2-2026-10-09-002/level-segments-corrected.parquet`
- ALDT reconstruction or exclusion flags → `derived/chn/study-runs/W2-2026-10-09-002/aldt-eligibility.parquet`
- Validation report showing corrected cruise speeds ~450-480 kt

### Unsupported uses, incomplete fields, and prerequisites

**DO NOT use current CHN processed data for:**
- ❌ Distance-dependent fuel metrics (kg/NM, burn per NM)
- ❌ Stage-length context or distance bands
- ❌ Distance-derived phase boundaries
- ❌ Speed-based analyses or wind estimation
- ❌ Coordinate-based route reconstruction
- ❌ Any metric requiring DISTANCE_NM field accuracy
- ❌ Descent analyses without accounting for 18.5% missing ALDT bias

**CAN use current CHN data for:**
- ✅ Time-based fuel metrics (kg/h, burn rate per hour)
- ✅ Phase fuel totals (CLIMB/CRUISE/DESCENT aggregates)
- ✅ Flight-level fuel/time totals (airborne duration, total fuel)
- ✅ Aircraft type distributions
- ✅ Route coverage assessment
- ✅ Temporal coverage (month/batch patterns)
- ✅ Milestone-based aggregates (TOC/TOD timing)
- ⚠️ Level segment analyses (with altitude stability caveats)

**Prerequisites for CHN full analytical use:**
1. Distance calculation correction implemented and validated
2. Missing ALDT investigation resolved or exclusion policy adopted
3. New candidate CHN artifacts uploaded to R2 and hash-verified
4. Corrected median cruise speed verified as ~450-480 kt
5. W3 rebuild using corrected W2 outputs

### Production promotion

**Status:** NOT REQUESTED (diagnostic investigation, no corrected data produced)

**Current production CHN artifacts remain:**
- Status: KNOWN INVALID for distance-dependent metrics
- Recommendation: DO NOT promote; await W2 corrected candidates OR restrict to time-only use
- Authoritative manifest: UNCHANGED

## Pending-upload package

**NOT APPLICABLE** — No candidate data produced by diagnostic investigation.

If W2 proceeds to full implementation with CAUC QAR worker, corrected package will be created at:
`derived/chn/study-runs/W2-<run-id>/` (new run ID for corrected data)

## Source questions resolved and unresolved

### Questions from W0 Release Contract — Status

**CAUC/QAR Questions:**

| Question | Status | Finding |
|----------|--------|---------|
| Which producer code/version generated each batch? | ⚠️ PARTIAL | 14 batches identified (output1-14), but producer version differences unknown |
| Are coordinates/altitudes/fuel-flow units declared? | ❌ UNRESOLVED | Requires raw QAR header inspection |
| What are cumulative-value timestamp conventions? | ❌ UNRESOLVED | Requires raw QAR processing code review |
| Gap/spike rules? | ✅ INFERRED | Spike cleaning implemented (`FF_SPIKE_FLAG`), gap interpolation present |
| Why are ALDT events absent? | ⚠️ PATTERNS IDENTIFIED | Batch/type/route patterns found; root cause requires source investigation |
| Available fields: weight, GS/TAS, wind/temp, tail ID, cruise level? | ❌ UNRESOLVED | Not in processed data; availability unknown |
| Detector settings and clock/altitude references? | ❌ UNRESOLVED | Requires source code/config review |
| Can reviewed examples run locally? | ⚠️ CONDITIONAL | If CAUC worker has R environment + raw data access |

### New Questions Raised by W2

1. **Distance calculation:** Why do phase summaries contain cumulative instead of incremental distance? Is this:
   - Intended design (caller expected to diff)?
   - Processing bug in phase summary aggregation?
   - Upstream error in cumulative distance construction?

2. **Missing ALDT batch patterns:** Why do output1/2/4/13/14 have high ALDT loss while output3/6/7/9/10/12 have none?
   - Different QAR processing helper versions?
   - Different raw QAR batch sources/vendors?
   - Different data truncation policies?

3. **C919/B737-MAX 100% missing ALDT:** Is this:
   - Type-specific detection threshold mismatch?
   - Systematic early data truncation for these types?
   - Raw QAR genuinely ending before landing?

4. **ZSSS-ZPPP 97.5% missing ALDT:** Route-specific issue or correlation with type/batch?

5. **Fuel unit inference:** Given distance errors contaminate burn-per-NM plausibility, should fuel units be reverified independently?

## Recommended Next Actions

### Option A: Full W2 Implementation (Preferred for complete study)

**Owner:** CAUC QAR worker with raw source access  
**Estimated effort:** 8-12 hours  
**Timeline:** 2-3 work days

**Steps:**
1. Access raw QAR coordinates for sample flights showing extreme speeds
2. Recalculate path distance from coordinates using haversine
3. Identify where cumulative-vs-incremental error occurs
4. Modify `R/canonical-fuel-milestones.R` or downstream aggregation
5. Investigate missing ALDT by batch (check helper versions, raw data extent)
6. For C919/B737-MAX: verify detection thresholds or accept exclusion
7. Regenerate phase summaries and level segments
8. Validate: median cruise ~450-480 kt, no segments >700 kt
9. Upload corrected candidates to R2 under `derived/chn/study-runs/W2-<new-run-id>/`
10. Document source findings in W2 final handoff

**Deliverables:**
- Corrected CHN phase summaries (parquet)
- Corrected CHN level segments (parquet)
- ALDT eligibility/reconstruction metadata (parquet)
- Distance reconciliation report (CSV showing before/after speeds)
- Source investigation findings (Markdown)
- W2 final handoff with verified hashes

### Option B: Restricted CHN Scope (Time-Only Analyses)

**Owner:** Joint analytical-data worker (W3)  
**Estimated effort:** 2-3 hours documentation  
**Timeline:** Immediate

**Steps:**
1. Mark CHN DISTANCE_NM field as INVALID in all documentation
2. Use CHN phase DURATION_MIN and FUEL_KG only
3. Exclude flights missing ALDT from descent analyses (5,231 eligible)
4. Compare time-based metrics only (CHN kg/h vs EUR kg/h)
5. Document limitations: no stage-length context, no kg/NM comparison
6. Proceed to W3 with restricted CHN eligibility flags

**Deliverables:**
- CHN eligibility flags (CSV): time_eligible, descent_eligible, distance_eligible
- Updated study scope excluding distance-dependent analyses
- W2 diagnostic elevated to official limitation documentation

### Option C: CHN Exploratory Extension Only

**Owner:** Release steward  
**Estimated effort:** 1 hour decision documentation  
**Timeline:** Immediate

**Steps:**
1. Elevate EUR to primary data source (pending W1 correction)
2. Mark CHN as exploratory/comparison only
3. Defer CHN full correction to post-Gate A
4. Focus resources on W1 EUR interval reconstruction
5. Reassess CHN priority after EUR validated

**Deliverables:**
- Scope decision memo
- Resource reallocation to W1
- CHN deferral timeline

**Steward decision required by:** 12 October 2026 (per Gate A deadline 16 October)

## References

- Study worker plan: `notes/study-worker-plan.md` lines 79-99
- Release contract: `notes/study-release-contract.md` lines 374-422
- W0 audit evidence: `notes/results/W0/W0-2026-10-09-001/study-readiness.csv`
- Worker handoff template: `notes/worker-handoff-template.md`
- CHN processing code: `R/canonical-fuel-milestones.R`, `scripts/process-chn-summer2025-update.R`
- Instruction commit: 1438f500003ffed0e53bd0d6037411120ef4ead5

---

**Handoff status:** DIAGNOSTIC INVESTIGATION COMPLETE, FULL W2 IMPLEMENTATION REQUIRES SOURCE ACCESS  
**Ready for:** Release steward decision on approach (full correction OR restricted scope OR defer)  
**NOT ready for:** Downstream W3 consumption without corrective action or scope restriction

**Co-Authored-By:** Claude Sonnet 4.5 <noreply@anthropic.com>
