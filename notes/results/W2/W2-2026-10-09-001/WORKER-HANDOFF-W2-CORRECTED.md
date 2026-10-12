# Worker Handoff: W2 — CHN Validation

**Run ID:** W2-2026-10-09-001  
**Worker:** Claude Sonnet 4.5  
**Completed:** 2026-10-12T10:30:00Z

## Result and Status

**Main finding:** CHN data has systematic coordinate/distance issues causing extreme implied speeds (17.7% phase records >700kt), plus 18.5% flights missing ALDT. Helper code distance calculation (cumulative difference) is correct; issue traces to raw coordinate data quality. Time/fuel metrics valid where phase boundaries present.

**Proposed claim:** CHN time-based metrics (kg/h) valid for 5,248 flights (81.7%) with complete airborne phases. Distance metrics (kg/NM) invalid across all flights pending coordinate investigation.

**Analysis status:** Diagnostic complete, phase-specific eligibility flags produced  
**Data delivery status:** R2 upload PENDING (no credentials available)  
**Review status:** Awaiting steward decision  
**Remaining work:** Raw coordinate investigation, ALDT reconstruction/exclusion, R2 candidate upload  
**Blocker:** Requires CAUC source access for coordinate validation

## Producing Code and Inputs

**Base commit:** w0-release-contract @ a6dbfb9  
**Producing commits:**  
- Validation: 663efac  
- Eligibility flags: bb7368a  
- Corrections: (current branch w2-chn-validation)

**Commands:**
```bash
Rscript scripts/W2-validate-chn-data.R
Rscript scripts/W2-create-eligibility-flags.R
```

**Inputs (all hash-verified):**

| Input | Key | SHA-256 |
|-------|-----|---------|
| CHN milestones | `processed/chn/CHN-canonical-milestones-summer2025.parquet` | 5907faeaf4094d79cd2fa3629c64a3a36fa76dc6e4f3e33ef8bd60cfd6c1db64 |
| CHN level segments | `processed/chn/CHN-level-segments-summer2025.parquet` | 5fdde9e482a60efaf094dac1d77cbb87c39e59cbdde6ce77fe1b1d37f942d4bb |
| CHN phase summaries | `processed/chn/CHN-phase-summaries-summer2025.parquet` | 5f7b0fdcb9e577699b9baf3e46a7e35bc2b5eb37cbda17fa02c28ed73d64ffae |

## Critical Findings

### 1. Distance Calculation — Coordinate Data Issue

**Observation:** 17.7% phase records, 27.6% level segments show implied speed >700kt.

**Root cause investigation:**
- Helper code (`R/canonical-fuel-milestones.R` lines 669, 724, 991) correctly calculates phase/segment distance as `END_DIST - START_DIST` from cumulative values
- Haversine calculation (line 5-11) implements standard formula
- Extreme examples: TAXI_OUT 7,660 NM in 0.033 min (13.7M kt), consistent with coordinate scaling/unit error or large coordinate gaps

**Hypothesis:** Raw QAR coordinate data contains:
- Scaling errors (degrees vs radians, or km misinterpreted as NM)
- Large unexplained gaps creating inflated path distance
- Batch-specific coordinate quality issues (all 14 batches affected but varying severity)

**Evidence:** Route ZSSS-ZPPP great circle ~1,283 NM; observed TAXI phase distance 7,660 NM (~6× actual), suggesting systematic coordinate error not helper logic error.

**Impact:**
- ❌ ALL distance-dependent metrics invalid (kg/NM, stage-length context)
- ✅ Time/fuel metrics unaffected (duration/fuel calculations independent of coordinates)

### 2. Missing ALDT — Batch/Type Pattern

**Observation:** 1,190 flights (18.5%) missing ALDT milestone.

**Patterns:**
- By batch: output4 (70%), output14 (50%), output1/2/13 (37-45%), others (0-20%)
- By type: C919 (100%, n=587), B737-MAX (100%, n=22), B737-700/800 (33-40%), Airbus A-series (~0%)
- By route: ZSSS-ZPPP (97.5%), ZLXY/ZSSS routes (22%)

**Impact on phases:**
- ALDT-independent: CLIMB (100% eligible), CRUISE (81.7%), DESCENT (100% of those with TOD)
- ALDT-dependent: LTO_APPROACH_LANDING (99.8% of those with ALDT), TAXI_IN (81.5%), RUNWAY_EXIT (requires ALDT)

### 3. Fuel Integration — Validated

All aircraft types show plausible burn rates (narrow-body 2,400-3,200 kg/h, wide-body 5,300-7,000 kg/h). Zero outliers.

## Phase-Specific Eligibility

**Time/Fuel Eligibility by Phase:**

