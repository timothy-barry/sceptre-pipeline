#!/usr/bin/env python3
"""Build a static Quarto site from canonical pipeline docs and the CLI schema."""
from __future__ import annotations

import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import posixpath
import re
import shutil
import subprocess
from urllib.parse import unquote, urlsplit

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
STAGING = HERE / ".build"
OUTPUT = HERE / "_site"
PAGES = {
    "demo.qmd": ("docs/demo.md", "One-command scientific demo"),
    "report.qmd": ("docs/report.md", "Scientific results report"),
    "usage.qmd": ("docs/usage.md", "Usage"),
    "outputs.qmd": ("docs/outputs.md", "Outputs"),
    "architecture.qmd": ("docs/architecture.md", "Architecture & migration"),
    "distributed-interface.qmd": ("docs/distributed-interface.md", "Distributed interface"),
    "validation.qmd": ("docs/validation.md", "Scientific qualification"),
    "nf-core.qmd": ("docs/nf-core.md", "nf-core principles"),
    "array-validation.qmd": ("docs/array-validation.md", "Slurm array validation"),
    "ci.qmd": ("docs/ci.md", "Continuous integration"),
    "coverage.qmd": ("docs/coverage.md", "Scientific test coverage"),
    "benchmark.qmd": ("docs/benchmark.md", "Real-screen benchmark"),
    "scale-boundaries.qmd": ("docs/scale-boundaries.md", "Real-screen scale boundaries"),
    "hpc.qmd": ("docs/hpc.md", "Slurm & Apptainer"),
    "containers.qmd": ("container/README.md", "Containers & scientific runtime"),
}
LINK = re.compile(r"(!?\[[^\]\n]*\]\()([^\s)]+)(\))")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def defaults_from_config() -> dict:
    config = (REPO / "nextflow.config").read_text()
    block = re.search(r"^params\s*\{\s*\n(.*?)^\}", config, re.M | re.S)
    if not block:
        raise ValueError("Cannot locate the top-level params block in nextflow.config")
    defaults = {}
    for line in block.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("//"):
            continue
        match = re.fullmatch(r"\s*(\w+)\s*=\s*(.*?)\s*", line)
        if not match:
            raise ValueError(f"Unsupported parameter default syntax: {line!r}")
        key, literal = match.groups()
        if len(literal) >= 2 and literal[0] in "\"'" and literal[-1] == literal[0]:
            value = literal[1:-1]
        elif literal in ("null", "true", "false"):
            value = {"null": None, "true": True, "false": False}[literal]
        elif re.fullmatch(r"-?\d+", literal):
            value = int(literal)
        else:
            raise ValueError(f"Unsupported default for {key}: {literal!r}")
        defaults[key] = value
    return defaults


