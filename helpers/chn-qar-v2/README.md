# CHN QAR helper 2.0.0-candidate.5

This isolated candidate evaluates the physical airborne study window and retains
separate full-record and ground diagnostics. It does not replace the distributed
helper, EUR pipeline, or any existing canonical release. Run it only in a
restricted source-data environment. Its outputs, plots, input manifests, and
repair/review logs contain flight-level information and must not enter GitHub.

Required R packages: `dplyr`, `tibble`, `readr`, `purrr`, `data.table`, `zoo`, `hms`,
`arrow`, `digest`, and `jsonlite`. Processing does not install packages or use a
network service.

```sh
Rscript HELPER-FOR-LINGLING-v2.R /path/to/qar.zip /restricted/new-output
Rscript HELPER-FOR-LINGLING-v2.R /path/to/qar-folder /restricted/new-output config.json
```

The output directory must be new or empty. Existing outputs and production
`processed/` or `parallel-preprocessing/` paths are refused. The script loads its
bundled R files relative to its location. Directory, ZIP, and nested-ZIP inputs
are supported; unsafe archive paths are rejected. Read failures produce explicit
problem records. Multiple exports sharing a flight identifier remain identity
holds in a batch; individual reference tests do not merge or select those exports.

## Study eligibility and diagnostics

`STUDY_EXCLUDE` and `PROBLEM_FLIGHT` describe the common airborne primary cohort:
ordered ATOT–TOC–TOD–ALDT, supported time, altitude/profile, required engine fuel,
and position throughout the source-supported airborne window. The problem and
study-exclusion CSVs are generated from the same flag and checked for byte equality.
Ancillary DLTO/ALTO boundaries have their own `LTO_BOUNDARIES_VALID` flag. Their
absence does not by itself exclude an otherwise supported airborne profile.

The issue ledger is broader. `SOURCE_STATUS` retains each original full-record
finding; `STUDY_RELEVANT` states whether it blocks the common airborne study.
`out_of_scope` findings remain visible and can keep full-record quantities invalid
without excluding supported airborne quantities. A reviewed share hold is recorded
as `reviewed`; an approval cannot release a missing channel or failed bridge.

`TIME_VALID`, `FUEL_VALID`, `DISTANCE_VALID`, and `PROFILE_DATA_VALID` retain their
full-record meanings. `AIRBORNE_*_VALID` flags and domain eligibility report the
airborne support separately. `GROUND_TIME_VALID` remains a conservative full-clock
check. No position or altitude endpoint cropping is performed: recorded ground
rows and times are retained after exact physical-observation deduplication.
AOBT/AIBT remain the legacy record-edge proxies, not independently observed block
events. Source-phase timing does not become precise wheel-touchdown timing.

## Outputs and cumulative references

The familiar canonical-milestone, nine-phase LTO summary, and level-segment tables
are written only in the new candidate directory. Additional tables are:

- `CHN-airborne-phase-summaries`: the physical `[ATOT,TOC)`, `[TOC,TOD)`,
  `[TOD,ALDT]` partition, independently tagged from the legacy nine-phase partition.
- `CHN-airborne-summaries`: ATOT–ALDT time, consumed fuel, distance, kg/min and
  kg/NM, with quantity-specific eligibility. Whole-airborne fuel/time may be
  supported even when a missing cruise boundary excludes the common cohort.
- `CHN-flight-quality`, `CHN-issue-ledger`, and `CHN-repair-log`: domain flags,
  source anomalies, native-channel cadence, repairs and review decisions.
- Diagnostic phase summaries and profile plots retain source artefacts; invalid
  analytical distances never become apparently valid extreme values or zero.

For a fully supported record, the original cumulative convention remains zero at
record start. If ground defects invalidate that full cumulative quantity but the
airborne window is supported, the candidate supplies an ATOT-zero cumulative
quantity **only within ATOT–ALDT**; ground values remain missing. Each quantity
carries `CANONICAL_FUEL_REFERENCE` / `CANONICAL_DISTANCE_REFERENCE`, so references
cannot be silently mixed. `AIRBORNE_FUEL_KG` and `AIRBORNE_DIST_FLOWN_NM` always
use ATOT-zero support. Full-record values are retained separately in the trajectory.
Missing prefixes are never filled with zero fuel or invented distance.

