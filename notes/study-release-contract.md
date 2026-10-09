# AICAP 2027 Study Release Contract

**Work Package:** W0 — Coordinator and release steward  
**Run ID:** W0-2026-10-09-001  
**Worker:** Claude Sonnet 4.5  
**Completed:** 2026-10-09T13:00:00Z  
**Instruction Commit:** 1438f500003ffed0e53bd0d6037411120ef4ead5  
**Producing-Code Commit:** 46f0a9d680b9c32ed3d33aa0d89ac7675b9218ec

## Executive Summary

This release contract establishes the frozen analytical baseline for the AICAP 2027 study. All seven manifest-listed artifacts are present and hash-verified. The audit confirms data **availability** but identifies critical analytical validity issues requiring W1 and W2 source validation before scientific use:

- **EUR:** 29,631 repeated segment keys, 18,860 flights with overlapping intervals (~57% exposure overstatement)
- **CHN:** 17,955 segments implying >700 kt, median enroute speed ~830 kt, 1,190 flights missing ALDT
- **Schema mismatch:** EUR 21/31 columns vs CHN 27/22 columns (not the claimed equivalence)
- **Phase semantics:** EUR phase labels differ from intended export

**Status:** Release identity frozen. Analysis release **NOT READY** pending W1/W2 validation.

## Release Identity and Manifest Snapshot

### Frozen Input Manifest

The authoritative manifest snapshot is preserved at:
- **Location:** `data-store/manifest/current-artifacts.csv`
- **Snapshot Copy:** `notes/results/W0/W0-2026-10-09-001/input-manifest-snapshot.csv`
- **Manifest Created:** 2026-10-09T11:35:10Z
- **Machine:** ESSP7869
- **User:** rkoelle

### Required Artifacts (All Hash-Verified ✅)

| Key | Source | Version | Size (MB) | SHA-256 (first 16) | Status |
|-----|--------|---------|-----------|-------------------|--------|
| `processed/chn/CHN-canonical-milestones-summer2025.parquet` | CHN/QAR | summer2025 | 19.95 | 5907faeaf4094d79 | ✅ verified |
| `processed/chn/CHN-level-segments-summer2025.parquet` | CHN/QAR | summer2025 | 5.86 | 5fdde9e482a60efa | ✅ verified |
| `processed/eur/EUR-canonical-milestones-summer2025.parquet` | EUR/PRU | FIXED-summer2025 | 21.01 | 2bed2d8638ba9c81 | ✅ verified |
| `processed/eur/EUR-level-segments-summer2025.parquet` | EUR/PRU | FIXED-summer2025 | 4.50 | a2c1b923a0826e41 | ✅ verified |

### Optional Reference Artifacts (All Hash-Verified ✅)

| Key | Purpose | Size (MB) | SHA-256 (first 16) |
|-----|---------|-----------|-------------------|
| `processed/chn/CHN-phase-summaries-summer2025.parquet` | CHN phase summaries | 2.59 | 5f7b0fdcb9e577699 |
| `raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet` | EUR raw metadata | 0.82 | e9d61aa942e0b986e |
| `raw/eur/g2g-segment-details-2025-summer-FIXED.parquet` | EUR raw segments | 25.41 | f341b8894335ebfb6 |

**Audit Result:** All seven manifest-listed files present and hash-verified. No missing or corrupted artifacts.

## Aggregate Audit Evidence

The readiness audit (`scripts/12-audit-study-readiness.R`) was executed on 2026-10-09 and generated seven aggregate diagnostic files in `outputs/study-design/`:

### Key Findings Summary

| Region | Flights | Milestone Rows | Segment Rows | Critical Issues |
|--------|---------|----------------|--------------|-----------------|
| EUR | 21,503 | 696,076 | 86,142 | 29,631 repeated keys, 18,860 overlapping flights, 51,611 intervals with >1000ft altitude change |
| CHN | 6,421 | 266,883 | 64,981 | 17,955 segments >700kt, 1,190 missing ALDT, 2,958 flights with enroute speed >700kt |

