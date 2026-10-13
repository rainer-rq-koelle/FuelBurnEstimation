# EUR parallel canonical build with M3 crossings

> **Superseded:** Terminal-phase eligibility and the corrected boundary diagnosis are published in [EUR-2026-10-13-002](../EUR-2026-10-13-002/README.md). This earlier release remains the provenance record for its original candidate.

**Status:** Candidate analytical data, for study development and review. This is a parallel preparation; it does not replace the endorsed PRU production pipeline.

## What this build does

The build starts from `EUR-2026-10-12-001`, the existing PRU G2G-derived candidate, and uses the matching summer 2025 Network Manager Model 3 (M3) profiles to refine event times and fill selected analytical gaps. The output keeps the shared CHN canonical milestone and phase-table schemas. `SOURCE_UID` remains the source-specific join/troubleshooting key; `FLTID` is retained as the shared flight-identification field.

For distance anchors it calculates the geodesic distance from each M3 position to the departure or arrival airport reference coordinate, then linearly interpolates each crossing between adjacent M3 samples. For flight-level anchors it similarly interpolates each crossing of the pressure-altitude threshold. It retains every crossing candidate and its direction, M3 bracket times/sequence IDs, bracket gap, threshold, and level-segment association. Crossings clearly within an accepted CCO/CDO level interval are not emitted as additional sub-phase milestones: the level interval already supplies its start/end boundaries. The detailed candidate table retains those suppressed crossings and the reason.

At candidate event times, cumulative adjusted and original G2G fuel and cumulative G2G distance are linearly interpolated in time. These are approximate G2G estimates, not M3 fuel measurements. The nearest G2G row is stored only as a trace pointer. No extrapolation beyond the G2G time series is performed.

The build applies the shared CHN `fuel_vfe_toc_tod` detector to M3 profiles to repair zero-duration core phases only when the resulting climb, cruise, and descent are all ordered, positive-duration, and have nonnegative fuel and distance. It restores the original G2G boundaries when that full coherence test fails. M3 is not used to manufacture runway-exit or taxi-in boundaries.

## Findings and disposition

- 21,503 study flights are covered by 2,833,869 M3 rows.
- 269,685 threshold-crossing candidates were generated; 1,565 flight-level candidates were associated with accepted CCO/CDO segments and suppressed from the canonical milestone table.
- 131,449 candidates (48.7%) have adjacent M3 samples no more than 30 seconds apart. All candidates remain available, but longer brackets should be treated as lower-resolution estimates; the 30-second flag is a screening aid, not proof of accuracy.
- All 49,836 CCO/CDO segment altitudes were converted from flight-level units (hundreds of feet) to feet before assigning altitude bands. Previously, values such as `140.2` had been labeled as feet, leaving every altitude band at zero. After conversion, no level segment has a zero altitude band. Among 99,672 segment-boundary comparisons, 93.4% are within 500 ft of the nearest M3 sample (median absolute difference 53 ft; p90 290 ft). This supports the unit conversion but does not validate the source detector or exact boundary timestamps.
- M3 repaired 107 flights with zero cruise duration and repaired the coincident DLTO boundary in those profiles, plus one separate zero-climb case. Seventy-five proposed repairs were reverted because they failed the full core-phase coherence check.
- After repair, 21,428 flights pass the core climb/cruise/descent screen. Seventy-five zero-duration cruise records remain unresolved. A further 411 terminal runway-exit/taxi-in records remain unresolved (403 zero durations and 8 missing durations); M3 coverage ends before those terminal boundaries.

## Remaining limitations requiring explicit treatment

1. **Airport reference coordinates:** the checked-in 11-airport coordinate table is an OurAirports proxy, not a verified NM ARP reference. Distance-anchor values are provisional until checked against the official NM airport reference coordinates.
2. **M3 sampling gaps:** the threshold interpolation is least reliable when sample brackets are wide. Apply the stored bracket-gap/resolution fields for sensitivity analysis; do not present all anchors as equally precise.
3. **G2G cumulative fuel/distance interpolation:** the values at M3-derived event times are estimates based on time interpolation between G2G samples. Report the method and uncertainty; retain original G2G milestone values for comparison.
4. **Terminal phase boundaries:** M3 does not resolve the 411 runway-exit/taxi-in issues. Keep these phases ineligible where their boundaries are absent or zero; do not infer stand movement from the airborne trajectory.
5. **Remaining zero cruise:** 75 cases did not pass the transactional repair checks. Preserve them as unresolved and exclude them from analyses requiring positive core-phase duration unless a later source review resolves them.
6. **Fuel correction convention:** the PRU operational 20% reduction from original modelled fuel is retained as provided. It is an operational assumption, not a measured factor; keep both adjusted and original cumulative fuel available and document the convention in comparisons.
7. **Other source-data quality:** negative or implausible G2G quantities, missing/duplicated source records, and CCO/CDO detection limitations require separate audit and sensitivity treatment. This build does not rewrite those source records.

## Outputs

Restricted, flight-level outputs are written to the R2 prefix:

`derived/eur/parallel-preprocessing/EUR-2026-10-13-001/`

This includes the six shared canonical parquet tables, the detailed crossing-candidate parquet, per-flight phase-repair detail parquet, build audit, SHA-256 release manifest, and manifest checksum. The detailed files remain in restricted R2 storage and are not checked into GitHub. Aggregate, identifier-free diagnostics are included beside this README:

- `EUR-parallel-build-audit.csv`
- `EUR-crossing-candidate-counts.csv`
- `EUR-phase-repair-audit.csv`

The reproducible build is `scripts/build-eur-parallel-canonical-m3.R`; its inputs, output hashes, and producing commit are recorded in the R2 release manifest. See `notes/canonical-milestone-model.md` for the event conventions.