def cell(value) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def parameter_page(schema: dict, defaults: dict) -> str:
    props = schema["properties"]
    if set(props) != set(defaults):
        raise ValueError("Schema/config parameter mismatch: " + repr(set(props) ^ set(defaults)))
    lines = [
        "---", "title: Parameters", "---", "",
        "The command-line interface is generated from `nextflow_schema.json`. "
        "Defaults are read directly from the `params` block in `nextflow.config`.", "",
        "Use `nextflow run . --help` for the engine's parameter help. Formulae and "
        "typed pair tables belong in the trusted RDS analysis configuration, not CLI strings; "
        "see [Usage](usage.qmd#prepare-scientific-input).", "",
        "## Command-line reference", "",
        "| Parameter | Type | Default | Required | Constraints / description |",
        "| --- | --- | --- | --- | --- |",
    ]
    required = schema.get("required", [])
    for name, prop in props.items():
        kind = prop.get("type", "—")
        if isinstance(kind, list):
            kind = " / ".join(kind)
        if prop.get("format"):
            kind += " · " + prop["format"]
        value = json.dumps(defaults[name], ensure_ascii=False)
        parts = []
        if prop.get("description"):
            parts.append(prop["description"])
        if "enum" in prop:
            parts.append("One of: " + ", ".join(f"`{v}`" for v in prop["enum"]) + ".")
        if "minimum" in prop:
            parts.append(f"Minimum `{prop['minimum']}`.")
        if "maximum" in prop:
            parts.append(f"Maximum `{prop['maximum']}`.")
        if "pattern" in prop:
            parts.append(f"Pattern `{prop['pattern']}`.")
        lines.append("| " + " | ".join([
            f"`--{name}`", cell(kind), f"`{cell(value)}`",
            "yes" if name in required else "—", cell(" ".join(parts)) or "—",
        ]) + " |")
    lines += [
        "", "## Execution policy", "",
        "`reference` invokes the public complete-family stage. `distributed` uses "
        "the package-owned prepare / worker / collector interface. "
        "`--n_work_units` partitions scientific work; `--array_size` batches ready "
        "workers only when the Slurm profile is selected. These are separate controls.", "",
        "See [Slurm arrays](usage.qmd#slurm-worker-arrays), "
        "[the distributed contract](distributed-interface.qmd) and "
        "[scheduler qualification](array-validation.qmd).", "",
        "## Scientific arguments", "",
        "Analysis, assignment, QC, calibration and execution argument lists live in "
        "`analysis_config.rds`. Their validation and defaults belong to the matching "
        "SCEPTRE public API; this pipeline schema does not recreate them. "
        "[Prepare the scientific configuration](usage.qmd#prepare-scientific-input).", "",
    ]
    return "\n".join(lines)


