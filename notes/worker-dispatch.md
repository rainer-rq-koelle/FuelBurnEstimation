# Pinned worker dispatch — AICAP 2027

Repository: https://github.com/rainer-rq-koelle/FuelBurnEstimation

**Instruction commit:** `1438f500003ffed0e53bd0d6037411120ef4ead5`

All workers use the definitions at this exact commit. This dispatch document is
published afterwards so it can name the completed instruction commit without a
self-reference. Read the linked versions below, rather than moving `main`, for
the agreed baseline. Worker changes belong on their own branches and produce
new commits; record both the instruction commit and producing commit in handoffs.

## Instruction set

1. [Worker plan and package-specific storage requirements](https://github.com/rainer-rq-koelle/FuelBurnEstimation/blob/1438f500003ffed0e53bd0d6037411120ef4ead5/notes/study-worker-plan.md)
2. [Methodological Technical Note](https://github.com/rainer-rq-koelle/FuelBurnEstimation/blob/1438f500003ffed0e53bd0d6037411120ef4ead5/technical-note-methodology.qmd)
3. [Worker handoff template](https://github.com/rainer-rq-koelle/FuelBurnEstimation/blob/1438f500003ffed0e53bd0d6037411120ef4ead5/notes/worker-handoff-template.md)
4. [Readiness audit script](https://github.com/rainer-rq-koelle/FuelBurnEstimation/blob/1438f500003ffed0e53bd0d6037411120ef4ead5/scripts/12-audit-study-readiness.R)
5. [Exploratory paper](https://github.com/rainer-rq-koelle/FuelBurnEstimation/blob/1438f500003ffed0e53bd0d6037411120ef4ead5/paper-exploratory-2026.qmd)
6. [Data-preparation Technical Note](https://github.com/rainer-rq-koelle/FuelBurnEstimation/blob/1438f500003ffed0e53bd0d6037411120ef4ead5/technical-note-data-preparation.qmd)
7. [Project setup and R2 workflow](https://github.com/rainer-rq-koelle/FuelBurnEstimation/blob/1438f500003ffed0e53bd0d6037411120ef4ead5/README.md)

## Initial dispatch: W0

Copy the following prompt to the first worker. Paths in the prompt are relative
to the repository root so they work on another machine.

```text
Repository: https://github.com/rainer-rq-koelle/FuelBurnEstimation
Instruction commit: 1438f500003ffed0e53bd0d6037411120ef4ead5
Work package: W0 — Coordinator and release steward

Use a clean checkout or isolated branch based on the instruction commit.
Follow the repository's rq/ branch convention. Preserve existing local work.
Read notes/study-worker-plan.md, technical-note-methodology.qmd,
notes/worker-handoff-template.md, README.md, and the relevant exploratory
paper/data-preparation note at that exact revision.

Complete W0's release-contract and readiness handoff. Identify the input
artifacts and verify their hashes against the selected R2 manifest. Run
Rscript scripts/12-audit-study-readiness.R where the required local data and
dependencies are available. Distinguish release identity from analytical
validity. Record source definitions, configuration provenance, unresolved
questions, ownership, and dependencies for W1/W2. Unconfirmed owner or source
information must be marked pending rather than invented.

Return a GitHub PR with notes/study-release-contract.md, a frozen input
manifest snapshot, an owner/dependency tracker, shareable aggregate readiness
evidence, and a completed handoff report in
notes/results/W0/<run-id>/ using notes/worker-handoff-template.md.
Use a unique run ID and record the instruction commit, actual producing
commit, input keys/hashes, commands, runtime, and checks.

Follow the package's GitHub/R2 storage and completion contract. W0 does not
require a new analytical dataset; establish that downstream workers can
retrieve the frozen inputs. If any reusable analytical artifacts are created,
store them only in authorised R2 candidate locations under new versioned keys
and supply a machine-readable artifact manifest and stored-hash verification.
If source data or R2 access is unavailable, complete independent documentation
and report the affected checks/delivery as pending. Package any generated
data locally for an authorised uploader; do not claim missing checks passed.

Keep credentials in the execution environment, outside prompts and GitHub.
Preserve production objects and manifest/current-artifacts.csv. Candidate
publication does not authorise production promotion. Do not launch other
workers, contact colleagues, or submit the conference paper in this package.
```

## Subsequent worker dispatches

Keep the same instruction SHA and replace W0 with the selected work package.
Include that package's full task, acceptance criteria, and storage paragraph.
Provide the accepted upstream handoff commits plus exact R2 keys/hashes; do not
infer accepted data from whichever artifacts happen to be newest in R2.
W1/W2 follow the W0 contract; W3 needs their accepted candidate artifacts;
W4/W5/W6 follow the dependency gates in the plan.

Data-producing packages must return both a reviewable GitHub result and the
required retrievable R2 artifacts, or explicitly mark data delivery pending.
Production adoption and the authoritative manifest update remain a separate
release-steward action. Any later change to these baseline instructions needs
a new explicitly named instruction revision in the dispatch and handoff.
