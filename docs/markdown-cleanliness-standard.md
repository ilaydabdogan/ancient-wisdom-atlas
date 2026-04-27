# Markdown Cleanliness Standard

This repo can keep raw internet captures for auditability, but only clean, canonical Markdown belongs in the corpus. The goal is to make every rights-cleared text readable by humans, stable for review, and predictable for export to JSONL, embeddings, or other machine formats.

## Directory Rule

Use raw and canonical directories for different jobs:

```text
imports/raw/            Source captures and raw acquisition artifacts.
imports/converted/      Intermediate conversion output.
texts/public-domain/    Clean full texts with verified public-domain rights.
texts/open-license/     Clean full texts with compatible open licenses.
texts/permissioned/     Clean full texts included by explicit permission.
texts/citation-only/    Metadata-only stubs when full text cannot be hosted.
```

Raw captures may contain HTML, scripts, navigation, comments, OCR noise, or source packaging. They are evidence, not finished corpus entries. They may be committed for provenance, but do not point extraction, motif analysis, exports, embeddings, or training jobs at raw captures.

Canonical files under `texts/` must be clean Markdown. They should preserve the source's structure and words without carrying over website scaffolding.

## No Raw HTML In Texts

Files under `texts/` must not contain raw page HTML such as:

- doctype, html, head, body, script, style, nav, or footer tags
- tracking pixels, analytics snippets, cookie banners, share buttons, menus, search boxes, or pagination chrome
- unconverted paragraph, heading, list, table, or line-break tags

Rare inline markup is allowed only when Markdown cannot represent the source cleanly and the tag is intentional, documented, and harmless. Prefer Markdown headings, lists, block quotes, tables, emphasis, and code fences.

## Entity Decoding

Canonical Markdown should use decoded readable characters:

- the ampersand entity becomes `&`
- the quotation-mark entity becomes `"`
- apostrophe entities become `'`
- the nonbreaking-space entity becomes a normal space unless nonbreaking behavior is textually meaningful
- numeric entities should be converted to the intended character or an accepted ASCII equivalent for that file

Do not leave entity soup in corpus files. If a symbol is uncertain because of OCR or encoding damage, record the uncertainty in `transcription.corrections` or `transcription.omissions` rather than hiding it in the source body.

## Preserve Source Structure

Clean conversion must preserve the selected witness, edition, or translation:

- keep the original book, chapter, section, verse, stanza, or line hierarchy
- use Markdown headings for major divisions
- preserve line breaks where they carry meaning, especially in verse, inscriptions, hymns, and dramatic dialogue
- keep verse numbers, section numbers, or folio/page markers when they are part of the usable citation structure
- do not blend editions, silently modernize wording, summarize passages, or insert commentary into the source body

If source layout is ambiguous, choose the simplest structure that supports citation and review, then document the choice in front matter.

## Boilerplate Removal

Remove web and publisher scaffolding that is not part of the work:

- site headers, footers, breadcrumbs, navigation, ads, cookie notices, newsletter prompts, and "related articles"
- search widgets, download controls, social links, share text, and print buttons
- duplicate title blocks created by page templates
- OCR or scraping artifacts that clearly come from page furniture

Keep license notices, translator notes, editorial notes, and attribution only when they are part of the rights-cleared edition or required by the license. When kept, place them in a clear source-appropriate section or front matter, not mixed randomly into the text.

## Front Matter Requirements

Every canonical full-text file must use `templates/full-text.md` and include complete YAML front matter before the text body.

Required fields include:

- identity: `id`, `title`, `alternate_titles`, `text_status`
- classification: `tradition`, `culture`, `region`, `source_type`, `tags`
- language and date: `source_language`, `text_language`, `date_range`
- provenance: `source_id`, `edition`, `translator`, `editor`, `publication_year`, `publisher`, `source_url`, `access_date`
- rights: `status`, `jurisdiction`, `license_url`, `training_use`, `full_text`, `notes`
- trademark: `status`, `marks`, `use_rules`
- transcription: `mode`, `complete`, `corrections`, `omissions`
- analysis hooks: `motifs`, `figures`

The source body starts after front matter and the top-level `# Title`. Commentary, extraction notes, and cross-cultural comparison belong in `patterns/`, `taxonomy/`, or work notes, not in the source text.

## Manual Review Checklist

Before a Markdown text is treated as canonical, review it for:

- no raw HTML document wrappers, scripts, styles, nav, footer, or tracking fragments
- entities decoded into readable text
- source structure preserved with stable headings and meaningful line breaks
- boilerplate removed without deleting license-required attribution or source notes
- front matter complete and consistent with `templates/full-text.md`
- rights fields match the source registry and justify full-text hosting
- no AI paraphrase, summary, or interpretation inside the source body
- citations remain possible through chapter, verse, line, section, or heading markers
- file path matches the rights tier: `public-domain`, `open-license`, `permissioned`, or `citation-only`

## CI And Lint Expectations

Validation should be boring and repeatable. Before export or review, run the existing metadata checks:

```sh
ruby scripts/validate_metadata.rb
ruby scripts/check_taxonomy_refs.rb
ruby scripts/check_first_500_corpus.rb
ruby scripts/check_structured_files.rb
ruby scripts/check_clean_markdown.rb
ruby scripts/export_jsonl.rb
```

Or run all checks:

```sh
ruby scripts/check_all.rb
```

Future Markdown linting should reject obvious raw HTML wrappers, undecoded common entities, missing front matter, malformed YAML, duplicate top-level titles, and files under `texts/` that do not match a known rights tier. CI should treat these as corpus quality failures, not stylistic preferences.

## Examples

Clean canonical Markdown:

```markdown
---
id: gilgamesh-example
title: The Epic of Gilgamesh
text_status: complete
source_language: Akkadian
text_language: English
rights:
  status: public_domain
transcription:
  mode: normalized
  complete: true
---

# The Epic of Gilgamesh

## Tablet I

He who saw the Deep, the country's foundation,
who knew the proper ways, was wise in all matters.
```

Bad scraped text:

```html
<!doctype html>
<html>
<head><script src="/analytics.js"></script></head>
<body>
<nav>Home | Search | Donate</nav>
<h1>The Epic of Gilgamesh</h1>
<p>He who saw the Deep &amp; knew all things...</p>
<footer>Share this page</footer>
</body>
</html>
```

Clean line-preserving verse:

```markdown
### Hymn

To the bright one I lift my voice;
to the keeper of thresholds, my offering.
```

Bad canonical file body:

```markdown
# Hymn

This page has been converted from ExampleSite. Click here for more sacred texts.
To the bright one I lift my voice;<br>to the keeper of thresholds, my offering.
My interpretation: this probably means rebirth.
```
