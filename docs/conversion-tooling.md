# Conversion Tooling

This repo keeps conversion outputs in `imports/converted/`, not `texts/`.
Converted files are review drafts only. They become corpus texts only after a
human checks rights, edition metadata, completeness, structure, and Markdown
quality.

## Plain Text to Markdown

Use `scripts/convert_plaintext_to_markdown.rb` for no-dependency conversion of
plain text captures from `imports/raw/` into Markdown drafts under
`imports/converted/`.

```sh
ruby scripts/convert_plaintext_to_markdown.rb imports/raw/example.txt imports/converted/example.md
```

The script:

- requires exactly one input path and one output path
- rejects inputs outside `imports/raw/`
- rejects outputs outside `imports/converted/`
- writes only `.md` files
- normalizes CRLF and CR line endings to LF
- trims trailing spaces and tabs from each line
- collapses runs of three or more blank lines to two blank lines
- preserves existing line breaks instead of rewrapping paragraphs or poetry
- adds YAML front matter stubs and TODO comments for human review

It does not fetch network resources, infer rights, detect editions, or decide
whether a text can be moved into `texts/`.

## Review Warnings

Every generated file needs manual review before it is considered canonical-ish
enough for the corpus workflow:

- Confirm the source is allowed for the intended use.
- Replace every `TODO` field in the front matter.
- Check whether line breaks are meaningful prose wrapping, verse lines, OCR
  artifacts, or damaged source structure.
- Add headings that match the source edition without silently rewriting it.
- Compare against the raw input for omissions, duplicated sections, boilerplate,
  OCR errors, encoding replacement characters, and source-specific disclaimers.
- Move reviewed work into `texts/` only after it satisfies the ingestion and
  cleanliness standards.

Generated files in `imports/converted/` are useful for provenance and cleanup,
but downstream exports, embeddings, motif extraction, and training data should
continue to use reviewed corpus files, not intermediate imports.
