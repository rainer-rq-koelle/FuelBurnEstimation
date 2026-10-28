# W1 PRU G2G pilot assessment

**Status:** Bounded, read-only source assessment; exploratory evidence, not a validated production method.  
**Sample:** Flights with LOBT dates 2025-06-11, 2025-06-27, and 2025-08-13.  
**Reproduce:** `Rscript scripts/W1-g2g-pilot-assessment.R`

## Question

Do the PRU G2G records support analysis organized by flight phase and FIR, while `LVL` is treated as a point/event label rather than an interval boundary? What do simple phase/FIR and altitude-trace checks show on a small multi-day sample?

## Inputs and scope

The script reads the local fixed G2G segment and metadata extracts, selects the three dates above, and writes aggregate CSV evidence only. It does not modify the inputs or production outputs and does not export flight-level identifiers.

| Input | SHA-256 |
| --- | --- |
| `g2g-segment-details-2025-summer-FIXED.parquet` | `f341b8894335ebfb62dd97f27dd90517da088f31b4e50fd46e1f420b755744fc` |
| `g2g-flight-metadata-2025-summer-FIXED.parquet` | `e9d61aa942e0b986ebb82073b489cba550991d7ca8860cc8d4b106893c7e3e35` |

The sample contains **753 flights and 22,094 rows**. There are no duplicate `(SAM_ID, TIME_OVER)` keys and no missing time, altitude, distance, adjusted fuel, original fuel, or `FIR_ID` values in the sample.

## Findings

### Phase and FIR attribution

Both `FLIGHT_PHASE` and `FIR_ID` are populated on the sampled rows, and phase- and FIR-indexed fuel/distance summaries can be computed reproducibly. This supports further descriptive analysis, subject to explicit interval attribution rules.

Fuel and distance are row increments. The extract does not itself establish whether each increment belongs to the state at the row timestamp, the preceding state, or should be split at a boundary. The pilot compares current-row and boundary records as a sensitivity diagnostic:

- **Phase:** 10,087 of 21,341 rows with a preceding phase are phase-change rows. They carry 1,056,130 kg, or **37.4% of sampled adjusted fuel**, and 130,780 NM. Assigning whole increments to either side can materially affect phase totals.
- **FIR:** There are 3,586 changes in `FIR_ID` among rows with a preceding FIR. Change rows carry 553,858 kg, or **19.6% of sampled adjusted fuel**, and 102,141 NM. Only 1,183 change rows (33.0%) also carry an `FIR` milestone label on the same row. The event label and ID change therefore should not be assumed to be a one-to-one crossing record.
- `FIR_ID` values are FIR/UIR-like identifiers; a verified FIR-to-country crosswalk is still required before reporting country totals.

The current-row and prior-row attribution are diagnostic alternatives, not established source semantics. Low-level PRU source data, if retrieved, may clarify interval anchoring and crossing timing.

### `LVL` events and altitude/time evidence

There are **2,898 `LVL`-tagged rows across 713 of 753 flights**; 995 tags (34.3%) are compound labels. **366 of the 713 flights with a tag (51.3%) have an odd tag count**, so alternating pairs cannot cover all tagged observations without special handling.

A deliberately naive pairing of consecutive `LVL` events yields 1,266 candidate pairs. **756 (59.7%) have endpoint altitudes differing by more than 1,000 ft.** This is evidence against interpreting the labels as universally clean start/end pairs, not proof of what each source label means.

An exploratory point-to-point altitude-rate check was run at 200, 300, and 500 ft/min with maximum data gaps of 5, 15, and 30 minutes. At 300 ft/min, the summed candidate level-interval time across the three days is:

| Maximum gap allowed | Candidate interval time |
| --- | ---: |
| 5 minutes | 8,115 minutes |
| 15 minutes | 25,179 minutes |
| 30 minutes | 40,037 minutes |

These are **not level-segment totals**: the result changes sharply with the gap cap, and this pilot did not impose a persistence rule or resolve truncated boundaries. It shows that altitude/time reconstruction is possible to test, while also showing that sampling gaps and method choices need explicit treatment. The `LVL` labels may be useful as supporting evidence, but this pilot does not justify using them alone as segment endpoints.

### Fuel adjustment

The pilot preserves and summarizes `FUEL_BURNT_KG` and `FUEL_BURNT_KG_ORIGINAL` separately. The extraction applies the intentional 0.8 operational adjustment to `Take-Off` fuel and retains the unadjusted modeled amount for sensitivity. The difference is a methodological choice, not a source-data defect.

## Interpretation and next step

The multi-day pilot is consistent with the structural interpretation that G2G observations carry phase and FIR context, while `LVL` is not a universally reliable start/end pair. Phase and FIR analyses look feasible as descriptive summaries, but boundary allocation and FIR-to-country mapping remain unresolved. The worker’s alternating-pair reconstruction should not be accepted as a general level-segment method on this evidence.

Next, inspect the low-level source data if it becomes available. In parallel, select a small set of anonymized trace examples from the existing extract and document how row timestamps, fuel/distance increments, phase labels, FIR IDs, and milestone labels align. Then choose and test one explicit boundary-allocation rule before scaling to the full dataset.

## Evidence files

- `daily-inventory.csv`
- `phase-row-summary.csv`
- `phase-boundary-sensitivity.csv`
- `fir-row-summary.csv`
- `fir-boundary-sensitivity.csv`
- `flight-lvl-inventory.csv`
- `naive-lvl-pair-diagnostic.csv`
- `level-interval-sensitivity.csv`

Reproduction script: [`scripts/W1-g2g-pilot-assessment.R`](../../../../scripts/W1-g2g-pilot-assessment.R)
