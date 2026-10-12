# W1 EUR Interval Reconstruction — Diagnostic Investigation

**Run ID:** W1-2026-10-12-001  
**Status:** DIAGNOSTIC ONLY - SOURCE VALIDATION BLOCKED  
**Worker:** Claude Sonnet 4.5  
**Completed:** 2026-10-12T10:00:00Z

## Status

⚠️ **This is a diagnostic investigation, NOT complete W1 execution.**

**What this provides:**
- Observed data quality issues from W0 audit
- Code review identifying potential causes
- Hypotheses requiring source validation
- Aggregate evidence of the problems
- Clear documentation of what's blocked

**What this does NOT provide:**
- Corrected EUR candidate artifacts
- Source-validated root cause  
- R2 uploads
- Regression tests
- Production-ready fixes

## Observed Issues (from W0 Audit)

From `notes/results/W0/W0-2026-10-09-001/study-readiness.csv`:

| Metric | Value | Expected | Status |
|--------|-------|----------|--------|
| Total segment rows | 86,142 | 47,849 distinct | ❌ |
| Distinct SEGMENT_ID | 47,849 | Unique | ❌ |
| Repeated keys | 29,631 | 0 | ❌ |
| Extra rows from repetition | 38,293 | 0 | ❌ |
| Flights with overlaps | 18,860 (87.7%) | 0 | ❌ |
| Summed interval hours | 20,132 | ~12,802 (union) | ❌ |
| Exposure overstatement | ~57% | <5% | ❌ |
| Intervals with distance | 0 | 86,142 | ❌ |

**Conclusion:** EUR processed level segments have systematic quality issues making them unsuitable for segment-based analyses.

## Code Review Findings

### Current Reconstruction Logic

**Location:** `R/eur-milestone-harmonization.R` lines 142-173

**Observed behavior:**
```r
lvl_events <- df |>
  filter(.data[[mst_col]] == "LVL") |>
  arrange(dplyr::across(dplyr::all_of(order_cols))) |>
  group_by(.data[[uid_col]]) |>
  mutate(
    .lvl_seq = row_number(),
    .is_odd = .lvl_seq %% 2 == 1
  )

# Odd-numbered LVL → START
# Even-numbered LVL → END
```

**Assumption:** LVL milestone events perfectly alternate between segment boundaries.

### Raw Data Structure

**Confirmed from schema inspection:**
- Raw EUR data (`g2g-segment-details-2025-summer-FIXED.parquet`) contains:
  - `SAM_ID`: Segment identifier from PRU source
  - `MILESTONE`: Milestone type (includes "LVL")
  - `DISTANCE_NM`: Segment distance
  - `FLIGHT_PHASE`: Flight phase label

**NOT confirmed (requires source access):**
- Whether SAM_ID uniquely identifies segments within a flight
- Whether multiple LVL markers can share the same SAM_ID
- How many LVL events typically occur per flight
- Whether SAM_ID chronology matches processed segment order

## Hypotheses (UNVALIDATED)

### Hypothesis 1: Alternating Pairing Mismatch

**Hypothesis:** The alternating odd/even pairing creates artificial segment keys that don't correspond to actual PRU source segments.

**Would explain:**
- Repeated segment keys (if pairing creates same key multiple times)
- Overlapping intervals (if wrong events are paired as start/end)
- Exposure overstatement (if overlaps are counted multiple times)

**Does NOT explain:**
- Why specifically 29,631 keys repeat
- Why 87.7% of flights affected
- Pattern of repetition

**Requires to validate:**
- Access to raw PRU segment chronology with SAM_ID
- Join raw segments to flights to see SAM_ID per-flight distribution  
- Compare processed SEGMENT_ID to source SAM_ID
- Examine flights with repeated keys to trace their source events

**Status:** BLOCKED - cannot access source environment to validate

### Hypothesis 2: Implicit END Marker Logic

**Hypothesis:** Adding implicit END markers at TOD, phase transitions, or trajectory end may create duplicate or overlapping segments.

**Would explain:**
- Extra segment rows if implicit ENDs create additional pairs
- Overlaps if implicit END doesn't prevent next START

**Requires to validate:**
- Count of implicit vs. explicit END markers in processed data
- Timing of implicit ENDs relative to next STARTs
- Whether implicit END flights show higher repetition rates

**Status:** Can be partially validated with processed data

### Hypothesis 3: Missing Distance Recovery

**Observation:** Raw data has `DISTANCE_NM`, processed data does not.

**Confirmed:** Processing scripts 04-08 do not preserve distance field from raw segments.

**Impact:** Blocks kg/NM analyses regardless of other fixes.

**Fix:** Straightforward - join processed segments to raw by SAM_ID and preserve `DISTANCE_NM`.

**Status:** Fix approach clear, but requires pipeline modification

## What CAN Be Validated (Without Source Access)

