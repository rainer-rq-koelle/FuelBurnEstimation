# AICAP 2027 study worker plan

Prepared 9 October 2026. These are proposed work assignments for collaborators or later workers; no workers have been launched, colleagues messaged, or production release changed by this plan.

## Objective and minimum publishable scope

Test whether independently defined operational profile descriptors improve phase-dependent fuel references beyond exact-aircraft-type/phase coefficients, using harmonised CHN QAR and EUR NM/AEM analytical outputs. Primary scope is airborne climb/descent, with enroute references and a focused cruise altitude/duration study where validated. Taxi and causal ATM benefit-pool estimation are later extensions.

Start with B738 and A320, then add A321/A20N/A21N if quality-filtered common context supports them. Preserve exact variants. Widebodies remain an optional exploratory extension; their shared totals are small, particularly in Europe. P20/P50/P80 are candidate summaries, not predetermined efficiency classes or confidence bounds.

The exploratory paper and `technical-note-methodology.qmd` are the design baseline. `technical-note-data-preparation.qmd` owns source preparation. The coordinator freezes decisions after reviewing worker evidence. Operationally motivated bands can be retained if transparent and robust; they need not be presented as statistically discovered cut points.

## Current evidence and critical path

Run `Rscript scripts/12-audit-study-readiness.R` for the current seven hash-verified artifacts. The aggregate CSVs under `outputs/study-design/` establish the starting evidence:

- EUR repeated interval keys and overlaps invalidate naive segment counts, level-time sums, and pooled segment-rate summaries.
- CHN distance/time inconsistencies affect kg/NM, distance matching, and distance-derived anchors.
- CHN missing ALDT affects 1,190 flights and requires phase-specific eligibility and selection assessment.
- EUR phase enrichment and canonical export differ from the intended semantic contract.

Critical path: **W0 release contract → W1/W2 source validation → W3 canonical phases/profiles → W4 parameter freeze → W5 lookup evaluation → W7 manuscript**. W6 cruise diagnostics can start from designs and existing records but final estimates depend on W1–W4. W1 and W2 can run concurrently in the relevant source environments. W0/W7 can draft documentation while source validation proceeds.

No modelling worker should treat a manifest match, an `ok` source flag, or zero orphan rate as evidence that interval pairing is correct. Keep current production artifacts intact while repairs are reviewed. New candidates require new hashes, provenance, and a separately approved release label; avoid silently overwriting shared R2 objects.

## Dispatch instructions for every worker

Dispatch the relevant work package together with the analytical contract in
`technical-note-methodology.qmd` and the storage/completion contract below.
Use `notes/worker-handoff-template.md` for the return report. Each package's
storage paragraph is mandatory even when copied into another bot on its own.

Give each execution a unique `run-id` and return the producing Git commit,
input/output SHA-256 hashes, run commands, parameters, and validation evidence.
Store code and shareable aggregate evidence in GitHub; store reusable analytical
data in authorised R2 candidate locations. The paths below are proposed naming
conventions, not objects that already exist. Record actual keys in the run
manifest. A PR or narrative alone is insufficient for a data-producing task.

## W0 — Coordinator and release steward

**Suggested owner:** PRU/CAUC lead analysts jointly; one named release steward. **Dependencies:** none. **Priority:** first.

1. Freeze the input manifest snapshot and distinguish delivered, candidate-corrected, and adopted releases.
2. Review aggregate readiness outputs and agree the minimum airborne study scope.
3. Record raw-data access, source definitions, actual AEM version/configuration, QAR integration conventions, units, sampling cadence, and time/altitude semantics.
4. Assign W1 and W2 to people with source access. Resolve the exact QAR delivery producer/version; the consolidation script alone is not detection provenance.
5. Agree domain-specific eligibility, intended lookup population, development/evaluation split policy, and rules for operational versus empirical parameter choices.

**Deliverables:** `notes/study-release-contract.md`, versioned input manifest, owner/dependency tracker, and responses to source questions below. **Acceptance:** every required input has a verified hash, owner, semantic definition, and known limitations. This accepts release identity and an investigation plan, not analytical readiness.

