# CHN helper: ARP anchors and profile-based TOC/TOD

`2.0.0-candidate.5` implements the clarified distance and profile definitions and
is the package prepared for the next CAUC processing exercise. It supersedes
candidate.4's unnecessary per-flight ARP-offset requirement. Existing EUR and CHN
canonical releases remain unchanged; candidate outputs are not an adopted release.

ARP anchors D040/D100/D200 and A200/A100/A040 use great-circle distance from/to
the airport coordinate. Distance flown separately accumulates successive short
great-circle legs along the cleaned/repaired track, with explicit full-record or
ATOT-zero airborne references. The package bundles 50 sourced airport coordinates,
covering all four airports in the fourteen returned batches and all airports in
the 233 reference/verification inputs. No manual per-flight ARP preparation or
runtime download is required. An OurAirports source CSV can also be read directly.

The public airport snapshot is pinned to OurAirports commit
`65beeb51c64fa411eb113c5d6680715309cd808a` (31 August 2025). The ZIP records its URL,
checksum and provenance. Coordinates are explicitly an airport-coordinate proxy
for ARP. The correct Changshui entry replaces the previously withheld legacy
Kunming reference. All distance-valid take-off/landing points in the test inputs
are within 3 NM of their selected airport coordinate; this supports the mapping
without asserting official ARP certification.

TOC/TOD are actual entry/exit boundaries of sustained level segments derived from
pressure altitude versus time. The 200 NM windows supply altitude context for
choosing the initial/final cruise level when enroute step changes occur. The
initial departure window ends at the first outward crossing; the final arrival
window begins after the last inward crossing. Their near-ceiling altitude bands
use the existing 1,000 ft / 3% tolerance. The first/last qualifying complete level
is selected; no level is clipped at a circle crossing or required to intersect
an outside-both-circles region. This preserves an initial cruise level that ends
before D200 followed by a lower enroute level. Lower level-offs after the main
TOD remain separate descent milestones. Climb evidence precedes TOC and sustained
descent evidence follows TOD. Missing partners stay unavailable in partial files.

The existing level criteria remain 300 ft/min and a 120-second minimum cruise
level, with shorter accepted level-offs retained in the full level table. Short
flights or unavailable geometry use the near-ceiling airborne-profile fallback.
Selection context is recorded in MST_METHOD; TOC/TOD link directly to level IDs.
There is one airport lookup and no legacy compatibility lookup/workaround.

| Input set | Files | Included / held | Whole-airborne fuel/time | All twelve ARP/pressure families present |
|---|---:|---:|---:|---:|
| Older reference exports | 220 | 186 / 34 | 187 | 208 |
| Modern controls | 3 | 3 / 0 | 3 | 3 |
| Verification flights | 10 | 7 / 3 | 10 | 7 |

These are input-file counts, not deduplicated study-flight counts. The 220 older
exports represent 121 identifiers. Anchor completeness is independent of fuel
availability and primary-cohort eligibility. Nine verification flights support the
pressure anchors; the file with missing altitude retains supported distance
information. Unsupported position streams do not receive invented ARP anchors.
All 233 inputs have airport references; none requires a manual ARP offset.

Common-cohort membership is unchanged from candidate.4. The 34 older holds remain
28 missing-fuel-channel exports, five clock/sampling cases and one position/profile
case. The three verification holds remain two unsupported position streams and
one missing altitude stream. The problem, exclusion and further-investigation
lists contain the same 37 input records and are byte-identical. The broader issue
ledger retains nonblocking/out-of-scope findings. Whole-airborne, full-record and
locally supported partial fuel/time coverage remain separate; full recorder span
is not proof of complete block-to-block coverage.

Results include the eighteen previously recorded exact-input position-share
reviews. Their physical repairs/exposure and clock/fuel/profile quality reproduced
unchanged before carrying the reviews to this helper version. The ZIP contains
no private approval manifest; without the matching restricted approvals, the
above-threshold repair-share holds remain. An approval cannot waive another
unsupported channel. The ARP calculation itself requires no such preparation.

All 233 inputs passed integration validation, with no runtime failures. All 97
synthetic checks passed, including enroute step levels, a cruise ending before
D200, levels extending across both windows, and moving a circle crossing within
the same level without moving TOC/TOD. Every emitted TOC/TOD equals the exact
boundary of its linked full level segment. Representative profiles with substantial
changes in an older reference, a modern control and a verification input were
reviewed; those plots and their input identities remain restricted.

TOC/TOD allocations intentionally change under the clarified method: 203 paired
TOC events and 190 paired TOD events differ, and one additional partial TOC is
retained. Some differences are a sample-boundary adjustment; larger differences
reflect the selection of initial/final cruise levels rather than an enroute
maximum or an intermediate step descent. All other paired event times, including
ATOT/ALDT and LTO boundaries, are unchanged. Whole-airborne time, fuel and distance
are identical to candidate.4. Phase-specific fuel allocations must therefore be
reviewed as new candidate results, not silently mixed with an earlier release.

The exact eight-member ZIP passed a seven-input standalone run. It matches the
direct helper on all 58 QC fields and twelve output tables, allowing the verified
1.1-microsecond Parquet timestamp precision bound. A separate direct-OurAirports
source-file run also produces every ARP/pressure anchor in the complete control.
Synthetic fuel units are declared for those controls. All 85 protected-file hashes
and 2,229 earlier evidence-file hashes match; the original and four earlier
helper ZIPs are unchanged. No flight data were uploaded to GitHub or R2.

Restricted evidence:
`.fuelburn-data-store/derived/chn/helper-v2/CHN-v2-2026-10-18-009/`.
The earlier exploratory runs remain restricted and are not the distributed build.
Adjacent CSVs contain aggregate evidence only.

Package: `outputs/CHN-fuel-burn-helper-2.0.0-candidate.5.zip`.
SHA256: `8078ad48d2471156b57455b2808f02ea407593c9065953602d4d471a445929a7`.
Usage, output definitions and optional configuration are in
`helpers/chn-qar-v2/README.md`. The ZIP contains source, documentation, public
airport metadata, version and checksums; it contains no QAR or flight-level evidence.
