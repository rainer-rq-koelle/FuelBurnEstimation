# W2 CHN Data Validation — Key Findings Summary

**Run ID:** W2-2026-10-09-001  
**Completed:** 2026-10-09T14:50:00Z  
**Worker:** Claude Sonnet 4.5

## Critical Issues Identified

### 1. Distance Calculation Error (BLOCKER for distance metrics)

**Problem:** Phase summaries contain cumulative distance instead of phase-specific incremental distance.

**Evidence:**
- TAXI_OUT showing 7,660 NM in 0.033 min → 13,788,378 kt implied speed
- 17.7% of phase records have implied speed >700 kt
- 27.6% of level segments have implied speed >700 kt  
- Median cruise speed 1,018 kt (should be ~450-480 kt)

**Impact:**  
❌ **BLOCKS** kg/NM, stage-length context, distance-derived boundaries  
✅ **DOES NOT AFFECT** time-based metrics (kg/h, fuel/time valid)

### 2. Missing ALDT Milestones (BIAS for descent analyses)

**Problem:** 1,190 flights (18.5%) missing actual landing time milestone.

**Patterns:**
- **By Type:** C919 (100%), B737-MAX (100%), B737-800/700 (33-40%), Airbus A-series (~0%)
- **By Batch:** output4 (70%), output14 (50%), output1/2/13 (37-45%), others (0-20%)
- **By Route:** ZSSS-ZPPP (97.5%), ZLXY-ZSSS/ZSSS-ZLXY (22%), others (<5%)

**Impact:**  
⚠️ **BIASES** descent/airborne analyses (excludes 18.5% of flights)

## Positive Findings

✅ **Fuel Integration Valid:** All aircraft types show plausible burn rates (narrow-body 2,400-3,200 kg/h, wide-body 5,300-7,000 kg/h)  
✅ **Phase Boundaries Valid:** All 54,131 phase records properly ordered, no negative durations  
✅ **Milestone Timing:** TOC/TOD present for 99.9% of flights

## Data Eligibility Status

| Analysis Type | Eligible Flights | Status |
|---------------|------------------|--------|
| Time-based metrics (kg/h) | 6,421 (100%) | ✅ VALID |
| Fuel integration | 6,421 (100%) | ✅ VALID |
| **Distance metrics (kg/NM)** | **0 (0%)** | **❌ INVALID** |
| **Stage-length context** | **0 (0%)** | **❌ INVALID** |
| Descent analyses | 5,231 (81.5%) | ⚠️ BIASED |

## Recommendations

**Option A (Preferred):** Full W2 implementation with CAUC QAR worker
- Recalculate distance from raw QAR coordinates
- Investigate missing ALDT by batch
- Regenerate corrected phase summaries
- Timeline: 2-3 days, 8-12 hours effort

**Option B:** Restrict CHN to time-only analyses
- Use DURATION_MIN and FUEL_KG only
- Exclude distance-dependent metrics
- Mark 1,190 flights as descent-ineligible
- Timeline: Immediate

**Option C:** Defer CHN, prioritize EUR W1 correction
- Mark CHN as exploratory only
- Focus resources on EUR interval reconstruction
- Reassess CHN after Gate A

**Decision required by:** 12 October 2026

## Files Created

11 diagnostic CSV files + worker handoff document in `notes/results/W2/W2-2026-10-09-001/`

See `worker-handoff-W2.md` for full details.
