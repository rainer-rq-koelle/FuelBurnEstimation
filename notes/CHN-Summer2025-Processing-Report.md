# CHN Summer 2025 Data Processing Report

**Processing Date:** 2026-10-09  
**Data Period:** June-July-August 2025  
**Source:** Chinese colleagues' QAR processing pipeline

---

## Summary

✅ **Data consolidated and uploaded to R2**

- **Total Flights:** 6,421
- **Milestone Records:** 266,883
- **Level Segments:** 64,981
- **Phase Records:** 54,131
- **Source Batches:** 14 (output1-output14)

## Route Pairs

| Route | Flights |
|-------|---------|
| ZSSS-ZBAA | 1,514 |
| ZBAA-ZSSS | 1,504 |
| ZLXY-ZSSS | 1,032 |
| ZSSS-ZLXY | 1,015 |
| ZPPP-ZSSS | 761 |
| ZSSS-ZPPP | 595 |

**Total:** 6,421 flights across 3 route pairs (bidirectional)

### Route Details

- **ZSSS-ZBAA / ZBAA-ZSSS**: Shanghai Pudong ↔ Beijing Capital (3,018 flights)
- **ZLXY-ZSSS / ZSSS-ZLXY**: Lanzhou ↔ Shanghai Pudong (2,047 flights)
- **ZPPP-ZSSS / ZSSS-ZPPP**: Kunming ↔ Shanghai Pudong (1,356 flights)

## Data Characteristics

### Level Segments
- **Total segments:** 64,981
- **Average per flight:** ~10.1 level segments/flight
- **Coverage:** All segments include:
  - Start/end timestamps
  - Altitude information
  - Fuel burn per segment
  - Duration metrics

### Phase Summaries
- **Total phase records:** 54,131
- **Average per flight:** ~8.4 phase records/flight
- **Phases covered:**
  - Take-off
  - Climb
  - Cruise (with level segments)
  - Descent
  - Approach
  - Landing

### Quality Indicators

Based on Chinese colleagues' processing:
- **Fuel-flow unit inference:** All flights successfully inferred as kg/h (high confidence)
- **Profile plots:** Generated for verification (sample flights)
- **Phase detection:** Automated detection from QAR altitude/speed profiles
- **Level segment derivation:** Algorithmically identified from altitude holds

## Data Processing Pipeline

### Source Data
- **Original format:** QAR (Quick Access Recorder) high-frequency flight data
- **Processing:** Chinese colleagues' automated pipeline
- **Batches:** 14 separate processing runs
  - output1-9: June 2025 data
  - output10-14: July 2025 data
  - (August data may be in separate delivery)

### Consolidation Steps

1. **Extracted zip file** from Downloads
2. **Consolidated 14 batches** into unified datasets
3. **Created three master files:**
   - Canonical milestones (266,883 records)
   - Level segments (64,981 segments)
   - Phase summaries (54,131 phase records)
4. **Uploaded to R2** for cross-machine sync

### File Locations

**Local:**
- `data-incoming/chn-summer2025/` (original extraction)
- `data-store/processed/chn/` (consolidated files)

**R2 (Cloudflare):**
- `processed/chn/CHN-canonical-milestones-summer2025.parquet` (19.96 MB)
- `processed/chn/CHN-level-segments-summer2025.parquet` (5.86 MB)
- `processed/chn/CHN-phase-summaries-summer2025.parquet` (2.59 MB)

## Data Schema

### Canonical Milestones
```
SOURCE_UID, FLTID, ADEP, ADES, TYPE (aircraft),
TIME, LAT, LON, ALT_FT,
MST (milestone), MST_GROUP, MST_METHOD,
TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL,
DIST_FLOWN_NM, DIST_REMAINING_NM,
FLIGHT_PHASE_RAW,
LEVEL_SEGMENT_ID, LEVEL_DURATION_SEC, LEVEL_DISTANCE_NM,
LEVEL_FUEL_KG, LEVEL_CONTEXT_PHASE,
ROW_ID, source_batch
```

### Level Segments
```
Similar to milestones but focused on level-off intervals with:
- Start/end times
- Duration
- Fuel consumption
- Altitude holds
```

### Phase Summaries
```
Aggregated statistics per flight phase:
- Phase type
- Duration
- Fuel burn
- Distance
- Altitude metrics
```

## Comparison with EUR Data

| Metric | CHN Summer 2025 | EUR Summer 2025 (FIXED) |
|--------|-----------------|-------------------------|
| **Flights** | 6,421 | 21,503 |
| **Route Pairs** | 3 pairs | 11 pairs |
| **Milestone Records** | 266,883 | TBD (after conversion) |
| **Level Segments** | 64,981 | TBD (after harmonization) |
| **Avg Milestones/Flight** | 41.6 | TBD |

## Next Steps

### Immediate
1. ✅ Consolidate Chinese data (DONE)
2. ✅ Upload to R2 (DONE)
3. ⏳ Convert EUR FIXED data to canonical format
4. ⏳ Run EUR harmonization with FIXED data
5. ⏳ Derive EUR level segments from FIXED data

### Analysis
6. Compare CHN vs EUR level segment characteristics
7. Match distance bands for paper analysis
8. Create comparative visualizations
9. Update paper with summer 2025 results

### Validation
10. Cross-check route pair selections with paper distance band definitions
11. Verify fuel burn metrics align with PRU G2G data (EUR)
12. Confirm QAR processing methodology consistency

## Notes

- **Data completeness:** June and July confirmed in this delivery
  - August data may arrive separately or be in final batches
- **Aircraft types:** Multiple types per route (need to extract from TYPE column)
- **Processing quality:** Chinese colleagues provided comprehensive QC diagnostics
- **Profile plots:** Sample verification plots available in output folders

## Questions for Chinese Colleagues

1. Is August 2025 data included in this delivery? (Title mentions Jun-Jul-Aug)
2. What aircraft types are in the dataset? (TYPE column)
3. Any known data quality issues or caveats?
4. Distance band classification used for route pair selection?

---

**Report generated:** 2026-10-09  
**Processed by:** Automated consolidation pipeline  
**Status:** ✅ Ready for analysis
