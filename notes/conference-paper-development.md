# Conference paper development

28 October 2026. The conference draft is `conference-paper.qmd`; `paper.qmd`
remains the full Technical Note. The new source has its own PDF, Word export and
figure directory. It reads the same adopted result caches and reviewed aggregate
snapshot, with a shared bibliography and working IEEE-like style. It does not
rebuild or change canonical inputs.

## Argument and section structure

The introduction and background develop the breadcrumbs already retained in the
earlier draft: environmental/performance motivation, the 2025 milestone approach,
regional operations versus conditional consumption, and an interpretable first
phase-reference lookup. No conceptual framework PDF is introduced as a reference.

Sections 1 and 2 carry that motivation and distinguish profile descriptors from
fuel-efficiency/compliance claims. Section 3 defines the trajectory, milestones,
four pressure windows, both terminal alternatives and ground segments, followed
by sample composition, independent eligibility, proposed categories and reference
construction. Aircraft reporting groups are newer single-aisle, conventional
single-aisle and widebody, with exact types retained and technology generation
available as a secondary descriptor within widebodies. Section 4 follows the
flight phases:

1. Departure and climb: B738 taxi-out/roll references, lower climb and both
   terminal alternatives, Chinese and European
   direction examples, comparable-time fuel for A20N/A21N/B738, and selected
   widebody climb contrasts.
2. Enroute altitude, duration and fuel intensity: altitude residence, sector
   context, the B738 TOC/TOD sensitivity on identical flights, five paired
   altitude-qualified kg/NM cells, and source-specific aircraft-group references.
3. Descent and arrival: A20N/B738 upper/lower conditional comparisons, a six-type
   exposure figure including C919 and widebodies, working thresholds, and
   both arrival terminal alternatives, and landing-roll/taxi-in references.
4. Phase reference lookup and synthesis: the complete A321neo example, the
   aircraft-group hierarchy and a matrix connecting each phase finding with its
   lookup qualifier. Marginal medians are not added into a synthetic flight.
5. Interpretation and scope: conditional transfer, aircraft-related fuel scale,
   broad-band composition, source provenance and descriptive interpretation.

Section 5 follows the conclusion checklist: answer both questions, state the
proposed categories and populated contribution, identify the principal limits,
and specify the next scientific assessment. The abstract and prose are developed
draft text; the original eight-page target does not constrain this revision.

## Selected evidence

The draft selects seven figures and eight tables. Figures cover the milestone
concept, source GCD distributions, modern-aircraft enroute altitude residence,
same-route climb time components, comparable-time climb fuel, descent exposure
categories across newer/conventional single-aisle types and widebodies, and
enroute kg/NM reference ranges. Tables give source inventory, working categories,
B738 ground references, lower-climb/terminal references, five altitude-qualified rate cells, conditional descent
fuel for A20N and B738, the full-metric A321neo lookup example, and phase synthesis.

The shared analysis layers are:

- `R/paper-window-references.R`: pinned local window eligibility and marginal
  fuel/time/distance references.
- `R/paper-climb-patterns.R`: checked climb examples and existing plot objects.
- `R/paper-descent-enroute-lookup.R`: checked descent, altitude and lookup review.

`R/conference-phase-evidence.R` selects the added phase/group examples from these
unchanged analyses and the verified aggregate lookup. It validates the displayed
strata and sample support without rebuilding a scientific cache. Its selections
are exported with the conference snapshot, including the European direction,
B738 ground/climb/enroute/boundary examples, fleet climb/enroute references,
conditional descent rows, and the 18 six-type descent exposure cells.

The smoke-test correction keeps metric-specific ground support visible: Chinese
B738 duration n is 220 in each displayed ground segment, while fuel and kg/min n
is 160. Table III and its prose report both counts. A separate summary restricted
to the 160 fuel-supported flights gives median taxi-out/taxi-in durations of
18.0/10.5 minutes, retaining the direction of the duration contrast. No ground
observations or canonical eligibility flags were changed.

Table IV connects the lower-altitude thread with five B738 entries: ATOT--DLTO,
ATOT--FL075, climb FL075--100, ALTO--ALDT and FL075--ALDT. Their counts, fuel
quantiles and durations come from the adopted window references. Fuel and time
counts happen to coincide in these entries and this is checked explicitly.
The overlapping terminal alternatives are not additive phase components.

The widebody result concerns higher absolute consumption and larger absolute
contrasts between observed descent exposure groups. It does not assert that
widebodies always climb more slowly, that proportional effects are greater, or
that the contrasts measure a causal level-off penalty. The three-type climb
distribution plot is selected directly from the unchanged adopted window view.

The broader GCD/fleet categories organise the table; exact types, narrower stage
checks and source/region remain visible. Source-native exposure bins are not
silently relabelled as common continuous/light/heavy classifications. The original
120-second/20% rule remains a comparison model, including its ten-minute necessary
window duration for the light class. Engine groups remain unstratified where the
source does not supply them.

The lookup's primary categories are the window-specific numerical qualifiers;
continuous/light/heavy remains a separate comparison model, with continuous
defined at the stated 120-second feature scale. The editorial framing treats
both regional datasets as suitable for the presented analyses and reports source
conventions as reference context. Acronyms and aircraft designators are expanded
at first use. The 2025 reference now includes publisher-deposited DOI and page
metadata, retained in `icns2025-publication-metadata.json` in the snapshot. The
shared numeric bibliography style was updated to display page ranges; the
Technical Note source and existing exports were not changed or re-rendered.

## Reproduction

With the existing adopted analyses available:

```sh
Rscript scripts/22-export-conference-paper-snapshot.R
quarto render conference-paper.qmd --to pdf
quarto render conference-paper.qmd --to docx
python3 scripts/format-conference-docx.py _output/conference-paper.docx
```

`scripts/22-export-conference-paper-snapshot.R` verifies the shared result layers,
exports only the selected identifier-free aggregate evidence, and records input
and source hashes plus a product manifest in
`notes/results/conference-paper-2026-10-28/`. The snapshot
does not become a second source of numerical coefficients: both documents still
load the same adopted analyses.

The PDF uses two columns, 10 pt Times New Roman and the existing IEEE-like working
layout. Word remains a single-column, editable review copy. The shared formatter
keeps data tables together and separates adjacent data/figure tables. The
conference wrapper also assigns explicit widths to the ground, terminal and
phase-synthesis tables so counts and phase names remain legible in Word. Official
conference-template adjustments can follow without changing the analysis.

## Export verification

The revised 28 October export contains ten PDF pages including references. Its
single-column Word review render contains nineteen pages, seven figures, eight
native editable data tables and ten native inline equation objects. Every page
of both exports was visually inspected; figures, captions and tables remain
legible with no clipping or overflow. Table I–VIII captions match the textual
references in both formats. Word tables are kept together and separated from
adjacent figure wrappers.

All 110 pinned input hashes and 28 conference source hashes were verified after
rendering. The full Technical Note source and its PDF/Word exports retain their
pre-conference-development hashes. Canonical inputs remain unchanged. Export
hashes and structural checks are recorded in
`_output/conference-paper-export-verification-2026-10-28.json`; this is local QA
metadata, while the repository reproduction record is the source/input manifests
and selected aggregate snapshot. `git diff --check` passed.
