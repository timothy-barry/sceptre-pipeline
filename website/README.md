# Pipeline documentation site

This local-only Quarto site takes the navigation and schema-generated parameter
reference approach from `feat/docs-site`, adapted to the native SCE pipeline.
Legacy input flags, trans-mode claims and the old license label are not reused.
The site is inspired by nf-core's documentation structure and engineering
principles; it does not use nf-core branding or assert community acceptance.

## Build and preview

Requirements: Python 3.9+ (standard library only) and Quarto 1.9+.
No R code executes during rendering. No Node/npm installation, remote fonts,
account, registry image or hosted service is needed to build these pages.

From the repository root:

```bash
python3 website/build.py
python3 website/build.py --check
python3 website/preview.py --port 8095
```

Open the printed `http://127.0.0.1:8095/` URL. Stop the preview with Ctrl-C.
`--check` validates source freshness plus local page, fragment and resource links
after rendering. It rejects a site built before the canonical docs changed.
The preview binds only to loopback and fails if the requested port is in use.

The generated static site is `website/_site/`. Its links are relative, so the
same directory can be served under a GitHub Pages project subpath. It contains
`.nojekyll`; no deployment workflow is installed and nothing is published.

## Source of truth

- `index.qmd` owns the landing-page narrative.
- `_quarto.yml`, `assets/site.css` and the local SVG mark own presentation.
- `docs/*.md` and `container/README.md` remain the canonical reference prose.
  The build copies these into ignored `website/.build/` files and rewrites their
  local links to the corresponding rendered site pages; it does not edit them.
- `nextflow_schema.json` supplies parameter names, types, constraints and
  descriptions. Literal defaults are read from the `params` block in
  `nextflow.config`. Unknown default syntax or schema/config mismatches fail the
  build rather than silently publishing an inaccurate table.
- Referenced evidence is copied from canonical source paths. Build hashes in
  `_site/build-manifest.json` identify every canonical input. The manifest is a
  documentation provenance receipt, not a scientific execution certificate.

Edit the canonical Markdown or schema, then rebuild. Do not hand-edit `.build/`
or `_site/`. Rendering is deliberately offline apart from Quarto's locally
installed assets; the site does not fetch package code or scientific data.

## Scope of validation

A successful site build establishes rendering and link integrity. Scientific,
container, scheduler and hosted-CI qualification belong to their named records
in the site. Status text distinguishes bounded ARM64 science, the Slurm scheduler
smoke test and a configured but unexecuted hosted workflow. If those scopes
change, update their canonical evidence and the brief landing-page status text.