### EUR Critical Observations

1. **Segment Identity Crisis**
   - Total segment rows: 86,142
   - Distinct segment keys: 47,849
   - **Repeated segment keys: 29,631** (34% of distinct keys)
   - Extra rows from repetition: 38,293

2. **Interval Overlap Epidemic**
   - Flights with overlapping intervals: 18,860 (87.7% of flights)
   - Summed interval hours: 20,132
   - Union interval hours: 12,802
   - **Exposure overstatement: ~57%** relative to union

3. **Altitude Stability Concerns**
   - Intervals with >1,000 ft altitude change: 51,611 (60% of segments)
   - All segments missing distance field (0 intervals with distance)

4. **Milestone Completeness**
   - All 21,503 flights have unique ATOT ✅
   - All 21,503 flights have unique ALDT ✅
   - All 21,503 flights have unique TOC/TOD ✅
   - 21,321 flights strictly ordered airborne (99.2%) ✅

### CHN Critical Observations

1. **Distance/Time Contradictions**
   - Intervals with implied speed >700 kt: 17,955 (27.6% of segments)
   - **Median interval implied speed: 435 kt** (within reasonable range)
   - Median enroute (TOC-TOD) implied speed: **830 kt** ⚠️
   - Flights with enroute speed >700 kt: 2,958 (46% of flights)

2. **Missing Landing Milestones**
   - **Flights missing ALDT: 1,190** (18.5% of CHN fleet)
   - Flights missing ATOT: 1 (negligible)
   - Flights missing unique TOC/TOD: 22

3. **Event Ordering**
   - Flights with strictly ordered airborne phases: 5,220 (81.3%)
   - Note: Missing ALDT prevents ordering check for affected flights

4. **Data Availability**
   - All 64,981 segments have distance field ✅
   - Total flown distance median: 1,283 NM ✅

### Schema Reality vs. Claim

| Region | Product | Actual Columns | Claimed |
|--------|---------|----------------|---------|
| EUR | Milestones | 21 | 21 ✅ |
| EUR | Level Segments | 31 | 31 ✅ |
| CHN | Milestones | 27 | 21 ❌ |
| CHN | Level Segments | 22 | 31 ❌ |

**Finding:** EUR and CHN schemas are **NOT equivalent** as previously claimed. CHN has 6 extra milestone columns and 9 fewer segment columns.

### Phase Label Provenance

EUR level segments show concerning phase labeling:
- `LEVEL_CONTEXT_PHASE` values: CLIMB, DESCENT (uppercase)
- `START_PHASE` values: `Lvl_climb`, `Lvl_descent` (mixed case with prefix)

**Finding:** Script `07-enrich-eur-level-segments.R` checks uppercase labels while delivered phases use lowercase convention, allowing altitude heuristics to potentially dominate intended phase assignment.

### Aircraft Type Common Support

Types with substantial two-region support for initial study:

| Type | CHN Flights | EUR Flights | Common Support |
|------|-------------|-------------|----------------|
| B738 | 885 | 1,336 | ✅ Strong |
| A321 | 507 | 3,095 | ✅ Strong |
| A320 | 362 | 4,934 | ✅ Strong |
| A21N | 350 | 1,003 | ✅ Strong |
| A20N | 203 | 5,771 | ✅ Strong |
| A333 | 1,404 | 155 | ⚠️ Moderate |
| B789 | 282 | 129 | ⚠️ Moderate |
| A332 | 803 | 102 | ⚠️ Limited EUR |

**Recommendation:** Start with B738 and A320 as specified, then add A321/A20N/A21N. Widebodies remain optional exploratory extension.

### Unresolved Types

