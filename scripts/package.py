#!/usr/bin/env python3
"""Create reproducible source archives from a clean, committed plugin repository."""
import gzip
import hashlib
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
out = pathlib.Path(sys.argv[1]).resolve()
if subprocess.check_output(["git", "status", "--porcelain"], cwd=root).strip():
    raise SystemExit("Commit or resolve working-tree changes before packaging.")
out.mkdir(parents=True, exist_ok=True)
version = subprocess.check_output(["git", "rev-parse", "--short=12", "HEAD"], cwd=root, text=True).strip()
release = re.search(r"^# version: ([0-9.]+)$", (root / "plugin.rb").read_text(), re.M).group(1)
stem = "discourse-educustomize-" + release + "-" + version
artifacts = []
for format_name, suffix in [("zip", ".zip"), ("tar", ".tar.gz")]:
    payload = subprocess.check_output(
        ["git", "archive", "--format=" + format_name, "--prefix=discourse-educustomize/", "HEAD"],
        cwd=root,
    )
    if format_name == "tar":
        payload = gzip.compress(payload, mtime=0)
    target = out / (stem + suffix)
    target.write_bytes(payload)
    artifacts.append(target)
(out / "SHA256SUMS").write_text(
    "".join(hashlib.sha256(item.read_bytes()).hexdigest() + "  " + item.name + "\n" for item in artifacts),
    encoding="utf-8",
)
print("\n".join(str(item) for item in artifacts))
