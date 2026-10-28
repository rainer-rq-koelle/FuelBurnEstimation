# CHN–EUR paper eligibility and comparability mapping

27 October 2026. This read-only assessment supports the paper stream, not further
QAR decoder development. **The data support finer climb/descent reference values;
the paper need not be restricted to whole-airborne fuel/time.** No input release,
helper or manuscript was changed or adopted by this assessment.

## Scientific target and source versions

The current concept in `paper.qmd`, `notes/paper-development.md`,
`notes/paper-lookup-table.md` and `notes/enroute-level-analysis.md` retains two
estimands: regional profile composition, and consumption conditional on comparable
aircraft/stage length/profile. It calls for source-aware phase fuel references,
pressure and airport-radius milestones, enroute altitude exposure and finer
climb/descent profile characterisation. Whole-airborne analysis is the baseline.

Counts below assess **returned CHN candidate.6 default outputs** for the same 6,421
identifiers, and **pinned EUR-2026-10-13-002** for 21,503 identifiers. They are
proposed paper-cohort support counts, not replacements for the current manuscript's
legacy-input baseline. The paper still reads the original fourteen CHN batches.
Input adoption requires an explicit analysis adapter and source/version manifest;
canonical files remain immutable.

## Eligibility follows the analysis window and metric

For CHN, local fuel/time is recovered from the supplied non-overlapping fine
interval partition. A named window requires supported ordered endpoints, complete
time coverage, eligible fuel on every constituent interval and positive fuel/time.
Its supported cumulative fuel differences agree with the local integration within
0.000002 kg. Unsupported data elsewhere in the flight need not remove the window.
Profile conditioning additionally requires local altitude support; kg/NM requires
local distance support and physical plausibility. Airport-radius windows also
retain the existing position quality/review gate. No approval was added or waived.

For EUR, fuel at enriched events is the existing time-interpolated model cumulative
fuel, not a fuel measurement from M3. Endpoint time/fuel support and positive
increments are required. All emitted cumulative fuel is monotone and unambiguous
at shared timestamps. M3 altitude profiles are converted from flight levels to
feet, checked for bracketing without extrapolation, and assessed separately for
crossing resolution and internal profile gaps. Existing source-model screening is
not raw-fuel calibration. The known EUR timing/GCD-context review case remains
outside fuel reference counts pending source review; a missing or zero enroute
phase does not automatically remove independently usable other windows.

The existing broad paper context screen (10–480 airborne minutes and endpoint-GCD
mean speed <=650 kt) is retained, not tuned to increase a count. One CHN record
has no airborne bounds. One EUR source-clock/context case needs review. Independently
supported local CHN windows can survive a gap outside their own interval.

| Fuel/time window | CHN | EUR |
|---|---:|---:|
| Whole airborne ATOT–ALDT | 6,388 | 21,502 |
| Source-window climb ATOT–TOC | 6,381 | 21,502 |
| Source-window enroute TOC–TOD | 6,360 | 21,427 |
| Source-window descent TOD–ALDT | 6,366 | 21,502 |
| Climb FL075–FL100 | 6,378 | 21,499 |
| **Climb FL100–FL180** | **6,378** | **21,476** |
| **Descent FL180–FL100** | **6,369** | **21,306** |
| Descent FL100–FL075 | 6,368 | 21,009 |
| Departure ARP040–100 | 2,911 | 21,502 |
| Arrival ARP100–040 | 2,913 | 21,502 |

These are overlapping, metric-specific supports, not independent samples to add.
Profile-plus-fuel support is 6,373 / 21,476 for climb FL100–180 and 6,369 / 21,306
for descent FL180–100, before assigning any profile class. Class-specific counts
must still be calculated. Whole-flight geometry is not required for pressure-window
fuel/time. For example, 3,517 held CHN flights support the FL100–180 fuel window;
26 flights support that local window despite unsupported whole-airborne fuel/time.
The corresponding descent numbers are 3,510 and 28. These are recoverable analysis
elements, not releases of position-review holds.

A complete positive-fuel whole/climb/enroute/descent decomposition exists for
6,352 CHN / 21,427 EUR flights. Use that intersection only for questions requiring
the complete decomposition, not as a prerequisite for every individual phase.

## Comparison support and paper cohorts

