# Adopted pressure-window and terminal references

28 October integration: the current PDF/Word technical note adds the
[descent/enroute review](results/descent-enroute-lookup-2026-10-28/README.md),
three figures, seven tables, and explicit proposed sector/fleet/altitude/exposure
categories. Its checked loader reads the review's aggregate snapshot; the
canonical and marginal-reference inputs remain unchanged. The historical
window-reference release and page counts below are retained for provenance.

The current PDF/Word exports have 21/49 pages, 29 figures and 33 data/result
tables. All final pages were visually checked. Word remains single-column with
editable tables and native equations. `scripts/format-paper-docx.py` separates
adjacent data/figure tables and releases the final data row so page breaks do
not attach a following figure or repeat a data header above it. The active
snapshot manifest pins the updated QMD, loader and formatting helper.

Latest scope update: the active document is now an unlimited-length study
technical note. The [interruption-class extension](paper-profile-classes.md)
defines working common thresholds and evaluates native-point coverage without
changing this marginal-reference layer. The 12--14 page guidance below records
the earlier exploration stage and no longer limits the document.

27 October 2026. Implements the adapter, cohort reconciliation and marginal
reference steps of the [integration plan](paper-integration-plan-2026-10-27.md).
The active `paper.qmd` now uses returned candidate.6 CHN data and the unchanged
EUR-2026-10-13-002 preparation through an explicit versioned analysis view.
The previous 22 October paper state remains in commit 3cd24ef and its aggregate
snapshots; the legacy R builders remain available for that historical analysis.

## Scope implemented

- Four core directional windows: climb FL075–100 / FL100–180 and descent
  FL180–100 / FL100–075, with eight matched aircraft/GCD cells each.
- Both departure terminal alternatives (ATOT–source DLTO and ATOT–FL075), plus
  arrival counterparts, without inventing a harmonised FL030 crossing.
- Metric-specific n and P20/P50/P80 for total kg, minutes, individual-flight kg/min,
  supplied flown-distance kg/NM and the corresponding flown distance.
- Source macro, whole-airborne, spatial and ground reference grids for context,
  with existing quantity-specific eligibility preserved.
- Updated regional composition and independently selected enroute altitude/time
  exposure, with a paired source/level-envelope boundary sensitivity.
- Expanded exploratory manuscript with interval plots, per-cell ECDFs, fuel/time
  points, median-ratio comparisons, airport boundary context and ground references.
  The user allows approximately 12–14 pages during exploration; the conference
  eight-page selection is deferred. Introduction/background/conclusion remain
  mainly aide-memoire bullets.

These are marginal references. No interruption thresholds, CCO/CDO certifications,
ground-distance proxy coefficients or independently calibrated regional fuel
effects are introduced. Profile coverage is not a global gate on fine-window
fuel. Numerical proxy distances and common interruption classes remain distinct
scientific design tasks.

## Adoption and input identity

`config/paper-analysis-2026-10-27.json` identifies the source releases, campaign-date
convention, minimum n, core/terminal windows, roll convention and restricted output.
Its companion input manifest pins 110 files by SHA-256: source products, M3 support,
airport coordinates and the checked derived eligibility views. Canonical inputs
are never overwritten. No decoder or EUR reprocessing is performed.

The paper adapter uses the previously checked cohort assessments as its normalised
eligibility layer. This is an explicit adoption of those derived analysis views,
not a directory-environment substitution into the old global-profile pilot.
It reads source milestone, QC, candidate and availability products to retain
event provenance, source context and independent enroute support. The first
assessment provides macro/pressure/ARP windows; the lower/ground assessment adds
terminal subdivisions and ground rows. Six overlapping windows must match exactly
for time, fuel and distance-rate eligibility. No source region borrows the other's
missing channel or detector semantics.

