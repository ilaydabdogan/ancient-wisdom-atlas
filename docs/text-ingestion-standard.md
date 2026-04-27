# Text Ingestion Standard

This repo is meant to hold complete Markdown texts, not just summaries.

## Directory Policy

```text
texts/
  public-domain/      Complete texts verified as public domain for the target use.
  open-license/       Complete texts under CC BY, CC BY-SA, or compatible licenses.
  permissioned/       Complete texts included under explicit permission.
  citation-only/      Metadata stubs for works that cannot be hosted in full.
```

## What "Original Complete Form" Means

For this project, "original complete form" means the complete text of a specific selected witness, edition, or translation, converted to Markdown without interpretive rewriting.

It does not mean:

- blending multiple editions into one synthetic text
- modernizing silently
- summarizing chapters
- inserting commentary into the source body
- assuming a modern translation is free because the ancient source is old

## Front Matter Required

Every full text file must include:

```yaml
id:
title:
text_status: complete | partial | excerpt
source_language:
text_language:
translator:
edition:
publication_year:
source_url:
rights:
  status:
  jurisdiction:
  license_url:
  training_use:
  full_text:
trademark:
  status:
  marks: []
  use_rules:
transcription:
  mode: diplomatic | normalized | corrected_ocr
  complete: true
  corrections: []
  omissions: []
```

## Markdown Structure

Use headings to preserve source structure:

```markdown
# Work Title

## Book 1

### Chapter 1

Source text here.
```

For verse or line-based texts, preserve line breaks when meaningful.

## Trademark Handling

If a source says a name is trademarked:

- keep the mark only as factual source metadata
- do not use the mark in repo branding
- do not imply endorsement by the source project
- if the text is modified and the source requires renaming, rename the file and title as a derived text

## No Full-Text Cases

For copyrighted or unclear works, create a `citation-only` stub with metadata, page references, motifs, and summaries. Do not host the full text.

