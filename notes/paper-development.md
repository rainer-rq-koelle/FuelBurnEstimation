# Conference-paper development record

Updated 22 October 2026. The enroute residence and TOC/TOD-definition extension,
its measurement assumptions, and ranked paper add-ons are documented in
`notes/enroute-level-analysis.md`. The original 18 October aggregate snapshot
and source releases remain preserved.

The lookup pilot and its source-fuel eligibility are documented in
`notes/paper-lookup-table.md`. The draft introduction now contains paraphrased
breadcrumbs from the opening abstract/introduction logic of the 2025 paper,
with a citation rather than a new block of developed prose.

## Scope

`paper.qmd` now provides the requested classical structure. The active methods
and results concern stage length, climb/enroute/descent duration, enroute share,
pressure altitude at source-selected TOC and TOD, reconstructed altitude-band
residence, and a paired sustained-level boundary sensitivity. Introduction, background
and conclusion contain reminders only. Smoothness classes remain reserved for
later work; the partial lookup now includes altitude-conditioned enroute fuel
references. The working PDF layout emulates IEEE:
two columns, US letter, 10 pt Times New Roman and numeric references. It is not
the official conference template. The developed paper must fit eight pages
including references. Processing-status commentary belongs in these notes,
while the draft states the methods and their scientific assumptions directly.

The study builds on the 2025 ICNS paper. The design preserves two estimands:
regional profile composition and
consumption conditional on comparable aircraft/profiles. P20/P50/P80 remain
descriptive. No ATM savings are calculated.

## Reproduce

From the project root, with the restricted local data cache populated:

```sh
Rscript scripts/13-characterise-paper-profiles.R
Rscript tests/enroute-level-exposure.R
Rscript scripts/14-characterise-enroute-levels.R
quarto render paper.qmd --to pdf
quarto render paper.qmd --to html
quarto render paper.qmd --to docx
```

The QMD recomputes its tables directly from the pinned inputs on each render;
there is no frozen knitr cache. The standalone script additionally writes the
flight-level ledger, aggregate CSVs, SHA-256 input manifest and R session info
under the ignored `outputs/paper-profile-characterisation/`. It does not repair,
upload or replace existing data releases. Required R packages: arrow, dplyr,
tidyr, ggplot2, digest, tibble, knitr and readr (the latter for the standalone
export). The PDF renderer uses XeLaTeX and the installed Times New Roman font.

A portable input-hash manifest and identifier-free result snapshot are checked in
under `notes/results/paper-profile-characterisation-2026-10-18/`. Paths beginning
`data-store/` resolve against `FUELBURN_DATA_STORE`; other paths resolve against
the project root. Compare regenerated aggregates with this snapshot to reproduce
the original descriptive baseline. Flight-level data and generated PDF/HTML/Word files remain ignored;
the committed QMD, analysis code, styles and bibliography reproduce the outputs.

### Word review copy, 22 October 2026

`quarto render paper.qmd --to docx` writes `_output/paper.docx` using the same
analysis, citations and manuscript as the other formats. Word uses a single
column for commenting; the conference layout remains specific to PDF. Tables
are native Word tables and figures are embedded. Agreed comments should be
integrated into `paper.qmd`, which remains the manuscript source of truth.
The review export was visually checked across all ten pages. Structural checks
confirmed twelve data tables, four figures, thirteen native equations and no
document protection. The enroute and lookup unit checks also passed.

The latest analysis snapshots are `notes/results/enroute-levels-2026-10-22/`
and `notes/results/lookup-pilot-2026-10-22/`. Their companion notes document
the inputs, definitions and support rules. Adding the Word output format does
not change the analysis. The lookup snapshot's manuscript hash is refreshed
for this output-configuration change; the older enroute snapshot retains its
historical source identity.

### Pinned sources

- EUR: `derived/eur/parallel-preprocessing/EUR-2026-10-13-002/` in the data store.
- CHN: the fourteen original `CHN-canonical-milestones.parquet` files under
  `derived/chn/verification/CHN-2026-10-18-001/returned-batches/`. These reproduce
  the 6,421 identifiers in the consolidated study release. They are not the
  233 helper-validation input files and not regenerated candidate.5 outputs.
- Coordinates: bundled `helpers/chn-qar-v2/data/airports.csv` for China and
  `notes/reference-data/EUR-airport-coordinates-2024-12-27.csv` for Europe.
  These are airport-coordinate proxies for ARP. GCD is calculated independently
  by a spherical haversine (radius 3,440.065 NM).

