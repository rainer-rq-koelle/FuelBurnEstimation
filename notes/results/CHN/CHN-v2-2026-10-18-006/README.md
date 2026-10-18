# CHN helper completeness and returned-batch smoke check

Use `2.0.0-candidate.4` for the next restricted CAUC evaluation. It adds explicit
milestone completeness, crossing evidence, finer airborne intervals and partial
fuel/time coverage to candidate.3. It also corrects the distance-anchor reference
mismatch. This is a new helper candidate; EUR and existing canonical releases
have not been changed or adopted into a new study release.

The full applicable milestone set is supported when its source channels, window
and references are supported. All six directional pressure thresholds, operational
landmarks and paired level boundaries are retained where possible. Repeated
crossings remain in the candidate table; the convenience view explicitly selects
first supported upward / last supported downward crossings. A crossing fully
associated with an accepted level segment remains evidence, while the level pair
provides the subphase boundaries. Sample brackets, interpolation fraction, gap,
threshold residual, support reason and selection are recorded. The finer partition
retains all supported unsuppressed crossings, including repeated ones.

**ARP completeness is conditional.** The documented D040/D100/D200 and
A200/A100/A040 definitions are along-track from/to ARP. Candidate.3 used ATOT/ALDT
under these labels. Candidate.4 provides those useful airborne anchors separately
as D_ATOT040/100/200 and A_ALDT200/100/040. It emits the canonical ARP labels only
with a supported, exact-input reference declaration. None of the supplied 233
inputs comes with that reference. Their ARP availability is therefore explicitly
`REFERENCE_UNSUPPORTED`; no radial distance or guessed ground path is substituted.
The package includes an empty reference template and instructions. A clean long
synthetic control with known ARP offsets produces all twelve ARP/pressure families.
Short flights distinguish unreached thresholds from missing or unresolved data.

The existing EUR candidate has distance-reference implementation differences from
the working model. Equal labels alone therefore do not establish identical
cross-regional distance semantics. EUR remains unchanged; a later analysis decision
must resolve that compatibility question before combining such anchors.

| Input set | Inputs | Common cohort included / held | Whole-airborne fuel/time | Full-record fuel/time | All six pressure anchors present |
|---|---:|---:|---:|---:|---:|
| Older reference exports | 220 | 186 / 34 | 187 | 175 | 209 |
| Modern controls | 3 | 3 / 0 | 3 | 3 | 3 |
| Verification flights | 10 | 7 / 3 | 10 | 10 | 9 |

These are file-level counts; the older exports represent 121 flight identifiers.
Cohort membership is identical to candidate.3, with no newly excluded input.
Pressure milestones remain useful even where fuel or position is unavailable.
Nine verification flights provide all six pressure anchors; the tenth has no
usable altitude stream. Eight provide supported ATOT/ALDT distance anchors, while
seven qualify for the joint fuel/time/distance cohort. Reference pressure families
are all resolved, including demonstrably unreached thresholds, for 216 older
exports. There are 2,081 level segments across the test set, each with exactly one
start/end pair and detection settings recorded.

Partial records now have contiguous supported fuel/time runs and observed points
at event brackets and coverage boundaries. The helper never integrates across
an unresolved span. Full-record and whole-airborne summaries have separate bounds
and eligibility. **Full record is the available recorder span, not proof of complete
block-to-block coverage**; record-edge AOBT/AIBT remain proxies. Missing finer
anchors do not alone exclude supported whole-airborne fuel/time. The common
problem/exclusion lists still coincide byte for byte, while metric-specific
eligibility supports later analysis preselection. The broader issue ledger also
retains nonblocking and out-of-scope findings.

The 34 older holds remain 28 missing-required-fuel-channel exports, five
clock/sampling cases and one position/profile case. The three verification holds
remain two unsupported position streams and one missing altitude stream. The
18 exact-input position-share reviews were carried forward under the new helper
version only after repairs, alignment, repair exposure and clock/fuel/profile
results reproduced unchanged. They cannot waive any other support failure.

The original fourteen returned batches contain 6,421 distinct flight identifiers,
266,883 milestone rows, 54,131 phase rows and 64,981 level rows. The scan uses 98
Parquet tables, seven table families per batch. Returned summaries lack executable
checksums; the earlier ten-flight reproduction establishes behavioral compatibility
with the originally sent helper, not proof of the producer's exact executable.
The earlier verification report records the original bundle provenance.