- **B737-MAX:** 22 CHN flights, 0 EUR — variant unresolved
- **C919:** 587 CHN flights, 0 EUR — CHN-only, no international comparison possible

## Source Definitions and Data Provenance

### CHN/QAR Source

**Status:** PARTIAL — integration logic known, but source batch/detector provenance INCOMPLETE

#### Known Information

1. **Temporal Coverage**
   - AOBT timestamps: June–August 2025
   - Distribution: 1,954 (June) / 2,228 (July) / 2,239 (August) flights
   - Timezone attribute: UTC

2. **Processing Pipeline**
   - Producer script: `scripts/process-chn-summer2025-update.R`
   - Integration helper: `R/chn-helper-functions.R` (forward-increment cumulative construction)
   - Boundary definitions: TOC/TOD detection applied

3. **Data Characteristics**
   - Coordinates available ✅
   - Altitude records present ✅
   - Fuel flow records present ✅
   - Distance field populated ✅
   - Sampling cadence: High-frequency QAR (exact rate unverified)

#### MISSING Source Information (W2 Required)

- [ ] **Producer/version:** Which code/software version generated each batch?
- [ ] **Unit declarations:** Are coordinates/altitudes/fuel-flow units formally declared?
- [ ] **Coordinate reference:** Scaling, encoding, datum
- [ ] **Altitude reference:** Pressure altitude or GPS altitude?
- [ ] **Fuel accounting:** Engine summation method, raw vs. cleaned, gap/spike rules
- [ ] **Cumulative conventions:** Are cumulative values "up to timestamp" or "including next interval"?
- [ ] **Distance calculation:** Cumulative path from coordinates? Which geodetic model?
- [ ] **Missing ALDT investigation:** 1,190 landing events absent (18.5% of flights). W2 diagnostic lead: check batch helper version and flight-level overlap before attributing to specific cause.
- [ ] **TOC/TOD detector:** Settings, altitude/rate thresholds, window definitions
- [ ] **Clock reference:** True instants or local wall times?

#### MISSING Additional Data (W2 Optional)

- [ ] Weight/mass information
- [ ] Ground speed vs. true airspeed
- [ ] Wind/temperature
- [ ] Tail ID
- [ ] Requested cruise level
- [ ] Cost index or operator information

#### Known Limitations

1. Distance/time contradictions require coordinate-level investigation
2. Missing ALDT affects 18.5% of fleet — selection bias risk for descent/airborne analyses
3. Historical plausibility checks DO NOT confirm units for new batches
4. Plausibility score itself uses distance, so invalid distance weakens that component

### EUR/PRU Source

**Status:** PARTIAL — AEM/BADA model unknown, interval reconstruction INCOMPLETE

#### Known Information

1. **Temporal Coverage**
   - Season: Summer 2025
   - Timezone attribute: Europe/Paris
   - Flights: 21,503

2. **Processing Pipeline**
   - Extraction: `external-pru-query` (LOBT bug corrected in FIXED version)
   - Milestone harmonization: `R/eur-milestone-harmonization.R`
   - Level detection: `R/level-off-milestones.R`
   - Scripts: 04–08 (enrichment and export)
   - Final export: `scripts/08-create-harmonized-analytical-datasets.R`

3. **Data Characteristics**
   - Source segment IDs: Available in raw form
   - Fuel accounting: Present in segments
   - Altitude records: Present
   - Time records: Present
   - **Distance field: ABSENT** in processed segments

#### MISSING Source Information (W1 Required)

- [ ] **Raw LVL semantics:** What do raw LVL rows actually denote in PRU output?
- [ ] **Source interval IDs:** Are trustworthy IDs available for pairing instead of algorithmic reconstruction?
- [ ] **AEM/BADA version:** Which version used?
- [ ] **AEM configuration:** Aircraft/engine config, mass, atmosphere, trajectory inputs
- [ ] **Source segment distance:** Can it be preserved from validated source fields?
- [ ] **Source phase labels:** Can original phases be preserved?
- [ ] **Export lineage:** Which stage produced the canonical release?
- [ ] **Paired level markers:** Why are FL markers absent in export?
- [ ] **Clock semantics:** True instants or local wall times?

