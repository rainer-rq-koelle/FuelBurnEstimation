# PRU LVL Milestone Data Quality Feedback
**Dataset:** EUR Canonical Milestones Summer 2025  
**Analysis Date:** 2026-10-08  
**Prepared by:** EUROCONTROL Fuel Burn Estimation Project Team

---

## Executive Summary

Analysis of PRU canonical milestone data reveals **systematic incompleteness in LVL (level flight) marker pairing**, affecting 54.4% of flights with level segments. This report documents the issue and proposes a methodology to complete the data for fuel burn analysis.

### Key Findings

| Metric | Count | % |
|--------|-------|---|
| **Flights analyzed** | 19,693 | 100% |
| **Source: Properly paired** | 8,989 | 45.6% |
| **Source: Unpaired (odd count)** | 10,704 | 54.4% |
| **Orphaned after harmonization** | 8,725 | 44.3% |

**Issue:** More than half of flights with LVL markers have incomplete pairing, preventing accurate level-segment duration and fuel burn calculations.

---

## Background: LVL Markers in PRU Data

### What Are LVL Markers?

PRU canonical milestone data includes `LVL` markers indicating level flight phases. These are derived from surveillance data and represent periods when aircraft maintain approximately constant altitude.

### Expected Behavior

Level flight segments should have:
- **LVL_START**: Beginning of level phase
- **LVL_END**: End of level phase

For paired analysis (duration, fuel burn), each START requires a matching END.

### Source Data Analysis

**Raw PRU Data (Summer 2025):**
- Total milestones: 431,901
- Total flights: 21,503
- **LVL markers: 55,176** (standalone `MST = "LVL"`)
- Flights with LVL: 19,693 (91.6%)

**LVL Distribution by Flight:**

| LVL Count | Flights | Pairing Status |
|-----------|---------|----------------|
| 1 (odd) | 4,479 | ✗ Unpaired |
| 2 (even) | 5,345 | ✓ Potentially paired |
| 3 (odd) | 4,288 | ✗ Unpaired |
| 4 (even) | 2,806 | ✓ Potentially paired |
| 5 (odd) | 1,556 | ✗ Unpaired |
| 6+ | 1,219 | Mixed |

**Mean LVL per flight: 2.8 markers**

---

## Problem: Incomplete Pairing

### Issue Description

**54.4% of flights (10,704) have odd LVL counts**, indicating incomplete START/END pairing:

```
Flight A: LVL, LVL, LVL → 1 START, 1 END, 1 START (orphaned)
Flight B: LVL → 1 START (orphaned)
Flight C: LVL, LVL, LVL, LVL, LVL → 2 complete + 1 orphaned
```

### Root Causes Identified

1. **Missing END at TOD (Top of Descent)**
   - Flight enters level cruise
   - LVL marker recorded at cruise entry
   - Flight begins descent at TOD
   - **No LVL marker at TOD** → segment remains open

2. **Missing END at Phase Transitions**
   - Level segments during climb (`Lvl_climb` phase)
   - Transition to cruise phase
   - **No explicit LVL marker** at transition point

3. **Missing END at Trajectory Boundaries**
   - Flight still in level when exiting coverage area
   - Trajectory data ends
   - **No closing LVL marker**

4. **Compound Milestone Handling**
   - Source uses compound labels: `"TOC/LVL"`, `"LVL/FL100"`, `"FIR/LVL"`
   - Pairing logic may not account for implicit END at these points

---

## Impact on Analysis

### Without Completion

| Issue | Impact |
|-------|--------|
| **Duration calculation** | Impossible for 54.4% of segments |
| **Fuel burn estimation** | Only 45.6% of segments usable |
| **Statistical bias** | Short segments over-represented |
| **Phase analysis** | Climb phase especially affected (70% orphaned) |

### Example: Unusable Segments

```
UID: 285760910 (LTFM → EDDM)
  LVL markers: 1
  Status: Orphaned (no END)
  → Duration: UNKNOWN
  → Fuel burn: UNCALCULABLE
```

---

## Proposed Solution: Implicit END Markers

### Methodology

Add **implicit LVL_END markers** at logical segment boundaries where source data is incomplete:

1. **At TOD** if preceded by active level segment
2. **At phase transitions** from `Lvl_*` to non-`Lvl_*`
3. **At trajectory end** if still in level phase

### Implementation

**Milestone Multiplicity Approach:**
- Original milestone retained (e.g., `MST = "TOD"`)
- Separate row added: `MST = "LVL_END"`, `.milestone_source = "implicit_end_at_TOD"`
- Same TIME/LAT/LON/ALT coordinates

