# Handover to the paper stream: CHN–EUR phase/profile references

27 October 2026. Technical assessment completed in the CHN preparation thread.
Continue scientific design and manuscript integration in the paper thread. QAR
read-in/decoding package development remains a separate, deferred stream.

## Recommendation

Keep finer climb/descent reference values as a main contribution. Whole-airborne
fuel/time supplies context; it is not the paper's ceiling. Use supported phases
and quantities independently, rather than one globally complete-flight cohort.
The full technical mapping and aggregate support tables are in
[the assessment](results/paper-cohort-mapping-2026-10-27/README.md).

## Inputs and adoption boundary

- Current manuscript: original fourteen CHN milestone batches, pinned EUR parallel
  release EUR-2026-10-13-002. These and the consolidated canonical files are unchanged.
- Proposed analysis source for the updated CHN references: returned candidate.6
  default outputs, all fourteen batches, 6,421 existing identifiers. This is the
  same flight population, with revised processing and richer support metadata.
- EUR remains the pinned 21,503-flight G2G+M3 preparation. Fuel is modelled, versus
  QAR-integrated Chinese fuel. Source and region remain confounded.
- CHN covers four airports / six directed pairs; EUR eleven / twenty-two. Type,
  stage, profile, airport context and source method must remain visible.
- An explicit paper-analysis adapter and input-version manifest are required before
  changing manuscript results. Do not merely change FUELBURN_PAPER_CHN_DIR: the
  pilot globally prefilters profiles and expects legacy unit/flow QC CSVs that
  candidate.6 does not supply. No canonical overwrite or decoder change is needed.

Restricted source root: `derived/chn/verification/CHN-2026-10-27-001/returned/`
under FUELBURN_DATA_STORE. EUR: `derived/eur/parallel-preprocessing/EUR-2026-10-13-002/`.
Assessment ledger: `derived/paper/eligibility-comparability/PAPER-2026-10-27-001/`.
Only aggregate notes/tables belong in Git; flight/window ledgers stay restricted.

## What is supported now

| Fuel/time reference | CHN | EUR |
|---|---:|---:|
| Whole airborne | 6,388 | 21,502 |
| Source climb ATOT–TOC | 6,381 | 21,502 |
| Source descent TOD–ALDT | 6,366 | 21,502 |
| Climb FL100–FL180 | 6,378 | 21,476 |
| Descent FL180–FL100 | 6,369 | 21,306 |
| Departure ARP040–100 | 2,911 | 21,502 |
| Arrival ARP100–040 | 2,913 | 21,502 |

These are feasibility counts before assigning profile classes or adopting a new
paper input version. Windows overlap; counts must not be added. A usable local
window need not belong to the whole-airborne fuel/time set. The single existing
EUR source timing/GCD review case remains excluded from fuel references.

Eight exact-type/GCD cells support the main fuel/time comparisons at the current
>=30-per-region lookup rule: A20N/600, A21N/500, A21N/600, A319/600, A320/600,
A321/500, A321/600 and B738/600, where 500 denotes 500–599 NM, etc.
Climb FL100–180 has 1,648 CHN / 6,223 EUR observations across those cells;
descent FL180–100 has 1,639 / 6,170. Recompute the denominator for each window,
metric and profile class. Unpaired or sparse observations remain in regional
characterisation rather than disappearing from the study.

## Cohort and lookup architecture

1. **Regional profile composition:** retain all independently supported quantities
   and show fleet/stage/route mixture. Do not match away profile differences before
   describing them. These are selected source samples, not all regional operations.
2. **Matched marginal phase references:** exact type × airport-GCD band × defined
   window, with total kg, minutes, kg/min and separate kg/NM support. Make FL100–180
   climb and FL180–100 descent the primary fine windows; add FL075–100 and ARP040–100
   where appropriate. Airport GCD is a stratum, never a flown-phase denominator.
3. **Profile-conditioned references:** add one common descriptor axis at a time.
   Effective net vertical rate over the fixed pressure interval is supported by
   endpoints/time and does not require dense geometry. Sustained-level exposure or
   interruption descriptors can add detail where their measurement coverage is
   adequate. Use common physical definitions independent of region/fuel outcome.
   Retain unknown coverage and marginal references; do not call a missing tag CCO/CDO.
4. **Spatial/distance sensitivity:** retain the existing geometry-review policy
   for ARP-defined windows and kg/NM. Pressure fuel/time references need not wait
   for mass approval of position-share holds. No new approvals were issued here.

The eight cells remain supported when both crossing brackets are <=30 s. This
is different from requiring a <=30 s sampling gap throughout the entire window:
that leaves six paired climb cells and no paired descent cells. The latter
cannot be the default gate for every fine-phase reference. A slower declared
profile reconstruction and its sensitivities can support sustained features, but
must not manufacture unobserved short interruptions. Do not select a gap limit
merely because it produces eight cells. Class-specific n remains to be established.

Source-defined macro TOC/TOD are not yet the same detector across regions.
Preserve source-window baseline rows and common level-envelope sensitivity on
identical flights. Recompute fuel at any newly selected boundaries; never carry
old phase fuel into a shifted TOD window. Both regions' source level products and
altitude-time data are available, but source detector counts are not directly
comparable without an analysis-level common definition and coverage treatment.

## Implementation contract

Produce analysis views for flights/strata, selected events with provenance and
all-candidate availability, window metrics with orthogonal time/fuel/profile/
geometry flags, and profile descriptors with explicit coverage. Use candidate.6
fine intervals/coverage for CHN local fuel validation; keep ground/full-record
findings diagnostic unless relevant to that window. Preserve the distinction
between altitude pressure references, airport radii and cumulative flown distance.

Keep the manuscript's two estimands separate: profile composition, then
consumption conditional on comparable profiles. Publish flight-weighted P20/P50/P80
with actual n per metric/class; no forced common intersection across all phases.
The existing n>=30 rule governs populated comparative reference cells, not the
validity of an entire flight. Show sparse/unassigned states without zeros or
hidden exclusion, and standardise cell weights for any pooled regional contrast.

Profile-class thresholds, primary versus sensitivity windows, operating-day/UTC
handling (two CHN timestamps are in September), and the compact eight-page display
are paper-thread decisions. Fuel method, engine uncertainty, atmospheric/payload
confounding and interpolation resolution remain interpretation limits. Do not
interpret percentile spreads or regional differences as recoverable ATM savings.

The current paper's profile-conditioned enroute pilot remains a preserved baseline;
its global prefilter should not silently determine the new climb/descent samples.
Add explicit climb/descent profile-reference examples to the manuscript, rather
than leaving both entirely as reserved future lookup slots.

## Reproduce the assessment

Run from the project root into a new approved restricted directory:

```sh
Rscript scripts/assess-chn-eur-paper-support.R /restricted/assessment-directory
Rscript scripts/assess-paper-profile-resolution.R /restricted/assessment-directory
```

The directory must be inside FUELBURN_DATA_STORE and already exist. These scripts
produce eligibility/support views only; no percentile coefficients, decoder fixes,
canonical replacements or manuscript changes were made. All inputs and paper
source files retain their hashes. No cross-thread message or external upload was sent.