Use exact aircraft variants and independent-flight counts in each 100 NM airport
GCD band. GCD does not require a trustworthy flown track. The existing >=30-per-region
rule is a lookup/comparison support rule, not a raw-data validity rule: sparse or
unpaired data remain available for regional descriptions with their actual counts.

Eight aircraft/stage cells support the main baseline and pressure-window fuel
comparisons: A20N/600–699, A21N/500–599, A21N/600–699, A319/600–699,
A320/600–699, A321/500–599, A321/600–699 and B738/600–699 NM.

| Comparison, in the supported cells | Cells | CHN observations | EUR observations |
|---|---:|---:|---:|
| Whole-airborne fuel/time | 8 | 1,645 | 6,224 |
| Climb FL100–180 fuel/time | 8 | 1,648 | 6,223 |
| Descent FL180–100 fuel/time | 8 | 1,639 | 6,170 |
| Climb: both crossing brackets <=30 s | 8 | 1,648 | 2,458 |
| Descent: both crossing brackets <=30 s | 8 | 1,639 | 1,627 |

These totals describe support, not a licence to pool differently weighted cells.
Show regional composition first; compare or standardise within the cells before
summarising a regional contrast. The broader regional populations include valid
widebody/C919 and other unpaired observations without pretending that a matching
European type/stage comparator exists. Do not infer a specific MAX or engine
variant where the metadata do not identify one.

Recommended nested analysis views:

1. **Regional descriptive view:** retain each valid phase/quantity, with fleet,
   stage and route composition. It describes the study samples, not all regional
   traffic. No mandatory all-phases or geometry intersection.
2. **Primary matched fine-phase reference view:** make climb FL100–180 and descent
   FL180–100 central, with fuel kg, minutes and kg/min P20/P50/P80. Retain macro
   source-window references for context and FL075–100/terminal windows as extensions
   with explicit airport-elevation context. Report n for every row and metric.
3. **Profile-conditioned view:** within a supported window, add a common, resolvable
   descriptor/class. Effective net vertical rate over a fixed pressure interval is
   directly supported by endpoints/time; a class based on it must be labelled as
   such, not as CCO/CDO. Add sustained-level exposure or interruption descriptors
   where coverage and common reconstruction support them. Missing class/unknown
   coverage does not remove fuel-valid flights from the marginal baseline.
4. **Spatial/rate view:** use ARP040–100 references and flown-distance/kg-NM only
   where the needed geometry passes. Keep ARP100–200 as a resolution-labelled
   extension; short/unreached radii or missing geometry do not exclude pressure
   windows. Never use airport GCD as a phase kg/NM denominator.
5. **Sensitivity views:** compare source and common level-envelope boundaries on
   identical flights; add crossing/profile resolution and input-review sensitivities.
   Their denominators need not become the primary cohort's denominator.

This expands the usable study elements compared with the older globally filtered
pilot (six shared cells, 672 CHN / 4,207 EUR duration records and 626 CHN fuel records
per macro phase). The difference reflects revised candidate processing and window
selection, not a newly enlarged source-flight population.

## What “profile comparable” can mean

**Crossing resolution and whole-profile resolution are different.** For all EUR
flights, both endpoint brackets <=30 s support 9,128 climb FL100–180 and 5,561 descent
FL180–100 fuel references. But requiring every overlapping M3 span in the complete
window to be <=30 s leaves only 2,137 climb / 263 descent profile-plus-fuel records,
with six / zero paired cells under the support rule. A blanket 30-second whole-profile
filter would therefore defeat the intended descent comparison.

At <=60 s internal gaps the same pressure windows have 17,982 climb / 9,863 descent
EUR profile-plus-fuel records and eight paired cells each; at <=120 s, 21,368 /
19,197. These are sensitivity/support facts, **not a reason to choose a cutoff
just to fill cells**. A common descriptor's minimum duration and resolution must
justify its measurement model. Coarsening CHN does not restore unobserved EUR detail.

The source level products are rich in both regions, but detectors differ: CHN
has dense QAR-derived levels including enroute; the EUR G2G product labels CCO/CDO
segments and has no equivalent enroute-level inventory. Applying common duration
and endpoint-altitude filters does not make the original detectors equivalent.
No source level tag must not be labelled “continuous” without adequate coverage.
For detailed classes, derive common descriptors from altitude-time support, retain
unknown coverage and compare against source level products. Freeze class thresholds
independently of region and fuel outcome. A sustained level is not automatically
an inefficiency, and these classes are not regulatory CCO/CDO certification.

