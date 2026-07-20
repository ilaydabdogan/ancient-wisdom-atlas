# Data dictionary

Field-level reference for the Atlas's core record types. Companion to the
repo-root `ARCHITECTURE.md` (read that first for the data model and pipeline).
All files are UTF-8; indexes are YAML; the evidence store is per-record YAML.

---

## Canonical text — `texts/public-domain/<tradition>/<source>/<slug>.md`

YAML frontmatter + markdown body. The body is the cleaned book text (canonical ==
cleaned converted; see ARCHITECTURE invariant 1). Frontmatter fields:

| field | meaning |
|---|---|
| `id` | stable dotted id, e.g. `australian.ethnological_studies_queensland.roth_archive` |
| `title`, `alternate_titles` | display titles |
| `text_status` | `complete` / partial |
| `tradition` | the grouping key used everywhere (= first path segment) |
| `culture`, `region` | finer provenance |
| `source_language`, `text_language` | original vs. the language of this text (usually English translation) |
| `date_range` | human-readable dating |
| `source_type` | `scripture` / `epic` / `ethnographic_study` / … |
| `provenance` | `source_id`, `edition`, `translator`, `editor`, `publication_year`, `publisher` |

## Extraction record — `extractions/generated/openai-batch/<run>/<slug>/*.yml`

One per passage-observation. **The evidence store.** Fields:

| field | meaning |
|---|---|
| `record_id` | `batch.motif.<slug>.l<start>-l<end>` |
| `source_text_path` | path to the canonical text this came from |
| `passage_locator` | `{label, start, end, translation, notes}` — the line range |
| `canonical_text` | `{quote, summary, language, quote_policy}` — the verbatim evidence |
| `literal_observations` | what the reader literally saw (pre-interpretation) |
| `figures`, `roles`, `symbols`, `scenes` | structured facets of the passage |
| `candidate_motifs` | the RAW MOTIFS proposed here (free-text labels) |
| `comparison_claims` | cross-tradition claims the reader flagged |
| `evidence` | quote(s) with `source_text_path` backing each claim |
| `confidence` | reader confidence |
| `reviewer_status` | review state (`needs_review` / reviewed) |
| `extracted_by`, `extracted_at` | model + timestamp provenance |

**Invariant:** `candidate_motifs` are raw (≈99% singletons). Family membership is
NOT stored here — it's resolved through the normalization pipeline into the indexes.

## Taxonomy family — `taxonomy/motifs.yml` → `motif_families.<key>`

The 44 curated canonical families. Each:

| field | meaning |
|---|---|
| `label` | human display name, e.g. "Divine Parent And Holy Child" |
| `description` | one-sentence definition of the family |
| `related` | sibling family keys (a soft graph, not a strict tree) |

## Queue item — `data/sources/auto-ingestion-queue.yml`

One per book; drives ingestion. Key fields: `id`, `status`
(`converted` → `ingested`), `source`, `tradition`, `tradition_cluster`,
`translator`, `rights`, `source_url`, `download_url`, and the pipeline paths
`raw_path` / `converted_path` / `canonical_path` / `manifest_path` / `extraction_dir`.
`status: converted` = cleaned but not yet promoted; `ingested` = live in `texts/`.

## Crown result — `data/indexes/crown-independent-taxonomy.yml`

The North Star. Top level: `verdict` (`STRONG`/`PARTIAL`/`NULL`), `primary_k` (64),
`preregistration` (path), `corpus` (`iso_records`, `iso_labels`, `con_records`,
`con_labels`), and `results[]` per k. Each result:

| field | meaning |
|---|---|
| `k` | number of blind clusters (40 / 64 / 90) |
| `reproduction` | fraction of iso-web bonds re-forming in the con web (the headline) |
| `null_mean`, `null_sd`, `null_max` | 500-permutation null distribution |
| `permutations_beaten` | e.g. `500/500` |
| `p_value` | permutation p |
| `degree_ks_stat`, `degree_ks_p` | topology-similarity test (KS on degree dists); p>0.05 = similar |
| `topology_iso`, `topology_con` | per-web graph stats (giant frac, clustering, modularity) |
| `matched_bonds` | (k=64) the named diptychs the site renders |

## Other frequently-read indexes

- `extraction-coverage.yml` — `summary` (corpus totals) + `texts[]` (per-book coverage,
  including `status: no_extractions` for the unextracted).
- `motif-occurrences.yml` — the family × tradition occurrence matrix.
- `motif-constellations*.yml` + `null-model*.yml` — the co-occurrence web + its null.
- `number-patterns.yml`, `astral-lore.yml` — the two 2026-07 findings (see `docs/finding-*.md`).

---

*To regenerate every derived index from the evidence store:
`bash scripts/regenerate_site_data.sh`. To validate: `ruby scripts/check_all.rb`.*
