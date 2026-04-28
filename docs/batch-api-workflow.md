# OpenAI Batch API Workflow

This workflow processes already-clean canonical corpus Markdown through the OpenAI Batch API. It does not fetch raw sources, scrape HTML, repair OCR, or rewrite canonical texts.

Use it for delayed, auditable semantic processing where stable inputs, resumability, and reviewable outputs matter more than live interactive latency.

## What The Pipeline Does

The first production pipeline is passage-level motif, symbol, and pattern extraction:

1. Segment canonical Markdown under `texts/public-domain/` into stable passage units.
2. Generate JSONL Batch API requests with deterministic `custom_id` values.
3. Upload request shards as OpenAI files with `purpose=batch`.
4. Create Batch jobs against `/v1/responses`.
5. Poll job status and record output/error file IDs.
6. Download output and error JSONL files.
7. Ingest successful results into draft YAML extraction records under `extractions/generated/openai-batch/<run_id>/`.

All run state lives under `data/batches/<run_id>/`.

The second production lane is extraction review and motif normalization:

1. Build an extraction coverage index to decide which texts still need dense extraction.
2. Prepare Batch requests over generated or seed extraction YAML records.
3. Ask the model to review motif usefulness, map labels to canonical taxonomy refs, flag over-specific labels, and classify comparison claims by mode.
4. Ingest review results under `data/reviews/extraction-quality/<run_id>/`.
5. Use those review records before promoting drafts or rebuilding pattern-facing indexes.

Embeddings are a later discovery lane for either:

- segmented canonical-text passages, using `passages.jsonl` from the segmenter
- existing extraction YAML records under `extractions/`

Embedding vectors are ingested under `data/embeddings/<run_id>/`.

## Official API Assumptions

The scripts follow the OpenAI Batch API contract:

- Batch input files are JSONL.
- Each request line has a unique `custom_id`, `method`, `url`, and endpoint-specific `body`.
- Batch input files are uploaded through the Files API with `purpose=batch`.
- Batch jobs are created with an uploaded `input_file_id`, an endpoint such as `/v1/responses`, and `completion_window=24h`.
- Completed jobs expose output and error files by file ID.
- Embedding batches can target `/v1/embeddings`; keep one embedding input per request for simple accounting against the documented 50,000 embedding-input batch limit.

Reference docs:

- <https://platform.openai.com/docs/guides/batch>
- <https://platform.openai.com/docs/api-reference/batch>
- <https://platform.openai.com/docs/api-reference/files>
- <https://platform.openai.com/docs/guides/structured-outputs>

## Secrets

Set the API key in your shell. Do not create or commit a real `.env`.

```sh
# Set OPENAI_API_KEY in your shell session; never write the real value to a repo file.
export OPENAI_API_KEY
```

You can override the default extraction model:

```sh
export OPENAI_BATCH_MODEL="gpt-5.2"
export OPENAI_BATCH_REASONING_EFFORT="high"
```

The request generator also accepts `--model`.

For the schema-driven motif extraction pipeline, prefer `gpt-5.2` over slower variants that do not support structured outputs.

You can override the default embedding model:

```sh
export OPENAI_EMBEDDING_MODEL="text-embedding-3-large"
```

## Demo Batch

Create a small local demo from two existing canonical texts:

```sh
ruby scripts/batch_segment_passages.rb \
  --run-id demo-motif-extraction \
  --text texts/public-domain/biblical/world-english-bible-classic/genesis.md \
  --text texts/public-domain/buddhist/project-gutenberg/dhammapada-max-muller.md \
  --max-passages-per-text 2 \
  --limit 4 \
  --force
```

Generate sharded Batch JSONL:

```sh
ruby scripts/batch_prepare_motif_requests.rb \
  --run-id demo-motif-extraction \
  --model "$OPENAI_BATCH_MODEL" \
  --max-requests-per-shard 2 \
  --force
```

This creates:

- `data/batches/demo-motif-extraction/passages.jsonl`
- `data/batches/demo-motif-extraction/request-map.jsonl`
- `data/batches/demo-motif-extraction/requests/index.yml`
- `data/batches/demo-motif-extraction/requests/shard-*.jsonl`
- `data/batches/demo-motif-extraction/manifest.yml`

Create a small embeddings demo from those same passages:

```sh
ruby scripts/batch_prepare_embedding_requests.rb \
  --run-id demo-embeddings \
  --source passages \
  --passages data/batches/demo-motif-extraction/passages.jsonl \
  --model "$OPENAI_EMBEDDING_MODEL" \
  --max-requests-per-shard 2 \
  --force
```

This creates:

- `data/batches/demo-embeddings/embedding-request-map.jsonl`
- `data/batches/demo-embeddings/requests/index.yml`
- `data/batches/demo-embeddings/requests/shard-*.jsonl`
- `data/batches/demo-embeddings/manifest.yml`

## Submit And Track

Upload input shards:

```sh
ruby scripts/batch_upload_inputs.rb --run-id demo-motif-extraction
```

Create Batch jobs:

```sh
ruby scripts/batch_create_jobs.rb --run-id demo-motif-extraction
```

Inspect status:

```sh
ruby scripts/batch_status.rb --run-id demo-motif-extraction
```

Inspect local recorded state without calling OpenAI:

```sh
ruby scripts/batch_status.rb --run-id demo-motif-extraction --local
```

Download outputs and errors after jobs complete or partially expire:

```sh
ruby scripts/batch_download_results.rb --run-id demo-motif-extraction
```

Ingest successful output records into draft extraction YAML:

```sh
ruby scripts/batch_ingest_motif_results.rb --run-id demo-motif-extraction
```

For embeddings runs, use the same upload, create, status, and download commands with the embeddings `run_id`, then ingest vectors:

```sh
ruby scripts/batch_upload_inputs.rb --run-id demo-embeddings
ruby scripts/batch_create_jobs.rb --run-id demo-embeddings
ruby scripts/batch_status.rb --run-id demo-embeddings
ruby scripts/batch_download_results.rb --run-id demo-embeddings
ruby scripts/batch_ingest_embedding_results.rb --run-id demo-embeddings
```

The importer writes machine-generated drafts to:

```text
extractions/generated/openai-batch/demo-motif-extraction/
```

These records are marked `needs_review`; treat them as draft data until a human review pass promotes or edits them.

## Overnight Motif Run

Use the nightly runner when you want one command to prepare, submit, and watch a motif extraction run.

Start with a canary. This prepares a tiny run and can submit it if `OPENAI_API_KEY` is set in the shell:

```sh
# Set OPENAI_API_KEY in your shell first; do not write it to a repo file.
export OPENAI_BATCH_MODEL="gpt-5.5"
export OPENAI_BATCH_REASONING_EFFORT="medium"

ruby scripts/batch_nightly_run.rb \
  --mode all \
  --canary \
  --max-output-tokens 12000 \
  --poll-seconds 300 \
  --max-polls 12
```

If the canary is accepted and completes cleanly, launch the larger overnight run:

```sh
ruby scripts/batch_nightly_run.rb \
  --mode all \
  --run-id motif-extraction-YYYY-MM-DD-nightly \
  --model "$OPENAI_BATCH_MODEL" \
  --reasoning-effort "$OPENAI_BATCH_REASONING_EFFORT" \
  --max-output-tokens 12000 \
  --max-requests-per-shard 500 \
  --poll-seconds 900 \
  --max-polls 96
```

If you want to prepare locally first without an API key:

```sh
ruby scripts/batch_nightly_run.rb \
  --mode prepare \
  --run-id motif-extraction-YYYY-MM-DD-nightly \
  --max-output-tokens 12000
```

Then submit and watch later:

```sh
ruby scripts/batch_nightly_run.rb --mode submit --run-id motif-extraction-YYYY-MM-DD-nightly
ruby scripts/batch_nightly_run.rb --mode watch --run-id motif-extraction-YYYY-MM-DD-nightly
```

## Full Corpus Run

Before launching a large extraction run, build the coverage index:

```sh
ruby scripts/build_extraction_coverage.rb
```

This writes:

- `data/indexes/extraction-coverage.yml`
- `docs/extraction-coverage.md`

For a targeted high-priority run, select only texts with no/thin/developing extraction coverage:

```sh
ruby scripts/batch_segment_passages.rb \
  --run-id motif-extraction-YYYY-MM-DD-high-priority \
  --coverage data/indexes/extraction-coverage.yml \
  --coverage-priority high \
  --max-chars 6000 \
  --min-chars 500 \
  --force

ruby scripts/batch_prepare_motif_requests.rb \
  --run-id motif-extraction-YYYY-MM-DD-high-priority \
  --model "$OPENAI_BATCH_MODEL" \
  --max-output-tokens 12000 \
  --max-requests-per-shard 500 \
  --max-bytes-per-shard 188743680 \
  --force
```

For a larger all-corpus run, omit `--limit` and tune shard sizes:

```sh
ruby scripts/batch_segment_passages.rb \
  --run-id motif-extraction-YYYY-MM-DD \
  --glob "texts/public-domain/**/*.md" \
  --max-chars 6000 \
  --min-chars 500

ruby scripts/batch_prepare_motif_requests.rb \
  --run-id motif-extraction-YYYY-MM-DD \
  --model "$OPENAI_BATCH_MODEL" \
  --max-requests-per-shard 1000 \
  --max-bytes-per-shard 188743680
```

Then upload, create, poll, download, and ingest with the same commands shown above.

## Extraction Review And Normalization

After generated extraction YAML exists, prepare a review batch:

```sh
ruby scripts/batch_prepare_extraction_review_requests.rb \
  --run-id extraction-review-YYYY-MM-DD \
  --coverage data/indexes/extraction-coverage.yml \
  --normalization taxonomy/motif-normalization.yml \
  --reviewer-status needs_review \
  --model "$OPENAI_BATCH_MODEL" \
  --max-output-tokens 8000 \
  --max-requests-per-shard 500 \
  --force
```

Use the same generic upload/create/status/download scripts:

```sh
ruby scripts/batch_upload_inputs.rb --run-id extraction-review-YYYY-MM-DD
ruby scripts/batch_create_jobs.rb --run-id extraction-review-YYYY-MM-DD
ruby scripts/batch_status.rb --run-id extraction-review-YYYY-MM-DD
ruby scripts/batch_download_results.rb --run-id extraction-review-YYYY-MM-DD
```

Then ingest review outputs:

```sh
ruby scripts/batch_ingest_extraction_review_results.rb --run-id extraction-review-YYYY-MM-DD
```

The review importer writes:

- `data/reviews/extraction-quality/<run_id>/reviews.jsonl`
- `data/reviews/extraction-quality/<run_id>/records/*.yml`
- `data/reviews/extraction-quality/<run_id>/manifest.yml`

Treat these as advisory review records. They do not automatically rewrite extraction YAML or taxonomy files; promotion should remain deliberate.

The normalization guidance lives in `taxonomy/motif-normalization.yml`. It supplies hierarchy notes, aliases, quality flags, comparison-mode discipline, and broader `canonical_motif_groups` for Pattern Explorer queries. Review batches can map labels like `descent`, `underworld_trial`, `sacred_fire`, or `renunciation` without collapsing them into one flat motif, while granular generated labels can still be placed through `raw_motif_group_index`.

## Embeddings

Embeddings are useful for later unexpected-discovery workflows, but they are not required before dense extraction and motif normalization.

To prepare embeddings for segmented passages:

```sh
ruby scripts/batch_prepare_embedding_requests.rb \
  --run-id passage-embeddings-YYYY-MM-DD \
  --source passages \
  --passages data/batches/motif-extraction-YYYY-MM-DD/passages.jsonl \
  --model "$OPENAI_EMBEDDING_MODEL" \
  --max-requests-per-shard 10000 \
  --max-bytes-per-shard 188743680
```

To prepare embeddings for reviewed or draft extraction records:

```sh
ruby scripts/batch_prepare_embedding_requests.rb \
  --run-id extraction-embeddings-YYYY-MM-DD \
  --source extractions \
  --extraction-glob "extractions/**/*.yml" \
  --model "$OPENAI_EMBEDDING_MODEL"
```

## Resumability

The pipeline is designed for reruns:

- Segmentation is deterministic for the same text files and options.
- Request `custom_id` values are based on stable passage IDs and line ranges.
- Request shards are indexed with SHA-256 checksums.
- Upload scripts skip shards that already have matching uploaded file IDs.
- Job creation skips shards that already have recorded Batch IDs.
- Download scripts skip files already present unless `--force` is used.
- Ingest writes `data/batches/<run_id>/ingested-results.jsonl` and skips already materialized records when content is unchanged.
- Re-running motif request preparation skips previously ingested `custom_id`s unless `--include-ingested` is passed.
- New motif runs can skip records already ingested by a prior run with `--skip-ingested-from-run-id PRIOR_RUN_ID`; use this for retry passes after queue failures, schema changes, or `max_output_tokens` truncation.
- Extraction review ingestion merges by `review_id` into `data/reviews/extraction-quality/<run_id>/reviews.jsonl` and records per-item ingest status under `data/batches/<run_id>/extraction-review-ingested-results.jsonl`.
- Embedding ingestion merges by `custom_id` into `data/embeddings/<run_id>/embeddings.jsonl` and records per-item ingest status under `data/batches/<run_id>/embedding-ingested-results.jsonl`.

Use the same `run_id` to resume an interrupted workflow. Use a new `run_id` for a new scientific pass, model change, prompt change, or corpus-wide rerun.

Example motif retry after incomplete JSON from an earlier run:

```sh
ruby scripts/batch_prepare_motif_requests.rb \
  --run-id motif-extraction-YYYY-MM-DD-retry-12000 \
  --passages data/batches/motif-extraction-YYYY-MM-DD/passages.jsonl \
  --skip-ingested-from-run-id motif-extraction-YYYY-MM-DD \
  --max-output-tokens 12000 \
  --reasoning-effort medium \
  --max-requests-per-shard 100
```

## Review Discipline

Batch output is not canonical on arrival. The importer preserves provenance but stages records under `extractions/generated/openai-batch/` with `reviewer_status.status: needs_review`.

Before promoting generated records into tradition-specific extraction directories:

- Check literal observations against the canonical passage.
- Remove unsupported comparison claims.
- Verify motif and symbol taxonomy refs.
- Keep source text and interpretation separated.
- Run `ruby scripts/check_all.rb`.

## Validation

After local preparation or ingestion, run:

```sh
ruby scripts/check_all.rb
```