**Storage and handoff:** commit the release contract, owner tracker, and input
manifest snapshot to GitHub. Record exact R2 input keys, versions, and hashes,
the producing commit, and commands in the handoff template. Establish who can
upload and who adopts releases. This documentation package needs no new
analytical dataset; confirm that downstream workers can retrieve its frozen
inputs. Do not change the authoritative production manifest at this stage.

## W1 — EUR interval reconstruction and export validation

**Suggested owner:** PRU data-processing worker. **Dependencies:** W0; local raw segment access. **Priority:** critical.

Inspect `R/eur-milestone-harmonization.R`, `R/level-off-milestones.R`, and scripts 04–08. Trace repeated starts/multiple ends to PRU source segment IDs and chronological source records. Review alternating LVL pairing and implicit-end state logic. Establish the source meaning before replacing it; do not use arbitrary earliest-end selection or deduplication as a repair.

Validate `(flight, segment)` uniqueness, one start/one end, interval ordering, parent-flight bounds, intersections, altitude stability, and cumulative fuel. Recover segment distance from trustworthy source fields. Replace altitude-only phase assignment with agreed milestone-window context and review the uppercase/raw-label mismatch in script 07. Check whether script 08 exports the intended harmonised milestones or an earlier enriched input. Resolve local `data-store/production` versus manifest `processed` paths through the release steward.

**Deliverables:** candidate EUR artifacts, corrected producer code if supported, source-trace examples retained locally, aggregate before/after checks, and excluded/ambiguous case counts. **Acceptance:** no unexplained duplicate interval keys, extra ends, overlaps, out-of-bounds intervals, or negative exposures among retained analytical intervals; explicit provenance for every inferred boundary. Preserve flags and exclusions for unresolved cases. For this substantive repair, add targeted regression cases for repeated ends, co-timed roles, missing ends, step climbs, and phase-boundary clipping, plus whole-release reconciliation checks.

**Storage and handoff:** commit producer changes, checks, and aggregate
before/after evidence to GitHub. Upload candidate EUR milestone and level-interval
Parquet files, plus reusable flight/interval eligibility flags, to R2 under new keys
such as `derived/eur/study-runs/<run-id>/W1/`. Supply a run manifest with input
and output hashes, schemas/units, producer commit, commands, and verified upload
status. Keep restricted source traces locally. W3 requires the actual retrievable
candidate data; a code-only PR does not satisfy this handoff. If upload is
unavailable, return the local package and identify upload as pending. Preserve
current production objects and their authoritative manifest.

## W2 — CHN distance, boundaries, and fuel validation

**Suggested owner:** CAUC QAR worker with operator/source access. **Dependencies:** W0. **Priority:** critical; can run alongside W1.

Inspect extreme and normal examples from every source batch. Recalculate path distance from source coordinates and compare with recorded ground speed and elapsed time. Check coordinate scaling/encoding, jumps, duplicated/unsorted records, units, gap interpolation, and forward-increment alignment. Avoid assuming that every inflated path shares one conversion error. Rebuild dependent distance anchors after any correction.

Investigate missing ALDT by batch/type/route; source evidence must support reconstructed landing events. Verify TOC/TOD definitions against capped, stepped, and short profiles. Confirm engine fuel-flow units and sum, original/cleaned fuel, spike rules, gap treatment, and cumulative-value timestamp alignment. Historical plausibility checks do not establish all new-batch units. Produce comparable domain flags, including unknown detection coverage.

**Deliverables:** candidate CHN release, source preparation/version note, distance reconciliation summary, boundary attrition table, fuel integration checks, and batch-level exception report. **Acceptance:** no unexplained time/distance contradictions in retained distance-eligible observations; ordered and source-supported boundaries for each phase-eligible observation; independent fuel accounting checks; clearly reported unresolved data. Test known coordinate/unit, duplicate-time, integration-boundary, missing-landing, and gap cases when repairing these calculations.

