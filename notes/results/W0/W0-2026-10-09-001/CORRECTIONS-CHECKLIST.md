# W0 Corrections Checklist

**Correction Commit:** 388ca3c  
**Original W0 Commit:** 46f0a9d680b9c32ed3d33aa0d89ac7675b9218ec  
**Instruction Commit:** 1438f500003ffed0e53bd0d6037411120ef4ead5

## ✅ Reproducibility Complete

- [x] Added producing-code commit SHA: 46f0a9d680b9c32ed3d33aa0d89ac7675b9218ec
- [x] Created `W0-deliverables-checksums.txt` with final file hashes after corrections
- [x] Fixed audit evidence paths from `outputs/study-design/` to `notes/results/W0/W0-2026-10-09-001/`
- [x] Verified audit script unchanged from instruction commit to W0 commit

## ✅ Removed Invented Statistics

### CHN Distance Validity (Line 136 of original worker-handoff-W0.md)

**REMOVED (unsupported):**
```
- Flights with valid distance: ~3,463 (53.9%, inferred from speed checks)
```

**REPLACED WITH (audit facts):**
```
- Segment rows: 64,981 (unique keys, all with distance field present; distance validity unresolved pending W2)
```

**Supporting audit evidence:**
- CHN: intervals_with_distance = 64,981 (all segments)
- CHN: intervals_implied_speed_over_700kt = 17,955 (27.6%)
- CHN: median_enroute_implied_kt = 830 (vs. expected ~450-500)
- CHN: flights_enroute_speed_over_700kt = 2,958 (46%)

**Correction rationale:** Distance field presence ≠ distance validity. The "3,463 valid flights" count was fabricated. Actual audit shows all segments have distance field but 27.6% show implausible speeds, indicating coordinate/calculation issues requiring W2 investigation.

## ✅ Reconciled Acceptance and Ownership

### Scope Statements
**Changed:** "Agreed Minimum Publishable Scope" → "Proposed Minimum Publishable Scope"  
**Changed:** "Minimum publishable scope agreed" → "proposed in study plan"  
**Rationale:** Study worker plan proposes scope; W0 does not confirm stakeholder agreement.

### Work Package Assignments

**W1 EUR Status Changed:**
- Original: "Status: ASSIGNED"
- Corrected: "Status: PROPOSED (awaiting owner confirmation)"

**W2 CHN Status Changed:**
- Original: "Status: ASSIGNED"  
- Corrected: "Status: PROPOSED (awaiting owner confirmation)"

**Rationale:** W0 proposes work package assignments per study plan. Owners remain "to be determined" pending PRU/CAUC lead confirmation. W0 cannot assign without authority to do so.

## ✅ Fixed Provenance and Causation Claims

### CHN Missing ALDT

**Original claim (implied causation):**
```
**Missing ALDT root cause:** Why are 1,190 landing events absent?
```

**Corrected (diagnostic lead, not confirmed cause):**
```
**Missing ALDT investigation:** 1,190 landing events absent (18.5% of flights). 
W2 diagnostic lead: check batch helper version and flight-level overlap before 
attributing to specific cause.
```

**Rationale:** W0 audit identifies 1,190 flights missing ALDT. Root cause unknown. Possible factors include batch processing logic, helper version differences, or data source issues. W2 must investigate before causal attribution.

### CHN Milestone Completeness

**Original (aggregated):**
```
- Flights with complete ATOT/TOC/TOD: 6,420 (99.98%)
```

**Corrected (disaggregated per audit):**
```
- Flights with complete ATOT: 6,420 (99.98%, 1 missing)
- Flights with complete TOC/TOD: 6,399 (99.7%, 22 missing unique pair)
```

**Audit evidence reconciliation:**
- flights_missing_unique_ATOT: 1 (not 0)
- flights_missing_unique_TOC_TOD: 22 (not 0)
- flights_missing_unique_ALDT: 1,190

## ✅ Inventory Count Reconciliation

All counts verified against `notes/results/W0/W0-2026-10-09-001/study-readiness.csv`:

