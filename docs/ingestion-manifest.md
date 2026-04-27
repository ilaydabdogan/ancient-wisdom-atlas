# Ingestion Manifest

Use an ingestion manifest to track each acquisition artifact from first download through converted intermediate output and final canonical Markdown.

The manifest is provenance metadata. It does not replace full-text front matter, rights review, or the Markdown cleanliness standard.

## Files

- Schema: `schemas/ingestion-manifest.schema.json`
- Template: `templates/ingestion-manifest.yml`

## Scope

Create one manifest entry for each acquired source artifact. If a work is assembled from multiple downloaded files, record each file as its own artifact and point them to the same canonical path only after review confirms that merge is intentional.

Record repo-relative paths only:

- `imports/raw/` for the original fetched file
- `imports/converted/` for converter output before manual cleanup
- `texts/` for reviewed canonical Markdown, or `texts/citation-only/` when full text cannot be hosted

## Required Artifact Fields

- `id`: stable manifest-local artifact id
- `work_id`: matching work id when known
- `source_url`: URL where the raw artifact was acquired
- `fetch_date`: date the raw artifact was fetched, as `YYYY-MM-DD`
- `raw.path`: repo-relative raw import path
- `raw.checksum`: checksum of the raw file before conversion
- `converted.path`: repo-relative converted intermediate path
- `canonical.path`: repo-relative canonical Markdown path
- `converter`: tool, version, command, and relevant settings used for conversion
- `cleanup_notes`: short notes for manual cleanup or normalization performed after conversion
- `rights`: copyright/license status and whether full text and training use are allowed
- `trademark`: source-brand or mark restrictions, if any
- `review`: review status, reviewer, date, and notes
- `extraction`: whether the canonical text is ready for motif/entity extraction

## Status Values

Use the same rights and trademark values as work metadata where possible.

`review.status` should be one of:

- `not_started`
- `in_progress`
- `needs_changes`
- `approved`
- `blocked`

`extraction.readiness` should be one of:

- `not_ready`
- `needs_cleanup`
- `ready`
- `extracted`
- `blocked`

Only mark extraction as `ready` after the canonical path exists, rights allow the intended use, trademark notes have been reviewed, and cleanup issues have no known blockers.

## Checksums

The raw checksum is required because it anchors provenance. Prefer `sha256`. Converted and canonical checksums are optional but useful when a reviewed text should be frozen for an export or extraction run.

## Review Rule

An artifact is ready to move into extraction only when:

1. rights status is not `unknown`
2. `rights.full_text` is `allowed` or the canonical path is a citation-only stub
3. trademark status is not `unknown`, unless review notes explain why
4. `review.status` is `approved`
5. `extraction.readiness` is `ready`
