# Candidate.5 returned verification — 22 October 2026

The two archives downloaded on 22 October contain ten additional QAR CSVs and a
complete 20-input candidate.5 result set. The recorded run took place on 19 October
2026 at 08:05:09 UTC. The result set combines the original ten verification flights
with all ten follow-up selections (eight diagnostic leads and two controls).
Flight identities, source files, correspondence, plots and individual findings
remain in the restricted, Git-ignored store.

## Inventory and provenance

- `data check20261019.zip`: ten source CSVs, 10,074,270 uncompressed bytes.
- `data results20261019.zip`: 49 files, 8,083,661 uncompressed bytes: seventeen
  table pairs (CSV/Parquet), ten profile plots, input manifest, airport lookup,
  run manifest, runtime information and checksum file.
- Both archives pass ZIP CRC checks. All 48 returned checksum entries match.
  All twenty input hashes match locally available source files; the original ten
  are byte-identical to the earlier delivery. Every follow-up requested ID is
  present, with no substitutions.
- The recorded processing-function and airport-lookup hashes exactly match the
  sent candidate.5 source and lookup. The manifest uses the default configuration:
  15-second maximum position bridge, 5-second fuel/altitude bridge, 1% repair-share
  review gate, automatic fuel units, bundled airport references, no private review
  manifest. Runtime is Windows / Asia-Shanghai; exit status reported by Lingling
  is zero. The CLI and legacy-core hashes are not separately recorded in this
  manifest, so exact provenance for those individual files is not independently
  established by the returned manifest alone.

## Results and comparison

| Input group | Files | Common-cohort included | Held | Whole-airborne fuel/time | All twelve ARP/pressure families present |
|---|---:|---:|---:|---:|---:|
| Original verification | 10 | 6 | 4 | 10 | 7 |
| Additional selection | 10 | 6 | 4 | 9 | 7 |
| Total | 20 | 12 | 8 | 19 | 14 |

Both newly selected controls pass. Anchor completeness and fuel/time eligibility
are separate from common-cohort membership. The returned problem/exclusion lists
are byte-identical. Eight holds are not eight unusable fuel/time records.

The original ten reproduce earlier findings. One additional stock-run hold versus
our earlier reviewed run is expected: the private exact-input position-share
approval was not included in the sent ZIP. No source change or new bridge failure explains this difference.
No private review approval was added or transferred during this audit.

Aggregate diagnostic findings across the follow-up selection distinguish ground
recording artefacts from airborne support. Ground fuel-flow impulses and altitude
artefacts can leave whole-airborne quantities usable while full-record quantities
remain held. The profile detector resolves the legacy coincident-boundary lead.
Other source limitations include coordinate precision loss, an absent altitude
channel and a ground-only excerpt; smoothing cannot supply the missing information.
An additional position repair-share hold requires individual assessment rather
than a global threshold change. Exact measurements, quantities, sample counts,
flight mappings and review evidence are retained only in the restricted case review.

## Reproduction and warnings

The unchanged helper was rerun locally on all twenty exact inputs with the returned
configuration. All fifteen independently generated table families match the
returned Parquet tables across 407 fields and their row counts/column sets. The
comparison permits at most 2 microseconds / 0.000002 numeric units; the largest
observed delta is 0.954 microseconds in timestamps. Derived problem/exclusion lists
were verified separately. No processing failures occurred.

All three reported warnings reproduce on the ground-only record. When no threshold
crossing exists, the empty crossing-candidate table lacks `BRACKET_FROM_ROW` and
`BRACKET_TO_ROW`. Enrichment reads those absent columns while determining position
support. This is a helper empty-table schema defect, not a source repair or an
exclusion-rule failure.

A minimal correction adding those two typed, zero-length columns was tested **in
memory only**. It removes all three warnings; all sixteen combined internal result
tables (including QC, events, repairs and clock diagnostics) retain identical values.
No helper source, version, package or existing release was changed. A future patch
should make the empty schema explicit and add a no-crossing regression test.

## Evidence and next action

Restricted audit:
`.fuelburn-data-store/derived/chn/verification/CHN-2026-10-22-001/`.
It contains archive/member inventories, preserved received ZIPs, verified hashes,
source-to-result mappings, warning stacks, per-field comparisons, trajectories,
case-by-case review, and the isolated schema experiment. The source archives and
returned diagnostic plots remain restricted.

Recommended next actions: review the new position-share hold individually; ask for
upstream altitude-channel restoration, full ground-only flight extraction, and
full-precision coordinate export where applicable. Prepare a small warning-schema
patch as a separately versioned candidate only after review; retain candidate.5 as
sent and all received outputs unchanged. The supplied evidence does not justify
blanket repairs, longer bridges or relaxing global repair-share limits.

All 85 protected-file hashes match the audit-start snapshot. EUR and existing CHN
canonical releases were not regenerated or modified. No GitHub/R2 upload occurred.

Reproduction script: `scripts/audit-chn-candidate5-return.R`. Run against the
restricted audit directory with its local verified source manifest. Pass the
exact candidate.5 helper directory extracted from the preserved source ZIP as
the second argument; the current helper source has advanced to candidate.6.

## Subsequent handoff

The additional position-share review was completed and recorded privately for the
exact input. The isolated schema correction is now packaged and validated as
[candidate.6](../CHN-v2-2026-10-22-003/README.md). The user confirmed the full-batch
processing email has been sent; returned full-batch outputs are pending. This
report retains the original default-run cohort counts rather than retrospectively
changing the delivered results.