## Preserved 18 October descriptive baseline

| Quantity | CHN | EUR |
|---|---:|---:|
| Source flights | 6,421 | 21,503 |
| Profile-screened flights | 2,296 | 21,427 |
| Additional flown-distance screen passes | 1,530 | 21,426 |
| Flights in common-support cells | 672 | 4,207 |
| Airports / directed pairs | 4 / 6 | 11 / 22 |

The conservative cohort is deliberately not forced to meet a target count.
4,990 Chinese flights pass boundary, timing, altitude and airport proximity
screens before the additional emitted-event screen; 2,694 of those fail the
event screen. This large selection effect merits a later sensitivity review.
Particularly short event intervals may be sensitive to coordinate precision.
No new threshold has been tuned to increase the count or to obtain a desired
regional outcome. This is a provisional descriptive screen, not raw-data
certification. The EUR candidate relies on its source preparation; interpolated
enriched events are not independent recorder samples and are not screened as
such. The different depth of source screening must be acknowledged.

There are six common-support cells (>=30 flights per region): A20N, A21N, A320,
A321 and B738 over 600--699 NM, plus A21N over 500--599 NM. Chinese climbs have
longer median durations in these cells; enroute duration differences are much
smaller than the regional overview suggests. Boundary-altitude differences are
large, but cannot yet establish lower time-weighted enroute operation in China.
Whole-flight and phase summaries use one observation per independent flight.

### Exclusions and interpretation

Sequential first-failure accounting is in the generated `exclusions.csv` and
paper table. CHN: 1,190 missing core boundaries, 11 coincident/unordered,
230 airport/runway position failures, 2,694 emitted-event screen failures.
EUR: 75 coincident boundaries, one timing/GCD failure. Coincident boundaries
are unresolved here, not proved absence of cruise. All source flights remain
in the restricted screen ledger. The two Chinese source records dated
1 September are reported transparently; seasonal/date conventions need review.

The whole-airborne partition is ATOT--TOC--TOD--ALDT. The supplied CLIMB and
DESCENT phase-table rows use DLTO--TOC and TOD--ALTO and omit airborne LTO
portions if read alone. Duration and altitude characterisation does not require
the suspect legacy cumulative flown distance. Distance-specific consumption
will require stronger distance and fuel validation than the present screen.

### Milestone glossary and next measurements

- AOBT/AIBT: off-/in-block times (source support and recorder-span interpretation
  must remain explicit); ATOT/ALDT: take-off/landing.
- ERWY/XRWY: runway entry/exit. DLTO/ALTO: departure/arrival LTO phase boundary;
  exact implementation and altitude reference must remain source-labelled,
  particularly at high-elevation airports.
- TOC/TOD: source-selected start/end of the enroute interval. Intended harmonised
  semantics are initial/final sustained cruise-level boundaries, preserving step
  changes. The returned CHN batches use legacy selection and are not candidate.5.
- D040/D100/D200 and A200/A100/A040: clarified airport-centred GCD radii, distinct
  from cumulative distance flown; legacy source definitions remain labelled.
- D_FL075/D_FL100/D_FL180 and A_FL180/A_FL100/A_FL075: upward/downward
  pressure-altitude crossings at 7,500, 10,000 and 18,000 ft.
- LVL_START/LVL_END: linked interval boundaries. Missing partners/coverage remain
  unknown; sparse G2G LVL tags cannot simply be paired in odd/even order.

The 22 October extension estimates altitude-band residence within TOC--TOD by
explicit interpolation of altitude-time knots and checks the contrast under a
common level-envelope definition. This supplies a model-based residence estimate,
not exact continuously observed occupancy. Maximum altitude and step structure
remain optional additions. The new note records the source-resolution sensitivity
and the full-batch input-adoption plan separately from the draft.

## Bibliography and page budget

The starter bibliography contains the 2025 conference paper, official AEM
documentation and the European CCO/CDO Action Plan.
Prior-paper publication details beyond author/title/conference/year await primary
metadata verification; the manuscript content was checked directly. The numeric
CSL is a small working style, not a claim of exact IEEE bibliographic compliance.

The requested approximate allocations already total eight pages before references.
Reserve reference space by keeping background below its two-page ceiling and
conclusion compact. Once prose grows, consolidate the sample overview and its
plots; move detailed screening rules/ledgers to the technical note.
