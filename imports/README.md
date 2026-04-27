# Imports Workspace

This directory preserves ingestion provenance.

Use:

- `imports/raw/` for downloaded HTML, TXT, EPUB, XML, OCR, or scraped source material
- `imports/converted/` for intermediate Markdown produced by conversion tools

These directories may be committed when the material is useful for audit, provenance, debugging, or reproducible conversion.

Canonical corpus files still belong only in `texts/` after rights review, cleanup, metadata, and validation.

Raw and converted imports are archival inputs, not corpus-ready texts. Export, motif extraction, and training data generation should read from `texts/`, `patterns/`, and explicit data files, not from raw imports.