#### Known Reconstruction Issues (W1 CRITICAL)

1. **Repeated Segment Keys**
   - Mechanism: Alternating LVL reconstruction? Multiple implicit ends?
   - Current logic: Joining ends by cumulative start order?
   - **Resolution required:** Trace to source segment IDs and chronological records

2. **Interval Overlaps**
   - 87.7% of flights affected
   - 57% exposure overstatement
   - **Resolution required:** Establish source semantics, validate pairing logic

3. **Phase Label Mismatch**
   - Script 07 checks uppercase: CLIMB/DESCENT
   - Delivered labels: `Lvl_climb`/`Lvl_descent`
   - **Resolution required:** Trace milestone-window context vs. altitude-only heuristic

4. **Large Altitude Changes**
   - 60% of intervals show >1,000 ft endpoint change
   - Could indicate: wrong boundaries, pairing error, or true behavior
   - **Resolution required:** Inspect full source altitude profiles

5. **Export Stage Ambiguity**
   - Does script 08 export intended harmonized milestones or earlier enriched input?
   - Local `data-store/production` vs. manifest `processed` path inconsistency
   - **Resolution required:** Validate through release steward

#### Known Data Quality Achievements

- ✅ 0% orphan rate (FIXED pipeline LOBT bug correction)
- ✅ 100% segment completion claimed
- ✅ All flights have required milestones (ATOT/TOC/TOD/ALDT)
- ✅ 99.2% flights have strictly ordered airborne phases

## Minimum Study Scope and Analysis Readiness

### Proposed Minimum Publishable Scope

**Objective:** Test whether independently defined operational profile descriptors improve phase-dependent fuel references beyond exact-aircraft-type/phase coefficients.

**Primary Scope:** Airborne climb/descent using harmonised CHN QAR and EUR NM/AEM analytical outputs.

**Aircraft Types:**
1. **Primary:** B738 and A320
2. **Extension (if quality supports):** A321, A20N, A21N
3. **Optional exploration:** Widebodies (A333, B789, A332) — low EUR counts
4. **Unresolved:** B737-MAX (variant unknown), C919 (CHN-only)

**Profile Summaries:** P20/P50/P80 as candidate summaries, not predetermined efficiency classes.

**Later Extensions:**
- Enroute phase references (where validated)
- Focused cruise altitude/duration study (where validated)
- Taxi operations
- Causal ATM benefit-pool estimation

### Current Analysis Readiness Assessment

| Domain | EUR Status | CHN Status | Ready for Analysis? |
|--------|-----------|-----------|---------------------|
| **Data Availability** | ✅ Present & hash-verified | ✅ Present & hash-verified | ✅ YES |
| **Segment Identity** | ❌ 29,631 repeated keys | ✅ Unique keys | ❌ NO (EUR) |
| **Interval Validity** | ❌ 87.7% overlapping | ✅ No overlaps detected | ❌ NO (EUR) |
| **Distance Integrity** | ⚠️ Field missing | ❌ 27.6% segments >700kt | ❌ NO (both) |
| **Phase Boundaries** | ⚠️ Label mismatch | ✅ Boundaries present | ⚠️ REVIEW NEEDED |
| **Landing Milestones** | ✅ 100% complete | ❌ 18.5% missing ALDT | ⚠️ CHN SELECTIVE |
| **Schema Contract** | ✅ 21/31 as claimed | ❌ 27/22 not equivalent | ⚠️ PARTIAL |
| **Fuel Accounting** | ✅ Present | ✅ Present | ⚠️ UNITS UNVERIFIED |

**Overall Readiness:** ❌ **NOT READY FOR ANALYSIS**