**Storage and handoff:** commit processing code, source-method notes, and
shareable aggregate checks to GitHub. Upload candidate CHN milestones, level
intervals, regenerated dependent phase summaries, and reusable eligibility flags
to R2 under new keys such as `derived/chn/study-runs/<run-id>/W2/`. Where a dependent
product cannot be regenerated, mark it unavailable or superseded explicitly.
Supply input/output hashes, schemas/units, producer commit, commands, parameter
configuration, and verified upload status in the run manifest. Raw QAR and
restricted traces stay in the authorised source environment. If upload is
unavailable, package outputs locally and mark upload pending. Preserve current
production objects and their authoritative manifest; W3 needs the actual data,
not only a report of corrections.

## W3 — Harmonised phases and independent profile descriptors

**Suggested owner:** joint analytical-data worker. **Dependencies:** W1 and W2 candidate evidence; can design tables before repair. **Priority:** critical.

Build `flights`, `phase_intervals`, `level_intervals`, and flight-phase `profile_descriptors` to the contract in the methodological note. Preserve physical and legacy phase schemes separately. Define true zero versus missing level evidence. Reconcile phase fuel/time/distance to airborne totals. Clip intervals to windows and use cumulative quantities at boundaries. Review TOC/TOD and pressure-altitude/AGL conventions; high-elevation ZPPP needs explicit attention.

Map exact aircraft types and report counts before/after eligibility. B737-MAX remains unresolved; C919 stays CHN-only. Create missing-data and common-support flow tables; compare included/excluded flights by batch, month, type, and route direction. Keep kg/min and kg/NM eligibility separate.

**Deliverables:** reproducible analysis-table builder, data dictionary, attrition/support tables, and stratified profile-review pack. **Acceptance:** unique analytical keys; phase additivity; level union time within eligible phase time; complete provenance; every exclusion explained; no fuel-dependent class assignment. Repeated records and a true no-level flight must have different, tested outcomes.

**Storage and handoff:** commit the builder, dictionary, and aggregate
attrition/support evidence to GitHub. Upload to R2: `flights`, `phase_intervals`,
`level_intervals`, `profile_descriptors`, and eligibility tables as Parquet
artifacts under `derived/study-runs/<run-id>/W3/`. Implement W0's development/
evaluation split policy before parameter tuning and save flight-level split
membership and its seed/configuration alongside these artifacts. Complete the
run manifest with source input hashes, output keys/hashes, schemas/units,
producer commit, commands, and upload verification. Restricted review examples
stay local. W4–W6 must be able to retrieve the exact frozen tables and split;
report local-only packages as upload pending and preserve production releases.

## W4 — Parameter trials and operational review

**Suggested owner:** methods worker plus operational reviewer. **Dependencies:** W3; access to source profiles for detector changes. **Priority:** high.

Trial the D01–D13 register in `technical-note-methodology.qmd`. Begin with one-factor screening on a reviewed sample. Test vertical rate 200/300/400 ft/min, duration 20/30/60/120 s, altitude range 100/200/300 ft, and source-appropriate smoothing/gaps. These are candidates. Existing delivered intervals may already exclude short events; rerun detection upstream where necessary. Downsample QAR to representative EUR cadence rather than assuming detector equivalence.

Compare continuous altitude/stage-length descriptions with provisional bins and shifted cut points. Define low/typical/high interruption independently of fuel, using operational cuts or development-only quantiles. Examine class transitions and common-support loss. Test sparse-cell rules at proposed independent-flight minima 30/50/100 and uncertainty/route diversity criteria; none is a universal standard.

**Deliverables:** `parameter-trials.csv`, reviewed examples, coverage/class-stability results, and adopted decision register with rationale. **Acceptance:** methods and operating windows are defensible, sensitivity is reported, tuning uses development data, and the final configuration is frozen before W5 evaluation. If profiles add unstable sparsity, retain continuous descriptors or the simpler lookup.

**Storage and handoff:** commit the trial code, shareable aggregate
`parameter-trials.csv`, operational review, and decision register to GitHub.
Store the selected machine-readable configuration (including bins, class rules,
and seeds), reusable trial results, and any revised profile/class-assignment
tables in R2 under `derived/study-runs/<run-id>/W4/`. Flight-level assignments
belong in R2. Record configuration and data hashes, W3 input/split references,
producer commit, reproduction commands, and verified upload status in the run
manifest. A proposed configuration awaiting review remains a candidate; keep
its selection status explicit. Report unavailable uploads as pending and leave
production releases intact.

