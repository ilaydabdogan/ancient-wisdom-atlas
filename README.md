# Ancient Wisdom Atlas

A Markdown-first knowledge base for myths, sacred texts, symbols, archetypes, ritual patterns, and recurring human themes across cultures and time.

The project has two goals:

1. Build a provenance-rich corpus that can later be used for search, analysis, embeddings, and training datasets.
2. Map recurring patterns across traditions: divine mother and child, dying-and-rising figures, world trees, flood myths, descents to the underworld, tricksters, sacred twins, hero journeys, and other symbolic structures.

## Core Principle

Do not make a pile of inspirational summaries. Make a scholarly memory system.

Every note should separate:

- `source_text`: what a tradition, text, image, or artifact actually says or depicts
- `interpretation`: what a scholar, analyst, or model thinks it means
- `comparison`: how it relates to motifs in other traditions
- `confidence`: how strong the evidence is
- `rights`: whether the material can be reused in datasets

## Repository Shape

```text
ancient-wisdom-atlas/
  data/
    sources/              Curated source registry
    index.yml             Machine-readable collection index
  docs/
    corpus-policy.md      Copyright, provenance, and inclusion rules
    methodology.md        How to compare myths without flattening cultures
    roadmap.md            Build phases from corpus to pattern atlas
  imports/                Tracked raw and intermediate ingestion workspace
  patterns/               Cross-cultural pattern essays
  schemas/                JSON schemas for metadata validation
  scripts/                Export and validation utilities
  taxonomy/               Motifs, traditions, symbols, and archetypes
  texts/                  Complete Markdown source texts
  templates/              Reusable Markdown entry templates
```

## Recommended Workflow

1. **Register the source**
   Add the text, artifact, image, or secondary work to `data/sources/seed_sources.yml`.

2. **Add the complete text when rights allow**
   Put full Markdown transcriptions in `texts/public-domain/`, `texts/open-license/`, or `texts/permissioned/`. Use `templates/full-text.md`.

3. **Create a work note**
   Use `templates/work.md` for a source text such as the *Epic of Gilgamesh*, *Theogony*, *Genesis*, *Bhagavad Gita*, *Popol Vuh*, or a hymn to Isis.

4. **Extract motifs**
   Use `templates/motif.md` to capture recurring symbols, roles, scenes, objects, and narrative events.

5. **Compare patterns**
   Use `templates/comparison.md` for cross-cultural hypotheses such as Divine Mother and Holy Child.

6. **Export for machines**
   Keep front matter consistent so the repo can later be exported to JSONL, embeddings, graph databases, or model training datasets.

## Rights Tiers

- `public_domain`: safe default for full-text ingestion when verified in the relevant jurisdiction.
- `cc0`: ideal for metadata and original contributions.
- `cc_by` / `cc_by_sa`: usable with attribution and license compatibility tracking.
- `citation_only`: use for modern copyrighted authors such as Carl Jung and Joseph Campbell unless a specific open license allows more.

## Full-Text Rule

The repo should contain complete Markdown texts for rights-cleared works. A trademarked title or source name is not the same thing as copyright. If a text is public domain but the source name is trademarked, keep the text only when the source permits it, avoid implying endorsement, and rename modified versions when required.

Raw internet data should never be treated directly as corpus text. Put downloaded HTML/OCR/XML/TXT in `imports/raw/`, use `imports/converted/` for intermediate conversion output, then move only reviewed, clean Markdown into `texts/`. Raw and intermediate imports may be committed for provenance, but export/training pipelines should read canonical files only. See [docs/markdown-cleanliness-standard.md](docs/markdown-cleanliness-standard.md).

## First Pattern Seed

Start with [Divine Mother and Holy Child](patterns/divine-mother-holy-child.md), because it naturally connects Egyptian, Christian, goddess, royal, and archetypal mother-child imagery while forcing careful separation between visual similarity, historical transmission, and psychological interpretation.

## Build Roadmap

See [docs/roadmap.md](docs/roadmap.md) for the staged plan: foundation, corpus buildout, AI extraction, pattern atlas, machine exports, and research questions.

## First 500

