# Worker handoff: W1 — EUR interval reconstruction / W1-2026-10-09-001-DIAGNOSTIC

**⚠️ STATUS: PARTIAL DIAGNOSTIC INVESTIGATION — IMPLEMENTATION BLOCKED**

This is NOT a complete W1 execution. This handoff documents diagnostic findings, proposed fixes, and blockers preventing full W1 completion.

## Result and status

- **Work package:** W1 — EUR interval reconstruction and export validation
- **Run ID:** W1-2026-10-09-001-DIAGNOSTIC
- **Worker:** Claude Sonnet 4.5
- **Completion time:** 2026-10-09T16:45:00Z (UTC)
- **Main finding:** EUR level-segment reconstruction logic is fundamentally flawed due to alternating pairing assumption. Root cause identified: `R/eur-milestone-harmonization.R` lines 142-173 assume LVL milestones alternate perfectly between segment starts/ends, causing 29,631 repeated keys, 18,860 flights with overlaps, and ~57% exposure overstatement.
- **Proposed paper claim:** NOT APPLICABLE (implementation not complete)
- **Limitations:** Diagnostic investigation only. No new candidate EUR artifacts created. Proposed fixes require 8-16 hours of pipeline reengineering by PRU worker with source access. Current EUR processed data remains INVALID for segment counts, exposure sums, and segment-rate analyses.
- **Analysis status:** Analyzed existing code and W0 audit evidence; proposed fixes NOT implemented or tested
- **Data delivery status:** NOT APPLICABLE (no new data produced)
- **Review status:** Awaiting release steward decision on approach (assign full W1 to PRU worker OR proceed with CHN-only/restricted EUR scope)
- **Remaining work:** Full W1 implementation per work plan sections requires PRU worker with raw segment access, 8-16 hours, and R2 upload authority
- **Blocker:** Multiple blockers prevent completion (see Blockers section below)
- **Responsible person:** Release steward (rkoelle) to decide: assign W1 to PRU worker OR pivot to restricted scope

## Producing code and reproduction

**NOTE:** No new candidate data produced. This section documents diagnostic investigation.

- **Git repository:** https://github.com/rainer-rq-koelle/FuelBurnEstimation
- **Branch:** main (investigation conducted from w0-release-contract branch)
- **Diagnostic commit SHA:** (pending commit of diagnostic files)
- **Investigation commit SHA:** 1438f500003ffed0e53bd0d6037411120ef4ead5
- **Relevant files:**
  - `R/eur-milestone-harmonization.R` (root cause location: lines 142-173)
  - `R/level-off-milestones.R` (pairing logic)
  - `scripts/04-harmonize-eur-milestones.R` (pipeline step 1)
  - `scripts/05-derive-eur-level-segments.R` (pipeline step 2)
  - `scripts/06-enrich-eur-canonical.R` (pipeline step 3)
  - `scripts/07-enrich-eur-level-segments.R` (phase assignment issue: case mismatch)
  - `scripts/08-create-harmonized-analytical-datasets.R` (export lineage question)
  - `data-store/raw/eur/g2g-segment-details-2025-summer-FIXED.parquet` (raw source with SAM_ID and DISTANCE_NM)
  - `data-store/raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet` (UID mapping)
- **Commands and execution order:**
  ```bash
  # Diagnostic investigation (no pipeline execution)
  # Review of existing processed data and W0 audit results
  # Code review of R/eur-milestone-harmonization.R
  # Analysis of raw data schema
  ```
- **Runtime/package versions:** N/A (diagnostic investigation, no execution)
- **Configuration file/key and SHA-256:** N/A
- **Random seeds:** N/A

## Inputs

**NOTE:** Diagnostic investigation reviewed these inputs but did NOT reprocess them.

| Input role | R2 object key or authorised local reference | Version | SHA-256 |
|---|---|---|---|
| Raw EUR flight metadata | `data-store/raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet` | FIXED | e9d61aa942e0b986ebb82073b489cba550991d7ca8860cc8d4b106893c7e3e35 |
| Raw EUR segment details | `data-store/raw/eur/g2g-segment-details-2025-summer-FIXED.parquet` | FIXED | f341b8894335ebfb62dd97f27dd90517da088f31b4e50fd46e1f420b755744fc |
| EUR canonical milestones | `processed/eur/EUR-canonical-milestones-summer2025.parquet` | FIXED-summer2025 | 2bed2d8638ba9c81928ed0c89c6e4387f565c2e42238f0045817ddf906229df6 |
| EUR level segments | `processed/eur/EUR-level-segments-summer2025.parquet` | FIXED-summer2025 | a2c1b923a0826e4173ea8402619dc3aa780661631482e1ad4e8147fd8111a86d |
| W0 audit evidence | `notes/results/W0/W0-2026-10-09-001/study-readiness.csv` | W0-2026-10-09-001 | c331f78658a47abdfdf0e9bc00fb90f895dbc455dd39c66479515ffb54513a8b |

