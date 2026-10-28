# Candidate.6 full-batch return: inventory and exclusion investigation

Received 27 October 2026. This is a diagnostic candidate evaluation, not adoption
of a new study cohort or replacement of existing canonical data.

**The full return holds 3,552 of 6,421 flights (55.3%) from the strict common
cohort, but 6,388 (99.49%) retain whole-airborne fuel/time.** The earlier 384/505
message describes one batch. Most holds reflect the 1% position-repair review
gate, rather than unusable fuel data or a failed batch run.

## Inventory and provenance

| Archive | Contents |
|---|---|
| `data result20261022.zip` | 14 result folders, 714 files: 17 CSV/Parquet table pairs per batch, 168 diagnostic plots, 14 input manifests, 14 airport lookups, 14 run manifests, 14 runtime files and 14 checksum files |
| `valid data20261025.zip` | 40 source QAR CSV files; all map to output9, comprising 33 A330 files and seven passing A320/A321 comparisons |

The result archive is 998,733,738 bytes (4,913,875,313 bytes uncompressed); the
source archive is 5,533,952 bytes (25,739,649 uncompressed). Complete archives are
preserved in restricted storage. Compact tables are extracted for analysis;
large repair CSVs remain available inside the preserved archive, with their full
checksums verified by streaming. File/member inventories retain all details.

All **700 returned checksum entries** match; ZIP members were fully read with CRC
verification. Every supplied raw file matches the corresponding input-manifest
SHA256. The earlier twenty verification inputs also match their recorded hashes.
There are **6,421 unique identifiers, exactly the same identifier set as the
earlier fourteen-batch outputs**, with no cross-batch duplicate IDs or additions.
The forty sources add verification material, not forty new study flights.

All batches record candidate.6 with the same processing-function hash as the sent
helper, the same bundled airport-lookup hash and identical default configuration.
The first run is dated 22 October and the remaining runs 25 October. Limits remain
15 seconds for positions, five seconds for fuel/altitude, and a 1% airborne repair
share. No private review manifest was used. All airports are supported; missing
ARP metadata is not causing the holds. CLI and legacy-core hashes are not separately
recorded in this run-manifest format, so their exact bytes cannot independently
be established from the manifests alone.

All input-manifest and QC populations agree; problem/exclusion CSVs are identical
within each batch. There are no `processing_error` records. Runtime/session files
are present, but console transcripts are not: absence of console warnings or exit
statuses cannot be established for the full runs from this delivery.

## Hold causes: mutually exclusive groups

| Category | Flights |
|---|---:|
| Position repair-share gate only | 2,596 |
| Unsupported position, including cases with additional holds | 913 |
| Position-share gate plus another domain hold, without unsupported positions | 13 |
| Other time/fuel/profile holds | 30 |
| **All common-cohort holds** | **3,552** |

The first group accounts for **73.1% of holds**. It is a review queue, not an
approval list. Across overlapping reason flags, 2,638 flights hit the airborne
position-share gate, 913 report unresolved position, 283 report position held
while moving, 38 report unresolved phase boundaries, 33 unresolved altitude,
27 sampling gaps and four fuel-unit review. Those overlapping counts must not
be summed. Only two full-return input hashes match existing private approvals;
the absence of those approvals cannot explain thousands of holds.

For the originally reported **output1**, 384/505 are held, of which **382 are
position-share-only holds**. Whole-airborne fuel/time remains supported for 503/505.
The large variation among batches mainly reflects their source/aircraft mix.

## Source-format concentration and supported quantities

- **A330: 2,207/2,207 held; 2,202 solely on position repair share.** Typical
  position repair exposure is approximately 2.1%. The helper separately records
  ordinary two-second channel alignment as cadence handling, rather than counting
  every aligned frame against the anomaly budget.
- **C919: 587/587 held.** Each reports unsupported position for its entire record;
  all retained observed-point samples have no usable coordinates. This is consistent
  with the earlier raw verification cases with zero source positions. Full raw QAR
  for these 587 was not supplied here, so their original extraction/encoding cause
  is not established by the outputs alone. Longer bridges cannot supply an entire
  missing position stream.
- **B787-9: 282/282 held.** Every flight's retained observed coordinate samples are
  whole-degree values and every flight triggers held-position detection. This
  matches the earlier raw verification of coarse exported coordinates. It points
  to a source precision/extraction limitation; no credible detailed track can be
  recovered by smoothing the supplied integer coordinates.
- **B737-MAX: 22/22 held.** None has usable altitude in its retained observed points,
  consistent with the previously confirmed absent altitude channel. Fuel/time and
  source-phase airborne bounds can survive, but altitude-dependent milestones cannot.