### Critical Path to Readiness

**Gate A (16 October):** Corrected or explicitly restricted analysis release

Required for Gate A:
1. ✅ W0 release contract (this document)
2. ⏳ W1 EUR interval reconstruction and validation
3. ⏳ W2 CHN distance/boundary/fuel validation
4. ⏳ W3 harmonized phases and profile descriptors (awaits W1/W2)

**Minimum viable restricted scope if source issues unresolved:**
- kg/min-only study IF phase boundaries and fuel/time pass independently
- Single-source case study + international contract + transparent limitations
- Subject to joint author agreement

**Do not:** Manufacture comparison coefficients to preserve original scope if validation fails.

## Work Package Assignments and Dependencies

### W1 — EUR Interval Reconstruction and Export Validation

**Status:** ASSIGNED  
**Owner:** To be determined by PRU data-processing lead  
**Dependencies:** W0 (complete); local raw segment access  
**Priority:** CRITICAL  
**Deadline:** 12 October 2026 (Gate A: 16 October)

**Scope:**
1. Trace repeated starts/multiple ends to PRU source segment IDs and chronological records
2. Establish source meaning of raw LVL rows
3. Review alternating LVL pairing and implicit-end state logic
4. Validate `(flight, segment)` uniqueness, ordering, bounds, intersections
5. Recover segment distance from trustworthy source fields
6. Replace altitude-only phase assignment with milestone-window context
7. Check script 08 export lineage (intended harmonized vs. earlier enriched input)
8. Resolve `data-store/production` vs. manifest `processed` path

**Prerequisites:**
- Access to raw PRU segment data
- Source segment IDs and chronological sequence
- AEM version/configuration documentation

**Deliverables:**
- Candidate EUR artifacts with corrected producer code
- Source-trace examples (retained locally)
- Aggregate before/after validation checks
- Excluded/ambiguous case counts
- Upload to R2: `derived/eur/study-runs/<run-id>/W1/`
- Run manifest with input/output hashes

**Acceptance Criteria:**
- No unexplained duplicate interval keys
- No extra ends or overlaps
- No out-of-bounds intervals or negative exposures
- Explicit provenance for every inferred boundary
- Regression tests for repeated ends, co-timed roles, missing ends, step climbs, phase-boundary clipping

**Blockers if Unresolved:**
- Cannot trust EUR segment counts
- Cannot sum EUR exposures
- Cannot compute reliable EUR phase rates
- EUR-CHN comparison invalid

### W2 — CHN Distance, Boundaries, and Fuel Validation

**Status:** ASSIGNED  
**Owner:** To be determined by CAUC QAR worker with operator/source access  
**Dependencies:** W0 (complete)  
**Priority:** CRITICAL (can run parallel to W1)  
**Deadline:** 12 October 2026 (Gate A: 16 October)

**Scope:**
1. Recalculate path distance from source coordinates
2. Compare with recorded ground speed and elapsed time
3. Check coordinate scaling/encoding, jumps, duplicates, units
4. Investigate missing ALDT by batch/type/route
5. Verify TOC/TOD definitions for capped/stepped/short profiles
6. Confirm engine fuel-flow units and summation
7. Verify original/cleaned fuel, spike rules, gap treatment
8. Check cumulative-value timestamp alignment

**Prerequisites:**
- Access to raw QAR coordinate/altitude/fuel records
- Source batch documentation
- Operator/detector documentation

**Deliverables:**
- Candidate CHN release with processing code
- Source preparation/version note
- Distance reconciliation summary
- Boundary attrition table
- Fuel integration checks
- Batch-level exception report
- Upload to R2: `derived/chn/study-runs/<run-id>/W2/`
- Run manifest with input/output hashes

**Acceptance Criteria:**
- No unexplained time/distance contradictions in retained observations
- Ordered and source-supported boundaries for phase-eligible observations
- Independent fuel accounting checks
- Clear reporting of unresolved data
- Test known coordinate/unit, duplicate-time, integration-boundary, missing-landing, gap cases

