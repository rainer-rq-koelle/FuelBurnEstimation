# Paper integration plan

27 October 2026. Planning record following the user's acceptance of the supplied
CHN and EUR data for cohort-based paper analysis. This plan does not adopt new
manuscript results. It uses the [paper handover](paper-cohort-handoff-2026-10-27.md)
and [assessment and aggregate support tables](results/paper-cohort-mapping-2026-10-27/README.md).

Scope update, 27 October: the user now treats the working document as a technical
note collecting all study aspects, without a page limit. Preserve the analyses
and sensitivity results; conference selection comes later. The latest
[interruption-class assessment](paper-profile-classes.md) adds working common
thresholds, native-point coverage and class-specific support. Source-level
inventories remain a separate evidence axis rather than interchangeable detectors.

Result-led extension: the [climb-pattern analysis](results/paper-climb-patterns-2026-10-27/README.md)
now precedes the fuller support/grid presentation. It compares fuel at similar
times and closer distances, source-native level exposure within region, identical-
distance route direction, stage length and equal-size subsampling. Weight remains
unobserved; native tagged-time accounting is descriptive rather than a causal
allocation of delay/fuel. Common class coverage does not gate these independently
supported descriptive comparisons.

Implementation update, 27 October: the [adopted reference layer](paper-window-references.md)
now implements explicit input adoption, independent cohort views, marginal pressure
and terminal reference grids, and the exploratory manuscript. Common interruption
classes now have an explicit working-definition/support extension; numerical
ground-distance proxies remain a separate design task. The
assessment counts below are reconciled with the adopted view; canonical data are
unchanged.

## Paper argument and analysis priorities

The paper extends the 2025 milestone approach into empirical phase and finer-window
references. Keep two questions separate:

1. How do the study samples differ in regional profile composition, for comparable
   aircraft and stage lengths?
2. How do fuel-consumption distributions compare within common aircraft, stage,
   window and profile definitions?

Describe composition before conditioning on profile. A difference in the prevalence
of interrupted profiles remains a result even if conditional fuel distributions
are similar. These are selected study samples, not estimates for all regional traffic.

Make climb FL075–FL100 and FL100–FL180, with their descent counterparts,
the core pressure-window set. Preserve
source-defined macro climb, enroute and descent, and whole-airborne references as
context. Retain enroute altitude residence as complementary profile context.
Keep ATOT–3,000 ft as a live terminal option, with its altitude reference explicit,
alongside ATOT–FL075; do not replace it at this planning stage. Airport-radius
windows and distance-based rates extend the reference grid where supported.
Fine climb/descent results must appear explicitly in
the paper, rather than both remaining future lookup slots.

Canonical data remain unchanged. CHN decoder development, data repair, additional
coverage and EUR preparation improvements are outside this work. Measurement
definitions and sensitivity analyses describe the supplied observations; they do
not require repairing the sources or resolving every existing review case.

## Cohorts and their presentation

Use separate eligibility masks for each window and quantity. A flight may support
several analyses, or only one. These are overlapping analysis views, not a single
nested exclusion funnel or a set of disjoint cohorts.

| View | Eligibility and reporting |
|---|---|
| Regional composition | Each supported time, altitude or profile quantity independently; include unpaired types/stages and show source mixture |
| Marginal fine-window reference | Ordered supported endpoints, local time/fuel eligibility and positive increments; no blanket whole-flight geometry or all-phase requirement |
| Profile-conditioned reference | Marginal fuel eligibility plus a defined common local descriptor and its coverage requirements |
| Spatial or kg/NM reference | Add relevant local geometry/distance eligibility; airport-radius windows retain their existing position gate |
| Complete airborne decomposition | Require all constituent phases only for analyses that actually partition total airborne fuel/time |
| Boundary/resolution sensitivity | Use its declared support; compare alternative boundary schemes on identical flights |

Duration-only descriptions need not require eligible fuel. Profile composition
need not require fuel either. Report class support independently from the fuel-valid
subset used for conditional references. A locally usable window can survive an
unsupported different phase or an unrelated ground/full-record finding.

The assessment provides the following planning counts. Reconcile them with the
versioned adapter before inserting them as adopted manuscript counts.

| Fuel/time window | CHN all eligible | EUR all eligible | CHN in paired cells | EUR in paired cells |
|---|---:|---:|---:|---:|
| Whole airborne | 6,388 | 21,502 | 1,645 | 6,224 |
| Climb FL075–100 | 6,378 | 21,499 | 1,648 | 6,223 |
| Climb FL100–180 | 6,378 | 21,476 | 1,648 | 6,223 |
| Descent FL180–100 | 6,369 | 21,306 | 1,639 | 6,170 |
| Descent FL100–075 | 6,368 | 21,009 | 1,639 | 6,041 |