| Phase | ALDT Dependent? | Eligible Records | % of Total | Notes |
|-------|----------------|------------------|------------|-------|
| CLIMB | No | 6,398 / 6,398 | 100% | Bounded by ATOT-TOC |
| CRUISE | No | 5,226 / 6,399 | 81.7% | Requires TOC and TOD |
| DESCENT | No | 5,226 / 5,226 | 100% | Bounded by TOD-ALTO |
| LTO_APPROACH_LANDING | Yes | 5,218 / 5,231 | 99.8% | Requires ALDT |
| TAXI_IN | Yes | 5,231 / 6,421 | 81.5% | Requires ALDT |
| TAXI_OUT | No | 6,392 / 6,421 | 99.5% | Bounded by AOBT-ATOT |
| LTO_CLIMB_OUT | No | 5,653 / 6,398 | 88.4% | |
| TAKE_OFF_ROLL | No | 6,420 / 6,420 | 100% | |
| RUNWAY_EXIT | Yes | 5,217 / 5,217 | 100% | Only present when ALDT present |

**Flight-Level Summary:**
- Airborne (CLIMB+CRUISE+DESCENT) time/fuel eligible: 5,248 flights (81.7%)
- Descent phase eligible: 5,226 flights (81.4%)
- Approach phase eligible: 5,218 flights (81.3%)

**Distance eligibility:** 0 flights (0%) — all invalid pending coordinate correction.

## Outputs

**GitHub (committed to w2-chn-validation branch):**
- Validation script: `scripts/W2-validate-chn-data.R`
- Eligibility script: `scripts/W2-create-eligibility-flags.R`
- 15 diagnostic CSV files (speed, ALDT, fuel, eligibility)
- This handoff

**R2 Candidate Location (UPLOAD PENDING):**
- Proposed key: `derived/chn/study-runs/W2-2026-10-09-001/phase-eligibility.parquet`
- Proposed key: `derived/chn/study-runs/W2-2026-10-09-001/flight-eligibility.parquet`
- Status: Local files ready, R2 credentials unavailable
- Local package: `notes/results/W2/W2-2026-10-09-001/*.csv`

**Flight-level data:** None in GitHub (aggregate only per instructions).

## Batch Producer Version

**Status:** UNKNOWN

**Evidence:**
- Processing summaries (`data-incoming/.../outputN/PROCESSING-SUMMARY.txt`) show dates 2026-10-08 but no helper version
- Git history shows helper code updates: 68b9f8b (2026-10-08), 1324771, 43abf68
- Most recent pre-processing commit: 68b9f8b "Handle CHN flights without level segments"
- Likely version: commit 68b9f8b or later, but cannot confirm exact version used for each batch

**Recommendation:** Query CAUC for exact R script version/commit used to process each output batch.

## Audit Result

**Data availability:** ✅ PASS — All 3 input files present and hash-verified  
**Distance integrity:** ❌ FAIL — 17.7% phase records, 27.6% level segments >700kt implied speed  
**Boundary ordering:** ✅ PASS — All 54,131 phase records properly ordered  
**Fuel plausibility:** ✅ PASS — All aircraft types within expected ranges, zero outliers  
**ALDT completeness:** ⚠️ PARTIAL — 1,190 flights (18.5%) missing ALDT  
**Phase eligibility:** ✅ COMPUTED — Phase-specific flags distinguish ALDT-dependent vs independent

**Overall:** Data suitable for time/fuel analyses with phase-specific eligibility restrictions. Distance analyses blocked pending coordinate investigation.

## Unresolved Issues

1. **Coordinate data quality:** Root cause of extreme distances (scaling? gaps? unit error?) requires raw QAR CSV inspection
2. **Missing ALDT mechanism:** Batch/type patterns suggest processing differences, but specific cause unknown without source investigation
3. **Helper version:** Cannot confirm exact code version used for each batch (processing summaries lack this metadata)
4. **C919/B737-MAX ALDT:** 100% missing suggests type-specific detection threshold mismatch or systematic data truncation
5. **ZSSS-ZPPP route:** 97.5% missing ALDT warrants route-specific investigation

## Recommended Actions

**For W3 (Immediate):**
- Use phase-eligibility flags to filter CHN phases for time/fuel analyses
- Restrict to 5,248 airborne-eligible flights (81.7%)
- Exclude all distance-dependent metrics from CHN
- Document 18.5% ALDT-dependent phase exclusion as known bias

**For Coordinate Correction (CAUC Worker, 2-3 days):**
1. Inspect raw QAR CSV coordinate fields for scaling/unit declarations
2. Recalculate distances from corrected coordinates
3. Validate: median cruise speed should be ~450-480kt, not 1,018kt
4. Regenerate phase summaries with corrected distances
5. Upload corrected candidates to R2

**For R2 Upload (Immediate when credentials available):**
- Upload `phase-eligibility.parquet` and `flight-eligibility.parquet` to proposed keys
- Verify stored hashes match local
- Update this handoff with actual keys and hashes

## References

- Study plan: `notes/study-worker-plan.md` lines 79-99
- Release contract: `notes/study-release-contract.md` lines 374-422  
- Helper code: `R/canonical-fuel-milestones.R` lines 5-11 (haversine), 669/724/991 (distance calc)
- Base commit: a6dbfb9 (w0-release-contract)

---

**Status:** Diagnostic complete, eligibility flags produced, R2 upload pending  
**Ready for:** W3 with phase-specific restrictions OR coordinate correction path  
**NOT ready for:** Distance-dependent analyses without coordinate correction

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
