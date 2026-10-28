# Enroute altitude-residence snapshot, 22 October 2026

Identifier-free evidence for the corresponding `paper.qmd` extension. Scientific
assumptions, boundary semantics, source-status details and proposed paper add-ons
are documented in `notes/enroute-level-analysis.md`.

Reproduce with `Rscript scripts/14-characterise-enroute-levels.R`; compare its
aggregate CSVs in `outputs/paper-enroute-levels/` with these tables. The source
comparison covers 672 CHN / 4,207 EUR flights in six shared aircraft/GCD cells.
The boundary sensitivity covers 671 / 4,162 identical flights under both rules.

- `summary.csv`: source-window and alternative-window summaries.
- `paired_summary.csv`: fixed-cohort comparison of both window definitions.
- `band_summary.csv`: per-flight minutes and shares by altitude band, including
  a <=300 s interpolation-span sensitivity; shares use whole enroute time.
- `boundary_summary.csv`: support, paired shifts and agreement within 60 s.
- `support.csv`: independent flights in both regions under each window rule.
- `input-manifest.csv`: SHA-256 of source inputs. Resolve `data-store/` against
  `FUELBURN_DATA_STORE`; other paths are relative to the repository root.
- `source-manifest.csv`: exact analysis, test, paper and style source hashes.
- `session-info.txt`: R environment from the standalone analysis run.

Altitude residence is reconstructed by piecewise-linear interpolation, not
continuous observation. P20/P50/P80 describe independent-flight distributions.
Unbracketed time stays separate. The sustained-level envelope is a definition
sensitivity, not a CCO/CDO compliance measure or a newly adopted canonical release.
Flight identifiers, individual profiles and per-flight decisions remain in the
Git-ignored local analysis store. The 18 October snapshot is unchanged.