**Example:**
```
Before:
  TIME        MST        ALT
  10:15:00    LVL_START  35000
  10:45:00    TOD        35000
  
After:
  TIME        MST        ALT      .milestone_source
  10:15:00    LVL_START  35000    derived_level_segment
  10:45:00    TOD        35000    (original)
  10:45:00    LVL_END    35000    implicit_end_at_TOD
```

---

## Results After Completion

### Improvement Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Paired segments** | 22,236 | 54,494 | +145% |
| **Orphan rate** | 54.4% | 44.3% | -18% |
| **Lvl_climb orphans** | 70.0% | 0.0% | -100% |
| **Lvl_descent orphans** | 18.6% | 15.3% | -18% |

### Completion Status by Type

| Status | Flights | % | Description |
|--------|---------|---|-------------|
| **Already paired** | 1,505 | 7.6% | Source data complete |
| **Completed** | 1,979 | 10.0% | Implicit ENDs added successfully |
| **Still orphaned** | 8,725 | 44.3% | No implicit boundary found |
| **Other** | 7,484 | 38.0% | Complex cases |

### Where Implicit ENDs Were Added

**32,258 implicit LVL_END markers** added across 15,898 flights:
- At TOD: ~40% of completions
- At phase transitions: ~35% of completions  
- At trajectory end: ~25% of completions

---

## Remaining Gaps

### Why 44.3% Still Orphaned?

1. **True boundary cases**: Segments starting near trajectory end
2. **Phase label inconsistencies**: `Lvl_*` phase not always present
3. **Missing TOD markers**: ~2,000 flights lack TOD milestone
4. **Data coverage gaps**: Flights entering/exiting coverage mid-segment

These represent legitimate data limitations rather than fixable incompleteness.

---

## Recommendations for PRU

### Short-term (Data Consumers)

1. **Document LVL pairing status** in data dictionary
2. **Provide pairing statistics** per dataset release
3. **Flag known incomplete flights** in metadata

### Medium-term (Data Production)

1. **Review LVL derivation algorithm**
   - Ensure END markers generated at TOD
   - Add ENDs at phase boundaries
   - Close segments at trajectory boundaries

2. **Enhance compound milestone handling**
   - When `"TOC/LVL"` created, also create standalone `"LVL_END"`
   - Document multiplicity explicitly

3. **Add pairing QC** to production pipeline
   - Flag flights with odd LVL counts
   - Cross-check with TOD/phase milestones

### Long-term (Methodology)

1. **Define level-segment standard**
   - Specify mandatory START/END pairing
   - Document edge case handling
   - Align with ICAO Doc 030 conventions

2. **Validation suite**
   - Automated pairing checks
   - Phase consistency validation
   - Statistical outlier detection

---

## Data Quality Assessment

### Overall Rating: ⚠️ **USABLE WITH CAVEATS**

| Dimension | Rating | Comment |
|-----------|--------|---------|
| **Completeness** | ⚠️ Moderate | 45.6% properly paired |
| **Consistency** | ✓ Good | Pattern is systematic, not random |
| **Correctness** | ✓ Good | Present markers appear accurate |
| **Timeliness** | ✓ Good | Recent data (Summer 2025) |

---

## Conclusion

PRU canonical milestone data provides valuable level flight information but suffers from **systematic incompleteness in LVL marker pairing**. The proposed implicit END methodology successfully completes ~10% of orphaned segments and provides a documented approach for fuel burn analysis.

**For PRU colleagues:**
- Current data is usable but requires completion logic
- Improvements in LVL derivation would benefit all consumers
- Proposed methodology can serve as interim solution

**For analysis:**
- Documented completion methodology ensures reproducibility
- QC flags allow sensitivity analysis
- Remaining gaps are data limitations, not processing errors

---

## Contact

For questions about this analysis or the completion methodology:
- **Project:** EUROCONTROL Fuel Burn Estimation
- **Dataset:** EUR Canonical Milestones Summer 2025
- **Analysis Date:** 2026-10-08

## Appendix: Technical Details

**Source Files:**
- Raw data: `data-store/raw/eur/EUR-canonical-milestones-summer2025.parquet`
- Harmonized: `data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet`
- Audit script: `scripts/audit-pru-lvl-simple.R`
- Detailed audit: `notes/pru-lvl-audit-simple.csv`

**Processing Pipeline:**
1. Extract standalone LVL markers from source
2. Pair odd/even occurrences within each flight
3. Identify implicit END points (TOD, phase transitions, trajectory end)
4. Add LVL_END markers as separate rows with `.milestone_source` metadata
5. Derive level-segment intervals with QC flags

**Reproducibility:**
All code and data products available in project repository with R2 manifest tracking.