- Other position-share-only holds concentrate in B737-700/800 records. Earlier
  individually reviewed short-return examples are relevant precedents, not blanket
  approvals for other inputs.

| Quantity/support | Flights |
|---|---:|
| Included in strict common cohort | 2,869 |
| Whole-airborne fuel/time eligible | 6,388 |
| Airborne distance valid under default review policy | 2,899 |
| Airborne profile data valid | 6,386 |
| All twelve ARP/pressure anchor families present | 5,516 |

**3,519 held flights still support whole-airborne fuel/time.** Ground and full-record
flags remain separate. Anchor presence alone does not approve repaired geometry
or make a flight fully compliant. Neither 3,552 holds nor 6,388 fuel/time records
is a substitute for choosing a metric-specific study cohort.

## Raw-file checks: source artefact versus rule strictness

The forty supplied files are a **single-batch, non-random sample**. Their source
hashes match the processed inputs. Local reruns reproduce all forty QC records
across 2,320 fields, with maximum numeric difference about 1.5e-10 and no helper
warnings. The seven A320/A321 comparisons pass; all 33 A330 files hit only the
position-share review gate.

All 33 A330 sources contain implausible native-coordinate steps **before alignment**.
Thus the anomalies are not simply two-second sampling being mistaken for a gap.
The sampled source observations jump and return; regular alignment can propagate
one bad source observation into adjacent one-second interpolated frames, which
then correctly require bounded anomaly repair. Source and repair traces remain
restricted. These checks do not establish the original recorder/export cause.

For this sample, airborne repair brackets are at most six seconds, maximum bridge
speed is approximately 687 kt and maximum observed-neighbour direction change is
26.5 degrees. Both lie within the existing physical screens. Cleaned distance
agrees with recorded-groundspeed integration within the prior individual-review
0.3% comparison envelope in **32/33** cases. The median absolute difference is
0.166%; replacing just repair-adjacent leg lengths with GS integration changes
whole-airborne distance by a median absolute 0.0076%. These are consistency and
sensitivity checks, not independent surveillance truth or uncertainty bounds.

Using the previous numerical review screen, **29/33 are promising review candidates**.
Three need expanded native-observation context because some current bridge endpoints
are cadence-aligned; a separate case falls outside the earlier GS comparison envelope.
These four are not automatically unusable, but require closer review. No new approvals
were recorded. Plots of representative source jumps, the largest GS discrepancy and
an endpoint-review case were inspected; every sample bridge was checked numerically.

The evidence supports a distinction: there are real, recurring source excursions,
while the 1% share threshold is a conservative review trigger that holds many
potentially useful repaired tracks. No reproducible calculation, version/configuration
mismatch or cadence-alignment defect was found in the supplied forty sources. This
does not prove that all unsupplied raw records are free of fringe cases.

## Recommended next steps

1. Retain separate fuel/time, distance and finer-profile candidate cohorts for
   discussion. Keep the existing canonical CHN data as the provisional paper basis.
2. Review the 2,596 position-share-only candidates through documented per-flight
   physical/context/GS checks, prioritising the thirty-three supplied A330 files
   and familiar short-return patterns. Do not waive the gate for an entire aircraft
   type, raise thresholds globally or treat the review queue as exclusions adopted
   for the paper.
3. Seek full-precision coordinate exports / correct channels for the unsupported
   position groups and altitude restoration for missing-profile groups. Confirm
   source units for the four unit-review cases and inspect genuine time gaps separately.
4. If approvals are granted, rerun only new restricted candidate evaluations with
   exact-input/version-bound manifests. Do not merely flip the exclusion flag:
   approving geometry can enable the 200 NM TOC/TOD context and alter phase allocation.
   Whole-airborne fuel/time can remain unchanged while finer phase boundaries change.
5. Discuss adoption and eligibility/candidate selection after those reviews. The
   current evidence does not justify another helper release solely to lower the
   exclusion count.

## Evidence and preservation

Restricted audit:
`.fuelburn-data-store/derived/chn/verification/CHN-2026-10-27-001/`.
This holds archives, member/hash inventories, all returned tables needed for the
audit, forty sources, per-flight QC/point support, a restricted position-review
queue, forty rerun results, bridge metrics and diagnostic plots. Exact flight
identities, coordinates, quantities and decisions remain restricted. Adjacent CSVs
contain aggregate evidence only. Summary reproduction:
`python3 scripts/audit-chn-batch-summary.py <restricted audit directory>`.

No helper code, thresholds, approval manifests, EUR data or existing canonical
release was changed; no candidate release was adopted or regenerated. The 92-file
protection set matches the audit-start snapshot, and the earlier 90-file protected
baseline remains unchanged. No flight data were uploaded to GitHub or R2; no
external messages were sent.