## W5 — Lookup estimation, holdout validation, and transfer

**Suggested owner:** statistical modelling worker. **Dependencies:** adopted W3 tables and W4 configuration. **Priority:** main scientific result.

Compare M0 exact type×phase coefficients, M1 adding stage-length context, and M2 adding interruption/altitude context. State whether the target is the typical-flight rate, exposure conversion, or phase fuel. Avoid allowing flights with many segments to dominate. Report independent flight counts and metric-specific samples.

Use blocked flight/date splits with route-holdout sensitivity; all rows of a flight stay together. Compare methods on identical eligible evaluation observations. Report MAE, bias, paired error changes, coverage, support, and uncertainty; calibrate any predicted quantiles. Test P10/P20/P25 and P75/P80/P90 against median/weighted coefficients; retain percentile outputs only where interpretable and stable. Benchmark gaps remain descriptive, signed, and distinct from causal savings.

Keep source-specific coefficients primary. Test CHN→EUR and EUR→CHN transfer on common support and report bias and support loss. If possible, coordinate an owner-run AEM-versus-QAR bridge on identical trajectories and record model configuration. No bridge means source effects remain inseparable from regional effects.

**Deliverables:** versioned lookup CSV, baseline/enrichment evaluation table, interval/quantile stability diagnostics, support/fallback metadata, and reproducible figure scripts. **Acceptance:** no tuning leakage; all unsupported cells explicit; practical improvement and bias reviewed against a prespecified criterion; no claim that P50−P20 is achievable savings. A null result is accepted evidence for a simpler coefficient table.

**Storage and handoff:** commit estimation/evaluation code, shareable aggregate
tables/figures, and the evidence report to GitHub. Upload the candidate lookup
CSV, cell support/fallback metadata, flight-level held-out predictions/errors,
evaluation metrics, and fitted model objects where required for reuse under
`derived/study-runs/<run-id>/W5/`. Reference the frozen W3 split and W4
configuration; store any additional resampling membership/seeds. Include metric
units, estimator definitions, input/output hashes, producer commit, commands,
and verified upload status in the run manifest. A shareable lookup copy may also
be tracked in GitHub, with the same hash and identified canonical R2 key.
Promotion to the production lookup release belongs to the release steward.
Package unavailable uploads locally and mark the empirical handoff pending.

## W6 — Cruise altitude/duration and earlier spurious-results study

**Suggested owner:** operational performance worker with CAUC input. **Dependencies:** validated relevant W1–W4 fields; exploratory design can start earlier. **Priority:** secondary; may remain wholly in the Technical Note.

Recreate the legacy relationship, then compare pooled versus within-type/route direction patterns. Recompute with physical TOC–TOD, corrected distance, reviewed boundaries, and whole-airborne fuel. Use time-weighted altitude and altitude residence rather than endpoint averages. Separate fuel rates at comparable context from total cruise fuel and total airborne fuel. Show the decomposition of climb/cruise/descent time and fuel when cruise duration changes.

Consider available mass, speed, winds, batch/day, and operator information; list unavailable confounders. Evaluate a small altitude×duration interaction only with support. Do not interpret observed altitude as an ATM restriction without requested/optimal/available level evidence. Retain reversed or absent associations and check phase reallocation, mixture effects, and selection from missing ALDT.

**Deliverables:** pooled/stratified comparisons, exposure-supported response plot if feasible, phase fuel/time decomposition, and a written explanation of which mechanisms the evidence supports. **Acceptance:** results survive relevant data checks or are explicitly inconclusive; no imposed “higher is better” monotonicity; no extrapolation to unobserved altitude/duration combinations.

**Storage and handoff:** commit side-study code, shareable aggregate comparisons,
figures, and interpretation to GitHub. Upload reusable cruise-study tables,
phase decompositions, fitted estimates, and diagnostic/evaluation outputs under
`derived/study-runs/<run-id>/W6/`; retain flight-level data in R2 rather than
GitHub. Return a manifest with exact upstream data/configuration hashes, output
keys/hashes and schemas/units, producing commit, run commands, and upload
verification. Inconclusive results still require the evidence artifacts.
Identify any local-only package as upload pending and preserve production data.

