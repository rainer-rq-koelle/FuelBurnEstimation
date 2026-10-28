# Airborne-window eligibility and bounded position repair

Candidate `2.0.0-candidate.3` implements study eligibility within the observed
ATOT–ALDT window, cadence-aware position reconstruction, and position bridges up
to 15 seconds. Ground recording problems remain visible without automatically
excluding supported airborne quantities. Fuel and altitude interpolation retain
their five-second limits. This is a tested candidate, not an adopted canonical
release or an aviation-wide interpolation standard.

## Results

| Input set | Candidate.2 included / held | Candidate.3 included / held |
|---|---:|---:|
| Older reference exports | 134 / 86 | **186 / 34** |
| Modern representative controls | 1 / 2 | **3 / 0** |
| Verification flights | 2 / 8 | **7 / 3** |

All 137 previously included inputs remain included. The older reference result
is 186/192 (96.9%) among exports that contain the required fuel channels; another
28 exports omit those channels. These are file-level results. The 220 older
exports represent 121 identifiers, of which 88 now have an included export;
the validation does not merge or select between overlapping exports.

The remaining 34 older holds comprise 28 missing-fuel-channel exports, five
clock/sampling cases, and one unresolved position/profile case. The three
remaining verification holds comprise two unsupported position streams and one
unsupported altitude/profile stream. They remain in the restricted further-
investigation list and output diagnostics. No unsupported stream is manufactured.

Useful partial data are retained independently of the common cohort. All ten
verification flights support whole-airborne fuel/time; nine support the primary
profile-based fuel/time outcome. Seven support the joint fuel/time/distance
cohort. Three modern controls and 187 older exports support whole-airborne
fuel/time. These domain flags do not silently override the declared common cohort.

## What changed

- Primary eligibility requires supported ATOT–TOC–TOD–ALDT and the airborne time,
  fuel, position and altitude/profile domains. Ancillary DLTO/ALTO availability is
  separate. Ground altitude/position defects do not alone fail this primary window.
- Recorded ground rows and timestamps are retained after exact-observation
  deduplication. Coordinate coverage no longer crops record edges. Ground phase
  timing/fuel eligibility is separate from distance eligibility. AOBT/AIBT remain
  legacy record-edge proxies, not independently observed block events.
- Position channels are aligned to their demonstrated sparse/held update cadence.
  Irregular repair is recorded separately from regular sampling reconstruction.
  Brackets must have plausible bounding samples and span at most 15 seconds.
- Physical checks remain: 750 kt gross airborne-motion limit, consistency with
  available groundspeed, and 120 kt for source-confirmed ground intervals. Airborne
  bridges longer than five seconds also need neighbouring directional support
  within 45 degrees. Long gaps, unsupported endpoints and persistent jumps stay
  unresolved. Linear ground-distance estimates may cut taxi turns; valid ground
  timing does not depend on trusting that geometric estimate.
- Missing ground prefixes cannot poison otherwise supported airborne cumulative
  quantities. Partial cumulative values are zero at ATOT and exist only through
  ALDT, with explicit reference metadata; unknown ground quantities remain missing.
  Fully supported records retain their record-start reference. Separate ATOT-zero
  airborne quantities and the physical three-phase partition are always provided.
- The legacy ZPPP lookup coordinate could not be verified for Changshui and is
  withheld in this candidate. An explicit airborne-profile fallback is used; no
  guessed replacement coordinate or source-data correction is installed. Existing
  helper versions and releases retain their original metadata unchanged.

