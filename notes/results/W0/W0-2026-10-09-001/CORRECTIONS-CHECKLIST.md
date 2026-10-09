# W0 Corrections Checklist

**Final Correction Commit:** (to be determined after commit)  
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

### CHN Processing Provenance

**Corrected statement:**
```
Batch processing provenance: `scripts/process-chn-summer2025-update.R` consolidates 
incoming batch outputs; batch producer/version unknown
Helper bundle provided to Lingling contains `R/canonical-fuel-milestones.R`; 
whether batch-level outputs used this or another helper version is unverified
```

**Rationale:** Distinguish the known local consolidation step, the helper we supplied, and the unverified batch-generation history. Do not attribute data issues to either source or helper without evidence.

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

## ✅ Fixed Links and References

### README.md
**Changed:** `[study-release-contract.md](../../study-release-contract.md)`  
**Corrected:** `[study-release-contract.md](../../../study-release-contract.md)`  
**Rationale:** Correct relative path from `notes/results/W0/W0-2026-10-09-001/` to `notes/`

### worker-handoff-W0.md Output Table
**Changed:** Duplicate SHA-256 hashes in output table  
**Corrected:** All hashes reference `W0-deliverables-checksums.txt`  
**Rationale:** Single source of truth for checksums; avoid stale duplicates

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

## ✅ File Cleanup

- [x] Removed `notes/study-release-contract.md.bak`
- [x] No other backup or temporary files in W0 deliverables

## File Checksums (Post-Correction)

`W0-deliverables-checksums.txt` is the single checksum index for the W0 package. It covers all deliverables except itself. The index is regenerated after final edits and verified against the exact files on the PR branch.

## Verification

- [x] No production artifacts modified
- [x] No authoritative manifest modified  
- [x] Audit script verified unchanged from instruction commit to W0 commit
- [x] All corrections reconciled with actual audit output CSV files
- [x] No W2 analytical dataset upload required (W0 is documentation only)
- [x] All links verified functional
- [x] All status claims reconciled (W1/W2 proposed, not assigned; W0 ready for review, not accepted)
- [x] All checksums verified against final file state

## Summary

**Corrections applied:** 14 substantive changes  
**Final reconciliation pass:** Updated the release contract, worker handoff, and correction checklist; regenerated the checksum index.
**Files removed:** 1 (notes/study-release-contract.md.bak)  
**Production data:** Preserved (no changes)

**Final checks:**
- [x] Broken link to study-release-contract.md fixed
- [x] "Agreed" scope claim corrected to "proposed in study plan"
- [x] Stale checksums replaced with authoritative file
- [x] CHN processing provenance states consolidation vs. unknown batch producer
- [x] All distance data statements precise (field present ≠ validity)
- [x] Output table references checksums file instead of duplicating hashes

**PR Status:** Final W0 corrections ready for commit and push  
**Ready for review:** Yes

---

*W0 corrections complete. Unsupported distance claims removed; provenance separates the known local consolidation step and supplied helper from the unverified batch producer; links, statuses, and checksums reconciled.*
