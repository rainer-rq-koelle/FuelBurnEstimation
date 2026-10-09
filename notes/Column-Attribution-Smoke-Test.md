# Column Attribution Smoke Test

**Purpose:** Clarify which columns belong in which dataset and when they're generated

---

## The Three Dataset Types

### 1. Canonical Milestones
**What:** Individual milestone events from trajectory  
**When:** First step after raw data extraction  
**Function:** `fuel_eur_milestones()`, `fuel_chn_qar_profile()`

### 2. Harmonized Milestones  
**What:** Canonical + implicit markers + convention mapping  
**When:** After canonical, before level segment derivation  
**Function:** `harmonize_eur_milestones()`

### 3. Level Segments
**What:** Derived intervals from paired LVL_START/LVL_END  
**When:** After harmonization  
**Function:** `derive_level_segments()`

---

## Column Attribution

### ✅ **Canonical Milestones Should Have:**

**Core trajectory:**
- `SOURCE_UID` - Unique flight identifier
- `FLTID` - Flight number
- `ADEP`, `ADES` - Departure/arrival airports
- `TYPE` - Aircraft type
- `TIME` - Timestamp
- `LAT`, `LON` - Position
- `ALT_FT` - Altitude

**Milestone:**
- `MST` - Milestone label (TOC, TOD, LVL_START, etc)
- `MST_GROUP` ✅ - Category (operational_profile, level_segment, etc)
- `MST_METHOD` ✅ - Derivation method (explicit, derived, implicit)

**Cumulative metrics:**
- `TOT_FUEL_KG` - Cumulative fuel burned
- `TOT_FUEL_KG_ORIGINAL` - Before corrections
- `DIST_FLOWN_NM` - Distance from origin to this point
- `TOTAL_FLOWN_NM` ✅ - **Total trajectory distance** (constant per flight)
- `DIST_FROM_DEP_NM` - Distance from departure
- `DIST_TO_ARR_NM` - Distance to arrival
- `DIST_REMAINING_NM` ✅ - Distance remaining (= TOTAL - FLOWN)

**Context:**
- `FLIGHT_PHASE_RAW` - Phase at this milestone
- `ROW_ID` - Sequence number in trajectory

**Optional level segment reference:**
- `LEVEL_SEGMENT_ID` - ID of segment this milestone starts/ends (NA for non-LVL)

**NOT in canonical (these belong in level segments):**
- ❌ `LEVEL_DURATION_SEC` 
- ❌ `LEVEL_DISTANCE_NM`
- ❌ `LEVEL_FUEL_KG`
- ❌ `LEVEL_CONTEXT_PHASE`

---

### ✅ **Level Segments Should Have:**

**Segment identification:**
- `SOURCE_UID` - Flight identifier
- `FLTID`, `ADEP`, `ADES`, `TYPE` - Flight metadata
- `LEVEL_SEGMENT_ID` - Unique segment identifier
- `LEVEL_CONTEXT_PHASE` - Phase context (ENROUTE, etc)

**Interval definition:**
- `START_TIME`, `END_TIME` - Temporal bounds
- `START_ROW_ID`, `END_ROW_ID` - Trajectory indices
- `START_ALT_FT`, `END_ALT_FT` - Altitude bounds
- `ALTITUDE_BAND_FT` - Classified altitude band

**Interval metrics:**
- `DISTANCE_NM` - Distance covered in segment
- `FUEL_KG` - Fuel burned in segment  
- `DURATION_SEC` - Segment duration
- `START_DIST_FLOWN_NM`, `END_DIST_FLOWN_NM` - Position along trajectory
- `START_FUEL_KG`, `END_FUEL_KG` - Cumulative fuel at bounds

**Quality:**
- QC flags (orphaned, excessive_alt_change, etc)

---

## Why This Structure?

### Canonical Milestones = Events
- Each row is ONE event (milestone)
- Cumulative metrics up to that point
- LEVEL_* columns mostly NA (only for LVL_START/END rows as references)

### Level Segments = Intervals
- Each row is ONE interval (level segment)
- Start/end bounds and derived metrics
- Complete interval data

---

## Smoke Test: Generate Each Column

### 1. TOTAL_FLOWN_NM
**Where:** Canonical milestones  
**How to generate:**
```r
canonical <- canonical %>%
  group_by(SOURCE_UID) %>%
  mutate(TOTAL_FLOWN_NM = max(DIST_FLOWN_NM, na.rm = TRUE)) %>%
  ungroup()
```
**EUR status:** ❌ Not generated (should be added)

---

### 2. DIST_REMAINING_NM
**Where:** Canonical milestones  
**How to generate:**
```r
canonical <- canonical %>%
  mutate(DIST_REMAINING_NM = TOTAL_FLOWN_NM - DIST_FLOWN_NM)
```
**EUR status:** ❌ Not generated (can be derived from TOTAL_FLOWN_NM)

---

### 3. MST_GROUP
**Where:** Canonical milestones  
**How to generate:**
```r
canonical <- canonical %>%
  mutate(MST_GROUP = case_when(
    MST %in% c("AOBT", "ERWY", "ATOT", "DLTO", "ALTO", "ALDT", "XRWY", "AIBT") ~ "operational_profile",
    MST %in% c("LVL_START", "LVL_END") ~ "level_segment",
    MST %in% c("TOC", "TOD") ~ "cruise_bounds",
    MST %in% c("D040", "D100", "D_FL075", "D_FL100", "D_FL180") ~ "departure_flow",
    MST %in% c("A040", "A100", "A_FL075", "A_FL100", "A_FL180") ~ "arrival_flow",
    TRUE ~ "other"
  ))
```
**EUR status:** ❌ Not generated (can be added based on MST conventions)

