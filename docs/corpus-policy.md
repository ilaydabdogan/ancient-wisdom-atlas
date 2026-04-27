# Corpus Policy

This project is meant to become useful for future retrieval, embeddings, fine-tuning, and comparative analysis. That means rights and provenance are part of the data model, not afterthoughts.

## Full-Text Corpus Goal

The repo should contain complete Markdown source texts whenever the selected edition or translation can legally be copied, redistributed, and used for the intended dataset purpose.

`trademarked` is not the same as `copyrighted`.

- Copyright usually controls whether the full text can be copied.
- Trademark usually controls whether a name, logo, or branding can be used in a way that identifies source or implies endorsement.
- A public-domain text can still have a trademarked edition name or source brand.
- A public-domain ancient work can still have a copyrighted modern translation, commentary, introduction, layout, or image.

So the inclusion rule is:

```text
Include the complete Markdown text if copyright/license permits full reuse.
Track trademark restrictions separately.
Exclude or rename branding when trademark rules require it.
```

## Inclusion Tiers

### Tier A: Full Text Allowed

Use for:

- verified public-domain works
- CC0 works
- works where you own the copyright
- works with explicit permission for dataset/training use

Allowed fields:

- full transcription
- normalized Markdown
- translations
- excerpts
- annotations
- embeddings
- training exports

### Tier B: Open License With Conditions

Use for:

- CC BY
- CC BY-SA
- compatible open scholarly editions

Allowed fields:

- full text if license-compatible
- attribution metadata
- license URL
- change notes

Watch carefully for:

- ShareAlike obligations
- noncommercial restrictions
- edition-specific rights
- translation rights

### Tier C: Citation And Summary Only

Use for:

- modern copyrighted authors
- most Carl Jung editions and translations
- most Joseph Campbell books
- copyrighted modern Bible translations
- modern scholarly books and articles

Allowed fields:

- bibliographic metadata
- short quoted excerpts only where legally appropriate
- summaries in your own words
- concept tags
- page references

Do not include full text in training exports unless rights are cleared.

## Rights Metadata

Every source should include:

```yaml
rights:
  status: public_domain | cc0 | cc_by | cc_by_sa | cc_by_nc | permissioned | citation_only | unknown
  jurisdiction: US
  license_url:
  source_url:
  notes:
  training_use: allowed | conditional | blocked | unknown
  full_text: allowed | conditional | blocked | unknown
trademark:
  status: none | present | unknown
  marks: []
  use_rules:
```

## Dataset Rule

No entry should enter a training dataset until `training_use` is `allowed` or `conditional` with the condition captured in metadata.

For a first version, prefer:

- public-domain primary texts
- CC0 metadata
- your own original notes released under CC0
- copyrighted secondary thinkers represented through citations, summaries, and concept maps

## Complete Markdown Standard

For complete source texts:

- preserve the complete selected edition or translation
- preserve original structure as much as possible: books, chapters, hymns, lines, verses, sections
- avoid modernization unless the file is explicitly marked as normalized
- do not mix commentary into the source body
- put commentary in work notes or pattern notes instead
- record omissions, corrections, and source cleanup in front matter
- remove distributor boilerplate only when it is not part of the work and removal is required or helpful for reuse
- keep attribution and license notices when required by the source license

## Cultural Care

The project should compare motifs without collapsing traditions into one vague universal soup.

Track:

- original language when known
- local names and epithets
- approximate date range
- ritual, political, or social context
- whether a similarity is visual, narrative, theological, linguistic, or psychological
- whether direct transmission is evidenced, plausible, speculative, or unlikely