| Metric | EUR | CHN | Source Column |
|--------|-----|-----|---------------|
| Flights | 21,503 | 6,421 | flights |
| Milestone rows | 696,076 | 266,883 | milestone_rows |
| Segment rows | 86,142 | 64,981 | segment_rows |
| Distinct segment keys | 47,849 | 64,981 | distinct_segment_keys |
| Repeated segment keys | 29,631 | 0 | repeated_segment_keys |
| Flights with overlaps | 18,860 | 0 | flights_with_overlapping_intervals |
| Missing ALDT | 0 | 1,190 | flights_missing_unique_ALDT |
| Missing TOC/TOD | 0 | 22 | flights_missing_unique_TOC_TOD |
| Intervals with distance | 0 | 64,981 | intervals_with_distance |
| Intervals >700kt | NA | 17,955 | intervals_implied_speed_over_700kt |

## ✅ Links and References

All references verified:

- [x] Instruction commit link: 1438f500003ffed0e53bd0d6037411120ef4ead5 ✅ valid
- [x] Study worker plan: `notes/study-worker-plan.md` ✅ exists
- [x] Worker handoff template: `notes/worker-handoff-template.md` ✅ exists
- [x] Methodological note: `technical-note-methodology.qmd` ✅ exists
- [x] Data preparation note: `technical-note-data-preparation.qmd` ✅ exists
- [x] Audit script: `scripts/12-audit-study-readiness.R` ✅ exists and unchanged

## File Checksums (Post-Correction)

From `W0-deliverables-checksums.txt`:

```
README.md                        319e9a505cc4d43d907525df2626d6ed4b4b834683e56202d62e6efe779a34f5
worker-handoff-W0.md             d12b136b114728325cbcd7607f94e564d3f167d8aaf9778298d2f78dd0bd225e
actual-schema.csv                f431e9b0f659192d5d1333f65183a880f61cc31c4e35e8d2a8f8a0ffc8b13b77
aircraft-common-support.csv      a84f822642570c84590ab45dc81bb026896a3bbead9f6c49f37c606cb9c7b1ee
input-manifest-snapshot.csv      25e4e1145511997efefbb8f9fe214c6209922e56edbb9c6446b0fbc7c861114e
milestone-coverage.csv           9924396e9c669e61d60e5c7b73c827a4ee9f275e75d472a6d76d58b7a2cd40da
phase-label-provenance.csv       afde03b37ed3d13971d0ef702ea0713f0d20b19a63578b51c4efaa3ab9a24696
release-integrity.csv            2635adfa71ce8af2afc1b0fc37cb5c950fa6abfe7da12fb18973cc4d31f29b6a
route-coverage.csv               a73babf30739d32cb960092a8b877cfb355bb5d55a08d8361ba400108e26b07d
study-readiness.csv              c331f78658a47abdfdf0e9bc00fb90f895dbc455dd39c66479515ffb54513a8b
study-release-contract.md        e1c184acca1fda4b6399e8da4124eb712c8b16f664029401ad57efb3569cb1a3
```

**Note:** `worker-handoff-W0.md` hash changed from original due to corrections.  
**Note:** `study-release-contract.md` hash changed from original due to corrections.

## Verification

- [x] No
production artifacts modified
- [x] No authoritative manifest modified  
- [x] Audit script verified unchanged from instruction commit to W0 commit
- [x] All corrections reconciled with actual audit output CSV files
- [x] No W2 analytical dataset upload required (W0 is documentation only)

## Summary

**Corrections applied:** 11 substantive changes  
**Files modified:** 2 (worker-handoff-W0.md, study-release-contract.md)  
**Files added:** 2 (W0-deliverables-checksums.txt, CORRECTIONS-CHECKLIST.md)  
**Production data:** Preserved (no changes)

**PR Status:** Corrected W0 deliverables pushed to w0-release-contract branch  
**New HEAD:** 388ca3c  
**Ready for review:** Yes

---

*W0 corrections complete. All placeholders replaced with actual values, invented statistics removed, provenance claims verified against audit evidence, and reproducibility established.*
