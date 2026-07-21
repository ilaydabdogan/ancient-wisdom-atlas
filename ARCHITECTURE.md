# Ancient Wisdom Atlas — Architecture & Orientation

**Read this first.** It is written for a future contributor — human or AI agent —
picking up this project cold. It explains what the Atlas is, how data flows from a
raw book to a published finding, where everything lives, and how to continue the
work. Numbers below are current as of 2026-07-20; regenerate to refresh them.

---

## 1. What this project is

A programmatic, falsifiable atlas of humanity's shared story-patterns. The core
question: **do peoples who never met tell stories built the same way, more often
than inheritance, diffusion, or chance can explain?** Jung and Campbell intuited
yes and could only gather examples. This project tries to *measure* it, with
preregistered tests, permutation nulls, and every claim traceable to a quoted line.

- **Live site:** https://ancientwisdomatlas.com (Astro static site in `site-next/`,
  deployed to Vercel project `atlas-manuscript`).
- **Corpus now:** 338 public-domain texts, 106 traditions, ~52,600 evidence-anchored
  extraction records, ~256k raw motifs → the curated family layer below.
- **Flagship result (the "North Star"):** the *crown experiment* — see §6.

**The family counts, disambiguated** (three layers answer "how many families?"):
- `taxonomy/motifs.yml` — **44 curated motif families**, the original hand-named layer.
- `taxonomy/motif-normalization.yml` — **65 canonical motif groups**, the working
  normalization layer (children + aliases). One (`_meta_textual`) is meta-apparatus,
  so the site displays **64**. Universality claims are made at this level.
- `taxonomy/experiential-motif-families.yml` — **28 experiential families**, authored
  from the NDE/contemplative/psychedelic seed corpus; never merged with the ancient
  taxonomy (compared only in `data/indexes/cross-corpus-taxonomy-comparison.yml`).
- The crown's k=40/64/90 are **blind KMeans clusters**, not any of these families —
  that independence is what makes the crown assimilation-immune.

---

## 2. The data model (the thing you most need to understand)

A single passage of a book becomes evidence through five layers:

```
TEXT            texts/public-domain/<tradition>/<source>/<slug>.md
  │             a cleaned public-domain book, one canonical markdown file
  │  segment    scripts/batch_segment_passages.rb  → passages (line ranges)
  │  extract    a model reads each passage, emits a RAW MOTIF + quoted evidence
  ▼
RAW MOTIF       "raven steals the sun and hides it in a box"
  │             one free-text label per passage-observation (~222,000 of them).
  │             98–99% are singletons — said once, in one book. That is expected.
  │  normalize  embed → cluster near-duplicates → merge synonyms (§4)
  ▼
SUB-FAMILY      "theft of celestial light"   (intermediate grouping)
  │  assign     nearest canonical centroid, gated by a reader model
  ▼
CANONICAL       sacred_knowledge / theft-of-fire
FAMILY          the curated family layer (44 families in taxonomy/motifs.yml;
  │             65 canonical groups, 64 non-meta, in motif-normalization.yml —
  │             see §1). Universality is claimed at THIS level, never at the
  │             raw-motif level.
  │  count
  ▼
OCCURRENCE      family × tradition × passage   → what the findings actually measure
```

**Key discipline:** a raw motif is what a reader *saw* in one passage; a family is a
*curated abstraction*. The gap between them is the normalization/assignment
pipeline (§4). When the corpus grows, raw motifs appear immediately but families
lag until a normalization pass runs — so "222k raw / 142k mapped" means ~80k raw
motifs are still awaiting family assignment. Closing that gap is ordinary
maintenance, not a bug.

---

## 3. Directory map