## W7 — Conference manuscript and Technical Note integration

**Suggested owner:** lead author/editor jointly with PRU and CAUC. **Dependencies:** drafting can start now; numerical results require W5 and selected W6 evidence.

Use the exploratory draft as the argument source and `paper.qmd` as the future concise manuscript. Allocate eight IEEE double-column pages: introduction/abstract/title 1.0, data 1.0, methods 1.5, results 2.0, validation 1.0, discussion/conclusion 0.75, references 0.75. Aim for a common-contract figure, a profile example, one baseline/enrichment comparison, a support/lookup table, and only the most informative sensitivity result. Verify the actual layout and PDF file size; default Quarto PDF is not the required template.

Keep full parameter trials, source checks, detailed attrition, bridge study, and optional cruise results in the Technical Note. The paper must be self-contained; do not assume an external note bypasses the eight-page limit on supplementary material. Rewrite the abstract and claims around validated final evidence, including null findings. Authors review definitions, affiliation details, provenance, and permitted aggregate disclosure before submission.

**Deliverables:** reviewable manuscript, supporting Technical Note, reproducible figures/tables, evidence-to-claim checklist, and render instructions. **Acceptance:** each numerical claim is reproducible from the adopted release; no diagnostic delivered-row table presented as validated coefficients; maximum eight pages including references/appendices and PDF ≤6 MB; source-versus-region confounding and key sensitivity stated.

**Storage and handoff:** commit manuscript/note sources, render instructions,
the evidence-to-claim checklist, and shareable final figures/tables to GitHub.
Archive review/submission renders explicitly as GitHub release assets or another
agreed durable destination; `_output/` alone is not an archive. Link every
numerical result to its adopted R2 artifact key/hash and producing commit.
Include the adopted release manifest snapshot and hashes of archived renders
in the handoff. No duplicate flight-level dataset is needed for this editorial
package. Report manuscript approval and conference submission separately;
preparing this package does not authorise submission or production promotion.

## Proposed schedule and decision gates

The official deadline is **30 October 2026**. These are planning targets, not commitments from colleagues.

| Dates | Target and gate |
|---|---|
| 9–12 October | W0 snapshot and definitions; W1/W2 investigate and produce traceable candidate repairs |
| 13–16 October | Gate A: corrected or explicitly restricted analysis release; W3 phases/profiles and selection report |
| 17–20 October | Gate B: W4 operational review and parameter freeze; W5 estimation; W6 side study |
| 21–24 October | Gate C: held-out evidence and stable lookup scope; main figures and complete manuscript draft |
| 25–27 October | Joint author review; resolve claims and methodological objections; IEEE layout |
| 28–29 October | Final verification, eight-page/6 MB check, reproducibility review, submission-ready package |
| 30 October | Author-controlled conference submission |

At Gate A, if source issues remain, restrict analyses by valid domain with transparent attrition. A kg/min-only study is possible only if phase boundaries and fuel/time pass independently; distance-derived boundary defects can still invalidate it. If one source cannot support comparable profiles, narrow the paper to a validated single-source case study plus the international contract and limitations, subject to joint author agreement. Do not manufacture comparison coefficients to preserve the original scope.

At Gate B, if profile classes are unstable, retain continuous interruption descriptors or M0/M1. At Gate C, if enrichment does not improve estimation, report that result and the conditions under which a simpler lookup is adequate. If the cruise study is unresolved, keep it in the note as an identified validation question rather than an asserted altitude penalty.

## Source questions to resolve in the work packages

**CAUC/QAR:** Which producer code/version generated each batch? Are coordinates/altitudes/fuel-flow units declared? What are cumulative-value timestamp conventions and gap/spike rules? Why are ALDT events absent on certain flights? Are weight, GS/TAS, wind/temperature, tail ID, and requested cruise level available in the owner's environment? Which detector settings and clock/altitude references were used? Can reviewed examples and the bridge study run locally without sharing raw QAR?

**PRU/EUR:** What do raw LVL rows denote, and are trustworthy source interval IDs available? Which AEM/BADA version, aircraft/engine configuration, mass, atmosphere, and trajectory inputs were used? Can source segment distances and source phases be preserved? Which export stage produced the canonical release, and why are paired level and directional FL markers absent? Are source clock values true instants or local wall times?

