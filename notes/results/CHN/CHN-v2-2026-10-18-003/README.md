# Older CHN reference-file rejection investigation

The 142/220 rejection count overstated the evidence against the reference inputs.
Two reproducible helper defects account for 56 avoidable exclusions. Candidate
`2.0.0-candidate.2` includes 134 files and holds 86 for investigation, compared with
78 included and 142 held in candidate.1. All 78 previously included files remain
included. This is a file-level diagnostic comparison, not an adopted study release.

The 220 exports represent 121 flight identifiers, with overlapping versions.
There are now 63 identifiers with at least one included export (previously 46),
and 58 with none. File counts must not be presented as independent flight counts.
The evaluation does not select between overlapping exports or create a merged cohort.

## Reproducible defects corrected

| Finding | Older files affected | Evidence and correction |
|---|---:|---|
| False clock ambiguity from duplicate-expanded exports | 37 | Repetition diluted the auxiliary clock's defects. On distinct physical observations, the progressing clock scores 1.000 in every case; the auxiliary clock scores 0.248–0.270. Some exports expand observations about 197-fold. Score distinct observations, while retaining genuine ambiguity/backward-time checks. |
| Short ground shutdown spike became an artificial unresolved fuel gap | 37 | Required source flows are finite and nonnegative. The spike heuristic blanks a candidate value, then the fourfold endpoint-ratio rule rejects its bracket because an observed engine endpoint is zero. All 40 affected rows lie outside the supported airborne window; all brackets are 2 seconds. Permit this bounded transition only with ground evidence at both endpoints and no contradictory available GS. |
| Cascaded profile-boundary diagnosis | 42 flags removed | A clock failure was also reported as missing profile boundaries even when the ordered observations existed. Report the actual gate separately in `BOUNDARY_FAILURE_CAUSE`; the phase eligibility gate itself remains strict. |

These findings overlap. Of the 56 additional included files, 29 had only the clock
defect, 22 only the shutdown defect, and five had both. Other affected files still
have separate reasons for review. No clock offset, subsecond timestamp, absent
engine channel, or unsupported endpoint is invented.

## What the remaining 86 holds mean

The following categories are mutually exclusive, assigned in the order shown.
The detailed restricted ledger retains all overlapping causes.

| Review category | Files | Interpretation |
|---|---:|---|
| Required fuel channels absent | 28 | Genuine source-content gap: neither required engine flow channel is supplied. Fuel quantity cannot be reconstructed from these exports. No alternative fuel-bearing export with the same identifier was found in this reference inventory. This does not establish that the original recording lacks those channels. |
| Clock or sampling issues | 6 | Single-clock exports contain backward/conflicting repeated timestamps or recording gaps. No alternate credible clock exists in these files. Leave unresolved rather than inventing a time axis. These files also have motion issues. |
| Airborne position repair bracket | 8 | The default 5-second bracket is insufficient for these held channels. An 8-second sensitivity run clears their airborne position defects; three then pass fully, five retain unsupported ground endpoints. These are repair-limit/configuration reviews, not demonstrated unhealable airborne gaps. |
| Ground-only position coverage | 22 | Unresolved coordinates lie outside the supported ATOT–ALDT window. All 22 retain ordered profiles and fuel/time eligibility. Full-record distance validity currently excludes them from the common cohort; that is broader than the airborne study requirement. |
| 1% repair-share cap | 22 | All other checks pass when only this cap is lifted. Eleven fuel cases represent four identifiers; eleven position cases represent five identifiers. This is a policy gate, not an unresolved interpolation gap. |

Thus 52 of the remaining 86 holds arise from acceptance limits or analysis scope;
34 have missing source channels or timing defects. The 86 must not be called
“bad flights.” Categories are about the supplied export and supported quantities.
Across all files, 23 have ground-only unresolved positions; one is assigned to the
clock category above. The eight airborne-position cases add another five with
ground-only residuals after the longer-bracket sensitivity.

The repair-cap cases warrant individual review. Fuel repairs affect 1.26–2.35%
of rows, all outside the airborne window, and reduce full-record source fuel
totals by 3.14–6.04%. Position repairs affect 1.02–1.41% of rows and reduce
artefact-inflated path totals by 53.4–58.8%. Each local repair passes the elapsed-time
and physical bridge checks, but the large effect on totals is a reason to inspect
the corrections rather than simply raising the percentage threshold.

The position sensitivity changes `max_gap_sec` for diagnosis only. Its 8-second
and 10-second results are identical for these eight files: three fully included,
five with three unsupported ground rows each. Recorded longitude updates have a
dominant 4-second cadence in each file, so a single bad native update can require
an 8-second bracket. A future cadence-aware position rule should retain the speed
and bracket-support tests and should not widen fuel or altitude repair limits.

## Acceptance recommendation

Keep a broad anomaly/repair ledger, and define exclusions by unsupported study
quantities within the relevant analysis window. A ground endpoint defect should
not automatically exclude supported airborne fuel/time data. Likewise, a healed
anomaly should remain visible without being described as missing data.

Retain a common problem/exclusion list for unresolved **study-scope** problems,
with the wider diagnostic ledger recording repaired and out-of-scope anomalies.
Before adopting a cohort, explicitly implement and validate airborne-window
eligibility, position-cadence handling, and a review decision for each repair-cap
case. Candidate.2 still uses the existing 5-second and 1% defaults and full-record
common-cohort gate. The sensitivity settings have not been adopted as defaults.

## Validation and evidence

- All 233 inputs were re-evaluated: 220 older references, ten verification flights,
  and three modern representative controls. No runtime failures occurred.
- Verification outcomes remain two included/eight held; modern controls remain
  one included/two held. All ten source-supported verification landings survive.
- Forty synthetic checks pass, including replicated-clock false ties, genuine
  clock ambiguity, source-ground shutdown repair, and rejection of a contradictory
  high-speed “ground” transition. Integration and phase-accounting errors are below
  `1e-6 kg`; invalid distances remain missing. Problem/exclusion CSVs match bytewise.
- The exact packaged candidate passes a four-input standalone check covering both
  new fixes and two included verification cases. Its ZIP contains source only.
- All 85 protected EUR/CHN pipeline/release files remain byte-identical. All 400
  files in the previous candidate evidence manifest and all 441 original
  verification-evidence files remain byte-identical.
- Input hashes were checked before each integration evaluation. Flight-level
  traces, repair logs, counterfactuals, manifests, and frozen candidate.1/.2 sources
  are restricted to `.fuelburn-data-store/derived/chn/helper-v2/CHN-v2-2026-10-18-003/`.
  No raw or flight-level artifacts were sent to GitHub or R2.

The source-only ZIP is `outputs/CHN-fuel-burn-helper-2.0.0-candidate.2.zip`, SHA256
`8e8a756dcbefe9eb7b7ee7570f92cd84c933a5040a1700c5f51c04d2719b3565`.
The distributed legacy helper, candidate.1 ZIP, EUR data and existing canonical
releases remain unchanged. This report and its adjacent CSVs contain aggregates only.

Diagnostic entry points: `scripts/diagnose-chn-reference-flags.R`,
`scripts/validate-chn-qar-v2.R`, `scripts/summarize-chn-reference-triage.R`, and
`scripts/probe-chn-reference-policy.R`. Candidate behavior and assumptions are
documented in `helpers/chn-qar-v2/README.md`.