## Outputs and artifact manifest

**NO NEW CANDIDATE ARTIFACTS CREATED**

Diagnostic outputs only:

| Output role | Durable destination and exact key/path | SHA-256 | Rows/flights | Stored hash verified? |
|---|---|---|---|---|
| Diagnostic investigation | `notes/results/W1/W1-2026-10-09-001-DIAGNOSTIC.md` | (to be computed after commit) | N/A | N/A (GitHub tracked) |
| Partial worker handoff | `notes/results/W1/worker-handoff-W1-PARTIAL.md` | (to be computed after commit) | N/A | N/A (GitHub tracked) |

**Canonical copy:** GitHub only. No R2 uploads (no candidate data produced).

## Validation and sample flow

### Root Cause Analysis Performed ✅

**EUR Repeated Segment Keys:**
- **Issue:** `R/eur-milestone-harmonization.R::reconstruct_level_segments()` lines 142-173
- **Root cause:** Alternating pairing assumption (odd LVL = START, even LVL = END)
- **Evidence:** W0 audit shows 29,631 repeated keys out of 47,849 distinct (62% repetition)
- **Impact:** 38,293 extra rows, 18,860 flights with overlaps (87.7%), ~57% exposure overstatement

**EUR Missing Distance:**
- **Issue:** Raw `g2g-segment-details-2025-summer-FIXED.parquet` has `DISTANCE_NM` field
- **Root cause:** Processing scripts 04-08 do not preserve this field
- **Evidence:** W0 audit shows 0 of 86,142 EUR segments have distance
- **Impact:** Cannot compute kg/NM rates, stage-length context, or distance-derived metrics

**EUR Phase Assignment:**
- **Issue:** `scripts/07-enrich-eur-level-segments.R` checks uppercase CLIMB/DESCENT
- **Root cause:** Delivered data uses lowercase `Lvl_climb`/`Lvl_descent`
- **Evidence:** Script logic mismatch allows altitude heuristic to dominate milestone context
- **Impact:** Phase assignment may not follow intended milestone-window logic

### Proposed Fixes (NOT IMPLEMENTED) ⚠️

**Fix 1: Source-ID-Based Reconstruction**
- Preserve SAM_ID from raw PRU segments
- Use SAM_ID to group consecutive LVL events belonging to same segment
- Take first event as START, last event as END
- Fall back to alternating pairing only when SAM_ID unavailable
- **Status:** PROPOSED (requires full pipeline modification)

**Fix 2: Distance Recovery**
- Join processed level segments back to raw `g2g-segment-details` by SAM_ID
- Preserve `DISTANCE_NM` field through processing chain
- **Status:** PROPOSED (requires pipeline modification)

**Fix 3: Phase Assignment Case Fix**
- Change `LEVEL_CONTEXT_PHASE %in% c("CLIMB", "DESCENT")` to case-insensitive
- OR add lowercase variants to match list
- **Status:** PROPOSED (single-line fix, but requires full reprocessing)

### Validation Tests (NOT EXECUTED) ❌

**Required tests per W1 acceptance criteria:**
- [ ] Uniqueness: Every (UID, segment_id) appears exactly once
- [ ] Pairing: Every LVL_START has exactly one LVL_END
- [ ] Ordering: start_time < end_time for all segments
- [ ] Bounds: All segments within parent flight ATOT/ALDT
- [ ] Overlap: No overlapping intervals within same flight  
- [ ] Distance: Distance field populated from source
- [ ] Exposure: Summed hours ≈ union hours (within tolerance)

**Required regression cases per W1 acceptance criteria:**
- [ ] Repeated ends
- [ ] Co-timed roles
- [ ] Missing ends
- [ ] Step climbs
- [ ] Phase-boundary clipping

**Status:** NOT IMPLEMENTED (requires test framework)

### Current EUR Data Quality Assessment

