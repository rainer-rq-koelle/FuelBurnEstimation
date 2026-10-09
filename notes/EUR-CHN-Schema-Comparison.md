# EUR vs CHN Schema Compatibility Check

**Date:** 2026-10-09  
**Purpose:** Verify compatibility before R2 reorganization

---

## Canonical Milestone Schemas

### CHN Canonical (from Chinese colleagues)
```
SOURCE_UID, FLTID, ADEP, ADES, TYPE,
TIME, LAT, LON, ALT_FT,
MST, MST_GROUP, MST_METHOD,
TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL,
DIST_FLOWN_NM, TOTAL_FLOWN_NM, DIST_REMAINING_NM,
DIST_FROM_DEP_NM, DIST_TO_ARR_NM,
FLIGHT_PHASE_RAW,
LEVEL_SEGMENT_ID, LEVEL_DURATION_SEC, LEVEL_DISTANCE_NM,
LEVEL_FUEL_KG, LEVEL_CONTEXT_PHASE,
ROW_ID
```
**Total:** 26 columns

### EUR FIXED Canonical (from fuel_eur_milestones)
```
SOURCE_UID, FLTID, ADEP, ADES, TYPE,
TIME, LAT, LON, ALT_FT,
MST,
TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL,
DIST_FLOWN_NM, DIST_FROM_DEP_NM, DIST_TO_ARR_NM,
FLIGHT_PHASE_RAW,
ROW_ID
```
**Total:** 17 columns

---

## Differences

### Core Columns (COMPATIBLE) ✅

Both have these essential columns:
- **Flight ID:** SOURCE_UID, FLTID, ADEP, ADES, TYPE
- **Trajectory:** TIME, LAT, LON, ALT_FT
- **Milestone:** MST
- **Fuel:** TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL
- **Distance:** DIST_FLOWN_NM, DIST_FROM_DEP_NM, DIST_TO_ARR_NM
- **Phase:** FLIGHT_PHASE_RAW
- **Index:** ROW_ID

### CHN-Only Columns (EXTRA METADATA)

**Milestone metadata:**
- `MST_GROUP` - Milestone category (operational_profile, etc)
- `MST_METHOD` - How milestone was derived (explicit, derived_chn_qar_profile, etc)

**Distance metrics:**
- `TOTAL_FLOWN_NM` - Total trajectory distance
- `DIST_REMAINING_NM` - Distance remaining to destination

**Level segment metadata:**
- `LEVEL_SEGMENT_ID` - Which level segment this belongs to
- `LEVEL_DURATION_SEC` - Duration of the level segment
- `LEVEL_DISTANCE_NM` - Distance covered in level segment
- `LEVEL_FUEL_KG` - Fuel burned in level segment
- `LEVEL_CONTEXT_PHASE` - Phase context for level segment

---

## Analysis

### ✅ **Core Compatibility: YES**

The **17 core columns** needed for analysis are present in both:
- Flight identification
- Trajectory data (time, position, altitude)
- Milestones
- Cumulative fuel burn
- Distance metrics
- Phase information

### 📊 **CHN Has Enhanced Metadata**

The Chinese colleagues added:
1. **Provenance tracking** (MST_GROUP, MST_METHOD)
2. **Pre-computed metrics** (TOTAL_FLOWN_NM, DIST_REMAINING_NM)
3. **Level segment enrichment** (embedded in canonical milestones)

### 🔧 **For Analytical Compatibility**

**Option 1: Use Common Subset (17 columns)**
- EUR and CHN both have the 17 core columns
- Simple, works immediately
- Loses CHN metadata advantages

**Option 2: Enrich EUR to Match CHN**
- Add the 9 CHN-only columns to EUR
- Better metadata tracking
- More work, but higher quality

**Option 3: Separate Processing**
- Keep EUR and CHN in their native formats
- Join/merge during analysis
- Most flexible

---

## Recommendation

**For immediate compatibility:** Use **Option 1** (common 17 columns)

**Reasoning:**
- All essential data present ✅
- EUR and CHN directly comparable ✅
- No additional processing needed ✅
- Can enrich EUR later if needed

**What to do:**
1. Create EUR datasets with same 17-column schema
2. Optionally add CHN-style metadata columns (with NA for EUR)
3. Upload both to R2 in compatible format
4. Analytical pipeline works on common columns

---

## Next Steps

### Before R2 Reorganization:

1. **Test analytical compatibility**
   - Load EUR FIXED canonical (17 cols)
   - Load CHN canonical (26 cols, use subset)
   - Verify they can be processed together

2. **Decide on schema strategy**
   - Option 1: Keep EUR at 17 cols
   - Option 2: Enrich EUR to 26 cols
   - Option 3: Keep separate, merge in analysis

3. **Update documentation**
   - Document schema differences
   - Note which columns are EUR/CHN specific

### After Verification:

4. **Execute R2 reorganization**
   - Archive OLD EUR data
   - Upload FIXED EUR data (chosen schema)
   - Verify CHN + EUR compatibility in R2

---

## Schema Decision Needed

**Question for user:**

Should EUR canonical milestones be:

**A) Keep 17-column format** (current EUR FIXED)
- Simpler
- Matches what fuel_eur_milestones() produces
- Less metadata

**B) Enrich to 26-column format** (match CHN)
- Better metadata tracking
- Consistent with CHN
- More columns (some will be NA for EUR)

**C) Add only some CHN columns** (hybrid)
- MST_GROUP, MST_METHOD for provenance
- Skip level segment pre-computation
- Middle ground

---

*Waiting for schema decision before R2 reorganization*
