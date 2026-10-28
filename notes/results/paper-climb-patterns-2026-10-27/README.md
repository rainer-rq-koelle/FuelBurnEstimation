# Climb fuel, traversal time, level exposure and sector context

27 October 2026. A result-led exploration of climb FL100--180 on the adopted,
unchanged CHN and EUR inputs. This extends the technical note beyond support
counts: it examines observed patterns without claiming to identify their causes.

## Similar fuel at similar times and closer distances

Restrict traversal time to 3 <= minutes < 4 and bring GCD closer using the same
band in both regions for each type. These are exploratory sensitivities, not
replacement primary stage bands and not matched mass/engine/weather cohorts.

| Aircraft | GCD sensitivity | CHN / EUR n | Median time CHN / EUR | Median fuel CHN / EUR | Fuel P20--P80 CHN / EUR |
|---|---|---:|---:|---:|---|
| A320neo | 650--699 NM | 87 / 90 | 3.48 / 3.49 min | 271.5 / 284.2 kg | 254--298 / 268--302 kg |
| A321neo | 570--599 NM | 109 / 67 | 3.38 / 3.42 min | 310.5 / 314.7 kg | 291--332 / 291--352 kg |

Actual mean GCD is approximately 664 / 670 NM for the A320neo comparison and
581 / 590 NM for A321neo. Fuel distributions substantially overlap. This is
descriptive similarity; recorded CHN and modelled EUR fuel methods remain explicit.
Matching on traversal time also conditions on the time denominator and cannot
explain why the original duration distributions differ.

The full 600--699 NM A320neo fuel means are 335.6 / 299.4 kg and medians
318.1 / 292.9 kg. A321neo means are 401.6 / 354.1 kg and medians 377.4 / 351.7 kg.
These describe this fixed 8,000 ft interval, not the complete climb or a universal
modern-aircraft coefficient.

## Long traversals coincide with tagged levels within CHN

Among the 61 CHN A320neo traversals taking at least five minutes:

- 59 have at least one native source episode lasting >=20 s inside the window.
- 54 have one such episode, five have two, and two have no qualifying source tag.
- 48 still have an episode at a >=60 s threshold; 29 do at >=120 s.

None of the 87 CHN traversals lasting 3--4 minutes has a qualifying >=20 s tag.
This supports a pattern of sustained level exposure among longer traversals,
rather than primarily many separate interruptions. No-tag is not a validated
continuous-climb class. The native detector inventories differ between regions;
these associations are interpreted within source, not as a common regional
interruption-prevalence comparison.

## The same sector has a strong directional pattern

All 187 Chinese A320neo observations in the primary 600--699 NM band fly the same
Shanghai Hongqiao / Xi'an pair (ZSSS / ZLXY), at 663.6 NM GCD.

| Direction | n | Mean total time | Mean tagged level time | Mean remainder | Mean fuel |
|---|---:|---:|---:|---:|---:|
| Shanghai to Xi'an | 94 | 5.47 min | 1.29 min | 4.18 min | 379.0 kg |
| Xi'an to Shanghai | 93 | 3.72 min | 0.07 min | 3.65 min | 291.8 kg |

The mean gap is 1.75 minutes: 1.22 minutes of additional source-tagged level
time and 0.53 minutes outside those tags. Approximately 70% of the arithmetic
time difference therefore lies inside tagged levels. This is not a causal share
of delay, and it does not allocate the 87.2 kg mean fuel difference to level-offs.
The remainder is time outside supplied tags, not verified active climbing time.

Fifty-nine of the 61 long traversals occur outbound from Shanghai. Sixty-one of
the 94 outbound flights have a qualifying source tag; 53 of those tagged flights
have an episode between 11,000 and 12,000 ft. This altitude concentration is a
specific operational-profile pattern worth describing alongside aggregate fuel.

## Sector length is relevant but does not identify weight

For A321neo, the direction pattern also appears on both Chinese stage lengths:

