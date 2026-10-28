# Offline paper exploration — 28 October 2026

This is a self-contained local R analysis, supervised by a small Python launcher.
It needs the already installed R packages and the existing adopted reference cache.
It does not require internet, model calls, package downloads, or a cloud environment.

Closing the lid normally puts a Mac laptop to sleep. The batch does not override
power settings: it pauses during sleep and can continue after wake. If the process
is terminated, the same command restarts it using completed checkpoints. Computing
through a closed-lid commute is not promised.

From the repository directory, launch or resume in the background:

```sh
python3 scripts/run-offline-paper-batch.py --background
```

To run in the foreground instead, omit `--background`. An advisory file lock
prevents two copies of the same run from executing concurrently.

The default run directory is `outputs/offline-paper-2026-10-28-001/`, ignored by
Git. Inspect `status.json`, `batch.log`, and `exit-code.txt`. A successful run has
`state: complete` and exit code 0. A missing exit-code file does not establish
success: the process may still be running or may have been interrupted.

The stages are:

1. Sample inventories by exact aircraft type and reporting fleet group, using GCD
   groups [0,300), [300,500), [500,700), [700,1000), and [1000,Inf) NM.
2. Marginal references for all 24 adopted windows, keeping exact-type and pooled
   fleet tables separate. Each metric retains its own eligibility and sample size.
3. Fuel references conditioned on traversal-time groups for the four finer
   pressure-altitude windows, including descent.
4. Within-source level-tag associations, altitude summaries, and reverse-route
   comparisons for the finer windows and source climb/enroute/descent phases.
5. Enroute altitude-residence summaries regrouped from the existing common cohort,
   with both Source and Level-envelope boundary schemes retained.

The last step creates two exploratory figures and verifies input hashes again.
P20/P50/P80 require at least 30 finite observations per metric. No threshold or
duration group in this batch assigns a common interruption class. Enroute level
time is cruise context, not automatically an inefficiency measure. Broader distance
and fleet groups do not balance route, exact-type, payload, or aircraft-mass mixes.
Engine groups remain unstratified; source type labels remain unchanged.

Completed stage aggregates are checkpointed under the restricted local store at
`derived/paper/offline-exploration/2026-10-28-001/`. The runner refuses to reuse
them if its code, cached base analysis, configuration, or pinned input manifest
changes. Every invocation verifies the 110 pinned source/eligibility inputs.
After a deliberate code or input change, use a new run identifier, for example:

```sh
python3 scripts/run-offline-paper-batch.py --background --run-id 2026-10-28-002
```

The batch does not change canonical inputs, source eligibility, the manuscript,
or existing PDF/Word exports. No decoder work, ground-distance proxy, extra 0.8
takeoff adjustment, commit, or push is performed. Results remain exploratory
until checked and selected for integration into the technical note.

## Initial verification

The default run completed successfully on 28 October 2026 in approximately 16
seconds. A second invocation reused all five checkpoints and completed with exit
code 0. Concurrent launch protection was also checked. The source verification
passed before and after both runs; published product hashes and suppression of
percentiles below n=30 were checked. Both exploratory PNGs were visually inspected.
The run is complete: no computing needs to continue during the commute.

## Review of 28 October

The substantive review and populated lookup are in
`notes/results/descent-enroute-lookup-2026-10-28/README.md`, reproduced by
`scripts/21-review-descent-enroute-lookup.R`.

The initial offline ground-window rows omitted GCD_NM, while retaining BAND100
and flight identity. Their broad GCD groups were therefore missing. The review
joins the existing flight-inventory GCD for reporting and checks agreement with
the other windows. Use the review's distance-stratified ground lookup rows rather
than the original batch's missing-group ground rows. The original batch and all
canonical inputs remain preserved.
