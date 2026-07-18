# Azure Campaign Plan — Five Days of Compute

**Window:** 2026-07-17 → 2026-07-22 (credits expire; ~$50,000 USD available).
**Decision (İlayda, 2026-07-17):** all four analytical fronts; skip experiential growth this round; full site evolution.

## Objective

Convert expiring Azure credits into permanent, versioned research assets:
a 5–10× larger ancient corpus, a replication study that calibrates the
extraction instrument, an embedding layer over every passage and motif, and
the first empirical test of narrative-sequence recurrence (the monomyth
question). Everything lands as committed YAML/JSONL in this repo — the
credits expire, the data does not.

## Hard constraints

1. **Batch latency:** Azure OpenAI Batch jobs have up to 24h completion
   windows. Five days ≈ at most ~5 sequential batch generations. Jobs must
   be enqueued continuously — the pipeline must never sleep.
2. **Quota:** Batch has enqueued-token ceilings per deployment; standard
   deployments have TPM ceilings. Request quota increases on Day 1, hour 1.
3. **Spend-rate math:** the credits expire regardless, so the metric is
   *useful work completed*, not cost efficiency. Batch's 50% discount gives
   2× work per credit — use it while quota allows. If batch quota is the
   bottleneck, saturate standard deployments in parallel (spending more per
   token is fine; stranding credits is not). If throughput is still the
   bottleneck, consider hourly provisioned-throughput (PTU) deployments,
   which buy guaranteed massive throughput at a fixed hourly burn.
4. **Methodology guards hold:** no experiential/ancient mixing; every new
   motif traces to a passage; taxonomy revisions follow evidence; run
   `ruby scripts/check_all.rb` after each ingest.

## Pipeline adaptation (done 2026-07-17)

`scripts/batch_common.rb` now honors `AZURE_OPENAI_ENDPOINT` +
`AZURE_OPENAI_API_KEY`. When set, all Files/Batches/Responses traffic goes
to `https://<resource>.openai.azure.com/openai/v1/` with the `api-key`
header, and `model` values in request JSONL must be **deployment names**.
Unset, the pipeline behaves exactly as before (api.openai.com). No other
script changes required.

## Provisioning checklist (Day 1, first hours)

- [ ] `az login` (device code) and confirm the subscription holding the credits
- [ ] Create resource group + Azure OpenAI resource in a region with
      Global-Batch support for the target models
- [ ] Deployments: one frontier-model **global-batch** deployment
      (extraction/normalization/critique), one **global-standard** fallback,
      one **text-embedding** deployment (high TPM)
- [ ] Check assigned quota; file quota-increase requests immediately
- [ ] Smoke test: one tiny batch run end-to-end through the existing
      `batch_*` scripts with `--run-id azure-smoke-1`
- [ ] Launch Wave 1 before end of Day 1

## The four fronts

### Front 1 — Corpus 5–10× (largest spend share)

Expand `data/sources/auto-ingestion-queue.yml` with public-domain texts that
maximize *tradition independence*: full Pali Canon (remaining), Zohar,
Nag Hammadi library, Popol Vuh, Kalevala (complete), Eddas (complete),
Chinese classics (Tao Te Ching, Zhuangzi, I Ching), Shinto texts (Kojiki,
Nihongi), African/Oceanic/Native-American oral-tradition collections,
Zoroastrian Avesta, Jain Agamas, remaining Vedic/Upanishadic material.
Then: fetch → convert → promote → segment → extract → normalize → index,
in rolling waves so extraction batches for wave N run while wave N+1 is
being ingested.

### Front 2 — Replication & rigor

- Re-extract a stratified sample (or, budget allowing, the full corpus)
  with a *second model family* under identical prompts; separate
  `--run-id replication-*` namespaces; never ingested into the primary
  index. New comparison script measures motif-level and family-level
  agreement (the LLM equivalent of inter-rater reliability).
- Second-pass critique (roadmap Phase 3) over all extraction records:
  a reviewer model flags unsupported claims, misquotes, and confidence
  inflation. Output feeds a review queue, not silent auto-edits.

### Front 3 — Embeddings & discovery

- Embed every passage (~all segmented passages) and every motif
  (label + evidence quotes) with the embedding deployment.
- Build: cross-tradition nearest-neighbor index; bottom-up cluster map to
  compare against the 65 human-curated families (does geometry agree with
  the taxonomy?); candidate assignments for the 1,195 unmapped motifs
  (suggestions → review queue, consistent with normalization workflow).
- Precompute the site's semantic-search index from these vectors.

### Front 4 — Sequence analysis (the monomyth test)

Passages are ordered within each text; extractions link to passages.
Build per-text ordered motif chains, then mine for recurring *sequences*
(descent → ordeal → boon → return, and whatever the data actually says)
across traditions with no historical contact. Batch LLM pass to segment
narrative arcs where mechanical ordering is insufficient. Output: a
sequence index + a Patterns essay reporting what recurs and what does not —
disconfirming evidence gets reported per methodology.md.

### Site evolution (time, not credits)

Commit the dendrogram constellation rework; add semantic search (Front 3
vectors, static-friendly); sequence/monomyth views; refreshed stats.

## Wave schedule (target)

| Day | In flight |
|-----|-----------|
| 1 | Provisioning, quota, smoke test; Wave 1 extraction (queue backlog) + full-corpus embeddings enqueued |
| 2 | Wave 1 ingest; Wave 2 extraction (new texts); replication sample enqueued; critique pass enqueued |
| 3 | Wave 2 ingest; Wave 3 extraction; normalization batches for new motifs; sequence-arc batches |
| 4 | Wave 3 ingest; final extraction wave; agreement analysis; unmapped-motif resolution |
| 5 | Final ingests before expiry cutoff; indexes rebuilt; site regenerated; everything committed |

## Budget sketch (flexible, revisit daily)

- Front 1 corpus extraction: ~50%
- Front 2 replication + critique: ~25%
- Front 3 embeddings: ~10% (embeddings are cheap; this likely overshoots)
- Front 4 sequence passes: ~10%
- Reserve/retries: ~5%

Track actual spend daily; if quota strands budget, shift to PTU or widen
the replication run to the full corpus (the most credit-hungry rigor win).
