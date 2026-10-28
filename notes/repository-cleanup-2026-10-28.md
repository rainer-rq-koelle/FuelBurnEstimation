# Repository cleanup — 28 October 2026

The user initially approved integrating the paper work into `main`, simplifying
the README, then retiring superseded branches and chats. Evidence was to be
preserved; restricted data and W2 history were held out of that first pass.
The follow-up below records the subsequent approval to complete local
housekeeping and retire the remaining worker branches after retaining lessons.

## Integration and documentation

- [PR #5](https://github.com/rainer-rq-koelle/FuelBurnEstimation/pull/5)
  merged the six paper/helper commits after the earlier EUR PR into `main`.
  Merge commit: `cdccac6c060d1e51270a15c13c8d9c4f8b555cb8`.
- The merged tree was verified identical to paper baseline
  `189557766cee7e4ce901fc1cd33da948816a6879` before documentation cleanup.
- README commit `bbc0ed39851b95bd4b0f2921d3432d05e181101c` makes the conference
  paper and full Technical Note the entry point, identifies their pinned inputs,
  separates rendering from intentional analysis rebuilding, and labels earlier
  FIXED/worker workflows as historical. Original documentation remains in Git
  history; supporting evidence and historical source files remain in place.

## Retired branch names and recovery

Recovery tags were pushed and verified before branch deletion. Unique unmerged
work was preserved without merging its obsolete implementation into `main`.

| Retired branch | Preserved tip | Recovery |
|---|---|---|
| `rq/eur-parallel-preprocessing` | `189557766cee7e4ce901fc1cd33da948816a6879` | Merged into `main`; tag `paper-baseline-2026-10-28` |
| `rq/eur-level-segments` | `e09d790574e3214bf662c2087c7c295ac0416903` | Tag `archive/2026-10-28/eur-level-segments` |
| `rq/w1-eur-diagnostic-clean` | `3ae337a2331b662d2cef732e9fefd55a1b418d58` | Tag `archive/2026-10-28/w1-eur-diagnostic-clean` |
| `w0-release-contract` | `3934335885a9dbeb006a3f0b6f28b12b94d5691a` | Already merged into `main` through PR #1 |

All four remote branch names and the three corresponding local topic branches
were removed. [W1 PR #2](https://github.com/rainer-rq-koelle/FuelBurnEstimation/pull/2)
was closed as superseded; its original body, diagnostic evidence and validation
script were retained. To inspect archived evidence without restoring a branch:

```sh
git show archive/2026-10-28/w1-eur-diagnostic-clean:notes/results/W1/W1-2026-10-12-001/README.md
git show archive/2026-10-28/eur-level-segments:R/eur-level-segments.R
```

## Archived chats

The following completed chats were archived, not deleted:

| Chat title | Chat ID |
|---|---|
| Set up fuel burn project | `01a10c3a-5edf-7121-9c56-e54e75c9bace` |
| Set up data storage | `01a11b62-0ef6-7f82-88b3-e956333691f5` |
| Complete EUR data prep and R2 publish | `01a11c0b-fb13-7c73-b78a-ba0d0d41474d` |
| EUR "parallel" data & framework | `01a120a3-ebf7-7033-8b31-fdbebfa102d1` |
| Audit CAUC QAR verification data | `01a14e0b-e9da-7a11-b4e2-79e6110a2b92` |

**Develop regional flight paper** (`01a14fc6-4386-7421-88db-6677728b0898`) remains
unarchived for paper review and development. The README preserves the EUR
unchanged-until-further-notice decision and deferred CHN decoder work; detailed
cohort handovers remain in `notes/`.

## Initial W2 hold (lifted in the follow-up)

The first pass retained the following remote branches at their original tips
because they contained W2 work, including the two whose names start with W1:

| Branch | Unchanged tip |
|---|---|
| `w1-eur-diagnostic-clean` | `42ecce339c870c32c9afc376aabccb706b2ee06a` |
| `w1-eur-interval-diagnostic` | `bb7368aaf75529d3eab26eec00aae7879367ab9d` |
| `w2-chn-validation-clean` | `2af7870b5f697f2126c60fed8d00372b6b14faca` |

[W2 PR #3](https://github.com/rainer-rq-koelle/FuelBurnEstimation/pull/3) remained
open after that first pass. No history rewriting, restricted-data deletion, R2
operation, canonical regeneration or analysis rebuild was performed. The
exploratory stash, render caches, local exports and stale temporary-worktree
registration were left for the follow-up.

## First-pass verification

- All 110 pinned input hashes, 28 conference source hashes, 23 conference product
  hashes, 33 descent/enroute product hashes and four document export hashes match.
- All analysis loaders used by both current documents passed without rebuilding.
- README checks validated 32 local links and 12 executable command targets.
- The README diff passed whitespace checks. Pre-existing whitespace in historical
  session logs/evidence was deliberately retained to preserve the recorded files.
- Remote tags and remaining branch tips were checked; PR #5 is merged, PR #2 is
  closed, and PR #3 was still open at its original head at that point.

## Follow-up: local housekeeping and worker retirement

The user then approved removing the exploratory stash/cache and missing worktree
registration, and retiring the remaining W1/W2 work after extracting useful
lessons. Paper exports, analysis caches and restricted data were to remain untouched.

Completed actions:

- Dropped the exact exploratory stash
  `2a7645852f3b36395a4ffd1d072fffecda8f95f6` (the only stash).
- Removed only `paper-exploratory-2026_cache/`: four files, 89,619,121 bytes
  (approximately 85.5 MiB). General Quarto metadata and all other caches remain.
- Pruned the registration for the already missing
  `/private/tmp/fuelburn-w0-final-fix`. The main checkout is the only worktree.
- Reviewed the original and corrected W1/W2 reports against the later EUR
  parallel build, CHN helper validation and returned-batch audit. Recorded the
  reusable findings in [preprocessing lessons learned](preprocessing-lessons-learned.md).
- Closed W2 PR #3 and deleted the three remaining remote branches listed above,
  using their exact expected tips as deletion guards. No W1/W2 code or flags were
  merged into the paper baseline. Only `main` remains as a local/remote branch.
- Retained existing recovery tags and historical evidence. No new W2 archive
  branch/tag was created, and no Git history rewrite or PR-record erasure occurred.

Verification compared a complete before/after inventory of `.fuelburn-data-store/`,
`outputs/`, `_output/` and `data-derived/`: all **6,135 files**, totalling
**9,106,603,166 bytes**, retained their sizes, modification times and SHA-256 hashes.
This includes the paper exports, analytical caches and restricted source/derived
data. No protected file was added or removed. The stash list is empty, the
exploratory render cache is absent, and the missing worktree registration is gone.
Documentation links and whitespace checks passed. No scientific rebuild or
document render was needed.

## Source and worker note cleanup

The next approved pass removed obsolete scripts and coordination notes while
retaining the dependencies of the current paper and Technical Note. The complete
pre-removal revision is `9bdd2af033f62d0df9d72006a7a06ff1a10ba30a`.

### Removed files

| File | Reason |
|---|---|
| `scripts/09-upload-eur-fixed-to-r2.R` | One-off FIXED release upload |
| `scripts/10-cleanup-intermediate-files.R` | Obsolete storage paths and destructive intermediate cleanup |
| `scripts/11-update-r2-registry-for-fixed.R` | One-off source-rewriting registry patch |
| `scripts/90-check-data-store.R` | Duplicate early storage checker with superseded folder assumptions |
| `scripts/clean-manifest.R` | One-off manifest reconciliation for the older release |
| `scripts/diagnose-manifest-r2-mismatch.R` | One-off earlier manifest/R2 investigation |
| `scripts/update-r2-registry.R` | One-off source-rewriting registry patch |
| `scripts/update-reconstruct-function.R` | One-off source-rewriting reconstruction patch |
| `scripts/upload-fixed-to-r2.R` | One-off FIXED source upload |
| `scripts/upload-chn-summer2025-to-r2.R` | One-off earlier CHN release upload |
| `scripts/audit-pru-lvl-completeness.R` | Unused early LVL exploratory diagnostic |
| `scripts/diagnose-lvl-imbalance.R` | Unused early LVL exploratory diagnostic |
| `scripts/inspect-raw-pru-lvl.R` | Unused early LVL exploratory inspection |
| `scripts/test-eur-canonical-import.R` | Ad hoc import smoke script for the older canonical release |
| `notes/study-worker-plan.md` | Completed or superseded worker/setup coordination |
| `notes/worker-dispatch.md` | Completed or superseded worker/setup coordination |
| `notes/worker-handoff-template.md` | Completed or superseded worker/setup coordination |
| `notes/mac-verification-request.md` | Completed or superseded worker/setup coordination |
| `notes/r2-verification-request.md` | Completed or superseded worker/setup coordination |
| `notes/level-segment-completion-report.md` | Completed or superseded worker/setup coordination |
| `notes/EUR-FIXED-R2-Upload-20261009.txt` | Completed or superseded worker/setup coordination |
| `notes/handover-2026-10-05.md` | Completed or superseded worker/setup coordination |
| `notes/up-to-speed.md` | Completed or superseded worker/setup coordination |

Fourteen scripts and nine coordination notes were removed (111,740 source bytes).
Their exact original contents remain in the published Git history; no data files
were removed in this pass. To inspect an original file without restoring clutter:

```sh
git show 9bdd2af033f62d0df9d72006a7a06ff1a10ba30a:scripts/update-reconstruct-function.R
git show 9bdd2af033f62d0df9d72006a7a06ff1a10ba30a:notes/study-worker-plan.md
```

### Retained dependency boundary

- Both current QMD sources, shared styles/bibliography, all `R/`, `config/`,
  `helpers/` and `tests/` files remain byte-identical.
- All `notes/results/` evidence, input/source/product manifests and the W0
  checksummed release contract remain byte-identical. The G2G pilot and its
  reproduction script are retained because they support the lessons learned.
- Paper scripts 13–22, upstream eligibility assessments, EUR parallel builders,
  source extraction, CHN helper construction/validation and evidence-producing
  diagnostics remain. An absent filename reference alone did not justify removing
  a helper-validation or data-producer script.
- Generic R2 storage utilities and their checker remain. Earlier data producers
  referenced by the storage registry or retained historical evidence also remain;
  the removed upload/patch wrappers are not required to regenerate their data.
- The preprocessing lessons note is unchanged. No scientific result, eligibility
  rule, input pin or numerical coefficient was changed.

### References and checks

The review scanned tracked code/document references, manifest paths and checksum
records before removal. No surviving executable source references a removed
script. README links and three historical QMD references were updated; the old
FIXED pipeline document now explicitly resolves retired commands at the original
revision above. Frozen W0 evidence still mentions the original worker-plan paths:
those are historical references to that revision, and were not edited to avoid
invalidating evidence hashes.

Completed validation:

- All document analysis loaders passed without rebuilding.
- `tests/paper-window-adoption.R` passed its cohort, window independence,
  terminal pairing, roll adjustment, date and exposure-accounting checks.
- `tests/paper-profile-class-adoption.R` passed its input immutability,
  independent profile/fuel eligibility, unknown accounting and provenance checks.
- All 335 protected source/evidence files retained their SHA-256 hashes.
- All 6,135 protected restricted-data, analysis-cache and export files retained
  their inventory, sizes, modification times and SHA-256 hashes.
- Retained Python sources parse; changed documentation links and whitespace
  checks pass. No removed path is referenced by surviving executable code.

Full data regeneration and document rendering were intentionally not performed;
the checks exercised the retained loaders/tests while preserving the pinned
analyses and exact review exports.