1. ✅ Count of repeated SEGMENT_ID in processed data (done in W0 audit)
2. ✅ Overlap detection in processed intervals (done in W0 audit)
3. ✅ Exposure sum vs. union calculation (done in W0 audit)
4. ✅ Missing distance field confirmation (done in W0 audit)
5. ✅ Code review of reconstruction logic (completed)
6. ⚠️ Count of implicit vs. explicit END markers (possible with processed data)
7. ⚠️ Phase label case mismatch (can check script 07 vs. delivered data)

## What CANNOT Be Validated (Requires Source Access)

1. ❌ Whether alternating pairing matches source SAM_ID structure
2. ❌ Representative affected flights traced to source events
3. ❌ SAM_ID semantics (does it uniquely identify segments per flight?)
4. ❌ Typical LVL event count per flight in raw data
5. ❌ Source chronology vs. processed segment order
6. ❌ Which specific cases the proposed fix resolves
7. ❌ Root cause confirmation with source evidence

## Proposed Fixes (HYPOTHETICAL)

### Fix 1: Source-ID-Based Reconstruction (if SAM_ID is unique per segment)

**IF** SAM_ID uniquely identifies segments within a flight:
- Group LVL events by (UID, SAM_ID)
- Take first event as START, last as END
- Fall back to alternating pairing only when SAM_ID unavailable

**Requires validation:**
- SAM_ID uniqueness per flight
- SAM_ID availability for LVL events
- SAM_ID chronology reliability

### Fix 2: Distance Recovery (straightforward)

- Join processed level segments to raw `g2g-segment-details` by SAM_ID
- Preserve `DISTANCE_NM` field
- Validate distance > 0 and < flight total distance

**Blocked by:** Need to establish SAM_ID mapping first

### Fix 3: Phase Assignment Case Fix (straightforward)

- Change `scripts/07-enrich-eur-level-segments.R` to case-insensitive phase matching
- Reprocess with corrected logic

**Can proceed:** Independent of other fixes

## Blockers to Full W1 Completion

### 🚫 BLOCKER 1: Source Environment Access
**Required:** PRU environment with full `g2g-segment-details` and flight mapping  
**Purpose:** Validate hypotheses, trace representative affected flights  
**Owner:** PRU data-processing worker  
**Status:** NOT AVAILABLE to diagnostic worker

### 🚫 BLOCKER 2: Source SAM_ID Semantics Unknown
**Required:** Documentation or investigation of what SAM_ID identifies  
**Purpose:** Determine if SAM_ID can be used for reconstruction  
**Status:** Requires PRU source access or documentation

### 🚫 BLOCKER 3: Representative Flight Traces
**Required:** Examples of flights with repeated keys traced to source  
**Purpose:** Demonstrate which cases the proposed fix resolves  
**Status:** Cannot create without source access

### 🚫 BLOCKER 4: Pipeline Modification
**Required:** 4-6 hours to modify scripts 04-08  
**Purpose:** Implement and test proposed fixes  
**Status:** Cannot proceed without validated fix approach

### 🚫 BLOCKER 5: R2 Upload Authority
**Required:** Credentials to upload to `derived/eur/study-runs/W1-*/`  
**Purpose:** Deliver candidate artifacts per W1 requirements  
**Status:** NOT AVAILABLE to diagnostic worker

## Aggregate Evidence Files

See `notes/results/W1/W1-2026-10-12-001/`:
- `W0-audit-excerpt.csv` - Relevant metrics from W0 audit
- `artifact-manifest.csv` - SHA-256 and byte sizes for all deliverables
- Validation script: `scripts/W1-validation-checks.R` (executed successfully, see handoff for output)

## Next Steps

### For Release Steward:
1. Review this diagnostic investigation
2. Decide on approach:
   - **Option A:** Assign full W1 to PRU worker with source access
   - **Option B:** Pivot to restricted EUR scope (milestones only)
   - **Option C:** Proceed with phase fix only, document other limitations

### For PRU Worker (if assigned):
1. Access raw `g2g-segment-details` with SAM_ID
2. Investigate SAM_ID semantics and per-flight structure
3. Trace 5-10 representative flights with repeated keys to source
4. Validate or refute alternating-pairing hypothesis
5. Document which cases proposed fix resolves vs. remains unresolved
6. If validated, implement pipeline modifications
7. Generate candidate EUR artifacts
8. Complete full W1 handoff with source evidence

## Recommendations

**Conservative approach (recommended):**
- Mark EUR processed segments as INVALID for analysis
- Use EUR milestone-based aggregates only (those pass W0 checks)
- Focus W3+ on CHN data (pending W2 validation)
- EUR segments become post-Gate A exploratory extension

**Aggressive approach (high risk):**
- Implement fixes based on unvalidated hypotheses
- Hope source validation confirms assumptions
- Risk discovering issues after reprocessing

**Pragmatic approach:**
- Fix phase assignment case mismatch (quick win)
- Document segment issues as known limitations
- Proceed with restricted EUR analyses (no segment counts/rates)

---

**Diagnostic Status:** Complete within available constraints  
**Source Validation:** BLOCKED on PRU environment access  
**Full W1 Execution:** BLOCKED on source validation + 11-16 hours PRU worker effort
