# FuelBurnEstimation

Flight-phase fuel-burn references for China–Europe benchmarking. The current
study baseline is the conference draft and supporting Technical Note completed
on 28 October 2026 and integrated into `main` through [PR #5](https://github.com/rainer-rq-koelle/FuelBurnEstimation/pull/5).
Both documents use the same checked analysis layers and pinned source inputs.

## Start here

| Document | Purpose | Local exports |
|---|---|---|
| [Conference paper](conference-paper.qmd) | Selected findings and phase-reference lookup proposal; current draft is ten PDF pages, with an eventual eight-page target | `_output/conference-paper.pdf`, `_output/conference-paper.docx` |
| [Technical Note](paper.qmd) | Full study, supporting analyses, sensitivities and reference tables; the filename is retained | `_output/paper.pdf`, `_output/paper.docx` |

Read the [conference development and reproduction record](notes/conference-paper-development.md)
and [adopted reference-layer guide](notes/paper-window-references.md) for details.
The bibliography and layout are shared through `paper-references.bib`,
`paper-numeric.csl` and `paper-style.tex`. Word exports are single-column review
copies; PDFs use the working two-column layout.

The four preserved review exports are identified by
[their checksum record](notes/document-exports-2026-10-28.json). The Technical Note
exports predate the final shared bibliography metadata update; keep those exact
review copies when generating new exports.

## Adopted inputs and analysis

[The analysis configuration](config/paper-analysis-2026-10-27.json) and its
[110-file input manifest](config/paper-analysis-2026-10-27-inputs.csv) define the
current paper inputs:

- **EUR:** `EUR-2026-10-13-002`, the parallel preprocessing release covering
  21,503 flights. This remains the stable paper basis until explicitly changed.
  See the [release evidence](notes/results/EUR/EUR-2026-10-13-002/README.md).
- **CHN:** `CHN-2026-10-27-001`, the fourteen returned candidate.6 batches covering
  6,421 flights. See the [return audit](notes/results/CHN/CHN-2026-10-27-001/README.md).
- **Analysis views:** pinned eligibility/comparability and lower-ground views,
  with independent support for each window and metric. Canonical inputs remain
  unchanged; there is no universal whole-flight exclusion mask.

Renders verify hashes and code fingerprints before loading the prepared
analyses. Restricted source data, eligibility views and analysis caches belong
in `FUELBURN_DATA_STORE`, outside Git. `data-store/` paths in the input manifest
resolve relative to that configured store.

| Analysis | Implementation / reproduction | Evidence and interpretation |
|---|---|---|
| Window and phase references | `R/paper-window-references.R`; scripts `16` and `17` | [Reference guide](notes/paper-window-references.md) |
| Interruption classes and coverage | `R/paper-profile-classes.R`; script `18` | [Class definitions](notes/paper-profile-classes.md) |
| Climb fuel patterns | `R/paper-climb-patterns.R`; script `19` | [Climb results](notes/results/paper-climb-patterns-2026-10-27/README.md) |
| Descent, enroute and lookup synthesis | `R/paper-descent-enroute-lookup.R`; script `21` | [Reviewed results](notes/results/descent-enroute-lookup-2026-10-28/README.md) |
| Conference evidence selection | `R/conference-phase-evidence.R`; script `22` | [Conference record](notes/conference-paper-development.md) |

The [enroute methods](notes/enroute-level-analysis.md),
[cohort handover](notes/paper-cohort-handoff-2026-10-27.md) and
[integration decisions](notes/paper-integration-plan-2026-10-27.md) retain the
reasoning behind the adopted analysis. Counts are specific to each analysis;
overlapping windows and marginal medians are not additive flight components.

## Render the current documents

Use an environment with R and the packages used by the analysis scripts,
Quarto, a working PDF/LaTeX setup and Python 3 for Word formatting. Configure the
restricted store in `.Renviron` using `.Renviron.example` as a starting point.
Keep credentials out of Git.

With the pinned inputs and prepared analysis caches already available, run from
the repository root, sequentially because formats share rendering intermediates:

```sh
quarto render paper.qmd --to pdf
quarto render paper.qmd --to docx
python3 scripts/format-paper-docx.py _output/paper.docx
quarto render conference-paper.qmd --to pdf
quarto render conference-paper.qmd --to docx
python3 scripts/format-conference-docx.py _output/conference-paper.docx
```

Rendering replaces the corresponding local exports. Preserve review copies
first if their exact bytes or comments are needed. Generated exports remain
outside version control.

An intentional analysis rebuild uses the existing pinned inputs and views:

```sh
Rscript scripts/16-build-paper-window-references.R
Rscript scripts/18-characterise-paper-interruptions.R
Rscript scripts/19-explore-climb-fuel-patterns.R
Rscript scripts/21-review-descent-enroute-lookup.R
Rscript scripts/17-export-paper-reference-snapshot.R
Rscript scripts/22-export-conference-paper-snapshot.R
```

These commands regenerate analysis caches and aggregate snapshots. They are not
needed for README or ordinary prose edits. Follow the
[reference-layer guide](notes/paper-window-references.md) when rebuilding upstream
eligibility views; adopt changed inputs through a new configuration and manifest.
The scientific checks are retained under `tests/`.

## Data storage and source preparation

Cloudflare R2 holds shared restricted artifacts; each machine has a local store.
The R2 storage manifest describes shared artifacts, while the paper's pinned
manifest defines the inputs actually adopted by this study. Downloading the old
`processed/` products alone does not reproduce the current paper.

Storage utilities remain available in `scripts/r2-list-files.R`,
`scripts/r2-sync-status.R`, `scripts/r2-download-data-store.R`,
`scripts/r2-upload-data-store.R` and `scripts/r2-publish-manifest.R`, backed by
`R/r2-storage.R`. Check the selected keys and manifests before downloading or
publishing; storage operations are separate from rendering.

The [CHN helper](helpers/chn-qar-v2/README.md), its
[candidate.6 validation](notes/results/CHN/CHN-v2-2026-10-22-003/README.md),
EUR parallel builders, airport lookups and source provenance remain preserved.
The helper's `R/legacy-core.R` is an active dependency despite its name.
CHN decoder development, coverage improvements and EUR preparation changes are
deferred; none is required to continue reviewing the current paper.

Git contains code, documentation, aggregate evidence and manifests. Raw and
flight-level data, private review evidence, credentials and generated caches
remain excluded. Preserve `notes/results/` and its source/input/product hashes;
some of these files are read directly by the documents.

## Historical work and supporting records

The [28 October cleanup record](notes/repository-cleanup-2026-10-28.md) lists
retired branches, recovery tags, archived chats and the unchanged W2 hold.

The following records remain available for provenance. Their original schedules,
release labels and readiness claims describe earlier work, not current tasks:

- [Exploratory paper](paper-exploratory-2026.qmd),
  [data-preparation note](technical-note-data-preparation.qmd) and
  [methodology note](technical-note-methodology.qmd): earlier design and process
  records; `paper.qmd` is the current full Technical Note.
- [Worker plan](notes/study-worker-plan.md), [dispatch](notes/worker-dispatch.md),
  [handoff template](notes/worker-handoff-template.md) and
  [W0 release contract](notes/study-release-contract.md): the earlier W0–W7 workflow.
- [FIXED pipeline documentation](notes/EUR-Pipeline-FIXED-Documentation.md),
  [LOBT investigation](notes/CRITICAL-LOBT-Filter-Bug.md) and
  [schema comparison](notes/EUR-CHN-Schema-Comparison.md): historical delivery and
  diagnostic evidence. Zero orphan counts and manifest matches did not establish
  analytical validity; the paper uses the later pinned releases above.
- [Original profile baseline](notes/paper-development.md) and
  [lookup pilot](notes/paper-lookup-table.md): earlier analyses retained for
  comparison and reproduction.

Historical repair/upload scripts and `scripts/10-cleanup-intermediate-files.R`
remain preserved, but are not part of the current paper workflow. The cleanup
script assumes older storage paths and should not be used for the adopted store.
The previous study is in `../paper-2025-ICNS-CHN-EUR-fuelburn` (or the location
specified by `FUELBURN_2025_PROJECT`).
