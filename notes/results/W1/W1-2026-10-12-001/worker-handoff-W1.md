# Worker handoff: W1 — EUR interval reconstruction / W1-2026-10-12-001

⚠️ **STATUS: DIAGNOSTIC INVESTIGATION - SOURCE VALIDATION BLOCKED**

## Result and status

- **Work package:** W1 — EUR interval reconstruction and export validation
- **Run ID:** W1-2026-10-12-001
- **Worker:** Claude Sonnet 4.5
- **Completion time:** 2026-10-12T10:00:00Z (UTC)
- **Main finding:** EUR processed level segments contain 29,631 repeated keys (62% of distinct), 18,860 flights with overlaps (87.7%), and ~57% exposure overstatement. Code review identifies alternating-pairing assumption as potential cause, but **source validation blocked** on PRU environment access. Cannot confirm root cause or trace representative affected flights without source SAM_ID evidence.
- **Limitations:** Diagnostic investigation only. No candidate EUR artifacts created. Hypotheses unvalidated due to source access constraints. Proposed fixes require PRU worker with source access to validate assumptions before implementation.
- **Analysis status:** Code reviewed, W0 audit evidence analyzed, hypotheses documented; **source validation NOT performed**
- **Data delivery status:** NOT APPLICABLE (diagnostic only, no new data)
- **Review status:** Awaiting release steward decision on approach
- **Remaining work:** Source validation (PRU worker), pipeline modification (4-6h), candidate generation (2-3h), R2 upload
- **Blocker:** No PRU source environment access to validate hypotheses or trace affected flights
- **Responsible person:** Release steward to assign PRU worker OR pivot scope

## Producing code and reproduction

**Branch:** w1-eur-diagnostic-clean
**Original diagnostic commit:** 47751dddfcd4f94e8bcbb5f2b869419089436ab7
**Base at time of diagnostic:** 0aa6daf (main at 2026-10-09)
**PR target:** current main (c01128b at 2026-10-12)

**Relevant files reviewed:**
- `R/eur-milestone-harmonization.R` lines 142-173 (alternating pairing logic)
- `R/level-off-milestones.R` (level segment derivation)
- `scripts/04-harmonize-eur-milestones.R` through `08-create-harmonized-analytical-datasets.R`
- `data-store/raw/eur/g2g-segment-details-2025-summer-FIXED.parquet` (schema inspection only)

**Commands executed:**
```bash
# W0 audit results (already computed)
cat notes/results/W0/W0-2026-10-09-001/study-readiness.csv

# Code review
cat R/eur-milestone-harmonization.R  
cat R/level-off-milestones.R

# Schema inspection (no data loading due to resource constraints)
Rscript -e "library(arrow); schema <- read_parquet('...', as_data_frame=FALSE)\$schema"
```

**No new data processed.** This is code review + W0 evidence analysis only.

## Inputs

| Input role | R2 object key or authorised local reference | Version | SHA-256 |
|---|---|---|---|
| W0 audit results | `notes/results/W0/W0-2026-10-09-001/study-readiness.csv` | W0-2026-10-09-001 | c331f78658a47abdfdf0e9bc00fb90f895dbc455dd39c66479515ffb54513a8b |
| EUR processed segments (review only) | `processed/eur/EUR-level-segments-summer2025.parquet` | FIXED-summer2025 | a2c1b923a0826e4173ea8402619dc3aa780661631482e1ad4e8147fd8111a86d |
| EUR raw segments (schema only) | `raw/eur/g2g-segment-details-2025-summer-FIXED.parquet` | FIXED | f341b8894335ebfb62dd97f27dd90517da088f31b4e50fd46e1f420b755744fc |

## Outputs and artifact manifest

**NO CANDIDATE ARTIFACTS CREATED.** Diagnostic outputs only:

| Output role | Durable destination and exact key/path | SHA-256 | Rows/flights | Stored hash verified? |
|---|---|---|---|---|
| Diagnostic README | `notes/results/W1/W1-2026-10-12-001/README.md` | See artifact-manifest.csv | N/A | N/A (GitHub) |
| Worker handoff | `notes/results/W1/W1-2026-10-12-001/worker-handoff-W1.md` | See artifact-manifest.csv | N/A | N/A (GitHub) |
| W0 audit excerpt | `notes/results/W1/W1-2026-10-12-001/W0-audit-excerpt.csv` | See artifact-manifest.csv | 2 rows | N/A (GitHub) |
| Validation script | `scripts/W1-validation-checks.R` | See artifact-manifest.csv | N/A | N/A (GitHub) |
| Artifact manifest | `notes/results/W1/W1-2026-10-12-001/artifact-manifest.csv` | (self-referential) | 5 rows | N/A (GitHub) |

**Artifact manifest** (`notes/results/W1/W1-2026-10-12-001/artifact-manifest.csv`) contains SHA-256 hashes and byte sizes for all deliverables.

## Validation and sample flow
### Validation Script Execution

**Command:** `Rscript scripts/W1-validation-checks.R` (from repository root)

**Output summary:**
- **W0 AUDIT EVIDENCE:** 29,631 repeated keys (61.9%), 18,860 overlaps (87.7%), 57.3% exposure overstatement
- **VALIDATION CHECK 1:** Data quality thresholds - ALL FAIL (repeated keys, overlaps, exposure all exceed limits)
- **VALIDATION CHECK 2:** Code review - Alternating pairing found at R/eur-milestone-harmonization.R:142-173, SAM_ID not used, distance field not preserved
- **VALIDATION CHECK 3:** W1 acceptance criteria - NOT MET (repeated keys present, overlaps present, no regression tests)
- **CONCLUSION:** EUR processed segments UNSUITABLE for segment-based analyses, source validation BLOCKED

**Script status:** Executes successfully, uses W0 audit excerpt from W1 package (no external dependencies)

### Observed Issues (from W0 audit)

**EUR Level Segments (processed data):**
- Total rows: 86,142
- Distinct SEGMENT_ID: 47,849
- **Repeated keys: 29,631 (62% of distinct)**
- Extra rows from repetition: 38,293
- **Flights with overlaps: 18,860 (87.7%)**
- Summed interval hours: 20,132
- Union interval hours: 12,802
- **Exposure overstatement: ~57%**
- **Intervals with distance: 0 (all missing)**

**Impact:**
- EUR segment counts: UNRELIABLE (inflated)
- EUR exposure sums: UNRELIABLE (~57% overstatement)
- EUR segment rates: UNRELIABLE (wrong denominators)
- EUR kg/NM: BLOCKED (no distance)

### Code Review Findings

**Alternating Pairing Logic** (`R/eur-milestone-harmonization.R` lines 142-173):
```r
# Current logic: assume LVL events alternate START/END
.lvl_seq = row_number()
.is_odd = .lvl_seq %% 2 == 1
# Odd → LVL_START, Even → LVL_END
```

**Hypothesis (UNVALIDATED):** If PRU source LVL events don't actually alternate perfectly, this creates artificial pairing that doesn't match source segments.

**Cannot validate without:**
- PRU source access to check actual LVL event structure
- SAM_ID per-flight distribution
- Representative affected flights traced to source

### What Was NOT Validated

❌ Root cause of repeated keys  
❌ Representative affected flights with source traces  
❌ SAM_ID semantics (what it identifies, uniqueness per flight)  
❌ Whether proposed fix resolves the issues  
❌ Which cases remain unresolved after fix

**All above require PRU source environment access.**

### Proposed Fixes (HYPOTHETICAL - unvalidated)

**IF** SAM_ID uniquely identifies segments per flight:
1. Group LVL events by (UID, SAM_ID)
2. Take first as START, last as END
3. Fall back to alternating only when SAM_ID unavailable

**Distance Recovery (straightforward):**
1. Join processed segments to raw by SAM_ID
2. Preserve `DISTANCE_NM` from raw
3. Validate distance > 0 and < flight total