See [docs/first-500-corpus.md](docs/first-500-corpus.md) for the first large collection target: 500 corpus units across ancient Near Eastern, Egyptian, biblical, Greek/Roman, South Asian, Buddhist, East Asian, Islamic/Persianate, Norse/Celtic, Mesoamerican, African, and Oceanic material.

## Pattern Logic

See [docs/pattern-discovery-logic.md](docs/pattern-discovery-logic.md) for how themes, symbols, motifs, and comparisons should be extracted and scored.

## Similarity Browser

Start with [comparisons/](comparisons/) for evidence-backed cross-cultural comparison pages and the generated [motif occurrence index](comparisons/motif-index.md), which groups extraction records by motif across traditions. The GitHub Pages site also builds individual motif pages, tradition-bridge tables, and a [timeline data index](data/indexes/cultural-timeline.yml) for approximate era comparison.

## Next Corpus Wave

[data/sources/corpus-wave-b-candidates.yml](data/sources/corpus-wave-b-candidates.yml) tracks 20 high-value public-domain or rights-review candidate sources for the next ingestion push, including Confucian, Islamic, Finnish/Karelian, Vedic, Celtic, Shinto, Mesoamerican, Zoroastrian, Persian, and Greek materials.

## GitHub Pages

The repository includes a generated static site for browsing the atlas as a website. The Pages workflow builds `site/` from Markdown and YAML files on every push to `main`, then deploys it with GitHub Pages.

Expected project URL after Pages is enabled: `https://ilaydabdogan.github.io/ancient-wisdom-atlas/`

## Batch Processing

Use [docs/batch-api-workflow.md](docs/batch-api-workflow.md) for the OpenAI Batch API workflows that segment clean canonical Markdown, prepare sharded JSONL requests, upload and track Batch jobs, download results, stage machine-generated extraction drafts for human review, and generate embeddings for passages or extraction records.

## Scale-Up Workflow

- [docs/source-prioritization.md](docs/source-prioritization.md): where to acquire first texts and in what order
- [docs/ingestion-manifest.md](docs/ingestion-manifest.md): how to track raw imports, converted drafts, checksums, rights, and canonical outputs
- [docs/conversion-tooling.md](docs/conversion-tooling.md): how to create reviewed Markdown drafts from raw plain text
- [docs/auto-ingestion.md](docs/auto-ingestion.md): how to grow the corpus from the queue-based fetch/convert/promote pipeline
- [docs/extraction-protocol.md](docs/extraction-protocol.md): how AI/humans should extract symbols, motifs, scenes, and comparison claims
- [docs/ci.md](docs/ci.md): what GitHub Actions checks on every push

## First Corpus Data

The first canonical collection is the public-domain World English Bible Classic Pentateuch: [Genesis](texts/public-domain/biblical/world-english-bible-classic/genesis.md), [Exodus](texts/public-domain/biblical/world-english-bible-classic/exodus.md), [Leviticus](texts/public-domain/biblical/world-english-bible-classic/leviticus.md), [Numbers](texts/public-domain/biblical/world-english-bible-classic/numbers.md), and [Deuteronomy](texts/public-domain/biblical/world-english-bible-classic/deuteronomy.md). Each book is backed by raw HTML imports, a converted draft, an ingestion manifest, and extraction records.

## Wave 2 Corpus Data

The first cross-cultural wave adds public-domain Project Gutenberg source texts for Daoist, Buddhist, Hindu, Greek, Egyptian, Mesopotamian, and Norse comparison work. Each text keeps its raw plain-text capture under `imports/raw/`, a converted draft under `imports/converted/`, a canonical Markdown file under `texts/public-domain/`, and an ingestion manifest under `manifests/`.

## Machine Export

Run:

```sh
ruby scripts/validate_metadata.rb
ruby scripts/check_taxonomy_refs.rb
ruby scripts/check_first_500_corpus.rb
ruby scripts/check_structured_files.rb
ruby scripts/check_clean_markdown.rb
ruby scripts/export_jsonl.rb
```

Or run the whole local check suite:

```sh
ruby scripts/check_all.rb
```

The exporter writes JSONL files into `exports/`, which can be committed as machine-readable dataset artifacts.