---

### 4. MST_METHOD
**Where:** Canonical milestones  
**How to generate:**
```r
canonical <- canonical %>%
  mutate(MST_METHOD = case_when(
    MST %in% c("LVL_START", "LVL_END") & .milestone_source == "implicit" ~ "implicit_derived",
    MST %in% c("AOBT", "ERWY", "ATOT", "DLTO", "ALTO", "ALDT", "XRWY", "AIBT") ~ "derived_operational",
    MST %in% c("D_FL075", "D_FL100", "D_FL180", "A_FL075", "A_FL100", "A_FL180") ~ "derived_fl_crossing",
    .milestone_source == "explicit" ~ "explicit_source",
    TRUE ~ "derived"
  ))
```
**EUR status:** ❌ Not generated (need .milestone_source tracking)

---

### 5. LEVEL_SEGMENT_ID (in canonical)
**Where:** Canonical milestones (only for LVL_START/LVL_END rows)  
**How to generate:**
```r
# After deriving level segments
level_segments <- derive_level_segments(harmonized)

# Join back to canonical to add LEVEL_SEGMENT_ID references
canonical <- canonical %>%
  left_join(
    level_segments %>% 
      select(SOURCE_UID, START_ROW_ID, LEVEL_SEGMENT_ID),
    by = c("SOURCE_UID", "ROW_ID" = "START_ROW_ID")
  ) %>%
  left_join(
    level_segments %>% 
      select(SOURCE_UID, END_ROW_ID, LEVEL_SEGMENT_ID),
    by = c("SOURCE_UID", "ROW_ID" = "END_ROW_ID"),
    suffix = c("", "_end")
  ) %>%
  mutate(LEVEL_SEGMENT_ID = coalesce(LEVEL_SEGMENT_ID, LEVEL_SEGMENT_ID_end))
```
**EUR status:** ❌ Not generated (optional enrichment)

---

### 6. LEVEL_DURATION_SEC, LEVEL_DISTANCE_NM, LEVEL_FUEL_KG
**Where:** ❌ **NOT in canonical milestones**  
**Where they belong:** ✅ **Level segments file**  
**How to generate:** Already done in `derive_level_segments()`

**EUR status:** ✅ Generated in level segments file (correct!)

---

### 7. LEVEL_CONTEXT_PHASE
**Where:** Level segments file  
**How to generate:**
```r
level_segments <- level_segments %>%
  mutate(LEVEL_CONTEXT_PHASE = case_when(
    start_phase %in% c("CLIMB", "LTO_CLIMB_OUT") ~ "CLIMB",
    start_phase %in% c("DESCENT", "LTO_APPROACH_LANDING") ~ "DESCENT",
    start_phase == "CRUISE" ~ "ENROUTE",
    TRUE ~ "OTHER"
  ))
```
**EUR status:** ❌ Not in level segments (should be added)

---

## Summary: What EUR Needs

### To Add to Canonical Milestones:
1. ✅ **TOTAL_FLOWN_NM** - max(DIST_FLOWN_NM) per flight
2. ✅ **DIST_REMAINING_NM** - TOTAL - DIST_FLOWN_NM (derived)
3. ✅ **MST_GROUP** - milestone category
4. ✅ **MST_METHOD** - how milestone was derived
5. ⚠️ **LEVEL_SEGMENT_ID** - optional reference (can skip for now)

### Already Correct in Level Segments:
- LEVEL_DURATION_SEC ✅
- LEVEL_DISTANCE_NM ✅
- LEVEL_FUEL_KG ✅

### To Add to Level Segments:
6. ✅ **LEVEL_CONTEXT_PHASE** - flight phase category

---

## Recommendation

**Enrich EUR canonical to have:**
- Current 17 columns
- **+ TOTAL_FLOWN_NM** (simple max calculation)
- **+ MST_GROUP** (milestone categorization)
- **+ MST_METHOD** (provenance tracking)

= **20 columns** (vs CHN's 26)

**Skip for now:**
- DIST_REMAINING_NM (can derive when needed)
- LEVEL_SEGMENT_ID in canonical (optional enrichment)
- LEVEL_* metrics in canonical (they're in separate level segments file)

**Add to EUR level segments:**
- **LEVEL_CONTEXT_PHASE** (phase categorization)

---

## Why We Proposed This to China

The structure provides:
1. **Provenance tracking** (MST_GROUP, MST_METHOD)
2. **Complete distance metrics** (TOTAL_FLOWN_NM)
3. **Separation of concerns** (events vs intervals)
4. **Optional enrichment** (LEVEL_SEGMENT_ID for cross-reference)

This enables:
- Quality assessment (which milestones are derived vs explicit)
- Distance band analysis (TOTAL_FLOWN_NM)
- Phase-based aggregation (LEVEL_CONTEXT_PHASE)
- Reproducibility (tracking derivation methods)

---

*Ready to implement these enhancements?*