All five rows have eight paired exact-type/100 NM GCD cells at n >= 30 per region:
A20N/600, A21N/500, A21N/600, A319/600, A320/600, A321/500, A321/600 and B738/600.
Here 500 means 500–599 NM and 600 means 600–699 NM. Class-specific cells can be
fewer; these counts do not establish support for any interruption class.
The source population remains 6,421 CHN and 21,503 EUR flights. The revised CHN
processing increases usable analysis elements, not the source-flight population.

In the manuscript's concept/methods/data section, retain source totals, dates,
airports, aircraft types and stage-length context, then show a compact window
support table. Replace the implication of one universal "analysis flights" count.
In results, give n alongside each metric/class and sensitivity. Do not repeat the
full support matrix in prose or sum overlapping window counts. Keep detailed
eligibility reasons and complete grids in companion aggregate outputs.

## Profile descriptors and scientific choices

Start with total detected sustained-level time and share, interruption count,
longest interruption and interruption altitude, separately for climb and descent.
For the primary fine-window references these describe the selected pressure
window, not the entire climb/descent. Report whole-phase descriptors separately
if available; never silently transfer a window class to a whole phase.

Derive common descriptors from altitude-time support with the same physical
definitions in both regions. Source segment inventories are supporting evidence,
not interchangeable detectors. Preserve raw descriptors before reducing them to
compact classes. Fix class thresholds independently of region and fuel outcome;
regional quantile classes would not have a common physical interpretation.

Keep three choices explicit before publishing conditioned results:

- **Feature scale and resolution:** define the shortest sustained feature to be
  described, then justify altitude/vertical-rate tolerances, minimum duration,
  internal-gap handling and coverage requirements. The existing enroute-envelope
  thresholds are not automatically terminal-phase class definitions. Assess
  descriptor sensitivity, not just the number of surviving cells.
- **Class meanings:** distinguish an assigned observed class, unknown coverage and
  a class not yet assigned. Adequate coverage with no detected sustained level is
  not proof that no shorter interruption occurred. Avoid unqualified "continuous"
  and formal CCO/CDO compliance claims. Partial coverage cannot establish a zero
  interruption count or a complete-window total/longest interruption.
- **Traversal speed:** effective vertical rate is endpoint-supported, but for
  these fixed pressure windows its magnitude is the altitude difference (2,500 or
  8,000 ft) divided by elapsed minutes.
  It is a duration-related descriptor, not independent smoothness evidence.
  Conditioning on it constrains duration and therefore the interpretation of
  fuel/time contrasts. Keep it supplementary and label this coupling explicitly.

Endpoint-crossing resolution and interior profile resolution need separate flags.
For the FL100–180 climb / FL180–100 descent windows, both crossing brackets
<=30 s retain eight paired cells for each window.
Requiring every interior gap <=30 s leaves six paired climb cells and no paired
descent cells. At <=60 s there are eight for each, but support alone does not
justify that cutoff. Coarsening CHN cannot recover unobserved EUR interruptions.
Use a declared reconstruction and unresolved-coverage state rather than making
short-interruption detection a prerequisite for every fuel/time reference.

Unknown-profile flights remain in marginal references and have explicit support
in the lookup's unknown category where applicable. Report the unknown share with
its denominator alongside profile composition. Sparse classes keep their counts;
suppress percentile values below n = 30. Unassigned support is missing, not zero.

## Window, fuel and comparison conventions

Retain source TOC/TOD labels and a common level-envelope sensitivity. Fixed pressure
windows avoid reliance on a common source TOC/TOD detector. Preserve candidate
availability and selection provenance for repeated directional pressure crossings;
make ordered crossing-pair selection explicit and reconcile it with the assessment.
Pressure altitude is not height above terrain; include airport-elevation context
when interpreting lower windows. Airport radii and cumulative flown distance remain
different quantities.

Whenever boundaries change, evaluate fuel at the new endpoints. Use the supplied
CHN locally eligible interval partition and EUR model cumulative series, with
their declared interpolation/accounting rules. Never reuse old phase fuel for a
shifted boundary. Preserve source conventions; apply no blanket airborne 20% factor.

