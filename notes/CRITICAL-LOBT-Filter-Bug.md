# 🚨 CRITICAL: LOBT Filter Bug Creating Artificial Orphans

**Date:** 2026-10-08  
**Status:** 🔴 **BUG IDENTIFIED - REQUIRES RE-EXTRACTION**  
**Impact:** High - Artificially inflating orphan rate from ~10-15% to 54.4%

---

## The Problem

### Current (BROKEN) Extraction Query

```sql
SELECT * FROM PRUPROD.PRU_G2G_FB_V4
WHERE LOBT >= TO_DATE('2025-06-01', 'YYYY-MM-DD')
  AND LOBT <  TO_DATE('2025-09-01', 'YYYY-MM-DD')  -- ❌ CUTS OFF SEGMENTS!
  AND ADEP IN (airport_list)
  AND ADES IN (airport_list)
```

### Why This Breaks

**LOBT** = **L**ast **O**ff-**B**lock **T**ime (scheduled departure time at FLIGHT level)  
**TIME_OVER** = Actual timestamp when aircraft crosses waypoint (SEGMENT level)

The query filters **SEGMENTS** by flight-level **LOBT**, causing segment truncation:

```
Flight Example: EDDF-LGAV
├─ SAM_ID: ABC123
├─ LOBT: 2025-08-31 23:30 UTC (scheduled departure)
├─ Segment 1 (TIME_OVER: 23:35): Takeoff ✓ INCLUDED
├─ Segment 2 (TIME_OVER: 23:50): Climb ✓ INCLUDED
├─ Segment 3 (TIME_OVER: 00:10): Cruise + LVL_START ✓ INCLUDED
├─ Segment 4 (TIME_OVER: 00:45): Cruise continues ✓ INCLUDED
└─ Segment 5 (TIME_OVER: 01:15): TOD + LVL_END ✗ EXCLUDED!
                                  (Sep 1 > LOBT filter!)

Result: LVL_START present, LVL_END missing → ARTIFICIAL ORPHAN
```

---

## Impact Assessment

### Measured Orphan Rates (BEFORE FIX)
- **Total:** 54.4% (10,704 / 19,693 flights)
- **Lvl_climb:** 70.0% orphaned
- **Lvl_descent:** 18.6% orphaned

### Expected Orphan Rates (AFTER FIX)
- **Estimated:** 10-15% (based on typical PRU data quality)
- **Lvl_climb:** ~20-30% (cruise-climb transitions)
- **Lvl_descent:** ~5-10% (TOD usually explicit)

### Flights Most Affected

**Highest risk for truncation:**
1. **Evening/night departures** (LOBT 20:00-23:59)
   - Segments spill into next day
   - Filter boundary at midnight cuts segments

2. **Long-haul routes** (>3 hours)
   - EDDM-LTFM (Munich-Istanbul): ~3.5 hours
   - EDDF-LGAV (Frankfurt-Athens): ~3.0 hours
   - More segments span filter boundary

3. **Late-month flights**
   - LOBT: Aug 31, 22:00
   - Segments at Sep 1, 01:00 → EXCLUDED

---

## The Fix: Two-Stage SAM_ID Extraction

### Corrected Approach

```sql
-- STAGE 1: Select FLIGHTS by LOBT (flight selection criteria)
SELECT DISTINCT SAM_ID, LOBT, ADEP, ADES
FROM PRUPROD.PRU_G2G_FB_V4
WHERE LOBT >= TO_DATE('2025-06-01', 'YYYY-MM-DD')
  AND LOBT <  TO_DATE('2025-09-01', 'YYYY-MM-DD')
  AND ADEP IN (airport_list)
  AND ADES IN (airport_list)

-- STAGE 2: Get ALL segments for selected SAM_IDs (no TIME_OVER filter!)
SELECT *
FROM PRUPROD.PRU_G2G_FB_V4
WHERE SAM_ID IN (selected_sam_ids_from_stage_1)
-- ✅ This captures ALL segments, even those with TIME_OVER beyond LOBT period!
```

### Why This Works

✅ **Flight selection still based on LOBT** (preserves period definition)  
✅ **All segments captured per flight** (no truncation)  
✅ **Complete LVL_START/LVL_END pairs** (no artificial orphans)  
✅ **Preserves data integrity** (flights are atomic units)

---

## Re-Extraction Plan