| Path | What lives there |
|---|---|
| `texts/public-domain/<tradition>/<source>/*.md` | The canonical corpus. One cleaned book per file, YAML frontmatter + markdown body. **This is the ground truth.** |
| `imports/converted/` | Staging: OCR/conversion output *before* promotion. Cleaned here, then promoted to `texts/`. |
| `manifests/` | Per-book provenance: source URL, checksums (raw + canonical), license. |
| `taxonomy/motifs.yml` | The 44 canonical families: `label`, `description`, `related`. The curated human layer. |
| `extractions/generated/openai-batch/<run>/<slug>/*.yml` | Per-passage extraction records (the raw motifs + quoted evidence). ~45k of them. The evidence store. |
| `data/batches/<run>/` | Extraction/embedding batch jobs: `requests/`, `results/`, `passages.jsonl`. Intermediates; `passages.jsonl` and `results/` of some runs are gitignored (see `.gitignore`). |
| `data/indexes/*.yml` | **Derived, regenerable** analysis outputs the site reads (§5). Never hand-edit; regenerate. |
| `scripts/` | The whole pipeline (Ruby) + analysis (`*.py`). See §7. |
| `site-next/` | Astro static site. `src/lib/atlas.js` loads the indexes at build time. |
| `docs/` | Methodology, findings, protocols, preregistrations. |
| `letters/` | The narrative "Letters" — findings written for humans. Auto-loaded by the site. |
| `data/sources/auto-ingestion-queue.yml` | The corpus queue: every book's status (`converted` → `ingested`). |

---

## 4. The normalization / family pipeline (how "grouping" happens)

When raw motifs need to be merged and assigned to families:

1. **Audit the gap** — `scripts/audit_normalization_gaps.rb` → `data/indexes/normalization-gap-audit.yml`
   lists raw motifs not yet mapped to a family.
2. **Embed** the orphan labels — `scripts/batch_prepare_label_embedding_requests.rb`
   → run via `scripts/batch_run_realtime.rb` → `scripts/batch_ingest_embedding_results.rb`.
3. **Propose merges** — `scripts/build_synonym_merge_proposals.rb` clusters
   near-identical labels; a reader model confirms via
   `scripts/batch_prepare_normalization_suggestion_requests.rb` →
   `scripts/batch_ingest_normalization_suggestion_results.rb`.
4. **Assign to families / sub-families** — `scripts/batch_prepare_subfamily_binning_requests.rb`
   and the `bin_*_subfamilies.rb` scripts sort confirmed groups under canonical families.
5. **Apply** — `scripts/apply_normalization_suggestion_acceptance.rb` /
   `scripts/apply_reviewed_subfamily_bins.rb` write the accepted mappings.
6. **Verify** — `scripts/check_taxonomy_refs.rb` confirms every ref resolves.

**Rule:** models *propose*; deterministic scripts *apply*. No model ever rewrites
canonical text or silently edits the taxonomy. Every merge is a reviewable artifact.

---

## 5. The indexes (what the site reads)

All in `data/indexes/`, all **regenerable** from the evidence store by
`scripts/regenerate_site_data.sh` (run it after any corpus change — it rebuilds
every site-read index in dependency order, so nothing goes stale):

| Index | Produced by | Feeds |
|---|---|---|
| `extraction-coverage.yml` | `build_extraction_coverage.rb` | corpus stats, per-text coverage |
| `motif-occurrences.yml` | `build_similarity_index.rb` | the family × tradition matrix |
| `canonical-motif-frequency.yml` | `build_canonical_motif_frequency.rb` | most-shared motifs |
| `motif-constellations*.yml` | `build_motif_constellations.rb` | the co-occurrence web |
| `null-model*.yml` | `build_null_model.rb` | permutation null for the web |
| `isolated-prediction-test.yml` | `build_isolated_prediction_test.rb` | the mapping-based lineage test |
| `crown-independent-taxonomy.yml` | `crown_analysis.py` | **the North Star** (§6) |
| `motif-sequences.yml` | `build_motif_sequence_index.rb` | Campbell ordering test |
| `motif-era-flow.yml` | `build_motif_era_flow.rb` | motifs across time |
| `replication-agreement.yml` | (reader-consensus ingest) | multi-model agreement |
| `number-patterns.yml` | `scratchpad number scripts` (see `docs/finding-sacred-numbers.md`) | the sacred-numbers finding |
| `astral-lore.yml` | astral expedition (see `docs/finding-astral-lore.md`) | the sky-lore finding |

---

## 6. The North Star: the crown experiment

The strongest, assimilation-immune test. Full method in
`docs/prereg-crown-independent-taxonomy.md`; engine in `scripts/crown_analysis.py`.

- Split the corpus into the **connected** Old World and the **isolated** lineages
  (Dreamtime, Arctic, Amazon, Siberian coast, the Americas — peoples with little/no
  historical contact with Eurasia).
