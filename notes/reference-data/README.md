# EUR airport coordinate reference

`EUR-airport-coordinates-2024-12-27.csv` contains the 11 aerodrome coordinates used by the current EUR study sample. It was extracted from the prior-project `ourairports-20241227.csv` reference file and keyed by ICAO code. Coordinates support approximate geodesic distance-to-airport calculations for M3 trajectories; they are not a substitute for a validated EUROCONTROL NM ARP reference if exact ARP provenance is required.

The source file remains in the prior project data folder and is not copied into this repository. The extracted 11-row table is checked in so the candidate build can be reproduced. Record its SHA-256 in the output manifest.