### Script Created
`scripts/extract-g2g-2025-summer-FIXED.R`

### Key Changes
1. **Two-stage extraction** using SAM_ID
2. **Verification step** counts segments beyond LOBT period
3. **Reports rescued LVL markers** that would have been lost

### Expected Results

**Before (BROKEN):**
- Segments: ~400,000
- Orphan rate: 54.4%
- Missing segments: ~50,000+ (estimated)

**After (FIXED):**
- Segments: ~450,000 (estimate +10-15%)
- Orphan rate: 10-15% (realistic for PRU data)
- Complete flights: 100%

---

## Verification Steps

After re-extraction, verify:

```r
library(arrow)
library(dplyr)

# Load FIXED data
seg_fixed <- read_parquet("data/g2g-segment-details-2025-summer-FIXED.parquet")

# Check 1: Segments per flight distribution
seg_fixed %>%
  count(SAM_ID) %>%
  summarise(
    min_seg = min(n),
    median_seg = median(n),
    mean_seg = mean(n),
    max_seg = max(n)
  )

# Check 2: TIME_OVER beyond LOBT period
seg_fixed %>%
  mutate(segment_date = as.Date(TIME_OVER)) %>%
  filter(segment_date >= as.Date("2025-09-01")) %>%
  nrow()
# Should be > 0 (rescued segments!)

# Check 3: LVL pairing after conversion
# (Run through canonical conversion and check orphan rate)
```

---

## Comparison: OLD vs FIXED

| Metric | OLD (BROKEN) | FIXED (Expected) | Change |
|--------|--------------|------------------|--------|
| **Flights** | 21,503 | 21,503 | Same |
| **Segments** | ~400,000 | ~450,000 | +12% |
| **Orphan Rate** | 54.4% | 10-15% | -75% |
| **Lvl_climb Orphans** | 70% | 20-30% | -60% |
| **Lvl_descent Orphans** | 18.6% | 5-10% | -50% |

---

## Root Cause Analysis

### Why This Happened

1. **Segment-level query** filtering by **flight-level timestamp** (LOBT)
2. **No explicit SAM_ID grouping** to ensure flight completeness
3. **Implicit assumption** that all segments have TIME_OVER within LOBT day
4. **Evening/night flights** violate this assumption regularly

### Why It Wasn't Caught

1. **Orphan rate seemed "plausible"** at first glance
2. **No segment count verification** against expected flight durations
3. **PRU data quality known to have issues** (masked the extraction bug)
4. **Diagnostic focused on source data** rather than extraction logic

---

## Action Items

- [x] **Identify bug** (LOBT filter truncating segments)
- [x] **Create fixed extraction script** (`extract-g2g-2025-summer-FIXED.R`)
- [ ] **Run re-extraction** with SAM_ID-based approach
- [ ] **Verify segment counts** increased by 10-15%
- [ ] **Convert to canonical format** using fuel_eur_milestones()
- [ ] **Rerun harmonization** with implicit END logic
- [ ] **Check new orphan rate** (should be 10-15%)
- [ ] **Update PRU feedback report** with corrected numbers
- [ ] **Re-upload to R2** with FIXED data
- [ ] **Document in paper methodology** (extraction approach)

---

## Lessons Learned

### For Future Extractions

✅ **Use SAM_ID/flight key** for complete flight extraction  
✅ **Filter on flight metadata**, not segment timestamps  
✅ **Verify segment counts** match expected flight durations  
✅ **Check boundary cases** (late evening, month-end flights)  
✅ **Validate completeness** before processing

### Red Flags We Missed

🚩 **54.4% orphan rate** for well-defined intra-EUR routes  
🚩 **70% orphan in Lvl_climb** (implausibly high)  
🚩 **Consistent pattern** (not random distribution)  
🚩 **No verification** of segment counts vs flight duration

---

## Status

**Current:** Using BROKEN extraction (54.4% artificial orphans)  
**Next Step:** **RUN FIXED EXTRACTION** to get correct data  
**ETA:** ~30-60 minutes for database query + processing  
**Priority:** 🔴 **HIGH** - Affects all downstream analysis

---

**Discovered by:** User observation that 54.4% orphan rate is "crazy" for intra-EUR flights ✅  
**Root cause:** LOBT filter truncating segments at day boundaries  
**Solution:** Two-stage SAM_ID-based extraction ensuring flight completeness
