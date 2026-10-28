"""Build a deterministic, source-only helper ZIP; never include QAR/evidence data."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import hashlib

root = Path(__file__).resolve().parents[1]
source = root / "helpers" / "chn-qar-v2"
version = (source / "VERSION").read_text().strip()
files = ["VERSION", "README.md", "HELPER-FOR-LINGLING-v2.R",
         "R/legacy-core.R", "R/chn-qar.R", "data/airports.csv", "data/airports-provenance.json"]
output = root / "outputs" / f"CHN-fuel-burn-helper-{version}.zip"
manifest = "".join(hashlib.sha256((source / name).read_bytes()).hexdigest()
                   + "  " + name + "\n" for name in files)
with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
    for name in files + ["checksums.sha256"]:
        content = manifest.encode() if name == "checksums.sha256" else (source / name).read_bytes()
        item = ZipInfo(f"CHN-fuel-burn-helper-{version}/{name}", (2026, 10, 18, 0, 0, 0))
        item.compress_type = ZIP_DEFLATED
        item.external_attr = 0o644 << 16
        archive.writestr(item, content)
print(output)
print("SHA256", hashlib.sha256(output.read_bytes()).hexdigest())
