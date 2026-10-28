# Lower-altitude and ground-movement support

27 October 2026. Read-only extension of the [cohort assessment](../paper-cohort-mapping-2026-10-27/README.md)
and [paper integration plan](../../paper-integration-plan-2026-10-27.md).
The supplied CHN candidate.6 and EUR-2026-10-13-002 products support a substantially
finer sequence than whole climb/descent or the two primary pressure windows alone.
No canonical data, decoder, source preparation or manuscript results were changed.
These are support counts, not newly adopted fuel-percentile coefficients.

## Sequence available from existing milestones

Departure: recorder-start/AOBT proxy → ERWY → ATOT → source DLTO → FL075 →
FL100 → FL180 → source TOC. Arrival: source TOD → FL180 → FL100 → FL075 →
source ALTO → ALDT → XRWY → recorder-end/AIBT proxy.

The pressure anchors have departure/arrival direction. The LTO anchors are source
definitions. This is a menu of locally usable windows, not a compulsory chain on
every flight: at a high airport the field-relative DLTO/ALTO may lie above FL075,
so those roles have a different order. Missing or reversed optional windows do
not remove independently usable pressure, ground or whole-airborne quantities.

## Fuel/time support and comparison samples

Each row below uses its own positive-duration, positive-fuel eligibility. The
paired columns sum observations in eight exact-aircraft/100 NM GCD cells, with
at least 30 flights per region per cell. Counts overlap and must not be added.
The full source population remains 6,421 CHN / 21,503 EUR flights.

| Airborne window | CHN all | EUR all | CHN in paired cells | EUR in paired cells |
|---|---:|---:|---:|---:|
| ATOT–source DLTO | 6,392 | 21,502 | 1,647 | 6,224 |
| Source DLTO–FL075 | 5,647 | 21,343 | 1,647 | 6,221 |
| Climb FL075–100 | 6,378 | 21,499 | 1,648 | 6,223 |
| Climb FL100–180 | 6,378 | 21,476 | 1,648 | 6,223 |
| Climb FL180–source TOC | 6,384 | 21,374 | 1,646 | 6,224 |
| Source TOD–FL180 | 6,367 | 21,414 | 1,639 | 6,221 |
| Descent FL180–100 | 6,369 | 21,306 | 1,639 | 6,170 |
| Descent FL100–075 | 6,368 | 21,009 | 1,639 | 6,041 |
| FL075–source ALTO | 5,789 | 21,057 | 1,639 | 6,085 |
| Source ALTO–ALDT | 6,376 | 21,502 | 1,639 | 6,224 |

Take-off–FL075 and FL075–landing provide broader pressure-terminal context with
6,391 CHN / 21,501 EUR and 6,391 / 21,168 fuel/time observations respectively;
each also has eight paired cells. They remain useful when a source LTO subdivision
is unavailable or has different semantics.

| Ground source segment | CHN time | EUR time | CHN fuel/time | EUR fuel/time | CHN / EUR fuel observations in paired cells |
|---|---:|---:|---:|---:|---:|
| Taxi-out: AOBT proxy–ERWY | 6,388 | 21,503 | 6,229 | 21,502 | 1,585 / 6,224 |
| Take-off roll: ERWY–ATOT | 6,388 | 21,503 | 6,229 | 21,502 | 1,585 / 6,224 |
| Landing roll/runway exit: ALDT–XRWY | 6,388 | 21,201 | 6,229 | 21,200 | 1,585 / 6,176 |
| Taxi-in: XRWY–AIBT proxy | 6,388 | 21,394 | 6,229 | 21,394 | 1,585 / 6,214 |

All four ground rows have eight paired fuel/time cells. These are A20N/600,
A21N/500, A21N/600, A319/600, A320/600, A321/500, A321/600 and B738/600; 500 and
600 denote 500–599 and 600–699 NM. The airborne table uses the same eight cells.
These totals are for marginal references; interruption/profile-class counts have
not been established. Duration-only support can exceed fuel support. Sparse and
unpaired types remain available for source-sample descriptions.

## Interpretation of lower-altitude boundaries

CHN DLTO/ALTO represent 3,000 ft above an observed field-pressure reference.
EUR source anchors are mostly at 3,000 ft in its stored altitude field, with
source G2G semantics and some M3-derived DLTO repairs. They do not establish a
common field-relative or standard-pressure boundary across regions. Keep the
source LTO scheme explicit; do not label DLTO as a common FL030.

The contextual audit shows CHN median DLTO near 9,786 ft and ALTO near 9,764 ft
at ZPPP, versus roughly 3,228 / 3,209 ft at ZSSS. At ZPPP the source LTO boundary
is above FL075. This explains why the DLTO–FL075 and FL075–ALTO windows have
smaller samples; a non-positive interval there is not proof of a faulty flight.
Fixed pressure windows themselves also need airport/elevation context: equal
pressure intervals need not represent equal height above terrain.

For matched lower-altitude references, include climb/descent FL075–100 alongside
FL100–180. Retain ATOT–source-DLTO as the live 3,000 ft terminal option, with
ATOT–FL075 as an alternative rather than a replacement. Show source LTO boundaries
explicitly, stratified by airport where practical. Do not pool
different boundary schemes into one purportedly common low-level coefficient.

## Ground movement: what is and is not supported