Fuel uses outgoing left-rectangle increments, included at the next timestamp.
Airborne fuel needs flow at ATOT through the last interval before ALDT; fuel at
ALDT belongs to the following ground interval. Position at ALDT is still required
to close the final airborne leg. Distance-anchor references are distinguished below.
Phase fuel/time and distance eligibility are independent; a taxi phase can retain
fuel/time with its distance missing. Do not sum across different partitions.

## Enriched milestones and partial completeness

Candidate.5 uses great-circle ARP radii following the clarified definition.
It removes candidate.4's unnecessary per-flight offset preparation. The six
completeness tables remain:

- `CHN-milestone-candidates`: all directional pressure and distance crossings,
  including unresolved candidates and level-associated crossings. Each has a stable
  candidate ID, source/sample brackets, time gap, fractional crossing time,
  threshold/reference, endpoint residuals, support reason and explicit selection.
- `CHN-milestone-availability`: one row for each of eighteen threshold families.
  Reasons distinguish available, represented by a level interval, not reached in
  the supported window, unresolved crossing, unsupported data/window, and unsupported
  reference. Absence of an optional anchor does not alone exclude whole-airborne use.
- `CHN-phase-intervals`: a positive-duration airborne partition at every supported,
  unsuppressed crossing and operational/level boundary. Repeated crossings remain
  in this partition. Coincident roles share one boundary. Fuel, distance, altitude
  change and macro phase are recorded with separate quantity eligibility.
- `CHN-fuel-time-coverage`: contiguous locally supported flow/time runs, split at
  supported ATOT/ALDT boundaries. Gaps are not integrated across. Repair share and
  quantity eligibility stay explicit; a locally supported run is not a full-flight
  completeness claim.
- `CHN-supported-data-points`: observed source points at event brackets and coverage
  boundaries, with channel quality flags. Interpolated crossing events are in the
  milestone/candidate tables; they are not presented as observed samples.
- `CHN-flight-summaries`: whole-airborne and full-record summaries. Join to the
  one-row-per-input `CHN-flight-quality` table for identity and domain flags.
  **FULL_RECORD means the available recorder span; it does not prove full block
  coverage.** Its endpoints are record-edge proxies.

Pressure anchors are `D_FL075`, `D_FL100`, `D_FL180` upward and `A_FL180`,
`A_FL100`, `A_FL075` downward, on standard-pressure altitude. Linear interpolation
is allowed only across a supported pressure bracket, at most five seconds. Repeated
crossings are retained; the convenience milestone view selects the first supported
upward / last supported downward crossing. A pressure crossing fully within one
accepted level segment is retained as evidence but suppressed as an extra subphase
boundary; its paired `LVL_START`/`LVL_END` represent the interval. Level tables
record the detector and configured minimum duration.

`D040/D100/D200` and `A200/A100/A040` are **great-circle radii from/to the
respective airport reference coordinate**, in NM. They are separate from distance
flown. At each repaired QAR position, haversine distance is calculated to ADEP and
ADES. All outward departure and inward arrival crossings are retained, including
recrossings after a turn. The crossing is resolved by bisection on the same
piecewise-linear repaired coordinates, retaining the bracket and final radial
residual. The supported position bracket is at most fifteen seconds. Circles may
overlap on short flights; the helper does not assume disjoint windows.

`DIST_FLOWN_NM` accumulates successive short great-circle legs on the cleaned,
cadence-aligned and boundedly repaired track, with its cumulative reference
explicitly recorded. `AIRBORNE_DIST_FLOWN_NM` is zero at ATOT. Separate
`D_ATOT040/100/200` and `A_ALDT200/100/040` anchors refer to cumulative airborne
track length and remain labelled separately. No extra whole-track smoothing or
unsupported ground-path reconstruction is applied.