The lookup key is source/region × exact aircraft/engine group × GCD band ×
phase/window definition × profile axis/class. Carry input version, fuel convention
and profile-definition version as metadata. Engine identity remains explicitly
unstratified where unavailable. Each metric has its own n and flight-weighted
P20/P50/P80. Calculate individual-flight rates before their quantiles. Airport GCD
is a stage stratum, never the denominator of phase kg/NM.

Prioritise cell-specific regional contrasts. If a pooled contrast is needed, use
the same declared cell weights for both regions and calculate from weighted
flight-level distributions; do not average cell percentiles. Matching type, stage
and profile does not control payload, weather, speed or all engine/operator effects.
QAR-integrated CHN fuel and modelled EUR fuel remain confounded with region.
Describe references and associations, without converting percentile gaps into
recoverable ATM savings or claiming statistical equivalence from similar medians.

For dates, the recommended primary convention is supplied campaign membership,
with actual UTC bounds reported and the two September-UTC CHN records disclosed.
Add a strict June–August UTC sensitivity if it affects a displayed comparison.
Do not invent an operating-day conversion or modify source timestamps. Record
the final date convention in the analysis manifest.

## Implementation sequence and completion checks

1. **Versioned analysis adapter and manifest.** Add an explicit opt-in analysis
   configuration for returned CHN candidate.6 and pinned EUR-2026-10-13-002.
   Identify all required input files and hashes; leave canonical releases and
   legacy manuscript configuration intact until the new view is reconciled.
   An environment-directory substitution alone is insufficient.
2. **Independent analysis views.** Produce flights/strata, selected events with
   all-candidate availability, window metrics with separate time/fuel/profile/
   geometry flags and reasons, and profile descriptors with coverage. Use local
   candidate.6 fuel support instead of the pilot's legacy unit/flow CSV requirements
   and global profile prefilter. Retain existing relevant source review exclusions.
3. **Marginal reference grids and support reconciliation.** Reproduce the assessed
   window/cell counts, document any differences, and populate primary climb/descent
   kg, minutes and kg/min references. Add locally supported distance metrics and
   macro context independently. Preserve empty, sparse and populated states.
4. **Profile composition and conditioned grids.** Implement and freeze the common
   descriptor/coverage definitions, then establish actual class-specific n. Keep
   marginal references alongside conditioned ones. If detailed classes have limited
   paired support, publish supported fine-window references and measured profile
   descriptors; do not redefine classes simply to fill the table.
5. **Manuscript adoption and reproduction.** Switch the paper explicitly to the
   reconciled versioned view; update cohort tables and affected results together.
   Preserve the 22 October pilot and its snapshots as historical evidence. Write
   new aggregate snapshots, input/code manifests and reproduction commands. Keep
   flight/window ledgers in the restricted store; publish aggregate evidence only.
   Render PDF and Word from the same adopted analysis.

Verification should cover directional/repeated crossing selection, local coverage
and fuel accounting, independence from unrelated phase/geometry failures,
unknown versus zero interruption, class-threshold boundaries, metric-specific n,
rate quantiles and support reconciliation. Reuse the assessment logic where suitable;
these are analysis checks, not decoder-development work.

No further user information is needed to begin the adapter and marginal-reference
steps. Numerical interruption thresholds remain a scientific design task within
the plan, to be justified before conditioned results are interpreted.

## Lower-altitude and ground extension

The [lower-altitude/ground support assessment](results/paper-lower-ground-support-2026-10-27/README.md)
quantifies the existing stepping stones from recorded taxi-out through source
climb-out, FL075/100/180, and the corresponding arrival sequence to recorded
taxi-in. Eight matched type/GCD fuel/time cells remain for each assessed segment.
Add FL075–100 and terminal-pressure references to the lower-altitude presentation,
and ground duration/kg/kg-min rows to the source-labelled reference grid.
Include ground-distance proxies as a planned analysis dimension; ground profile
classes are not presumed available from the operational milestones alone.

Keep source LTO boundaries distinct from common pressure levels: CHN field-relative
3,000 ft boundaries are not interchangeable with EUR source LTO anchors. Ground
record edges are not independently observed block times. Carry the EUR roll-fuel
original/delivered variants explicitly. Other flight levels (including FL050/120/150)
are deferred, including checking their source implementation. No extra crossings
or decoder changes are required for the current paper plan.

### Terminal alternatives and airport sensitivity

Retain the user's ATOT–A/FL030 option as a 3,000 ft terminal-window candidate,
with separate boundary schemes for a field-relative altitude and a standard-pressure
FL030. The existing ATOT–DLTO counts support the source-defined 3,000 ft option;
they do not establish availability of a harmonised literal FL030 crossing. Do not
merge the schemes under an ambiguous A/FL030 label in the final lookup.

