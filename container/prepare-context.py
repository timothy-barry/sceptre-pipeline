#!/usr/bin/env python3
"""Create a credential-free, exact-source Docker context; never copy a checkout."""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import tarfile

HERE = pathlib.Path(__file__).resolve().parent
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("repository", type=pathlib.Path, nargs="?")
p.add_argument("revision", nargs="?", help="Committed package revision (working changes are excluded)")
p.add_argument("--source-manifest", type=pathlib.Path, help="Bundled frozen archive receipt; mutually exclusive with repository/revision")
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
    if not re.fullmatch(r"[0-9a-f]{64}", a.package_sha256):
        p.error("Source manifest requires a full SHA256")
    if receipt.get("source_identity") == "archive_sha256":
        if commit is not None:
            p.error("Archive-only identity must not invent a source commit")
    elif not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        p.error("Source manifest requires a full commit and SHA256")
    a.package_archive = a.source_manifest.resolve().parent / archive_name
    resolution = "frozen_archive_receipt"
else:
    if not a.repository or not a.revision:
        p.error("Supply repository and revision, or --source-manifest")
    commit = subprocess.check_output(["git", "-C", str(a.repository), "rev-parse", a.revision + "^{commit}"], text=True).strip()
    resolution = "local_git_commit"
if bool(a.package_archive) != bool(a.package_sha256):
    p.error("--package-archive and --package-sha256 must be supplied together")
if a.package_archive and hashlib.sha256(a.package_archive.read_bytes()).hexdigest() != a.package_sha256:
    p.error("Provided package archive SHA256 does not match the declared source checksum")
if a.source_manifest:
    frozen_name = receipt.get("frozen_manifest")
    if frozen_name:
        if pathlib.Path(frozen_name).name != frozen_name:
            p.error("Frozen manifest must be a filename in its own directory")
        frozen = a.source_manifest.resolve().parent / frozen_name
        if hashlib.sha256(frozen.read_bytes()).hexdigest() != receipt.get("frozen_manifest_sha256"):
            p.error("Frozen manifest checksum mismatch")
        frozen_receipt = json.loads(frozen.read_text())
        if frozen_receipt.get("archive_sha256") != a.package_sha256:
            p.error("Frozen manifest archive checksum mismatch")
        if receipt.get("source_identity") == "source_commit_and_archive_sha256" and frozen_receipt.get("source_commit") != commit:
            p.error("Frozen manifest source commit mismatch")
if a.package_archive:
    with tarfile.open(a.package_archive, "r:gz") as archive:
        members = [entry for entry in archive.getmembers()
                   if entry.name in ("sceptre/R/s4_class.R", "R/s4_class.R")]
        if len(members) != 1:
            p.error("Archive must contain the native schema-7 class definition")
        source = archive.extractfile(members[0]).read().decode("utf-8")
        if not re.search(r"schema_version\s*=\s*7L", source):
            p.error("Archive does not declare native object schema 7")
if not a.package_archive:
    source = subprocess.check_output(["git", "-C", str(a.repository), "show", commit + ":R/s4_class.R"], text=True)
    if not re.search(r"schema_version\s*=\s*7L", source):
        p.error("Git source does not declare native object schema 7")
if a.verify_only:
    print(json.dumps({"sceptre_commit": commit, "source_resolution": resolution,
                      "sceptre_archive_sha256": a.package_sha256}, indent=2))
    raise SystemExit(0)
out = a.output.resolve()
if out.exists():
    raise SystemExit(f"Output already exists; choose a fresh --output directory: {out}")
out.mkdir(parents=True)
(out / ".dockerignore").write_text("*\n!Dockerfile\n!install-dependencies.R\n!sceptre.tar.gz\n!source.json\n!source.sha256\n")
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
metadata = {"schema": 1, "source_resolution": resolution,
            "archive_kind": "R_CMD_build" if a.package_archive else "git_archive",
            "sceptre_commit": commit, "sceptre_archive_sha256": source_sha,
            "object_schema": 7, "storage": "SingleCellExperiment/native_HDF5",
            "bioconductor_version": "3.22",
            "cran_snapshot": "https://packagemanager.posit.co/cran/2025-11-15",
            "base": "rocker/r-ver:4.5.1@sha256:03b023fbf7b1b24ac1bb8b2ac5fd7e15a767e67b40ff50c155e328110981c2aa"}
(out / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
print(json.dumps({"context": str(out), **metadata}, indent=2))