Enroute exposure has its own time/profile cohort and common-support selection.
CHN held geometry cannot silently supply airport-circle context: altitude support
is retained and the boundary sensitivity uses its declared ceiling fallback where
geometry is unsupported. Fuel is not copied into shifted envelope windows; that
sensitivity reports altitude/time only. The enroute cohort is 1,639 CHN / 6,224 EUR;
paired alternative-boundary support is 1,639 / 6,135.

Source event, candidate, availability, flight and window views, and the cached
analysis object, remain under
`FUELBURN_DATA_STORE/derived/paper/reference-tables/PAPER-REFERENCES-2026-10-27-001/`.
Only identifier-free aggregate tables/manifests are exported to the repository.

## Reproduce

With the pinned restricted input store present:

```sh
Rscript tests/paper-window-references.R
Rscript scripts/16-build-paper-window-references.R
Rscript tests/paper-window-adoption.R
Rscript scripts/18-characterise-paper-interruptions.R
Rscript scripts/19-explore-climb-fuel-patterns.R
Rscript scripts/21-review-descent-enroute-lookup.R
Rscript scripts/17-export-paper-reference-snapshot.R
quarto render paper.qmd --to pdf
quarto render paper.qmd --to docx
python3 scripts/format-paper-docx.py _output/paper.docx
quarto render paper.qmd --to html
```

The standalone build recalculates references and enroute exposure from the pinned
views and source profiles. The QMD verifies source-input hashes and analysis-code
fingerprints before reading the restricted cache. A changed analysis function or
configuration requires an explicit rebuild; a manuscript/style edit does not
rerun data analysis. PDF, Word and HTML therefore use the same numerical results.
Run formats sequentially because they share Quarto intermediates and figure names.
The optional stdlib-only Word formatting step keeps short editable tables
together. The QMD fixes Word figure width at 3.45 inches so tall scientific
plots fit the page; it does not impose two columns or modify any numerical content.

If rebuilding the upstream assessment views, run
`scripts/assess-chn-eur-paper-support.R` in a new restricted directory, followed by
`scripts/assess-paper-profile-resolution.R`; then run
`scripts/assess-paper-lower-ground-support.R` in a separate new restricted directory.
The latter consumes the base view. Pin the rebuilt outputs explicitly in a new
configuration/manifest rather than silently replacing the adopted files. The
source assessment notes document their exact input releases and selection rules.
No new decoder invocation is needed.

## Evidence and checks

The [aggregate reference snapshot](results/paper-window-references-2026-10-27/README.md)
contains the core, terminal and ground wide tables, with each metric's own support,
percentiles and status. The full long/wide source/aircraft/stage/window grid remains
in the restricted derived output and can be regenerated with the same commands.

Unit checks cover sparse-percentile suppression, independent time/fuel/distance
eligibility and percentile-of-individual-rate accounting. Integration checks cover
the assessed support counts, local pressure windows surviving unsupported whole
airborne fuel, identical matched departure-option flight sets, one application of
the delivered roll convention, campaign-date retention, exposure conservation and
uncensored 100% plotting. Every populated window endpoint has selected-event
provenance. Source hashes are verified before/after the build and on every render.

The scientific interpretations remain descriptive. Source and region are confounded;
large descent differences must retain that context. Common-support counts are
not equivalence tests or validity requirements for all other observations.

## Render verification

The exploratory PDF has 14 pages, 22 figures and 19 result/data tables. The
single-column Word review copy has 31 pages with the same content, native editable
tables/equations and no document protection. All pages were visually inspected;
the HTML output also contains the same 22 figures and 19 tables. Word's taller
page count reflects its review layout rather than additional results.

The packaged renderer produced the Word preview. A Poppler raster-cache defect
omitted repeated glyphs in some multi-page PNGs despite intact PDF text; PDFium
was used to confirm the actual rendered content. This affected QA images only,
not the manuscript outputs. The enroute plot's separate 100% stack-rounding
censoring issue was corrected in the plotting code and is covered by a test.