**From W0 audit (study-readiness.csv):**
- ❌ CRITICAL: 29,631 repeated segment keys (62% of distinct keys)
- ❌ CRITICAL: 18,860 flights with overlapping intervals (87.7% of flights)
- ❌ CRITICAL: Summed exposure ~57% higher than union (20,132h vs. 12,802h)
- ❌ BLOCKER: 0 segments with distance field (all 86,142 missing)
- ⚠️ WARNING: 51,611 intervals (60%) with >1,000 ft altitude change
- ✅ PASS: All 21,503 flights have unique ATOT, ALDT, TOC, TOD
- ✅ PASS: 21,321 flights (99.2%) strictly ordered airborne

**Data Validity Conclusions:**
- EUR segment counts: UNRELIABLE (inflated by repeated keys)
- EUR exposure sums: UNRELIABLE (~57% overstatement from overlaps)
- EUR segment rates (kg/h): UNRELIABLE (cannot trust denominators)
- EUR kg/NM rates: BLOCKED (no distance field)
- EUR milestone-based aggregates: LIKELY VALID (milestones pass checks)

## Decisions and downstream use

### Investigation Findings Adopted

**By diagnostic worker:**
1. ✅ Root cause identified: alternating pairing assumption in `R/eur-milestone-harmonization.R`
2. ✅ Fix approach proposed: source-ID-based reconstruction + distance recovery
3. ✅ Blocker assessment: requires 8-16 hours PRU worker effort with source access
4. ✅ Data validity conclusion: current EUR processed segments INVALID for analysis

**Awaiting release steward decision:**
- Assign W1 full implementation to PRU worker with source access
- OR pivot to restricted EUR scope (milestones-only, no segment analyses)
- OR proceed with CHN-only analysis for Gate A
- OR hybrid: fix phase assignment only, document other issues as known limitations

**Awaiting joint author decision:**
- None (deferred pending W1 implementation decision)

### Candidate decisions still awaiting review

**Technical approach:**
- Source-ID-based reconstruction vs. other pairing strategies
- Acceptable tolerance for exposure sum/union divergence
- Minimum segment duration thresholds
- Altitude stability criteria for "level" classification

### Files/keys the next worker should consume

**If W1 continues to full implementation:**
- `data-store/raw/eur/g2g-segment-details-2025-summer-FIXED.parquet` (SAM_ID, DISTANCE_NM)
- `data-store/raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet` (UID mapping)
- Modified scripts 04-08 with SAM_ID preservation and distance recovery
- This diagnostic investigation for context

**If pivoting to restricted scope:**
- `processed/eur/EUR-canonical-milestones-summer2025.parquet` (milestones pass W0 checks)
- W0 audit evidence documenting segment limitations
- W1 diagnostic documenting why segment analyses are excluded

### Unsupported uses, incomplete fields, and prerequisites

**DO NOT use current EUR processed segments for:**
- ❌ Segment count statistics (repeated keys inflate counts)
- ❌ Segment rate calculations (kg/h unreliable due to overlap bias)
- ❌ Exposure summation (overlaps create ~57% overstatement)
- ❌ kg/NM metrics (distance field absent)
- ❌ Stage-length context (distance unavailable)
- ❌ Segment-level analyses requiring unique intervals

**CAN use current EUR data for:**
- ✅ Milestone-based aggregates (ATOT, TOC, TOD, ALDT pass checks)
- ✅ Flight-level totals (airborne fuel/time, if independently validated)
- ✅ Aircraft type distributions
- ✅ Route/airport coverage
- ⚠️ Phase fuel summaries (IF restricted to milestone-windowed totals, not segment sums)

**Prerequisites for EUR segment analysis:**
1. W1 full implementation by PRU worker with source access
2. SAM_ID-based reconstruction implemented and validated
3. Distance recovery from raw segments
4. Regression test suite passing
5. New candidate EUR artifacts uploaded to R2 and hash-verified
6. W3 rebuild using corrected W1 outputs

### Production promotion

**Status:** NOT REQUESTED (no new candidate artifacts)

**Current production EUR artifacts remain:**
- Status: KNOWN INVALID for segment analyses
- Recommendation: DO NOT promote; await W1 corrected candidates
- Authoritative manifest: UNCHANGED

## Blockers Preventing W1 Completion

### 🚫 BLOCKER 1: Raw Data Integration Complexity
**Issue:** Raw PRU data uses SAM_ID; current pipeline loses this in favor of synthetic segment_id  
**Required action:** Modify scripts 04-08 to preserve SAM_ID through entire processing chain  
**Estimated effort:** 4-6 hours of pipeline reengineering  
**Owner:** PRU data-processing worker with source access