The package bundles `data/airports.csv` and an identical built-in lookup tibble:
**50 airports**, covering all four airports in the fourteen returned batches and
the union of older/reference/verification inputs. The public OurAirports snapshot
is pinned to commit `65beeb51c64fa411eb113c5d6680715309cd808a` (31 August 2025),
with source URL, hash and selection date in `data/airports-provenance.json`.
Kunming's entry is Changshui, replacing the previously withheld legacy coordinate.
OurAirports coordinates are identified as an **airport-coordinate proxy for ARP**,
not certified aeronautical-publication ARP coordinates.

**No additional per-flight preparation or runtime internet access is required.**
Use the bundled default. Optional `airport_reference_path` can instead read an
OurAirports `airports.csv` directly, a prepared `ICAO,LAT,LON` table, or an
`ICAO,ARP_LAT,ARP_LON` table. Keep that reference file outside the QAR input folder.
For OurAirports files, explicit `icao_code` takes precedence over a conflicting
`ident` fallback; closed entries and non-ICAO identifiers are ignored. Remaining
duplicate codes, invalid coordinates or malformed schemas are configuration
errors. Airport lookup is independent for departure and arrival; a missing airport
leaves only its ARP families `REFERENCE_UNSUPPORTED`. It does not manufacture a
position or automatically exclude supported airborne fuel/time.

The CLI preserves normalized `airports-used.csv`, the source checksum and snapshot
metadata. For a supplied file it also preserves the exact reference source.
`ENRICHED_ANCHORS_RESOLVED` accepts available/level-represented or demonstrably
unreached thresholds; `ALL_12_ARP_FL_ANCHORS_PRESENT` requires all twelve families
available or level-represented. Invalid QAR position or a track that never reaches
a radius can still prevent an anchor even with complete airport metadata.

The earlier along-track ARP-offset interpretation is superseded by this clarified
radius definition. Candidate.4's `arp_reference_path` and per-flight offset template
are removed. EUR and existing canonical releases remain unchanged.

## Position repair and cadence

These are explicit study candidate parameters, not an aviation-wide interpolation
standard. The default `max_position_gap_sec` is **15 seconds between bounding
observations**, with a hard configurable ceiling of 15 seconds. A 15-second bound
allows at most fourteen interior missing samples on a one-second series. It does
not permit endpoint extrapolation, filling an entirely absent stream, or a long
persistent coordinate change.

Native sparse/multiplexed and held channels are identified by repeated update
cadence before joint motion screening. Regular sampling reconstruction is reported
separately from irregular/anomaly repair and does not consume the anomaly budget.
Reconstruction follows the demonstrated native cadence; it is not unrestricted
smoothing across multiple missed updates.

Every joint position bridge must satisfy:

- Finite, geographically valid bounding observations and forward time.
- At most 750 kt implied motion and consistency with available GS (knots).
- At most 120 kt on source-confirmed ground intervals without contradictory GS.
- For airborne bridges longer than five seconds, valid observations before and
  after the bracket with adjacent bearing changes no greater than 45 degrees.

A longer bridge across a turn or without neighbouring support remains unresolved.
Ground linear distances remain estimates: a bridge may cut a taxi turn. Ground
timing and fuel eligibility do not depend on accepting that geometric estimate.
Original positions and every change remain in the repair ledger. A finite,
nonzero joint position held for more than fifteen seconds during source airborne
phases with independent GS (or IAS when GS is absent) above 80 kt is flagged as
`position_frozen_while_moving`. Its path is withheld; no curve is manufactured.
Stationary ground samples do not trigger this rule. This is a targeted freeze
screen, not proof that every more subtle trajectory error has been detected.

## Fuel, altitude, time and the repair-share review

