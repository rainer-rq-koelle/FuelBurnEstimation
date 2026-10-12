# Worker Handoff: W2 — CHN Validation

**Run ID:** W2-2026-10-09-001  
**Worker:** Claude Sonnet 4.5  
**Completed:** 2026-10-12T16:00:00Z

## Result and Status

**Main finding:** CHN data exhibits batch-wide distance anomaly (18.3% of non-zero-duration phase records show implied speed >700kt) and 18.5% missing ALDT. Helper code distance calculation appears correct by inspection; cause unknown until source QAR cases and batch-producer versions checked.

**Analysis status:** Diagnostic complete  
**Data delivery status:** PENDING R2 upload (credentials unavailable, local package ready)  
**Review status:** Awaiting steward decision  
**Blocker:** R2 upload credentials; CAUC source access for coordinate investigation

## Producing Code and Inputs

**Base commit:** a6dbfb9 (w0-release-contract)  
**Branch:** w2-chn-validation-clean  
**Producing commits:** 451aaa1, 3c4c184, (final corrections pending)

**Commands:**
```bash
Rscript scripts/W2-validate-chn-data.R
Rscript scripts/W2-create-eligibility-flags-corrected.R
```

**Inputs (hash-verified):**

| Input | SHA-256 (first 16) |
|-------|--------------------|
| CHN milestones | 5907faeaf4094d79 |
| CHN level segments | 5fdde9e482a60efa |
| CHN phase summaries | 5f7b0fdcb9e57769 |

## Critical Findings

### 1. Distance Anomaly — Cause Unknown

**Observed:** 9,573 of 52,171 non-zero-duration phase records (18.3%) show implied speed >700kt.

**Speed calculation:**
- Numerator: Phase records with `DISTANCE_NM / (DURATION_MIN/60) > 700kt`
- Denominator: Phase records with `DURATION_MIN > 0` and `!is.na(DISTANCE_NM)`
- Excluded: Zero-duration records from denominator

**Helper code inspection:** `R/canonical-fuel-milestones.R` lines 669, 724, 991 calculate phase distance as `END_DIST_FLOWN_NM - START_DIST_FLOWN_NM`, which correctly computes the increment from cumulative values.

**Cause:** Unknown. Root cause cannot be determined from processed data. Requires inspection of source QAR coordinate records and batch-producer version confirmation.

**Impact:**  
- ❌ Distance metrics (kg/NM, stage-length) invalid
- ✅ Time/fuel metrics unaffected

### 2. Missing ALDT

1,190 flights (18.5%) missing ALDT. Patterns: C919 (100%), B737-MAX (100%), batch output4 (70%).

**Impact:** Limits DESCENT phase presence to 5,226 flights; ALDT-dependent phases (APPROACH, TAXI_IN) have 18.5% exclusion.

### 3. Fuel Plausibility Checks

All aircraft types show burn rates within plausible ranges (narrow-body 2,400-3,200 kg/h, wide-body 5,300-7,000 kg/h). These are plausibility checks against aircraft-type references, not independent fuel integration validation.

## Phase-Specific Eligibility

**Flight-Level (corrected):**
- Total flights: 6,421
- Airborne eligible (CLIMB+CRUISE+DESCENT all present and eligible): 5,226 (81.4%)
- Has ALDT: 5,231 (81.5%)

**Explanation:** Airborne eligibility requires all three phases present AND eligible. DESCENT presence is limited to 5,226 flights (those with TOD), which becomes the limiting factor.

**Phase-Level:**

| Phase | ALDT-Dep | Eligible | Total | % |
|-------|----------|----------|-------|---|
| CLIMB | No | 6,398 | 6,398 | 100% |
| CRUISE | No | 5,226 | 6,399 | 81.7% |
| DESCENT | No | 5,226 | 5,226 | 100% |
| LTO_APPROACH_LANDING | Yes | 5,218 | 5,231 | 99.8% |
| TAXI_IN | Yes | 5,231 | 6,421 | 81.5% |

Distance eligible: 0 flights.

## Outputs and Manifest

**Aggregate summaries (in GitHub):**
- Validation scripts (2)
- Diagnostic CSVs (14): speed analyses, ALDT patterns, fuel plausibility, eligibility summaries
- Findings summary, worker handoff
- Output manifest with SHA256 hashes

**Flight-level flags (local package, NOT in GitHub):**
- `local-package/phase-eligibility-flags.csv` (54,131 records)
  - SHA256: e6a7a59517c2626807e4408bca41784e22984f85feeead1906334e22d5966624
- `local-package/flight-eligibility-flags.csv` (6,421 records)
  - SHA256: 88bf459382786123e45a20941821a1ca135641a697476bef82e0868afc826331

**R2 Candidate Location (UPLOAD PENDING):**
- Proposed: `derived/chn/study-runs/W2-2026-10-09-001/phase-eligibility.parquet`
- Proposed: `derived/chn/study-runs/W2-2026-10-09-001/flight-eligibility.parquet`
- Status: CSV sources ready locally, Parquet conversion pending, R2 credentials unavailable
- **Data delivery: PENDING** until upload and hash verification complete

**Complete manifest:** `notes/results/W2/W2-2026-10-09-001/output-manifest.txt`

## Batch Producer Version

**UNKNOWN** — Processing summaries lack version metadata. Likely commit 68b9f8b (2026-10-08) or later based on git history, but cannot confirm exact version per batch without CAUC documentation.

## Audit Result

- ✅ Data availability: All inputs present and hash-verified
- ❌ Distance integrity: 18.3% extreme speeds, cause unknown
- ✅ Boundary ordering: All phase records properly ordered
- ✅ Fuel plausibility: All types within expected ranges
- ⚠️ ALDT completeness: 18.5% missing
- ✅ Phase eligibility: Computed and validated

## Unresolved Issues

1. Distance anomaly root cause (requires source QAR inspection)
2. Missing ALDT mechanism (batch/type specific)
3. Batch producer version confirmation
4. R2 upload credentials
5. Parquet flag file creation

## Recommended Actions

**For R2 Upload (when credentials available):**
1. Convert local CSV flags to Parquet
2. Upload to proposed R2 keys
3. Verify stored hashes
4. Update this handoff with actual keys/hashes
5. Mark data delivery COMPLETE

**For W3:**
Do NOT proceed with CHN phase-level analyses until R2 upload completes and flags are retrievable. When ready:
- Use 5,226 airborne-eligible flights for time/fuel analyses
- Exclude all distance metrics
- Apply phase-specific eligibility flags

**For CAUC Investigation:**
Inspect source QAR coordinate records and confirm batch-producer versions to diagnose distance anomaly.

## Delivery Status

**NOT READY for W3** — Required eligibility flags exist locally but are not yet retrievable from R2. Data delivery incomplete.

---

**Base:** a6dbfb9  
**Branch:** w2-chn-validation-clean  
**Status:** Diagnostic complete, R2 upload PENDING

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
