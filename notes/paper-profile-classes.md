# Common interruption classes and native-point support

27 October 2026. Analysis-only extension of the regional-profile/fuel-reference
study. The user now treats `paper.qmd` as an expanding technical note with no page
limit. Keep the existing pressure-window, terminal, enroute, TOC/TOD and ground
analyses; later conference selection must not determine what is investigated.

## Working definitions

The definition file is `config/paper-profile-classes-2026-10-27.json`.
Rules are fixed independently of regional quantiles and fuel outcomes. They are
working research definitions, not validated regulatory CCO/CDO classifications.

For the primary two-minute feature scale:

1. A qualifying episode is consecutive motion with absolute altitude-time slope
   at most 300 ft/min, lasting at least 120 seconds **inside the selected window**.
   At least two original native intervals must support it. No extra altitude-span
   restriction is asserted: this is a sustained low-rate descriptor, not proof
   of exactly constant altitude.
2. Complete native bracketing of the whole window is required. Every original
   overlapping interval must be at most 60 seconds, with finite endpoint altitude.
   Only clip/interpolate original intervals at window edges. Interpolated
   milestones do not count as additional observed samples, and long native gaps
   cannot be subdivided into apparently observed shorter intervals.
   An explicit negative source local-altitude support flag is retained as an
   additional gate. A previously unassessed (NA) flag in a terminal view is not
   a source failure; the new native-coverage test assesses that descriptor directly.
3. **Continuous at the stated scale:** no qualifying episode in a classifiable
   window. Shorter level-offs may still exist.
4. **Lightly interrupted:** 1--2 qualifying episodes, combined level share <=20%,
   and longest episode <=180 seconds. All limits must hold.
5. **Heavily interrupted:** count >=3 **or** share >20% **or** longest >180 seconds.
   These cut points express operational exposure, not an assumed fuel ranking.
6. **Unknown:** unsupported/unaligned time, incomplete altitude bracketing,
   an excessive native gap, a window shorter than the feature scale, or material
   vertical reversal. Reverse progress is summed only over intervals faster than
   300 ft/min in the opposite direction; >300 ft remains outside this taxonomy.
   In the coarse sensitivity, a qualifying low-rate run with too few native
   intervals is also unknown rather than a false zero-interruption observation.

Threshold equality is inclusive for light. Retain raw total seconds, share,
episode count, longest episode, altitude and edge-censoring counts. Unknown
descriptors are missing, not zero. Episode counts describe episodes intersecting
the window that themselves meet its in-window duration threshold. They do not
establish the number or full duration of interruptions outside the window.