The recorded ground segments support descriptive duration, total fuel and kg/min
references now. CHN phase fuel uses its supplied eligibility and cumulative
reference: unsupported full-record prefixes leave ground fuel missing even when
airborne fuel remains supported. We do not manufacture a ground prefix from
airborne-only fuel, or relax the source's conservative ground/full-clock flags.

CHN AOBT/AIBT are recorder edges, not independently observed off-/in-block times.
EUR operational events derive from G2G/model source segments. Counts establish
usable supplied intervals, not equal physical precision or complete stand-to-stand
coverage. ERWY and XRWY are source phase boundaries; do not infer precise runway
occupancy or wheel-touchdown observations. Ground results must carry those labels.

In EUR, 298 runway-exit and 105 taxi-in rows have zero duration, with four further
missing durations in each phase. They do not enter positive-duration references;
they do not prove absence of the corresponding real movement. No ground stop/start,
queue-time, engine-start or engine-count classification follows from these four
milestones alone. Airport/route and aircraft context should accompany regional
ground comparisons: matching GCD is not matching taxi distance or airport process.

EUR taxi-out and take-off-roll supplied phase distances are zero for all positive
duration rows. Therefore **there is no paired kg/NM support using those supplied
distances**. The user accepts reasonable analysis-derived distance proxies;
their definitions, uncertainty and actual coverage belong in a separate lookup
distance basis (see the integration plan). The counts here do not assess proxy
availability and do not exclude those fuel/time records from proxy development.
Positive fuel-and-distance support under the supplied flags is 1,201 CHN for taxi-out,
take-off roll and runway exit, and 1,200 for taxi-in. EUR supports 21,200 runway-exit
and 21,394 taxi-in rows with positive distance/fuel, but only one paired cell
(B738/600) remains for either distance-based comparison: 81 CHN / 1,004 EUR for
runway exit and 81 / 1,005 for taxi-in. These are quantity-availability counts,
not independently validated detailed ground tracks. Prefer kg/min and total fuel.

The delivered EUR take-off-roll fuel is 0.8 times its original variant for all
21,502 eligible records. The other assessed windows have identical original and
delivered fuel differences. The user reports stakeholder confirmation on 27 October:
the model's 100% take-off-thrust assumption motivates the agreed reduced-thrust
fuel adjustment. Use the delivered adjusted roll variant in the planned primary
reference and retain the original for provenance/optional sensitivity. Do not apply
0.8 twice, treat it as measured flight-specific thrust, or propagate it to other phases.

## Further stepping-stone flight levels

The delivered directional pressure crossings are FL075, FL100 and FL180.
FL050, FL120, FL150, FL240, etc. are not additional supplied crossing products.
The CHN supported-data-point table contains event brackets and coverage endpoints,
not the complete dense altitude/flow trace. The fine airborne partition stores
integrated fuel and altitude changes between its emitted boundaries. It does not
locate an arbitrary interior pressure crossing without a reconstruction model.

The user has deferred extra flight levels and checking their source implementation.
If revisited, extra analysis-only levels can be considered without changing canonical data,
but must carry their interpolation model, actual bracketing intervals and local
fuel-accounting assumptions. A new interior crossing cannot inherit the native
resolution or sample count of FL100–180 merely because it lies between them.
The present tables quantify existing supported windows only. Do not claim exact
crossing counts, short interruptions or fuel at FL120/150 from these counts.
No decoder rerun or source-data recovery is required for the sequence already
quantified here. Any further reconstruction is a separate analysis decision.

## Reproducibility and evidence

Run from the project root, with a new empty directory inside FUELBURN_DATA_STORE:

```sh
Rscript scripts/assess-paper-lower-ground-support.R /restricted/new-output-directory
```

The script consumes the supplied products and the earlier assessment's flight
strata. It writes derived support only, never back to canonical inputs. It checks
that all input SHA-256 hashes are unchanged at completion, reproduces time/fuel/
distance eligibility exactly for six overlapping earlier windows, verifies CHN
local fuel against supported endpoint differences within 0.000002 kg, and checks
unique flight/window keys and complete canonical type/GCD strata. Ground counts
use supplied phase flags; no new ground-speed threshold was introduced.

The checked restricted run is
`derived/paper/eligibility-comparability/PAPER-2026-10-27-004-lower-ground/`.
Earlier exploratory 002/003 directories are marked superseded and are not evidence
for this note. Flight/window ledgers remain restricted. This directory contains
identifier-free aggregate support, input/code hashes and the R runtime record:

- `window-summary.csv`: compact all-region and paired fuel/time support, with
  time-only and positive-distance support kept separate.
- `aggregate-window-support.csv`: each window's endpoints and quantity-specific n.
- `aggregate-type-stage-window-support.csv`, `aggregate-paired-support.csv`:
  exact type/GCD/metric cells and their support summaries.
- `aggregate-lto-boundary-context.csv`: source method and altitude by airport.
- `aggregate-ground-limitations.csv`: zero/missing ground durations and distances.
- `aggregate-eur-fuel-convention.csv`: original/delivered window-fuel audit.
- `aggregate-local-fuel-validation.csv`: local CHN integration reconciliation.
- `input-manifest.csv`, `source-manifest.csv`, `runtime.txt`: reproduction identity.

No new fuel percentiles, formal profile classes, manuscript results or decoder
changes were produced. The canonical-input hashes were unchanged.
