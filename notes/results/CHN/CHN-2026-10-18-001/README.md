# CHN QAR verification — 18 October 2026

The supplied sources reproduce the ten requested problem cases with the
unchanged distributed helper. The extreme results have several causes: unusable
position or altitude observations in the supplied extracts, arrival logic that
depends on distance and absolute pressure altitude, and a phase-boundary
accounting error. Consolidation did not introduce these discrepancies.

This is an investigation, not a corrected analytical release. The EUR parallel
dataset, existing CHN releases, helper bundle, and helper source were not changed.
No canonical deliverables were regenerated and nothing was uploaded to R2 or
GitHub. This directory contains only aggregate evidence; identifiers, source
records, returned subsets, and detailed diagnostic results remain in the approved
Git-ignored local data store.

## Inputs and provenance

| Input | Inventory and role |
|---|---|
| Verification archive received 17 October | 10 CSVs; all 10 requested cases matched by full source identifier and expected return batch |
| Distributed 2026 helper bundle | Four files: standalone entry script, canonical functions, README, quick start |
| Original summer return archive | 14 output batches, 322 files; includes milestones, phases, level segments, QC, processing summaries, and plots |
| Consolidated CHN release | 266,883 milestone rows, 54,131 phase rows, 64,981 level rows; 6,421 flights |
| Earlier four source archives | 220 CSVs, of which 192 have engine fuel-flow columns and 28 do not; historical inventory, not 220 newly validated flights |
| Earlier method-demonstrator archive | 132 raw flight CSVs with a corresponding historical canonical table; three deterministic type-based examples used as representative controls |
| Original small source archive | Three additional type-based examples used specifically as legacy-format compatibility controls |

The bundle SHA-256 is
`6457e3da0e4d1b00d096dc4f90816d2d8898cadfdc6f24786653ed8b7ed99c13`.
Its canonical-functions file matches commit
`68b9f8b1664ed43b2c64f7f413de9b5278d0ddc5` (8 October, “Handle CHN flights
without level segments”). Its entry script matches the version last changed in
`13247718425284a95aea367e5ec0a1df929f2368`. Both match the project working copies.

The returned processing summaries specify `auto` fuel units. They do not record
an executable checksum or Git commit. Exact reproduction demonstrates behavioral
compatibility with this bundle for the ten supplied cases; it cannot prove which
executable bytes were run, or distinguish another revision that behaves identically
on these inputs. The historical reference also lacks a confirmed producer commit.

The local authoritative manifest's SHA-256 values match all three consolidated
CHN files. All rows and fields in those files also match the original 14-batch
return tables after attaching batch provenance. Thus the return archive and
consolidated release are a verified comparison baseline.

## Comparison results

The unmodified packaged functions were evaluated in memory using the packaged
five-airport configuration and `fuel_flow_unit = "auto"`. The production entry
scripts were not run. Diagnostic exports contain comparisons and source evidence,
not replacement releases.

- All ten requested flights match their original batch and consolidated records.
- All 365 selected milestone rows, 71 phase rows, and 85 level rows reproduce:
  no missing/extra keys and no differing shared field values at absolute tolerance
  `1e-6` (seconds for timestamps, native units for other numeric fields).
- All ten select kg/h with the helper's “high” confidence. This is algorithmic
  plausibility evidence, not independent confirmation of source units.
- Two representative controls pass the position screens and reproduce the
  historical reference's shared operational event fields. A third contains
  additional position anomalies; its TOD differs under the bundled airport
  configuration and matches the historical TOD when legacy airport metadata is
  supplied in a diagnostic intervention.
- Legacy distance anchors used different semantics. Their names must not be
  interpreted as proof that they equal the current along-track anchors. Expected
  anchor/schema differences and missing airport metadata are recorded separately
  from operational-event comparisons.

## Findings and evidence

