#!/usr/bin/env python3
"""Create a credential-free, exact-commit Docker context; never copy a checkout."""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
ONDISC = "589803edea2a66ad15e7f07186bee16c7739ab8c"
ONDISC_SHA = "806165dde5bdee21beec015d2bed4676ac1e30692b654b3196a4be5521bea3ab"
ZLIB_SHA = "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16"
RHDF5_SHA = "170606eaa916cc0489bdc0a6dcf25fa13ee2c9275c95573b6145345d857c8746"
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("repository", type=pathlib.Path, nargs="?")
p.add_argument("revision", nargs="?", help="Committed package revision (working changes are excluded)")
p.add_argument("--source-manifest", type=pathlib.Path, help="Bundled qualified archive receipt; mutually exclusive with repository/revision")
p.add_argument("--verify-only", action="store_true", help="Validate source identity without downloads or a Docker context")
p.add_argument("--package-archive", type=pathlib.Path, help="Use exact R CMD build archive bytes instead of git archive")
p.add_argument("--package-sha256", help="Required SHA256 for --package-archive")
p.add_argument("--output", type=pathlib.Path, default=HERE / ".build")
a = p.parse_args()
if a.source_manifest:
    if a.repository or a.revision or a.package_archive or a.package_sha256:
        p.error("--source-manifest cannot be combined with repository/revision or archive arguments")
    receipt = json.loads(a.source_manifest.read_text())
    if receipt.get("schema") != 1 or receipt.get("archive_kind") != "R_CMD_build":
        p.error("Unsupported source manifest schema or archive kind")
    archive_name = receipt.get("archive", "")
    if not archive_name or pathlib.Path(archive_name).name != archive_name:
        p.error("Source manifest archive must be a filename in its own directory")
    commit = receipt.get("source_commit", "")
    a.package_sha256 = receipt.get("archive_sha256", "")
    if not re.fullmatch(r"[0-9a-f]{40}", commit) or not re.fullmatch(r"[0-9a-f]{64}", a.package_sha256):
        p.error("Source manifest requires a full commit and SHA256")
    a.package_archive = a.source_manifest.resolve().parent / archive_name
    resolution = "qualified_archive_receipt"
else:
    if not a.repository or not a.revision:
        p.error("Supply repository and revision, or --source-manifest")
    commit = subprocess.check_output(["git", "-C", str(a.repository), "rev-parse", a.revision + "^{commit}"], text=True).strip()
    resolution = "local_git_commit"
if bool(a.package_archive) != bool(a.package_sha256):
    p.error("--package-archive and --package-sha256 must be supplied together")
if a.package_archive and hashlib.sha256(a.package_archive.read_bytes()).hexdigest() != a.package_sha256:
    p.error("Provided package archive SHA256 does not match the declared source checksum")
if a.verify_only:
    print(json.dumps({"sceptre_commit": commit, "source_resolution": resolution,
                      "sceptre_archive_sha256": a.package_sha256}, indent=2))
    raise SystemExit(0)
out = a.output.resolve()
if out.exists():
    raise SystemExit(f"Output already exists; choose a fresh --output directory: {out}")
out.mkdir(parents=True)
(out / ".dockerignore").write_text("*\n!Dockerfile\n!install-dependencies.R\n!sceptre.tar.gz\n!ondisc.tar.gz\n!Rhdf5lib.tar.gz\n!zlib.tar.gz\n!source.json\n!source.sha256\n!optional.sha256\n")
for filename in ("Dockerfile", "install-dependencies.R"):
    shutil.copy2(HERE / filename, out / filename)
if a.package_archive:
    shutil.copyfile(a.package_archive, out / "sceptre.tar.gz")
else:
    subprocess.run(["git", "-C", str(a.repository), "archive", "--format=tar.gz", "-o", str(out / "sceptre.tar.gz"), commit], check=True)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
source_sha = sha(out / "sceptre.tar.gz")
(out / "source.sha256").write_text(source_sha + "  sceptre.tar.gz\n")
for name, url in {
    "ondisc.tar.gz": f"https://codeload.github.com/timothy-barry/ondisc/tar.gz/{ONDISC}",
    "zlib.tar.gz": "https://zlib.net/fossils/zlib-1.3.2.tar.gz",
    "Rhdf5lib.tar.gz": "https://bioconductor.org/packages/3.21/bioc/src/contrib/Rhdf5lib_1.30.0.tar.gz",
}.items():
    # The context contains only public sources and this script needs no credentials.
    subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error",
                    "--retry", "3", "--output", str(out / name), url], check=True)
if sha(out / "zlib.tar.gz") != ZLIB_SHA:
    raise SystemExit("zlib source checksum mismatch")
if sha(out / "ondisc.tar.gz") != ONDISC_SHA:
    raise SystemExit("ondisc source checksum mismatch")
if sha(out / "Rhdf5lib.tar.gz") != RHDF5_SHA:
    raise SystemExit("Rhdf5lib source checksum mismatch")
optional = {name: sha(out / name) for name in ("ondisc.tar.gz", "Rhdf5lib.tar.gz", "zlib.tar.gz")}
(out / "optional.sha256").write_text("".join(f"{value}  {name}\n" for name, value in optional.items()))
metadata = {"schema": 1, "source_resolution": resolution, "archive_kind": "R_CMD_build" if a.package_archive else "git_archive", "sceptre_commit": commit, "sceptre_archive_sha256": source_sha,
            "ondisc_commit": ONDISC, "ondisc_version": "1.3.5",
            "Rhdf5lib_version": "1.30.0", "zlib_version": "1.3.2", "optional_source_sha256": optional,
            "cran_snapshot": "https://packagemanager.posit.co/cran/2025-07-01",
            "base": "rocker/r-ver:4.5.1@sha256:03b023fbf7b1b24ac1bb8b2ac5fd7e15a767e67b40ff50c155e328110981c2aa"}
(out / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
print(json.dumps({"context": str(out), **metadata}, indent=2))