The [terminal-option assessment](results/paper-terminal-options-2026-10-27/README.md)
compares the existing source option with ATOT–FL075 on the actual flight sets.
Departure fuel/time support is 6,392 CHN / 21,502 EUR for source DLTO and
6,391 / 21,501 for FL075. The paired samples are identical: 1,647 CHN / 6,224 EUR
for each option across eight aircraft/GCD cells. Retain both until the boundary
semantics and resulting fuel/time distributions guide the choice; sample size
alone does not favour replacement.

Report support by departure/arrival airport. Omitting ZPPP at the relevant window
endpoint is a sensitivity, not a new eligibility rule: it reduces CHN source
climb-out support from 6,392 to 5,648 and approach/landing from 6,376 to 5,790.
It changes none of the existing paired fuel counts for these windows. This does
not make the remaining source 3,000 ft references equivalent across regions.
Retain high-airport flights for their independently valid analyses. ATOT–FL075
is a broader pressure-window alternative at most of these airports; do not
assume it is longer than a field-relative 3,000 ft window at every airport.

### Ground-distance proxies

Zero supplied EUR taxi-out/roll distance is an absent usable denominator, not a
ban on analysis-derived proxies. Add an explicit distance basis to each lookup
row: supplied flown/ground distance or a named proxy with source/version and
uncertainty range. Retain kg, minutes and kg/min for all eligible ground records.

For taxi-out, prioritise an airport/terminal-to-runway route or characteristic
ground-path estimate supported by airport geometry or documented representative
paths. For take-off roll, use a documented aircraft/runway/performance estimate
where possible; full runway length is not automatically roll distance. Do not
assign numeric distances before their provenance and assumptions are specified.
No canonical distance needs to be filled or corrected.

Report kg per proxy NM distinctly from kg per supplied distance. Show sensitivity
to plausible proxy bounds and apply the same proxy method to both regions for
any direct proxy-based contrast. If supplied CHN distance and EUR proxies are
also compared, label that separate comparison as having different denominator
methods. Multiplying total elapsed taxi time by a fixed speed makes kg/proxy-NM
an algebraic rescaling of kg/min and counts stops as movement; it cannot provide
independent distance-efficiency evidence.

Proxy support has its own n. The present ground fuel/time counts are the potential
upper bound, not populated proxy counts: 6,229 CHN / 21,502 EUR for taxi-out and
roll, including 1,585 / 6,224 in paired cells. Airport/runway proxy availability
may reduce these. Existing zero-distance rows remain in the source and continue
to support the non-distance metrics.

### Confirmed take-off-roll fuel convention

On 27 October the user reports stakeholder confirmation that the underlying EUR
model retains ICAO 100% take-off thrust while common operation uses reduced thrust.
The agreed 0.8 fuel factor is therefore the intended delivered roll convention.
Use the already adjusted delivered EUR roll fuel in the planned primary reference;
retain the original model value and the stakeholder rationale as provenance and
optional sensitivity. Do not multiply the delivered value by 0.8 again, extend
the factor to other phases or interpret it as a measured per-flight thrust setting.
This confirmation changes the planned interpretation, not any source fuel values
or support counts. A citable stakeholder/source-method attribution can be added
when manuscript prose is developed.

## Technical note scope and later conference selection

The latest user instruction removes the page limit and treats the working
document as a technical note collecting all study aspects. This supersedes the
earlier approximate 12--14 page exploration allowance. Retain additional
visualisations, result tables, class support and sensitivities before selecting
material for the eventual conference submission. Keep introduction/background/
conclusion breadcrumbs while exploring the result story.

The original agreed conference structure remains introduction, background,
concept/methods with a data subsection, results/discussion, conclusion and references.
The initial approximate 1 / up to 2 / 2 / 2 / 1-page allocations were discussion
guides; references also need space. The later tentative compact allocation was
1 / 1 / 2 / 2.75 / 0.5 / 0.75 including references. Both are eventual editorial
planning aids, not a limit on the current exploration.

Results order: sample/profile composition; enroute context; marginal climb/descent
references; profile-conditioned examples; compact sensitivity and interpretation.
During exploration show cohort support, composition, interval/distribution views,
fine-window reference tables, fuel/time relationships and both terminal options.
The later conference selection can favour a composition figure, compact cohort
table, fine-window reference display and supported conditional example. Full grids
and technical diagnostics remain companion material. Data-work status, decoder
plans and source-processing history stay outside manuscript prose. Do not cite
the conceptual framework PDF.
