# CHN helper candidate.6: isolated warning correction

Candidate.6 declares typed `BRACKET_FROM_ROW` and `BRACKET_TO_ROW` columns in the
empty crossing-candidate table. This prevents the three uninitialised-column
warnings reproduced on a ground-only verification input. No repair, threshold,
clock, fuel, coordinate, TOC/TOD, airport lookup or eligibility logic changes.
Only the helper version, empty-table schema, package documentation and checksums
differ in the ZIP; the CLI, legacy core and public airport metadata are unchanged.

## Validation

- All **101 synthetic checks pass**, including four checks for a ground-only
  no-crossing record: no warnings, an empty crossing table, typed bracket columns,
  and retained full-record fuel/time without invented airborne eligibility.
- All **243 input-file tests** pass paired candidate.5/candidate.6 evaluation:
  220 older reference exports, three modern controls, the original ten verification
  files, and all ten additional selections. Exact input hashes are verified.
  Repeated historical exports remain separate tests, not independent study flights.
- All **19 exact-input private approvals** also pass paired evaluation under
  matching version-specific manifests. Previously reviewed analytical quantities
  and inclusion decisions are unchanged. A new restricted candidate.6 manifest
  carries those exact decisions; earlier manifests are untouched, and none is
  bundled. Candidate.5 approvals are rejected under candidate.6 as intended.
- Across default and reviewed runs, **4,454 per-input table comparisons** have
  identical analytical values, with no numeric tolerance required. Version labels
  and the declared empty bracket columns are the documented differences. Engine
  fuel, physical repairs, milestones, phase allocations and eligibility are stable
  when the review configuration is matched. Airborne/fine-partition fuel accounting
  checks pass within 0.000001 kg where supported.
- Candidate.5 emits the three known bracket warnings; candidate.6 emits **zero R
  warnings** across the paired evaluations. No input processing failures occur.
- The exact eight-member ZIP passes a separate 20-file standalone CLI run, with
  no R warnings and the same **12 included / 8 held** under default settings.
  All **17 packaged table families / 509 fields** match Lingling's candidate.5
  Parquet results after normalising input IDs/order and version labels, within the
  2-microsecond/0.000002 comparison tolerance. Maximum observed delta is
  0.954 microseconds in timestamps. CSV problem/exclusion lists remain byte-identical.
  All 49 packaged-run checksum entries and the package's member checksums verify.
  Plot selection can differ with input ordering; plots remain restricted.

## Default settings versus private reviews

| Input group | Files | Default included | Default held | Whole-airborne fuel/time |
|---|---:|---:|---:|---:|
| Older reference exports | 220 | 169 | 51 | 187 |
| Modern controls | 3 | 3 | 0 | 3 |
| Original verification | 10 | 6 | 4 | 10 |
| Additional verification | 10 | 6 | 4 | 9 |

These stock-run counts deliberately omit private review approvals. The older
reviewed result of 186 included / 34 held is unchanged under matched approvals;
the default 169 / 51 is not a regression. Reviewing a position-share hold can
release distance support and therefore airport-context milestone selection, as
recorded in the restricted review. Comparing default and reviewed configurations
would conflate that effect with this warning fix. The tests here compare like
with like. Lingling should use default settings, retain all flagged records and
return complete outputs for subsequent analysis review.

## Handoff and preservation

Package: `outputs/CHN-fuel-burn-helper-2.0.0-candidate.6.zip`.
SHA256: `0eb34da219f0d8dc4ae7ca2b79cc53a231d24533cb62611000b44909f2434ded`.
Rebuild: `python3 scripts/build-chn-qar-helper-v2.py`.
Synthetic checks: `Rscript tests/chn-qar-v2-regression.R`.
Paired validation: `Rscript scripts/validate-chn-candidate6.R <restricted run>`.

A short email requests processing of all fourteen original batches into separate
new output directories, preserving batch labels and all flagged flights. It asks
for full result folders and console logs via the restricted sharing channel,
excluding extracted raw-input folders. The user confirmed the email was sent on
22 October 2026; correspondence remains restricted. Full-batch processing is
expected over the next days. Once results arrive, inventory and verify the returned
inputs/configuration, then resume eligibility, candidate selection and individual
review. The full-batch outputs have not yet been received or adopted.

Restricted evidence:
`.fuelburn-data-store/derived/chn/helper-v2/CHN-v2-2026-10-22-003/`.
It includes exact source snapshots, input hashes, per-input paired comparisons,
warning logs, private reviews, accounting checks, standalone outputs and runtime
information. Source QAR, trajectories, flight identifiers and correspondence
remain outside Git. Adjacent CSVs contain aggregate evidence only.

All 90 protected baseline hashes match (the existing 85-file protection set plus
candidate.5 ZIP, CLI, legacy core and both airport metadata files). All 531 earlier
frozen evidence files across the prior final validation, returned-run audit and
individual review are unchanged. EUR and existing CHN canonical releases were not
regenerated or modified. Candidate.5 is preserved. No flight-level data are
uploaded to GitHub or R2 as part of this handoff.