`max_gap_sec` stays **5 seconds** for fuel and altitude. Fuel never sums a missing
required engine as zero. A short bracket containing an observed engine-zero state
may cross the fourfold endpoint-ratio screen only if both endpoints have source
ground phase 1/2/3/14 and no available GS of 80 kt or more. Airborne zero-flow
brackets remain unresolved. Fuel-unit inference is a plausibility check; set
`fuel_flow_unit` explicitly to `kg/h` or `lb/h` when declared by the producer.

Altitude gross-motion screening stays 12,000 ft/min; a repaired bracket must be
at most 6,000 ft/min. Pressure altitude is preserved. Ground altitude problems do
not alone invalidate supported airborne altitude; relative 3,000-ft LTO anchors
still require observed field-pressure support and retain independent availability.
TOC/TOD need sustained profile evidence; no blind shared-maximum fallback is used.

Clock scoring uses distinct physical observations, so duplicate-expanded exports
cannot dilute auxiliary-clock faults. Credible distinct clocks remain ambiguous
unless configured. Only supported evening-to-morning transitions become midnight
rollover; no subsecond clock or missing recording rows are invented. The maximum
integration interval remains 30 seconds, with separate window checks.

The 1% repair-share review threshold remains in place. In the airborne window it
uses elapsed-time-weighted repaired sample exposure. Ground-only repairs do not
consume the airborne budget, while full-record repair holds remain diagnostic.
An above-threshold airborne case stays excluded unless individually reviewed.

A restricted optional CSV supplied via `repair_review_path` can release **only**
a repair-share hold. Required columns are `SHA256`, `DOMAIN`, `DECISION`,
`HELPER_VERSION`, `MAX_REPAIR_SHARE`, and `EVIDENCE`. A record must match the exact
input hash and helper version, use `approve_airborne`, contain an evidence note,
and cover the observed share. Duplicate, stale, or mismatched records do not grant
approval. All other support and physical checks still apply. This manifest is
private evidence, excluded from the source ZIP and GitHub. The CLI copies the
manifest used into its restricted output and records its checksum.

Example configuration:

```json
{
  "fuel_flow_unit": "kg/h",
  "max_position_gap_sec": 15,
  "max_gap_sec": 5,
  "max_repair_share": 0.01,
  "require_airport_metadata": false,
  "max_plots": 12
}
```

TOC/TOD are entry/exit boundaries of complete sustained level segments detected
from pressure altitude versus time (existing 300 ft/min and 120-second cruise
criteria). The initial departure / final arrival 200 NM windows identify the
relevant altitude context, so enroute step climbs/descents do not substitute a
mid-flight global maximum for the initial or final cruise level. The existing
near-ceiling band (1,000 ft or 3%) selects the relevant full level segments.

TOC is the first qualifying level entry; TOD is the last qualifying level exit.
A selected level is never clipped at D200/A200, nor required to cross a circle.
This also retains an initial cruise level ending before D200 followed by a lower
enroute step level. Lower level-offs after main descent remain separate events.
TOC/TOD link to their level IDs. Short flights or missing geometry use the same
near-ceiling rule on the available airborne profile; the context/fallback is
recorded in `MST_METHOD`. Climb evidence is required before TOC and sustained
descent evidence after TOD. Unsupported partners remain missing in partial
profiles. There is one airport lookup and no compatibility workaround.
`phase_codes_confirmed` defaults to true for the established source contract
(airborne phases 6–11, sustained landing phase 12). Set it false for an unconfirmed
source; the candidate then cannot qualify its airborne window.

## Provenance and distribution

The frozen `R/legacy-core.R` is utility/schema code from revision
`68b9f8b1664ed43b2c64f7f413de9b5278d0ddc5`. Candidate CHN behavior is defined in
`R/chn-qar.R` loaded afterward into an isolated environment. EUR functions in the
utility file are never called by this entry point. The source ZIP contains only
helper source, public airport metadata, this documentation, version and checksums.

Runs record effective configuration, function checksum, input hashes, environment,
review/airport-reference provenance and output checksums. Keep these with restricted
evidence. Cohort adoption, canonical release replacement, and reproducibility
sharing remain separate decisions.