For enroute altitude residence, retain the paper's declared interpolation model
and the gap-limited sensitivity. Long flat M3 spans often represent sparse level
knots; a >300 s span is not proof of absent level flight. Requiring complete <=300 s
coverage of the whole source enroute window leaves only one paired cell. Apply the
coverage condition to the specific descriptor, with unbracketed/unknown time shown,
instead of excluding every other usable flight metric.

## Definitions and fuel-source comparability

- ARP anchors are great-circle airport radii; cumulative flown distance is separate.
  Select first departure/outward and last arrival/inward crossings within airborne
  bounds; pressure crossings retain their direction and repeated candidates.
  Level-associated suppression is a supported level representation, not proof of
  a bad flight. Fixed windows need not all be present on a flight.
- Pressure FL075/100/180 is standard-pressure altitude, not height above terrain.
  High airport elevations matter especially for ATOT–FL075 and FL075–ALDT; report
  route/elevation context rather than silently equating those windows to LTO height.
- Current macro boundaries are not a common detector: 3,517 CHN TOCs / 3,508 TODs
  use the altitude-only fallback, while the rest use 200 NM context; EUR mostly
  retains explicit G2G boundaries. Fixed pressure windows avoid that TOC/TOD dependency.
  Keep source-window labels and a common-envelope sensitivity; do not pool schemes.
- A different TOC/TOD requires fuel at its actual endpoints. Do not copy fuel from
  the source phase into a newly defined window. Existing level/fine products and
  model cumulative series support an analysis adapter without QAR decoder changes.
- CHN fuel is QAR-integrated and EUR fuel is modelled; source and region remain
  confounded. Type/stage/profile matching does not establish equivalence, causal
  ATM effects or an independently measured regional fuel penalty. Payload, weather,
  speed and engine identity are not fully controlled.
- Original/delivered EUR airborne fuel differences are identical for the checked
  windows. Do not add a blanket 20% airborne correction. Carry source conventions
  and boundary schemes in every reference-table key.
- The populations are summer 2025, but two CHN ATOT timestamps fall in September
  UTC. Resolve operating-day versus UTC/date semantics transparently during paper
  selection, not by quietly changing inputs.

## Paper implementation handover

The concept already states metric-specific eligibility. The pilot implementation
still starts from `profiles$profiles |> filter(COMMON)`, a globally screened set.
It also expects the legacy CHN unit/flow QC file names, absent from candidate.6.
**Changing `FUELBURN_PAPER_CHN_DIR` alone is not a valid input adoption.** Add a
paper-analysis adapter for the new QC, interval, candidate/availability and level
schemas. Remove blanket position/event/full-record-fuel prefilters from analyses
that do not need them; retain relevant time/fuel/profile/geometry checks per window.

Keep the full lookup grid separate from populated cells. Show n per metric, phase
and class, retain marginal references when a class is unknown, and distinguish
sparse from unassigned classes. Percentiles of individual rates are not ratios
of percentiles or one joint reference flight. Keep the printed paper compact:
main profile-composition figure, one fine-phase reference example, and per-analysis
support; retain the complete grids and technical diagnostics in the companion outputs.

The technical contract belongs in this data-preparation thread. The scientific
choice of profile descriptors, class definitions, primary windows, sensitivities
and final manuscript integration belongs in the paper thread. See
`notes/paper-cohort-handoff-2026-10-27.md`. No message was sent to another thread.

## Evidence and preservation

Restricted flight/window ledger, M3-resolution masks and input hashes:
`.fuelburn-data-store/derived/paper/eligibility-comparability/PAPER-2026-10-27-001/`.
Adjacent CSVs contain identifier-free aggregate support only. This assessment
has not calculated or published new percentile coefficients or adopted new input
versions. All protected canonical and paper-source files retain their hashes.

Reproduce with `scripts/assess-chn-eur-paper-support.R` followed by
`scripts/assess-paper-profile-resolution.R`, each given a new restricted output
directory (the second consumes the first script's ledger). No raw decoding,
source repair, canonical regeneration or external upload is performed.
