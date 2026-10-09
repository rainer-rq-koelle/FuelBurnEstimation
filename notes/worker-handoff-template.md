# Worker handoff: <work-package> / <run-id>

Copy this template for each worker execution. Replace all placeholders and
record actual evidence. Store the shareable completed report and aggregate
attachments in `notes/results/<work-package>/<run-id>/` in GitHub. Reusable
analytical data go to the authorised R2 candidate location specified in the work
package. Do not include credentials or restricted flight-level traces in GitHub.

## Result and status

- Work package, run ID, worker, and UTC completion time:
- Main finding and proposed paper claim, including limitations:
- Analysis status: implemented but not run / analysed locally / analysed and checked.
- Data delivery status: not required / upload pending / uploaded and hash verified.
- Review status: awaiting review / accepted by the named reviewer, with reference.
- Remaining work, blocker, and responsible person:

An empirical package requiring shared data is ready for downstream use only when
its acceptance checks pass and its required artifacts are retrievable with
verified hashes. A local-only package remains delivery pending. Acceptance of
the work package is separate from adoption as a production release.

## Producing code and reproduction

- Git repository and branch/PR:
- Exact producing commit SHA:
- Relevant files:
- Commands and execution order:
- Runtime/package versions:
- Configuration file/key and SHA-256:
- Random seeds and development/evaluation split artifact/key and SHA-256:

Use the committed producer code for the recorded run. Identify any uncommitted
changes or differences from the input release; do not claim a commit produced
outputs if the working tree had material unrecorded changes.

## Inputs

| Input role | R2 object key or authorised local reference | Version | SHA-256 |
|---|---|---|---|
| <role> | <actual key/reference> | <version> | <hash> |

## Outputs and artifact manifest

Include a machine-readable `artifact-manifest.csv` or JSON equivalent with one
row per output. Record: run ID; work package; artifact role; destination/object
key; format; SHA-256; size in bytes; schema/dictionary reference and units;
input keys/hashes; producing commit; command/configuration reference; UTC
creation time; candidate/adopted status; and upload verification status. For
tabular data, include row count and unique flight count where applicable.

| Output role | Durable destination and exact key/path | SHA-256 | Rows/flights | Stored hash verified? |
|---|---|---|---|---|
| <role> | <actual R2 key or tracked GitHub path/release asset> | <hash> | <counts or N/A> | <yes/pending/N/A> |

Identify the canonical copy if an aggregate output is held in both GitHub and
R2. Keep candidate artifacts and run manifests separate from the authoritative
production manifest. Do not overwrite production objects or prior runs.

## Validation and sample flow

- Checks performed and aggregate results, including failures:
- Delivered, eligible, excluded, and analysed counts by relevant source/phase:
- Exclusion reasons and whether counts overlap:
- Data/schema/units and accounting reconciliation:
- Parameter sensitivity, stability, and null findings:
- Holdout/leakage checks, where applicable:
- Remaining uncertainty and limits of interpretation:

## Decisions and downstream use

- Decisions adopted, by whom, and evidence/reference:
- Candidate decisions still awaiting review:
- Files/keys the next worker should consume:
- Unsupported uses, incomplete fields, and prerequisites:
- Production promotion: not requested / pending steward review / adopted with release reference.

## Pending-upload package, if needed

If R2 access is unavailable, provide the local package path, manifest, output
hashes, proposed destination keys, and uploader/next action. Retain that package
until upload and stored-hash verification are confirmed. Mark data delivery as
pending; a GitHub narrative or PR alone does not archive the analytical data.