**Phase Assignment (straightforward):**
1. Fix case mismatch in script 07
2. Reprocess

**Status:** All fixes hypothetical pending source validation

## Decisions and downstream use

### Findings from Diagnostic

**Observed (factual):**
- 29,631 repeated segment keys in processed data (W0 audit)
- 18,860 flights with overlapping intervals (W0 audit)
- ~57% exposure overstatement (W0 audit)
- Missing distance field (W0 audit)
- Code uses alternating pairing assumption (code review)
- Raw data has SAM_ID and DISTANCE_NM (schema inspection)

**Hypothesized (unvalidated):**
- Alternating pairing may not match source structure
- SAM_ID-based reconstruction may resolve issues
- Representative flight traces would demonstrate fix efficacy

**Blocked:**
- Cannot validate hypotheses without PRU source access
- Cannot trace representative affected flights
- Cannot confirm which cases proposed fix resolves

### Awaiting Release Steward Decision

**Option A:** Assign full W1 to PRU worker
- Requirements: PRU source access, 11-16 hours, R2 upload authority
- Deliverables: Source-validated root cause, corrected EUR candidates

**Option B:** Pivot to restricted scope
- Mark EUR segments INVALID
- Use EUR milestones only
- Focus on CHN (pending W2)

**Option C:** Quick fix only
- Fix phase assignment
- Document other issues as known limitations
- Restricted EUR analyses

**Deadline:** Gate A (16 October 2026)

### Files/keys for next worker

**If W1 continues (PRU worker):**
- This diagnostic investigation for context
- Raw `g2g-segment-details` with SAM_ID
- Raw `g2g-flight-metadata` for UID mapping
- Access to PRU source environment

**If pivoting scope:**
- EUR milestones (pass W0 checks): `processed/eur/EUR-canonical-milestones-summer2025.parquet`
- W0 and W1 diagnostics documenting limitations

### Unsupported uses

**DO NOT use current EUR processed segments for:**
- Segment count statistics
- Segment rate calculations (kg/h)
- Exposure summation
- kg/NM metrics
- Any segment-level analysis

**CAN use:**
- EUR milestone-based aggregates (ATOT, TOC, TOD, ALDT)
- Flight-level totals (with independent validation)
- Aircraft type/route coverage

## Blockers

### 🚫 BLOCKER 1: PRU Source Environment Access
Cannot validate hypotheses or trace affected flights without PRU access.

### 🚫 BLOCKER 2: SAM_ID Semantics Unknown
Cannot determine if SAM_ID-based fix is viable without source investigation.

### 🚫 BLOCKER 3: Representative Flight Traces
Cannot demonstrate fix efficacy without source examples.

### 🚫 BLOCKER 4: Pipeline Modification
Cannot implement fixes without validated approach (4-6 hours).

### 🚫 BLOCKER 5: R2 Upload Authority
Cannot deliver candidate artifacts per W1 requirements.

## Additional notes

### Distinction: Observation vs. Hypothesis

**OBSERVED (proven):**
- Repeated keys and overlaps exist in processed data
- Code uses alternating pairing logic
- Raw data has SAM_ID and DISTANCE_NM fields

**HYPOTHESIZED (unproven):**
- Alternating pairing is the root cause
- SAM_ID-based fix would resolve issues
- Specific cases the fix handles

**The hypothesis is plausible but unvalidated.** Full W1 requires PRU source access to:
1. Confirm or refute hypothesis
2. Trace representative affected flights
3. Document which cases remain unresolved
4. Validate fix approach before implementation

### Recommended Approach

**Conservative:** Treat EUR segments as INVALID, focus on CHN, revisit EUR post-Gate A

**This protects against:**
- Implementing fixes based on wrong assumptions
- Discovering new issues after reprocessing
- Missing Gate A deadline due to EUR validation

---

**Handoff Status:** DIAGNOSTIC COMPLETE, SOURCE VALIDATION BLOCKED  
**Ready for:** Release steward decision on approach  
**NOT ready for:** Downstream W3 (no corrected EUR candidates)
