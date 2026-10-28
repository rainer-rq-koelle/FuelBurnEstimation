#!/usr/bin/env python3
"""Launch/resume a network-free, checkpointed paper exploration on this Mac."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--background", action="store_true")
    parser.add_argument("--run-id", default="2026-10-28-001")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9-]+", args.run_id):
        parser.error("run-id must contain only letters, digits, and hyphens")
    root = Path(__file__).resolve().parents[1]
    out = root / "outputs" / ("offline-paper-" + args.run_id)
    out.mkdir(parents=True, exist_ok=True)
    if args.background:
        with (out / "batch.log").open("ab", buffering=0) as log:
            child = subprocess.Popen(
                [sys.executable, str(Path(__file__).resolve()), "--run-id", args.run_id],
                cwd=root, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                start_new_session=True,
            )
        print(json.dumps({"launcher_pid": child.pid, "directory": str(out),
                          "note": "Check status.json/batch.log for startup and completion. Sleep pauses computing."}))
        return 0
    rscript = shutil.which("Rscript")
    if not rscript:
        parser.error("Rscript is not installed; this runner does not install packages")
    with (out / "runner.lock").open("a+") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("This run is already active. See batch.log and status.json.", file=sys.stderr)
            return 3
        (out / "runner.pid").write_text(str(os.getpid()) + "\n")
        # The R child inherits the lock too, protecting against a second launcher
        # if its Python supervisor is terminated while R is still alive.
        result = subprocess.run(
            [rscript, "scripts/20-offline-paper-exploration.R", str(out), args.run_id],
            cwd=root, stdin=subprocess.DEVNULL, pass_fds=(lock.fileno(),),
        )
        (out / "exit-code.txt").write_text(str(result.returncode) + "\n")
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