| Smoke screen | Distinct flights flagged |
|---|---:|
| Non-taxi phase mean speed above 750 kt | 3,290 |
| Taxi/exit phase mean speed above 120 kt | 1,362 |
| Missing ALDT under the legacy detector | 1,190 |
| Coincident TOC/TOD / zero-length cruise | 1,173 |
| Invalid or zero position at an emitted event | 684 |
| Airborne phase lasting at least ten minutes with zero distance | 588 |
| Legacy fuel-spike share above 1% | 151 |
| Event-to-event vertical rate above 12,000 ft/min | 10 |
| Fuel cleaning changes full-record total by more than 5% | 7 |
| Emitted altitude outside the gross range | 1 |

Counts overlap. There are 4,540 identifiers with at least one screen flag;
**this is not a proposed exclusion count or a diagnosis from raw QAR**. Missing
ALDT and shared-peak cruise outputs can reflect the known legacy detector issues.
All returned fuel-unit QC records infer kg/h at high confidence, but inference is
not a producer unit declaration. Nineteen other screens have zero findings,
including backward emitted timestamps, decreasing cumulative quantities, negative
phase quantities, inconsistent zero-time quantities, overlapping level segments
and repeated identifiers across batches. Sparse event summaries cannot establish
raw sampling completeness or rule out every raw-data fault.

The principal additional trajectory lead is **frozen nonzero position**. Of the
588 long zero-distance cases, 587 have all emitted event positions on a zero
coordinate; one has nonzero position evidence elsewhere in the flight. Its raw
QAR is absent from the supplied source inventory, so a phase-specific freeze is
not confirmed. Candidate.3 also reproducibly accepts a synthetic finite nonzero
position stream that stops updating while independent recorded groundspeed
continues to indicate flight. Candidate.4 flags a joint position held more than
15 seconds during source airborne phases with GS, or IAS when GS is absent,
above 80 kt. It withholds unsupported distance and preserves supported fuel/time;
stationary ground samples do not trigger the rule. No long freeze is smoothed.

Six older inputs receive that secondary flag, all already excluded. Individual
review identifies one locally clock-supported nonzero freeze with independent
airborne groundspeed evidence; five have unresolved airborne timing, so the freeze
flag does not establish an independent source-data diagnosis for those five.
The seven large fuel-cleaning changes and ten extreme vertical-rate cases remain
restricted source-review leads; the batch summaries do not justify an additional
repair or exclusion rule. Request their raw channels before attributing a cause.

All 233 inputs passed integration validation without runtime errors. Seventy-seven
synthetic checks cover reference semantics, fully populated and unreached anchor
families, repeated/level-associated crossings, fractional fuel accounting, partial
coverage, nonzero freezes and the earlier repair safeguards. Operational event
timestamps and quantities, whole-airborne totals and physical repair results are
unchanged from candidate.3. Maximum finer-partition discrepancies are below
`3.9e-10 kg`, `9.6e-12 NM` and `1.2e-13 min`.

The exact source ZIP passed a seven-input standalone run and matches the direct
API on all 58 QC fields and twelve output tables. Parquet timestamps match within
1.1 microseconds; other nonempty values match at the test tolerance. Empty
per-input tables remain empty when combined into batch schemas. A further packaged
run with declared synthetic fuel units confirms complete ARP/pressure output and
eligibility. Ambiguous automatic fuel-unit inference correctly retains a hold.

All 85 protected-file hashes and all 1,805 earlier evidence-file hashes match.
The original bundle and candidates.1/.2/.3 are unchanged. Flight-level findings,
source files, exact reference/review manifests and diagnostic artifacts are only in
`.fuelburn-data-store/derived/chn/helper-v2/CHN-v2-2026-10-18-006/`.
Adjacent public CSVs contain aggregates only. Nothing was uploaded to GitHub or R2.

Package: `outputs/CHN-fuel-burn-helper-2.0.0-candidate.4.zip`.
SHA256: `f4ea21aa5fd26074b72cac8b1cbcc2f60ed36943a5d58cd263c67bfb9a981d56`.
The seven ZIP members are source, documentation, version, an empty ARP-reference
template and checksums. No raw data, per-flight references or repair approvals are
bundled. See `helpers/chn-qar-v2/README.md` for the output contract and CAUC usage.