def prepare() -> None:
    if STAGING.exists():
        shutil.rmtree(STAGING)
    STAGING.mkdir(parents=True)
    missing = [source for source, _ in PAGES.values() if not (REPO / source).is_file()]
    if missing:
        raise FileNotFoundError("Missing canonical docs: " + ", ".join(missing))
    tracked_inputs = {HERE / name for name in ("build.py", "preview.py", "README.md")}
    for filename in ("_quarto.yml", "index.qmd", "assets/site.css", "assets/table-scroll.lua", "assets/theme.scss", "assets/sceptre-mark.svg", "assets/site-footer.html"):
        source = HERE / filename
        dest = STAGING / filename
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        tracked_inputs.add(source)
    # Also render linked independent-review reports, retaining their canonical source.
    page_for_source = {(REPO / source).resolve(): Path(page) for page, (source, _) in PAGES.items()}
    pending = [(REPO / source, Path(page), title) for page, (source, title) in PAGES.items()]
    done = set()

    def rewrite(text: str, source: Path, page: Path) -> str:
        def replace(match):
            url = urlsplit(match.group(2))
            if url.scheme or url.netloc or not url.path:
                return match.group(0)
            target = (source.parent / unquote(url.path)).resolve()
            if not target.is_relative_to(REPO):
                raise ValueError(f"Local link escapes repository in {source}: {url.path}")
            if not target.is_file():
                raise FileNotFoundError(f"Broken source link in {source}: {url.path}")
            if target.suffix.lower() == ".md":
                if target not in page_for_source:
                    generated = Path("sources") / target.relative_to(REPO).with_suffix(".qmd")
                    if generated.name.lower() == "readme.qmd":
                        generated = generated.with_name("readme-source.qmd")
                    page_for_source[target] = generated
                    pending.append((target, generated, target.stem.replace("_", " ")))
                destination = page_for_source[target].with_suffix(".html")
            else:
                destination = Path("resources") / target.relative_to(REPO)
                asset = STAGING / destination
                asset.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(target, asset)
                tracked_inputs.add(target)
            relative = posixpath.relpath(destination.as_posix(), page.parent.as_posix())
            if url.fragment:
                relative += "#" + url.fragment
            return match.group(1) + relative + match.group(3)
        return LINK.sub(replace, text)

    for source, page, title in pending:
        source = source.resolve()
        if source in done:
            continue
        done.add(source)
        tracked_inputs.add(source)
        text = source.read_text()
        # The source H1 becomes the Quarto title, avoiding a duplicated heading.
        first_heading = re.search(r"^#\s+(.+)$", text, re.M)
        if first_heading:
            text = text[:first_heading.start()] + text[first_heading.end():]
        text = rewrite(text, source, page)
        note = f"\n\n::: {{.source-note}}\nCanonical source: `{source.relative_to(REPO)}`. Generated at site build time.\n:::\n"
        dest = STAGING / page
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text("---\ntitle: " + json.dumps(title) + "\n---\n\n" + text.strip() + note)
    config = (REPO / "nextflow.config").read_text()
    version = re.search(r"nextflowVersion\s*=\s*'>=([^']+)'", config)
    if not version:
        raise ValueError("Cannot read the minimum Nextflow version")
    index = STAGING / "index.qmd"
    index.write_text(index.read_text().replace("@@NEXTFLOW_MIN@@", version.group(1)))
    schema = json.loads((REPO / "nextflow_schema.json").read_text())
    (STAGING / "parameters.qmd").write_text(parameter_page(schema, defaults_from_config()))
    for name in ("nextflow.config", "nextflow_schema.json", "LICENSE"):
        tracked_inputs.add(REPO / name)
    shutil.copyfile(REPO / "LICENSE", STAGING / "LICENSE.txt")
    (STAGING / ".nojekyll").touch()
    # Build resources are copied verbatim by Quarto; all URLs remain project-relative.
    config_path = STAGING / "_quarto.yml"
    config_path.write_text(config_path.read_text().replace('    - "*.qmd"', '    - "**/*.qmd"\n  resources:\n    - "resources/**"\n    - "LICENSE.txt"\n    - "build-manifest.json"'))
    manifest = {
        "schema": 1,
        "purpose": "Documentation source provenance; not scientific execution evidence",
        "inputs": {str(p.relative_to(REPO)): digest(p) for p in sorted(tracked_inputs)},
    }
    (STAGING / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Prepared {len(done) + 2} pages from canonical docs and schema.", flush=True)


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        for key in ("href", "src"):
            if key in attrs:
                self.links.append(attrs[key])


def check() -> None:
    if not (OUTPUT / "index.html").exists():
        raise FileNotFoundError("No rendered site. Run python3 website/build.py first.")
    manifest = json.loads((OUTPUT / "build-manifest.json").read_text())
    stale = [name for name, expected in manifest["inputs"].items()
             if not (REPO / name).is_file() or digest(REPO / name) != expected]
    if stale:
        raise ValueError("Documentation inputs changed; rebuild the site: " + ", ".join(stale))
    parsed = {}
    for page in OUTPUT.rglob("*.html"):
        parser = Links()
        parser.feed(page.read_text())
        parsed[page.resolve()] = parser
    failures = []
    checked = 0
    for source, parser in parsed.items():
        for link in parser.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                continue
            path = unquote(url.path)
            target = source if not path else ((OUTPUT / path.lstrip("/")) if path.startswith("/") else (source.parent / path)).resolve()
            if target.is_dir():
                target = target / "index.html"
            checked += 1
            if not target.exists():
                failures.append(f"{source.relative_to(OUTPUT)}: missing {link}")
            elif url.fragment and target in parsed and unquote(url.fragment) not in parsed[target].ids:
                failures.append(f"{source.relative_to(OUTPUT)}: missing fragment {link}")
    if failures:
        raise ValueError("Site link check failed:\n" + "\n".join(failures))
    print(f"Site links OK: {len(parsed)} HTML pages, {checked} local page/resource/fragment references.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check an existing rendered site only")
    parser.add_argument("--prepare", action="store_true", help="Generate Quarto inputs without rendering")
    args = parser.parse_args()
    if args.check:
        check()
        return
    if not shutil.which("quarto"):
        parser.error("Quarto is required; install Quarto 1.9+ before building.")
    prepare()
    if args.prepare:
        return
    subprocess.run(["quarto", "render", str(STAGING)], check=True)
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    shutil.move(str(STAGING / "_site"), str(OUTPUT))
    (OUTPUT / ".nojekyll").touch()
    check()
    print(f"Static documentation: {OUTPUT}")


if __name__ == "__main__":
    main()
