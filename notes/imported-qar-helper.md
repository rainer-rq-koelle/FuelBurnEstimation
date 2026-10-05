# Imported QAR Helper

Date imported: 2026-10-05

The local QAR processing helper was imported from:

`../international-CHN-EUR-2025`

Imported files:

- `R/canonical-fuel-milestones.R`
- `scripts/prepare-chn-qar-canonical.R`
- `scripts/HELPER-FOR-LINGLING-fuel-burn-processing.R`
- `notes/QUICK-START-FOR-LINGLING.txt`
- `notes/README-FOR-LINGLING-fuel-burn-data-request.md`

The canonical helper converts one-file-per-flight QAR CSV inputs into a milestone table and phase summaries. It already contains the first VFE-style logic used last year:

- read and normalise QAR files;
- parse filename metadata into `SOURCE_UID`, `DATE`, `FLTID`, `TYPE`, `ADEP`, and `ADES`;
- integrate fuel flow to cumulative fuel burn;
- derive the main canonical milestones;
- detect profile smoothness with a 300 ft/min vertical-rate threshold;
- write phase summaries, level descriptors, QC diagnostics, and profile plots.

For this paper, the next methodological extension is to preserve detected level portions as first-class milestone pairs rather than only summarising them as phase descriptors.
