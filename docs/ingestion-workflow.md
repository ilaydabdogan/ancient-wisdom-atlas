# Ingestion Workflow

Use this checklist when adding a complete source text.

## 1. Select The Witness

Decide exactly what you are adding:

- original-language text
- public-domain translation
- open-license translation
- diplomatic transcription of an artifact
- normalized edition

Do not blend editions unless the file is explicitly a derived critical edition.

## 2. Verify Rights

Before adding full text, record:

- copyright status
- translation or edition rights
- license URL
- source URL
- jurisdiction
- trademark restrictions
- whether full text can be redistributed
- whether training/embedding use is allowed, conditional, blocked, or unknown

If rights are unclear, add a `texts/citation-only/` stub instead.

## 3. Convert To Markdown

Use `templates/full-text.md`.

Raw downloaded material should go under `imports/raw/`, and intermediate converter output should go under `imports/converted/`. These files may be committed for provenance and reproducibility. Only reviewed canonical Markdown belongs under `texts/`; use `docs/markdown-cleanliness-standard.md` as the cleanup standard.

Preserve:

- book/chapter/section hierarchy
- line breaks where meaningful
- verse numbers where present
- translator notes only if they are part of the rights-cleared edition and useful

Avoid:

- silent modernization
- AI paraphrase in source body
- mixing commentary with source text
- source-brand boilerplate that is not part of the work, unless the license requires keeping it

## 4. Add Machine Metadata

Fill in:

- `id`
- `title`
- `tradition`
- `source_language`
- `text_language`
- `provenance`
- `rights`
- `trademark`
- `transcription`
- `tags`

## 5. Extract Motifs

After the full text is in place:

1. Run an extraction pass for figures, relationships, places, symbols, scenes, and motifs.
2. Store interpretive notes outside the source text.
3. Mark uncertain comparisons as hypotheses.
4. Link motifs back to exact chapters, verses, lines, or sections.

## 6. Export

Run:

```sh
ruby scripts/check_clean_markdown.rb
ruby scripts/export_jsonl.rb
```

The export writes machine-readable JSONL files under `exports/`.
