#!/usr/bin/env python3
"""Render deterministic badges from native nf-test CSV and pipeline manifest."""
import argparse
import csv
import html
from pathlib import Path
import re


def badge(label, value, color):
    left, right = 7 * len(label) + 12, 7 * len(value) + 12
    width = left + right
    label, value = html.escape(label), html.escape(value)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="20" role="img" aria-label="{label}: {value}">
<title>{label}: {value}</title>
<rect width="{width}" height="20" rx="3" fill="#555"/>
<path fill="{color}" d="M{left} 0h{right}v20H{left}z"/>
<g fill="#fff" text-anchor="middle" font-family="Verdana,DejaVu Sans,sans-serif" font-size="11">
<text x="{left / 2:g}" y="14">{label}</text><text x="{left + right / 2:g}" y="14">{value}</text>
</g></svg>
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with args.csv.open() as stream:
        rows = list(csv.DictReader(stream))
    if not rows or any(row.get('covered') not in ('true', 'false') for row in rows):
        parser.error('Coverage report must contain nonempty native boolean rows')
    names = [row['filename'] for row in rows]
    if len(names) != len(set(names)):
        parser.error('Duplicate source files in coverage report')
    covered = sum(row['covered'] == 'true' for row in rows)
    pct = 100 * covered / len(rows)
    version = re.search(r"(?m)^\s*version\s*=\s*'([^']+)'", Path('nextflow.config').read_text())
    if not version:
        parser.error('Pipeline manifest version missing')
    outputs = {
        'nf-test-coverage.svg': badge('nf-test file coverage', f'{pct:.0f}% ({covered}/{len(rows)})', '#dfb317' if pct < 90 else '#4c1'),
        'version.svg': badge('pipeline', version[1], '#007ec6'),
    }
    for filename, content in outputs.items():
        path = Path('docs/badges') / filename
        if args.check:
            if not path.exists() or path.read_text() != content:
                parser.error(f'{path} is stale; rerun without --check and commit the badge')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    print(f'nf-test file coverage: {covered}/{len(rows)} ({pct:.0f}%); version: {version[1]}')


if __name__ == '__main__':
    main()