| Pair and direction | n | GCD | Median window time | Median window fuel |
|---|---:|---:|---:|---:|
| Beijing to Shanghai | 130 | 581 NM | 3.32 min | 305 kg |
| Shanghai to Beijing | 125 | 581 NM | 5.59 min | 414 kg |
| Xi'an to Shanghai | 47 | 664 NM | 4.03 min | 340 kg |
| Shanghai to Xi'an | 47 | 664 NM | 6.52 min | 460 kg |

The longer sector has higher fuel and time within each direction. That is
compatible with a weight-related hypothesis, but sector length also changes the
destination and route context. The direction gap at an identical distance, and
the fact that the shorter outbound sector exceeds the longer inbound sector,
show that sector length alone cannot describe the pattern. Different payload,
fuel reserves, speed, climb strategy, weather and operational constraints remain
unmeasured possible influences. No mass or loaded-fuel estimate is imputed.

## Unequal sample numbers

The >=5-minute share is 61/187 = 32.6% CHN versus 12/481 = 2.5% EUR for the
primary A320neo cell. Repeatedly draw 187 EUR flights without replacement from
the fixed EUR sample: the central 95% of 5,000 shares is 1.1--4.3% (median 2.7%).
This equal-size sensitivity leaves the contrast intact within the supplied
samples. It is not a population confidence interval and does not balance their
routes, dates or operators. Sample composition remains an important concern;
unequal sample number alone is not a mechanical explanation for the percentages.

## Files and reproduction

Run `Rscript scripts/19-explore-climb-fuel-patterns.R` from the project root.
The current base reference view must already exist. All 110 adopted input hashes
are verified before loading and after this analysis. Canonical releases, source
detectors, existing eligibility flags and fuel quantities remain unchanged.

The technical-note render additionally requires the existing marginal-reference
and common-interruption views (builders 16 and 18). After building this extension:

```sh
Rscript scripts/17-export-paper-reference-snapshot.R
quarto render paper.qmd --to pdf
quarto render paper.qmd --to docx
python3 scripts/format-paper-docx.py _output/paper.docx
quarto render paper.qmd --to html
```

- `modern_overview.csv`, `duration_bands.csv`, `stage_bands.csv`, `routes.csv`:
  independent-flight counts, fuel/time summaries and source-native exposures.
- `closer_distance_comparison.csv`: the two nearer-distance, similar-time cases.
- `source_tag_exposure.csv`, `long_window_episode_counts.csv`,
  `chn_level_altitudes.csv`: tagged exposure, count and altitude patterns.
- `same_route_decomposition.csv`: additive means, explicitly not causal effects.
- `equal_size_subsampling.csv`: seed, size, draws and finite-sample ranges.
- Three PNG/PDF figures: similar-time fuel distributions, same-route additive
  time components, and the CHN fuel/time/tagged-exposure scatter.
- Input/code manifests and session information provide reproduction provenance.

Percentiles are suppressed below n=30; sparse descriptive means/counts retain
their n. Level inventories are audited as non-overlapping before summing. Clipped
episodes qualify only on their duration inside the window, with source
endpoint-average absolute vertical rate <=300 ft/min. Explicit negative source
altitude support gives unknown exposure, while marginal fuel stays eligible.
Only aggregates and figures are exported here; flight/segment ledgers and the
render cache remain in the restricted `derived/paper/climb-patterns/` store.

The technical note presents these fuel/profile patterns before the fuller
composition, coverage and reference-grid material. Means, medians, native tags
and common interruption classes remain separate quantities.

## Verified exports

The updated technical note renders to an 18-page two-column PDF and a 41-page
single-column Word review copy, with 26 figures and 26 editable data tables.
All rendered pages were visually reviewed; the new result sections and figures
are readable and figure captions remain with their graphics in Word. Both use
the same cached, source-fingerprint-checked analysis. HTML is generated from the
same final source. Build assertions verify native interval non-overlap, duration
accounting, same-route distance equality, percentile support and unchanged input
hashes. The stored record does not identify the weight or causal mechanism.