**Blockers if Unresolved:**
- Cannot trust CHN distance-dependent metrics (kg/NM)
- Cannot trust CHN stage-length context
- Cannot trust distance-derived phase boundaries
- 18.5% missing ALDT creates selection bias for descent/airborne analyses

### W3 — Harmonised Phases and Profile Descriptors

**Status:** PENDING W1/W2  
**Owner:** To be determined (joint analytical-data worker)  
**Dependencies:** W1 and W2 candidate evidence  
**Priority:** CRITICAL  
**Deadline:** 16 October 2026 (Gate A)

**Scope:**
1. Build `flights`, `phase_intervals`, `level_intervals`, `profile_descriptors` to methodological contract
2. Preserve physical and legacy phase schemes separately
3. Define true zero vs. missing level evidence
4. Reconcile phase fuel/time/distance to airborne totals
5. Create missing-data and common-support flow tables
6. Implement development/evaluation split

**Can Start Now:**
- Table design and schema
- Attrition flow logic
- Split policy design

**Cannot Complete Until W1/W2:**
- Actual table population with validated data
- Attrition counts with corrected inputs
- Profile descriptor calculation

### W4–W7 Status

**W4 (Parameter trials):** PENDING W3  
**W5 (Lookup estimation):** PENDING W4  
**W6 (Cruise study):** PENDING W1–W4 fields, can design earlier  
**W7 (Manuscript):** Drafting can start now; numerical results require W5/W6

## Source Access and Authority

### CHN/QAR Access

**Authorised Environment:** CAUC operator/source environment  
**Access Holders:** To be confirmed by CAUC  
**Data Restrictions:**
- Raw QAR records: CANNOT be shared outside authorised environment
- Restricted flight-level traces: Local retention only
- Aggregate evidence: SHAREABLE in GitHub
- Processed analytical datasets: SHAREABLE via R2 with appropriate keys

**Required W2 Actions in Authorised Environment:**
- Coordinate/altitude/fuel unit verification
- Distance recalculation from raw coordinates
- Missing ALDT investigation by batch
- Fuel integration verification
- Example profile review

### EUR/PRU Access

**Authorised Environment:** PRU data-processing environment  
**Access Holders:** To be confirmed by PRU  
**Data Restrictions:**
- Raw PRU segment data: Local access required for W1
- Source segment IDs: Can be preserved in derived products
- Restricted source traces: Local retention only
- Aggregate evidence: SHAREABLE in GitHub
- Processed analytical datasets: SHAREABLE via R2

**Required W1 Actions with Source Access:**
- Raw LVL row inspection
- Source segment ID tracing
- Chronological record sequence review
- AEM configuration documentation
- Source distance field recovery

### R2 Upload Authority

**Current Upload Authority:** rkoelle@ESSP7869  
**Authorised Uploaders:** To be expanded by release steward  
**Upload Protocol:**
1. Process in authorised environment
2. Generate run manifest with input/output hashes
3. Upload to R2 under versioned candidate keys: `derived/<region>/study-runs/<run-id>/<work-package>/`
4. Verify stored hashes match local hashes
5. Commit run manifest and aggregate evidence to GitHub
6. Mark candidate status explicitly
7. Do NOT overwrite production objects

**Production Promotion Authority:** Release steward ONLY after review

## Unresolved Questions for Joint Authors

### Operational Scope

1. **Primary hypotheses:** Which operational hypotheses are primary for the study?
2. **Practical improvement threshold:** What constitutes "practically useful predictive improvement"?
3. **Percentile interpretation:** Agreement on P20/P50/P80 as descriptive references vs. efficiency targets?

### Disclosure and Ethics

