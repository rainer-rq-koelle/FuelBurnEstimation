"""Download a public, pinned OurAirports snapshot; never read flight records."""
from pathlib import Path
import urllib.request
import json
import hashlib
import sys

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
query = 'https://api.github.com/repos/davidmegginson/ourairports-data/commits?path=airports.csv&until=2025-08-31T23:59:59Z&per_page=1'
request = urllib.request.Request(query, headers={'User-Agent': 'fuelburn-research-airport-reference'})
commit = json.load(urllib.request.urlopen(request, timeout=40))[0]
source_url = 'https://raw.githubusercontent.com/davidmegginson/ourairports-data/' + commit['sha'] + '/airports.csv'
content = urllib.request.urlopen(source_url, timeout=60).read()
(out / 'airports-source.csv').write_bytes(content)
metadata = {
    'repository': 'https://github.com/davidmegginson/ourairports-data',
    'commit': commit['sha'], 'commit_date': commit['commit']['committer']['date'],
    'source_url': source_url,
    'snapshot_selection': 'Last airports.csv revision on or before 2025-08-31 UTC, end of the summer-2025 study period',
    'downloaded_client_date': '2026-10-18',
    'source_sha256': hashlib.sha256(content).hexdigest(),
    'license_url': 'https://ourairports.com/data/',
    'coordinate_status': 'OurAirports airport-coordinate proxy for ARP, not certified AIP ARP'
}
(out / 'source-provenance.json').write_text(json.dumps(metadata, indent=2) + '\n')
print(json.dumps(metadata, indent=2))
print('Downloaded bytes:', len(content))
