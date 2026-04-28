# Auto Ingestion

This repo can now grow corpus texts from a machine-readable queue instead of
hand-editing one hardcoded importer per work.

## Queue

The queue lives at:

```sh
data/sources/auto-ingestion-queue.yml
```

Each item must include enough metadata to create a canonical corpus file,
manifest, and registry entry. Automatic promotion is allowed only when the
item's `rights` fields explicitly say:

```yaml
status: public_domain
jurisdiction: US
full_text: allowed
training_use: allowed
```

Use `citation_only`, `rights_review`, or a candidate file for anything modern,
ambiguous, culturally sensitive, or license-restricted.

## Run The Pipeline

Process a small batch from the queue:

```sh
ruby scripts/corpus_run_pipeline.rb --limit 2
```

Preview first:

```sh
ruby scripts/corpus_run_pipeline.rb --limit 2 --dry-run
```

Process exact items by queue id or Gutenberg id:

```sh
ruby scripts/corpus_run_pipeline.rb --ids sufi.jami.persian_mystics.davis_gutenberg
ruby scripts/corpus_run_pipeline.rb --ids 45158
```

Fetch and convert without promoting:

```sh
ruby scripts/corpus_run_pipeline.rb --limit 5 --no-promote
```

The runner calls these stage scripts:

```sh
ruby scripts/corpus_fetch_queue.rb
ruby scripts/corpus_convert_queue.rb
ruby scripts/corpus_promote_queue.rb
```

## Safety Rules

- Raw downloads go under `imports/raw/`.
- Converted drafts go under `imports/converted/`.
- Canonical Markdown goes under `texts/public-domain/` only after rights fields
  allow automatic promotion.
- Manifests go under `manifests/`.
- The ingested corpus registry is updated at `data/collections/ingested-corpus.yml`.
- The scripts never read or write API keys.

For Project Gutenberg, keep direct downloads small. For large-scale acquisition,
use mirrors, offline catalogs, or a staged download process rather than high
volume requests against the main site.

## After A Pipeline Run

Always run:

```sh
ruby scripts/check_all.rb
rg -n "sk[-]proj-|OPENAI[_]API[_]KEY=|Authorization:[ ]Bearer" .
```

Then commit and push the changed corpus, manifests, indexes, exports, and queue
state. GitHub Pages will rebuild from the pushed Markdown and YAML.

## Batch API Comes After Clean Markdown

The auto-ingestion scripts create clean canonical text. Batch extraction and
embeddings should run after that:

```sh
ruby scripts/batch_segment_passages.rb ...
ruby scripts/batch_prepare_motif_requests.rb ...
ruby scripts/batch_prepare_embedding_requests.rb ...
```

Keep AI-generated motif records in draft status until reviewed.
