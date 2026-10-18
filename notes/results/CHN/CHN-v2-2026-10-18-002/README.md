# CHN helper v2 candidate — 18 October 2026

The next helper is implemented as **2.0.0-candidate.1**, separately from the
distributed helper and shared EUR code. Its source is in `helpers/chn-qar-v2/`;
the source-only deliverable is
`outputs/CHN-fuel-burn-helper-2.0.0-candidate.1.zip`.

The recommended approach is implemented: keep problematic inputs and their raw
diagnostics, repair only supported short anomalies, and make unresolved problem
flights exactly the common-study exclusion set. Do not silently filter before
producing diagnostics. Repaired findings remain in the audit ledger but do not
automatically exclude a flight once every required domain passes.

## What changed

- Cumulative fuel/distance now represent the sample timestamp, fixing the
  outgoing-increment boundary error in phases and levels.
- Clock selection evaluates candidate clocks and permits an explicit column
  contract. Only plausible midnight transitions roll the date; small backward
  steps, conflicting duplicate timestamps, and ambiguous clocks stay unresolved.
  Identical observations can be deduplicated with evidence.
- Multiplexed/held position channels are aligned before motion screening.
  Unsupported boundary frames can be cropped within the configured short limit;
  coordinates are not extrapolated. This is distinct from declaring a well-formed
  sampled QAR file intrinsically bad.
- Interior coordinate/altitude/engine-flow gaps and spikes can be interpolated
  only within a five-second bounding interval, with motion/rate checks and a
  one-percent anomaly repair budget. Entire empty channels, long gaps, persistent
  discontinuities, and unsupported endpoint excursions remain unresolved.
- Source-supported landing events no longer depend on valid position/distance or
  an absolute 3,000-ft altitude gate. LTO boundaries use observed field-pressure
  references; pressure-altitude flight-level anchors retain their original datum.
- Unsupported TOC/TOD remain absent instead of becoming a fictitious zero-length
  cruise. Unknown level context is explicit; filtered-out level candidates return
  typed empty tables rather than crashing.
- Airport coverage is checked and an explicit profile fallback is recorded when
  metadata is absent. Configuration can instead require complete airport metadata.
- Missing engines are not summed as zero. Unknown canonical quantities are
  missing, while diagnostic totals, source excursions, repairs, and plots remain
  available. Unit plausibility alone does not clear other quality flags.

The package README documents the complete default policy, phase-code contract,
sampling/integration assumptions, output fields, and configuration overrides.
These thresholds are candidate parameters, not an asserted universal QAR standard.

## Validation

| Input group | Files processed | Included under candidate common-cohort policy | Investigation / exclusions |
|---|---:|---:|---:|
| Requested verification cases | 10 | 2 | 8 |
| Modern representative controls | 3 | 1 | 2 |
| Older reference CSVs | 220 | 78 | 142 |
| Total | 233 | 81 | 152 |

These are **file-level evaluations**, not a newly adopted study sample. The 220
older files represent 121 distinct source identifiers, with overlapping exports
across archives. They were evaluated independently; a combined helper input batch
also applies the documented duplicate-identity exclusion. The older
files remain the accepted source-format baseline. Conservative study eligibility
is a different question: 28 older tables lack fuel-flow channels; among the 192
fuel-bearing files, 78 meet this full candidate contract and 114 retain unresolved
requirements. Flags include clock ambiguity, unsupported channel/gap coverage,
repair limits, and profile boundaries; they are not evidence that every flagged
recording is intrinsically wrong. Detailed reasons stay with each restricted input.

All 192 fuel-bearing older files still infer kg/h with high confidence. The 28
no-flow files have unknown unit confidence and are separately identifiable by
`missing_engine_flow_column`. All ten verification flights now retain their
source-supported landing event. Two qualify after bounded repairs/helper fixes;
eight retain unresolved evidence and are listed for investigation. No entirely
missing altitude or all-zero position stream was reconstructed.

Validation includes:

- **33 analytic synthetic checks** covering known fuel totals, timestamp/phase
  conservation, high-elevation arrivals, missing altitude/engines, short versus
  long and endpoint gaps, multiplexed coordinates, clocks, and empty level sets.
- **233-file integration evaluation**, with no unhandled file-processing failures;
  phase/fuel accounting and invalid-distance masking checks passed.
- **Standalone ZIP entry-point execution** against all ten verification files from
  outside the repository, exercising the exact handoff layout and dependencies.
  Restricted plots were visually inspected; unavailable channels are labelled.
- A small batch contract check with duplicate exports and an unreadable input:
  inputs remain accounted for, duplicate identities are excluded, and problem /
  exclusion CSVs are identical.
- Sensitivity to 0-, 2-, and 5-second interpolation brackets for the ten cases and
  three modern controls. The verification inclusion count is 0, 2, and 2
  respectively. This parameter also governs sampled-channel alignment/edge
  coverage; it is not a pure isolated-spike experiment. See `repair-sensitivity.csv`.

Only plotting of unavailable channels changed after the broad integration run;
the final ZIP was rerun on the ten verification cases. The restricted provenance
records the bulk-tested analytical source separately from the final plotted package.

## Problem list and exclusion list

`PROBLEM_FLIGHT == STUDY_EXCLUDE` is enforced. The standalone helper writes the
same quality-table subset to `CHN-problem-flights.csv` and
`CHN-study-exclusions.csv`, then verifies byte equality. Runtime/read failures and
duplicate flight identifiers also enter those lists; neither disappears silently.

The full issue ledger intentionally includes resolved repairs and information,
so it is not itself the exclusion list. Domain flags distinguish time, fuel,
distance, profile, and derived boundaries. A future partial-domain analysis can
define a different cohort explicitly; the current common-study cohort excludes
every unresolved finding.

This preserves visible “wild artefacts” in diagnostic products without making them
apparently valid analytical distances or silently assigning zero to unknown fuel.
The raw sources remain unchanged and every interpolation/alignment is traceable.

## Delivery and retained evidence

- Generic helper code, synthetic tests, package builder, and identifier-free
  aggregate validation evidence are suitable for the project repository.
- All flight identifiers, candidate canonical files, source copies, problems /
  exclusions, repair logs, diagnostic plots, and input manifests remain under
  `.fuelburn-data-store/derived/chn/helper-v2/CHN-v2-2026-10-18-002/` (with source
  archive copies in the preceding preparation run referenced by its input manifest).
- `verification-case-review.csv` maps the ten original requests to candidate
  findings. `evaluation/` contains the broad comparisons and per-input repair logs.
  `packaged-final-qa/` contains the final distributed entry-point run.
- The restricted manifest records input/code/output hashes, environment, checks,
  and the exact archive checksum. No restricted evidence belongs in GitHub.

EUR and all existing canonical releases remain byte-for-byte unchanged; the old
helper/bundle and the earlier verification evidence are also preserved. No R2
objects, production registries, or authoritative manifests were updated. This
candidate is ready for review and controlled CAUC use; it has not been adopted as
the paper's canonical CHN release.