**Joint authors:** Who owns each work package? Which operational hypotheses are primary, what constitutes practically useful predictive improvement, and what disclosure level is permitted? How will the independent Technical Note be hosted/cited within conference rules? These questions do not prevent the read-only audit, design work, or source-local investigation from proceeding.

## Worker handoff format

Every worker returns: input release hashes; code/version and commands; outputs with schema/units; sample flow and exceptions; decisions made versus decisions still proposed; checks performed and failures; sensitivity results including null findings; and a short recommended paper claim with its limitations. Keep flight-level traces in the authorised local data environment and share aggregate evidence. The coordinator reviews the handoff before adopting a release or final parameter choice.

## Storage and completion contract for delegated workers

GitHub and R2 hold complementary parts of a completed work package. A GitHub
report alone does not complete a task that produces analytical data needed by
later workers. The current `.gitignore` excludes `outputs/`, `data-derived/`,
`figures/`, `_output/`, and local data stores, so a normal commit does not archive
those results.

| Output | Durable destination | Required handoff |
|---|---|---|
| Code, commands, methodology, decisions, validation narrative | GitHub branch/PR or commit | Commit SHA, changed files, reproduction command, checks and limitations |
| Small aggregate tables/figures suitable for sharing in the repository | Explicitly tracked GitHub results folder, for example `notes/results/<work-package>/<run-id>/` | Caption, units, denominator, input release and producing code; review disclosure before tracking |
| Candidate corrected EUR/CHN milestones and level intervals (W1/W2) | R2, versioned candidate keys in the appropriate source's derived area | Input/output hashes, schema, producer commit, validation summary, candidate status |
| Flight, phase, level, profile, eligibility, and evaluation-split datasets (W3–W5) | R2, versioned derived study artifacts | Stable keys, units, flags, parameter/split version, dependencies and hashes |
| Parameter trials, model/evaluation outputs, cruise side-study results (W4–W6) | GitHub for shareable compact evidence; R2 for reusable data or larger artifacts | Enough outputs to review the result and reproduce downstream steps |
| Adopted canonical products and approved lookup release | R2 production release, with publication metadata/code in GitHub | Steward-reviewed release and authoritative manifest update |
| Raw or restricted flight-level review material | Existing authorised source environment; R2 only where sharing is already authorised | Local provenance and aggregate review evidence; no raw traces in GitHub |

Each run should have a stable ID and a machine-readable artifact manifest
(CSV or JSON) recording object key, SHA-256, size, schema/units, input artifact
hashes, producing Git commit, command, parameter configuration, creation time,
and candidate/adopted status. The GitHub handoff links to the R2 keys and run
manifest without including credentials. Candidate manifests are separate from
`manifest/current-artifacts.csv`; only the release steward promotes adopted
artifacts into the authoritative production manifest. Retain prior releases.

Where authorised, workers upload candidate results under new versioned keys and
verify the stored hashes. They do not overwrite production objects or promote
their own candidate simply because checks passed. If a worker lacks R2 access,
it returns the complete local artifact package and manifest, explicitly marks
upload as pending, and identifies the uploader. Downstream work requiring those
data waits for upload and verification; code-only delivery is not described as
a completed empirical study.

Mandatory instruction to include when dispatching a data-producing work package:

> Return code and a concise evidence report in GitHub, together with the actual
> reusable data artifacts in the project's authorised R2 store under versioned
> candidate keys. Include input/output hashes, producing commit, run command,
> parameters, schemas, sample flow, and validation results. Preserve the current
> production release. If upload or source access is unavailable, package the
> outputs locally and report the missing step explicitly. Do not claim the
> empirical task complete based on a narrative or code changes alone.

## Sources

[Organiser's submission guidelines](https://easychair.org/cfp/AICAP-2027) and [official conference page](https://event.ntu.edu.sg/AICAP-2027), verified 9 October 2026. The NTU call-for-papers subpage supplied in the request was inaccessible during the review; the organiser's EasyChair listing specifies the format rules.