Different recorder channels can have different sampling intervals; for example,
the FAA recorder specification distinguishes position and groundspeed rates.
That supports checking observed cadence, but does **not** prescribe a 15-second
repair limit. The limit here is an empirical study setting.
[FAA Appendix M](https://www.ecfr.gov/current/title-14/chapter-I/subchapter-G/part-121/appendix-Appendix%20M%20to%20Part%20121)

## Does 15 seconds help?

The comparison below changes only the position ceiling, under the same new window
rules and recorded input-specific review decisions. Fuel/altitude limits remain
five seconds throughout.

| Targeted test set | Included at 5 s | Included at 8 s | Included at 15 s |
|---|---:|---:|---:|
| Eight earlier reference bracket-review files | 0 | 8 | 8 |
| Three modern controls | 1 | 2 | 3 |
| Ten verification flights | 5 | 6 | 7 |

Thus 15 seconds adds useful recovery beyond eight seconds for the controls and
verification set; it does not waive the remaining unsupported position/altitude
streams. Seconds refer to the distance between bounding timestamps: a 15-second
bracket on a one-second series contains at most fourteen interior missing samples.

## Individual repair-share review

The 1% airborne repair-share review threshold is retained. The original 22 cases
were reviewed individually: eleven have fuel repairs wholly outside the airborne
window, and eleven have supported short position-return repairs. The latter all
have at most three-second brackets and consistent neighbouring directions.
Their full-record fuel/position findings remain in the ledger.

Six additional older exports exceeded 1% when exposure was measured within the
airborne window rather than diluted by ground time. They were reviewed by the same
short-return criteria. A further verification share hold received a separate
review including independent recorded-groundspeed integration. No general increase
of the 1% threshold was needed.

Eighteen position-share approvals are recorded in a **restricted** manifest,
matched to exact input SHA256, helper version, domain and reviewed share. They
release only that hold; they cannot release missing samples, ambiguous timing,
unsupported profiles or physically failed bridges. The higher repair exposures
remain explicit for sensitivity analysis. The eleven ground-fuel cases qualify
for the airborne study without releasing their full-record ground-fuel holds.

The reported cohort includes these recorded reviews. The source-only package
contains no flight identities or private approval records. Without a matching
private review manifest it retains the above-threshold holds; a new flight or
changed export cannot inherit an old approval.

## Validation and preservation

All 233 inputs were retested against the final candidate: 220 older exports, ten
verification flights and three modern controls. There were no runtime failures.
Fifty-eight synthetic checks cover 15/16-second boundaries, turn rejection,
ground timing preservation, partial cumulative references, cadence alignment,
stale/mismatched review rejection and protection against waiving another domain.

Fuel and distance reconcile within their physical airborne partitions: maximum
fuel error is below `1.1e-9 kg`, distance error below `3e-12 NM`. Previously
included whole-airborne fuel changes are below `1.2e-10 kg`; paired ATOT/ALDT
timestamps are unchanged. The largest distance change among previously included
older exports is 0.090 NM, from revised sampling reconstruction.

The exact ZIP passed a six-input standalone run, including approvals, ground-only
defects and an unresolved stream. Its results match the API on all 51 common QC
fields and on the physical airborne tables. All 29 individual review records and
1,116 position-bridge records reproduced exactly in a frozen diagnostic rerun.
Problem and exclusion CSVs are byte-identical. Sensitive evidence is retained only
in `.fuelburn-data-store/derived/chn/helper-v2/CHN-v2-2026-10-18-005/`; the first
window/cap diagnostic run is preserved separately as `CHN-v2-2026-10-18-004`.

EUR and existing canonical releases remain unchanged. Protected-file and prior-
evidence checksums are recorded in the restricted validation manifest. No raw or
flight-level data were sent to GitHub or R2. This report and adjacent CSVs contain
aggregate evidence only. Any later cohort adoption remains a separate decision.

Source ZIP: `outputs/CHN-fuel-burn-helper-2.0.0-candidate.3.zip`.
SHA256: `b8239c9e610f5661a273e7cb156df016a324691dd17e948d7adf88dbc3a01e10`.

Implementation assumptions and output semantics are documented in
`helpers/chn-qar-v2/README.md`. The restricted run records the effective settings,
input hashes, exact source, environment, review manifest and evidence checksums.