4. **Disclosure level:** What aggregate statistics can be published? Any route/airport restrictions?
5. **Technical Note hosting:** Where will independent Technical Note be hosted/cited within conference rules?
6. **Raw data sharing:** Any bridge study requiring raw QAR comparison?

### Workflow

7. **Work package ownership:** Confirm W1 owner with PRU source access
8. **Work package ownership:** Confirm W2 owner with CAUC source access
9. **Development/evaluation split:** Temporal holdout? Route holdout? Both?
10. **Sparse cell policy:** Minimum independent-flight count for lookup cells (30/50/100)?

**Note:** These questions do not block W0 completion, read-only audit, design work, or source-local investigation.

## Storage and Completion Status

### GitHub Artifacts ✅

- [x] This release contract: `notes/study-release-contract.md`
- [x] Frozen manifest snapshot: `notes/results/W0/W0-2026-10-09-001/input-manifest-snapshot.csv`
- [x] Owner/dependency tracker: Embedded in this document
- [x] Aggregate audit evidence: `outputs/study-design/*.csv` (7 files)

### R2 Artifacts

**Status:** N/A (W0 is documentation package, no new analytical datasets)

### Handoff Verification

- [x] Frozen input manifest with all required artifacts hash-verified
- [x] Aggregate readiness audit executed and evidence preserved
- [x] Critical EUR/CHN validity issues documented
- [x] Source questions enumerated for W1/W2
- [x] W1/W2 scope, dependencies, acceptance criteria defined
- [x] Minimum publishable scope proposed in study plan
- [x] Unresolved author questions documented
- [x] Storage locations for all deliverables specified

## Acceptance and Next Actions

### W0 Acceptance Criteria ✅

- [x] Every required input has a verified hash
- [x] Every required input has owner and semantic definition
- [x] Known limitations documented
- [x] W1/W2 assigned with clear scope and acceptance criteria
- [x] Investigation plan established

**W0 Status:** ✅ **ACCEPTED** — Release identity and investigation plan established

**Note:** This accepts release identity and investigation plan, NOT analytical readiness. Analysis release remains BLOCKED on W1/W2 validation.

### Immediate Next Actions

**For Release Steward:**
1. Review and accept this W0 release contract
2. Confirm W1 owner with PRU source access
3. Confirm W2 owner with CAUC source access
4. Resolve joint author questions on scope and disclosure
5. Establish R2 upload authority for W1/W2 workers

**For W1 Worker (EUR):**
1. Accept W1 assignment
2. Confirm PRU source access and AEM documentation access
3. Begin source segment ID tracing and interval reconstruction
4. Target completion: 12 October 2026

**For W2 Worker (CHN):**
1. Accept W2 assignment
2. Confirm CAUC source access and batch documentation
3. Begin coordinate/distance recalculation and missing ALDT investigation
4. Target completion: 12 October 2026

**For W3 Worker:**
1. Review W3 scope and methodological contract
2. Design table schemas and attrition flow
3. Prepare split policy options
4. Stand by for W1/W2 candidate data

## Sources and References

- Instruction commit: `1438f500003ffed0e53bd0d6037411120ef4ead5`
- Study worker plan: `notes/study-worker-plan.md`
- Worker handoff template: `notes/worker-handoff-template.md`
- Methodological note: `technical-note-methodology.qmd`
- Data preparation note: `technical-note-data-preparation.qmd`
- Readiness audit script: `scripts/12-audit-study-readiness.R`
- Authoritative manifest: `data-store/manifest/current-artifacts.csv`

## Document Control

**Version:** 1.0  
**Status:** Release candidate for steward review  
**Last Updated:** 2026-10-09T13:00:00Z  
**Git Branch:** w0-release-contract  
**Instruction Lineage:** Commit 1438f50 → W0 dispatch → This contract

---

*This release contract establishes analytical baseline governance. It does NOT authorize production promotion, manuscript submission, or coefficient publication. Those decisions require completion of validation gates A, B, C per the study worker plan.*