- Let **each world build its own taxonomy of myth blind**: cluster only its own raw
  motif embeddings, never referencing the 44 curated families or the other world.
- Build each world's co-occurrence web on its own blind clusters.
- Align the two webs by optimal centroid assignment and ask: **what fraction of one
  world's bonds re-form in the other's**, vs a 500-permutation null?

**Current result (final rebalanced corpus, 2026-07-20):** verdict **STRONG**.
Reproduction 0.577 / 0.525 / 0.541 at k=40/64/90 vs chance ~0.355–0.372; 500/500
permutations beaten at every k; degree-topology KS p = 0.77 / 0.42 / 0.99. Only 151
of ~249,000 labels are shared between the two worlds' vocabularies, so the webs are
genuinely independent. The middle run's dip (k=64 0.544 → 0.494 when the corpus grew
lopsidedly) and its recovery after wave-9 rebalancing (→ 0.525) are recorded in the
index and in `letters/what-happened-to-the-north-star.md`. **The rule: publish
whichever way the number moves.**

To re-run after a corpus change: `crown_prep_records.rb` → `build_crown_label_embed_prep.rb`
→ embed the labels → `crown_analysis.py`.

---

## 7. Common operations (runbook)

```sh
# Add a book: place cleaned markdown in imports/converted/, then
ruby scripts/corpus_promote_queue.rb --ids <queue-id> --source <src> [--force]
#   (promotion builds canonical from the CLEANED converted file — see the
#    canonical==converted parity invariant; never promote dirty OCR.)

# Extract motifs from newly-added texts:
ruby scripts/batch_segment_passages.rb --run-id <run> --text <path> ...
ruby scripts/batch_prepare_motif_requests.rb --run-id <run> --model <model>
ruby scripts/batch_run_realtime.rb --run-id <run> --concurrency N   # or per --shard
ruby scripts/batch_ingest_motif_results.rb --run-id <run>

# Rebuild everything the site reads (idempotent, safe to run any time):
bash scripts/regenerate_site_data.sh

# Full sanity check before committing:
ruby scripts/check_all.rb

# Deploy (site exceeds Vercel's 15k-file limit → build locally, deploy prebuilt):
cd site-next && npx vercel build --prod && npx vercel deploy --prebuilt --prod --archive=tgz
```

---

## 8. Invariants (violating these has burned us before)

1. **canonical == cleaned converted.** Promotion builds a book's canonical text from
   its *cleaned converted* file, not the raw scan. (A bug that rebuilt from raw
   silently discarded all OCR cleanup for months — see git history 2026-07-19.)
2. **Models propose, scripts apply.** No model rewrites canonical text or edits the
   taxonomy directly. Every merge/assignment is a reviewable, deterministic artifact.
3. **Every claim points at a quote.** Extraction records carry the verbatim line and
   its source path. Findings that can't be traced to text don't ship.
4. **Preregister, then publish either way.** Tests have a written prereg in `docs/`
   committed before the result is known. Negative and dipped results ship too.
5. **Indexes are derived.** Never hand-edit `data/indexes/`. Regenerate.
6. **Universality is a family-level claim,** never a raw-motif claim (raw motifs are
   ~99% singletons by design).

---

## 9. Where the findings are written for humans

- `letters/` — the narrative account of each finding (start with Letter III, the crown).
- `docs/finding-*.md` — the rigorous write-ups (crown, sacred numbers, astral lore, gate precision).
- `docs/methodology.md` — the levels-of-claim framework.
- `docs/prereg-*.md` — the preregistrations.
- The site's `/crown/`, `/findings/`, `/lab/` pages render these live from the indexes.

---

## 10. What to do next (open threads)

- **Close the taxonomy:** ~80k raw motifs from the enlarged corpus await family
  assignment. Run the §4 pipeline. This is the highest-value legibility work.
- **Rebalance the isolated side:** the crown's k=64 dipped because the corpus grew
  lopsidedly (connected ≫ isolated). Extracting more isolated-world texts (Plains,
  Arctic, Amazon, Oceanic) directly strengthens the test.
- **Sub-family layer:** currently implicit. Materializing it in `taxonomy/motifs.yml`
  would make the middle of the hierarchy inspectable.
- **Open data / preprint:** the corpus + indexes are a citable dataset; a DOI release
  and an honest preprint are the natural next milestone.
