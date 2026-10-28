# Lessons from the retired W1/W2 preprocessing work

Recorded 28 October 2026 when closing the original worker effort. W1 and W2
identified useful failure patterns but did not deliver the corrected, validated
inputs needed by the study. They are retired, not pending work packages.

The current study instead adopts **EUR parallel preprocessing
`EUR-2026-10-13-002`** and the **CHN candidate.6 full-batch return
`CHN-2026-10-27-001`**, through the
[paper configuration](../config/paper-analysis-2026-10-27.json) and
[pinned input hashes](../config/paper-analysis-2026-10-27-inputs.csv).
These are the frozen basis for the current paper. W1/W2 counts, flags and
recommendations must not be substituted for those adopted inputs.

## What is worth retaining

### 1. Establish source semantics before reconstructing events

W1 proposed explanations for duplicate/overlapping intervals but lacked the
source evidence to validate them. In particular, alternating `LVL` labels did
not establish start/end pairs, and a proposed segment-ID interpretation of
`SAM_ID` was not established. The adopted EUR release uses `SAM_ID` as the
source flight identity, not as a justification for pairing arbitrary level events.

The later [G2G pilot](results/W1/W1-2026-10-12-002-G2G-pilot/README.md)
made the limitation concrete: 51.3% of tagged flights in its three-day sample
had odd tag counts, and 59.7% of naive pairs differed by more than 1,000 ft.
Those are sample diagnostics, not current-release error rates.

**Carry forward:** document event labels, identity keys, units and interval
attribution; trace representative source records before scaling a transformation.
The [parallel release](results/EUR/EUR-2026-10-13-002/README.md) combines explicit
G2G/M3 provenance with accepted CCO/CDO intervals and preserves unresolved cases.

### 2. Distinguish a plausible explanation from a demonstrated cause

An early W2 completion report described a cumulative-versus-incremental distance
error as established. Its corrected report subsequently found that the inspected
helper already used cumulative differences and left the cause unresolved pending
raw QAR and producer-version checks. The initial explanation was not a validated fix.

Similarly, plausible aircraft burn rates did not independently validate fuel
units or integration. Ordered milestones did not prove correct event semantics
or explain missing phase rows. A successful diagnostic script can report failing
data-quality checks; its exit alone is not evidence of an acceptable release.

**Carry forward:** label observations, hypotheses, reproduced defects and verified
fixes separately. Require source-backed examples, independent accounting checks
and regressions before claiming a correction or completion.

### 3. Make eligibility specific to the quantity and window

W2's blanket distance rejection and requirement for all airborne phases were
conservative rules for an unresolved older delivery, not a reusable cohort policy.
The assertion that time/fuel were unaffected also required their own clock,
unit, coverage and boundary checks; independence from coordinates alone was
insufficient.

The [candidate.6 return audit](results/CHN/CHN-2026-10-27-001/README.md)
illustrates the difference: 3,552 flights were held from its strict common cohort,
yet 6,388 of the 6,421 source flights retained whole-airborne fuel/time support.
Neither count defines every finer-window analysis.

**Carry forward:** assess fuel, duration, geometry and profile coverage separately
for each requested window. Treat review holds separately from missing source
support. Use the [adopted reference layer](paper-window-references.md), with
denominators reported for each analysis; do not restore W2's old 5,226-flight gate.

### 4. Validate conservation and physical meaning, not just table shape

W1 exposed repeated keys, overlapping intervals and an approximately 57% excess
of summed interval exposure over union exposure in the old audited EUR product.
Zero orphan counts, matching columns and positive durations had not caught the
underlying interpretation problem. A positive distance also does not prove a
physically credible track or fuel-per-distance rate.

**Carry forward:** check uniqueness, overlap/union, boundary support, units,
speed plausibility and fuel/time partition conservation. Preserve original and
adjusted quantities and apply each documented convention only once. The parallel
EUR preparation and current analysis retain separate resolution and eligibility
flags instead of manufacturing unsupported ground events.

### 5. Freeze a verifiable delivery, including the producer

W2 could not establish the exact helper version that produced its batch inputs.
The later helper work supplied a versioned source package, bounded repairs,
domain-specific flags, regression checks and full-batch input/output manifests.
[Candidate.6 validation](results/CHN/CHN-v2-2026-10-22-003/README.md) and the
returned-batch audit made comparisons reproducible. The return audit verified
all 700 supplied checksum entries and the processing-function/configuration
identity, while explicitly recording the remaining CLI/legacy-core hash limitation.

**Carry forward:** record input hashes, complete producer/package identity,
configuration, output hashes and runtime evidence. Compare equivalent review
settings. Explicitly adopt a release; do not silently replace pinned inputs or
broaden repair thresholds to improve a headline acceptance rate.

### 6. Define completion by deliverables and independent acceptance

W1 was blocked on source validation. W2's corrected handoff still lacked a
verified shared delivery of its flags. Neither established a corrected input
release ready for downstream use, regardless of the number of reports produced.

**Carry forward:** check source access and delivery capability before assigning
a repair task. Require a bounded representative case, a demonstrated correction,
regression/conservation evidence and retrievable hash-verified artifacts. Escalate
an access blocker or change the approach rather than repeatedly polishing an
unverified completion report. For this study, that change was EUR parallel
preprocessing and the independently validated CHN helper delivery.

### 7. Verify repository contents, not packaging claims

The final W2 branch still tracked incoming batch data and flight-level flags,
despite its handoff saying the flags were local-only. Mixed W1/W2 branches also
made review and retirement harder.

**Carry forward:** inspect staged paths and the complete proposed Git tree before
publishing. A directory called `local-package` or a commit title saying files were
removed is not an exclusion mechanism. Keep worker branches focused and publish
only source, documentation and shareable aggregate evidence. Restricted artifacts
belong in the approved data store with a separate delivery manifest.

## Reviewed historical sources and disposition

The retrospective used the following historical revisions without adopting their
flags, proposed fixes or completion claims:

- `3ae337a`: W1 diagnostic README and handoff, run `W1-2026-10-12-001`.
- `42ecce3`: mixed W1/W2 diagnostic branch and W1 handoff.
- `bb7368a`: early W2 completion-verification report, which overstated validation.
- `2af7870`: corrected W2 findings/handoff, run `W2-2026-10-09-001`, and tracked-tree audit.

The old worker branch names and PRs are retired; their contents are not merged
into the paper baseline. This note retains the useful lessons. Existing
aggregate evidence, the G2G pilot, current builders/helper, pinned inputs and
scientific reproduction records remain in place. Closing PRs/removing branch
names does not rewrite historical commits or erase GitHub PR records.