The 300 ft/min lineage is documented in
[EUROCONTROL's vertical profile methodology](https://ansperformance.eu/methodology/cd-vertical-flight-efficiency-pi/).
The [2020 network fuel-inefficiency study](https://www.eurocontrol.int/sites/default/files/2020-12/eurocontrol-european-atm-network-fuel-inefficiency-study.pdf)
describes a shorter 20-second convention. The two-minute scale and 20%/2/180-second
class limits are this study's proposals, not numbers attributed to either source.
The existing TOC/TOD level-envelope settings are a separate algorithm.

## Feature and class sensitivities

- 20 s minimum episode / 10 s maximum native gap: short-feature sensitivity.
- 60 s / 30 s: one-minute feature sensitivity.
- 120 s / 60 s: primary sustained-feature proposal.
- 120 s / 30 s: stricter coverage at the primary feature scale.
- 120 s / 120 s: deliberately coarser reconstruction sensitivity. It does not
  supply equivalent evidence that a two-minute interruption was observed.

At fixed primary coverage, vary the light share limit to 10/20/30%, maximum count
to 1/2/3, and longest episode to 120/180/240 s, one at a time. Do not choose the
setting that maximises paired cells or produces a preferred fuel/regional result.
Raw physical descriptors allow alternative class boundaries without rewriting
canonical data or detecting episodes again.

## Why native coverage and source segments are separate

CHN `CHN-supported-data-points` contains observed event-bracket and coverage-edge
points, including event-selected level endpoints. It is **not** a dense QAR
trajectory. `PROFILE_OK` in the marginal window view established local altitude
support/QC, not delivery of all source samples at that cadence. Treating its
source <=30 s QC condition as the observed spacing of these returned knots would
overstate common detector support.

EUR M3 is also an irregular altitude-time representation. Both inputs are
deduplicated at native timestamps; conflicting duplicate altitudes or invalid
altitudes remain unknown and are not silently median-repaired. Native gaps retain
their original length even if only part overlaps a window. No dense CHN trace is
regenerated, and no decoder or quality/coverage improvement is attempted.

Separately count flights having a source level episode with at least 120 seconds
inside the window and a source endpoint-average absolute rate <=300 ft/min.
These are **positive source-segment evidence counts**, not class assignments.
CHN's 31-sample median detector and EUR's source CCO/CDO segment inventory are not
made equivalent by filtering endpoints and duration. A missing tag does not prove
continuous flight; a long source segment cannot fill an unobserved native gap in
the common reconstruction.

Long flat spans in irregular EUR M3 can also fail a short-gap requirement. This
is an observation-mechanism issue in both sources; a common algorithm alone does
not make its selected classifiable cohorts representative or exchangeable.

Importantly, event-selected CHN knots can retain the ends of a long interruption
while omitting its interior samples. A complete short-gap filter may therefore
select against interrupted profiles. Report that selection and do not interpret
the common-classifiable subset as representative regional prevalence. Source
positive evidence helps expose this effect without fabricating common coverage.

## Eligibility and references

Assess all four directional pressure windows, both departure and arrival terminal
alternatives, and source macro climb/descent separately. No all-phases
intersection is imposed. Unknown class does not invalidate independently supported
fuel/time or distance references.

Count independent flights in exact type x 100-NM airport-GCD band x window x
class x region. The existing n>=30-per-region rule is retained for a populated
paired class reference. Sparse and zero-support slots remain explicit. Unknown
is exported for diagnostic fuel references but never treated as a comparable
operational class. Engine identity remains unstratified where unavailable.

Class-conditioned P20/P50/P80 are calculated only after classification, using
independent metric eligibility and individual-flight rates. Total fuel remains
alongside duration, kg/min and supported kg/NM. No fuel threshold, source fuel
rank, regional class quantile, causal saving or attainable optimum defines a class.

## Reproduction and immutability

From the project root, with the existing adopted marginal reference view built:

```sh
Rscript tests/paper-profile-classes.R
Rscript scripts/18-characterise-paper-interruptions.R
Rscript tests/paper-profile-class-adoption.R
Rscript scripts/19-explore-climb-fuel-patterns.R
Rscript scripts/17-export-paper-reference-snapshot.R
quarto render paper.qmd --to pdf
quarto render paper.qmd --to docx
python3 scripts/format-paper-docx.py _output/paper.docx
quarto render paper.qmd --to html
```

The source code, definitions, aggregate tables and manifests belong in Git.
Flight/window ledgers and the native-interval cache remain under
`FUELBURN_DATA_STORE/derived/paper/profile-classes/PAPER-PROFILE-CLASSES-2026-10-27-001/`.
The cache is a derived analysis convenience, keyed by source hashes and the
versioned native-interval preparation rule. It is not a replacement canonical
trajectory.

The aggregate snapshot is
`notes/results/paper-profile-classes-2026-10-27/`. Its input manifest extends the
110 already pinned inputs with fourteen CHN supported-point products and fourteen
run manifests (138 files). Hashes are verified after analysis and again on loading
for a render. Canonical releases, source detectors, existing eligibility views,
pressure milestones and fuel values are never overwritten.

The technical note now presents the threshold rules, support and evidence tables,
feature/resolution plot and study-aspect inventory. Introduction/background and
conclusion remain mainly development breadcrumbs, as requested. The two-column
PDF and single-column Word commenting copy use the same QMD source; their length
is allowed to grow with the study.

## Verification of the interruption-class export

The page/figure counts below describe the preceding interruption-class export.
The subsequent [climb-pattern extension](results/paper-climb-patterns-2026-10-27/README.md)
adds substantive fuel/time, route-direction and source-level results to the
technical note; its verification record supersedes these document counts.

- Common-rule unit checks and the adopted-view integration checks pass, including
  class-boundary equality, no gap splitting, missing altitude, short windows,
  reversals, source support gates, independent fuel eligibility and unknown
  accounting. The existing window, enroute and lookup checks also pass.
- All 138 adopted input hashes remain unchanged. The independently supported
  marginal-reference cohorts and the existing take-off-roll convention are retained.
- The technical note renders to a 16-page two-column PDF and a 37-page
  single-column Word review copy, with 23 figures and 22 editable data tables.
  Every rendered page was visually reviewed. Figure/caption rows stay together
  in Word, and the PDF does not duplicate automatically generated table captions.
- The HTML export is generated from the same final source. Detailed ledgers
  remain restricted; the aggregate snapshots contain no flight identifier columns.