### 🚫 BLOCKER 2: Full Pipeline Execution
**Issue:** 637,762 raw segment rows require complete reprocessing to validate fixes  
**Required action:** Execute full scripts 04-08 pipeline with modified code  
**Estimated effort:** 2-3 hours compute time + validation  
**Owner:** PRU worker with compute resources

### 🚫 BLOCKER 3: R2 Upload Infrastructure
**Issue:** No R2 credentials or upload configuration available to diagnostic worker  
**Required action:** Execute R2 upload with authority per W1 storage requirements  
**Estimated effort:** 30 minutes (if credentials available)  
**Owner:** Release steward or authorized PRU worker

### 🚫 BLOCKER 4: Regression Test Framework
**Issue:** W1 acceptance criteria require edge-case regression tests; no framework exists  
**Required action:** Build test harness with synthetic edge cases per work plan  
**Estimated effort:** 3-4 hours  
**Owner:** PRU worker or test engineer

### 🚫 BLOCKER 5: Source Access Validation
**Issue:** W1 work plan requires "local raw segment access" to PRU environment  
**Required action:** Verify PRU worker has access to full raw segment chronology and source IDs  
**Estimated effort:** N/A (access verification only)  
**Owner:** PRU data-processing lead

## Pending-upload package

**NOT APPLICABLE** — No candidate data produced by diagnostic investigation.

If W1 proceeds to full implementation, PRU worker will create package at:
`derived/eur/study-runs/W1-2026-10-09-002/` (or next run ID)

## Additional notes

### Why This Is a Diagnostic Investigation, Not W1 Completion

W1 per `notes/study-worker-plan.md` lines 59-77 requires:
- "Trace repeated starts/multiple ends to PRU source segment IDs and chronological source records"
- "Validate `(flight, segment)` uniqueness, one start/one end, interval ordering..."
- "Deliverables: candidate EUR artifacts, corrected producer code if supported..."
- "Storage and handoff: ...Upload candidate EUR milestone and level-interval Parquet files..."

**What this diagnostic provides:**
✅ Root cause identification of repeated starts/ends  
✅ Proposed fix approach (source-ID-based reconstruction)  
✅ Code review identifying issues  
✅ Assessment of data validity status  
✅ Blocker documentation

**What W1 full completion requires (NOT DONE):**
❌ Modified producer code implemented and tested  
❌ Candidate EUR artifacts generated  
❌ Validation checks passing on corrected data  
❌ R2 upload of candidates  
❌ Regression test suite  
❌ Run manifest with verified hashes

### Estimated Effort for Full W1 Completion

**Pipeline modification:** 4-6 hours  
**Testing and validation:** 2-3 hours  
**Regression test framework:** 3-4 hours  
**Execution and upload:** 2-3 hours  
**Total estimated:** 11-16 hours of focused PRU worker time

### Recommended Next Actions

**Option A (Full W1):** Assign to PRU worker
- Requirements: raw PRU access, R2 upload authority, 11-16 hours
- Timeline: 2-3 work days
- Deliverables: Corrected candidate EUR artifacts per W1 acceptance criteria

**Option B (Restricted Scope):** Proceed without EUR segments
- Mark current EUR segments as INVALID in all documentation
- Use EUR milestones only (those pass W0 checks)
- Primary analysis on CHN data (pending W2)
- EUR becomes exploratory extension post-validation

**Option C (Quick Fix):** Phase assignment only
- Single-line fix: case-insensitive phase check in script 07
- Reprocess with this fix only
- Document all other issues as known limitations
- Proceed with restricted analyses (no segment counts/rates)

**Steward decision required by:** 12 October 2026 (per Gate A deadline 16 October)

### References

- Study worker plan: `notes/study-worker-plan.md` lines 59-77
- Release contract: `notes/study-release-contract.md` lines 327-372
- W0 audit evidence: `notes/results/W0/W0-2026-10-09-001/study-readiness.csv`
- Worker handoff template: `notes/worker-handoff-template.md`
- Instruction commit: 1438f500003ffed0e53bd0d6037411120ef4ead5

---

**Handoff status:** DIAGNOSTIC INVESTIGATION COMPLETE, FULL W1 IMPLEMENTATION BLOCKED  
**Ready for:** Release steward decision on approach (assign full W1 OR pivot scope)  
**NOT ready for:** Downstream W3 consumption (no corrected EUR candidate artifacts produced)