| Finding | Attribution and reproducible evidence | Implication |
|---|---|---|
| All five requested extreme-distance cases contain gross position discontinuities | **Supplied source + missing helper QC.** Independent vector-based great-circle calculations reproduce the inflated paths and expose individual legs inconsistent with elapsed time and recorded GS. Some samples are zero; others are nonzero and within legal latitude/longitude ranges. | A common unit factor cannot resolve these cases. Rejecting out-of-range coordinates alone is insufficient. Determine recording/export/encoding causes before choosing any repair. |
| Two complete position streams are zero | **Supplied source + helper dependency.** Every LAT/LON pair is zero, but altitude, GS, and landing-phase records remain. The helper calculates zero path; its `DIST_FLOWN_NM > median(DIST_FLOWN_NM)` gate never opens. A distance-only, GS-based diagnostic intervention restores ALTO/ALDT for both flights. | Missing position is incorrectly allowed to suppress independently supported landing evidence. The GS intervention assumes knots and is not an adopted replacement trajectory. |
| Two high-elevation arrivals lose ALTO and ALDT | **Helper logic.** Landing-phase pressure altitudes are roughly 6,600–6,800 ft. The helper requires absolute pressure altitude at or below 3,000 ft before it will consider landing, even when landing-phase/taxi records exist. | Separate pressure-altitude anchors from airport-relative approach/landing detection. Airport elevation and source phase semantics need an explicit contract; do not force these pressure altitudes to zero. |
| One supplied altitude stream is entirely missing | **Supplied source.** All 10,116 altitude samples are absent; no alternative altitude column is supplied. Phase codes can produce ATOT, but the altitude-dependent landmarks have no supporting observations. | Obtain a usable altitude channel or keep altitude-dependent products unavailable. No altitude reconstruction is justified by this extract alone. |
| Distance and fuel quantities are shifted across timestamp boundaries | **Helper logic.** The reader computes outgoing row increments and immediately includes them in the cumulative value at that same row. Endpoint subtraction consequently replaces the starting increment with the ending increment. A synthetic three-sample example reproduces this without restricted data; identities also hold in the real-flight comparisons. | Correct cumulative-value timestamp semantics before rebuilding dependent anchors, phases, or level quantities. This is separate from source position defects. |
| Invalid prerequisite events create misleading cruise/approach outputs | **Helper logic interacting with source defects.** Five of ten requested flights have TOC and TOD at the same row through fallback logic; one also has ALTO before the cruise-end row. | “TOC/TOD present” and a zero-duration cruise do not establish valid physical phases. Missing or contradictory prerequisite evidence must propagate to validity flags. |
| Legacy clock selection is unsafe | **Reader configuration/source interpretation.** Three old-format examples contain two time columns. The helper always selects the second; it has thousands of duplicate steps and yields much longer durations, including a small backward jump treated as a day rollover. The first clock progresses at about one second per row. | Confirm the fields with the source owner and select by an explicit schema contract. This does not explain the ten new-format cases, which have a single clock. |
| Empty retained level sets can still crash the helper | **Helper logic.** A six-sample, flat synthetic profile above the altitude gate has candidates but none lasting ten seconds. The unchanged helper errors in rowwise altitude calculation. No candidates returns an empty table correctly; a retained 20-second level succeeds. The three legacy compatibility examples also hit this error. | The existing empty-level handling does not cover “candidates existed but all failed minimum duration.” This is reproducible independently of the legacy clock ambiguity. |
| Missing airport metadata changes TOD silently | **Configuration.** The packaged study-airport table omits the destination used by the older demonstrator. Adding that legacy airport record changes TOD in one of three controls and restores its historical event row. | Validate airport coverage explicitly. This is a control-configuration finding, not an explanation for the ten requested study-pair cases, whose airports are covered. |

The phase-boundary identity is:

`reported interval = timestamp-aligned interval + outgoing increment at end - outgoing increment at start`.

For a synthetic one-second interval with outgoing distances 1 and 2 NM and fuel
flows 1,000 and 2,000 kg/h, the helper reports 2 NM and 2,000/3,600 kg instead of
1 NM and 1,000/3,600 kg. No interpretation of aircraft performance is needed to
demonstrate the indexing error. Independent geometric calculations and the helper
use slightly different rounded nautical-mile conversion constants; the accounting
identity is therefore checked using the helper's own increments, separately from
the independent geometry check.

## Evidence, limits, and next work

`aggregate-checks.csv` gives identifier-free counts and numerical checks. The
restricted run is under
`.fuelburn-data-store/derived/chn/verification/CHN-2026-10-18-001/`:

- `provenance/input-manifest.csv`: input paths, byte sizes, SHA-256 hashes.
- `provenance/archive-members.json`: helper/return member hashes and ZIP timestamps.
- `source-inventory.json`, `requested-cases.csv`, `control-cases.csv`: sensitive
  source-to-case mapping and deterministic control selection.
- `evidence/case-findings.csv`: a finding and evidence references for each
  requested flight; detailed source events, comparison differences, accounting,
  landing support, clocks, interventions, and synthetic reproductions sit beside it.
- `evidence/runtime.txt`: R/package environment and evaluated helper checksum.
- `protected-inputs-before.json` and `protected-inputs-after.json`: SHA-256
  preservation checks for all 85 pre-existing protected data-store files.
- `run-manifest.json` and `evidence-files.sha256`: audit code/input provenance
  and checksums for the retained evidence package.

Rerun the diagnostic comparisons with:

```sh
Rscript scripts/audit-chn-qar-verification.R .fuelburn-data-store/derived/chn/verification/CHN-2026-10-18-001
Rscript scripts/audit-chn-qar-fringe-cases.R .fuelburn-data-store/derived/chn/verification/CHN-2026-10-18-001
```

These commands require the restricted prepared inputs. They do not download,
upload, alter the helper, or update release/registry objects. Rerunning changes
diagnostic evidence files, so refresh the evidence manifest afterward if retaining
a new run. Immutable copies of the audit scripts are included in the restricted
provenance directory.

The position screen at 750 kt is diagnostic, not an adopted cleaning or eligibility
rule. GS integration assumes knots; source units, phase-code meanings, coordinate
export behavior, altitude channels, and airport-relative detection parameters still
need source-owner confirmation. The cases were deliberately selected for problems;
their counts do not estimate prevalence across the 6,421-flight study dataset.

Specific issues are now reproducible, satisfying the requested investigation
gate. Any later helper repair should address timestamp accounting, source validity
and clock/airport contracts, arrival detection, fallback validity, and empty-level
behavior with these cases as regressions. That repair and any new canonical release
are separate work. Original verification and return archives are retained locally;
archival upload to the private R2 bucket remains pending. Public sharing of derived
canonical study data remains undecided.
