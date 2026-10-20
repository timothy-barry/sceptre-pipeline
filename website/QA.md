> Publication scope: historical validation below refers to the explicitly named original source/runtime. Detailed local evidence and raster previews are not distributed in this review branch. This publication commit has its own pending qualification; see the publication scope document.

# Documentation verification

## Final frozen-runtime documentation

The final local build on 2026-10-19 rendered **27 HTML pages** and verified
**1,865 local page, resource and fragment links**. Both `python3 website/build.py`
and an independent `python3 website/build.py --check` exited 0. Source freshness
passed against the complete saved canonical-input manifest. The parameter
reference contains 14 flags generated from the current schema/config.

The documentation now distinguishes current SCEPTRE source
`01bb39ccf8373ae8965a2679ee4813a63ea2d85d`, archive SHA256
`606363fce32238354fc0d126d79f515973da7c8287ca43b14ce53ce2d00df4b7`,
from the historical `169c16e` compatibility baseline. The rendered qualification
page includes the current 38-case statement, current source identity, historical
baseline, terminal review addendum and platform/scale limits. This is a
presentation readback of canonical evidence; documentation QA did not rerun the
scientific suites.

A separate Chrome task tab checked all 27 final routes at a measured
**390 × 844 CSS-pixel viewport**. Every page fit its available width, had one
visible H1 and had no broken images. Desktop landing-page QA used the default
1491 × 775 viewport. Engineering navigation opened the scale-boundaries guide;
its sidebar link opened Scientific qualification. Current-versus-historical
headings and source identities were checked in the rendered page. Final console
inspection returned no warnings/errors.

Chrome's viewport capability request was calibrated to the measured CSS size;
browser zoom settings were not changed. The owned QA tab was closed, the viewport
override reset and the loopback preview stopped.

- Final verification receipt (historical evidence retained locally)
- Build log (historical evidence retained locally) and independent freshness/link check (historical evidence retained locally)
- Exact canonical-input hashes (historical evidence retained locally)
- Rendered page/asset hashes (historical evidence retained locally)
- Desktop landing page (historical evidence retained locally) and phone landing page (historical evidence retained locally)
- Current qualification: desktop (historical evidence retained locally) and phone (historical evidence retained locally)
- All 27 phone-page measurements (historical evidence retained locally)
- Navigation and qualification readback (historical evidence retained locally)

## Historical checkpoints

Raw historical receipts, screenshots and measurements remain unchanged. Their
then-pending runtime/text refreshes are resolved by the final build above; those
receipts are retained as dated evidence rather than rewritten.

- Original 16-page interaction receipt (historical evidence retained locally):
  992 links, mobile navigation, keyboard table scrolling, Slurm search and console
  checks on the original snapshot. These specific interactions are not claimed
  as newly repeated on all 27 final pages.
- 21-page source-169c16e checkpoint (historical evidence retained locally):
  1,447 links and root-supplied desktop/phone/HPC layout evidence.
- 23-page scale preview (historical evidence retained locally):
  1,615 links, fresh Chrome phone-layout measurements and scale-page screenshots
  while the replacement runtime qualification was still in progress.

These checks establish documentation rendering, navigation, source freshness and
layout. Scientific, scheduler, container and hosted-CI qualification remain in
their canonical records. Build output is ignored. No publication or deployment
occurred, and the documentation agent made no commit.

Reproduce from the repository root:

```bash
python3 website/build.py
python3 website/build.py --check
python3 website/preview.py --port 8095
```

Open the printed loopback URL and stop the preview with Ctrl-C.
