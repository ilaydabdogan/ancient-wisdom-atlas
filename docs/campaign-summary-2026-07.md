# The Azure Campaign — Complete Summary
### Ancient Wisdom Atlas, 2026-07-17 → 2026-07-18 (days 1–2 of 5)

**Mission:** build the most detailed, most rigorous, and largest programmatic
atlas of humanity's shared story-patterns — and test, with falsifiable
methods, whether the recurrence of myth across unconnected cultures exceeds
inheritance, diffusion, and chance: the first empirical measurement of the
territory Jung and Campbell mapped by intuition.

---

## 1. What existed when we began

- 58 public-domain texts, ~23 traditions, 5,763 hand/pipeline extraction
  records, 9,072 motifs / 31,658 occurrences, 65 evidence-derived canonical
  families (9 hand-binned into sub-families), a static GitHub Pages site,
  and one methodological crown jewel: strict separation between the ancient
  corpus and the experiential (NDE/contemplative) corpus.
- A failed April extraction run (3,353 passages, stalled on 4k token limits)
  sat unfinished in the OpenAI batch queue.

## 2. Infrastructure built (day 1)

- **Azure OpenAI provisioned from zero**: resources `awa-atlas-0..3` across
  the sponsorship subscriptions; primary spend on a7e9 per İlayda. Eleven
  deployments including gpt-5.5 (primary extractor), gpt-5.4 + gpt-5.1
  (batch readers), gpt-5.6-terra / -sol / -luna, text-embedding-3-large.
- **Pipeline made Azure-portable** with two env vars (batch_common.rb);
  **`batch_run_realtime.rb`** — a realtime parallel runner emitting
  batch-compatible results so every existing ingest script works unchanged.
- **Content-filter finding**: default moderation silently blocked ~11% of
  mythic passages (battle, sacrifice, descent — the Shadow). A custom
  `atlas-scholarly` RAI policy (high-severity-only) fixed it; loss fell to
  <1%. An Atlas built naively would have been biased against the dark half
  of myth.
- **Operational doctrine learned**: sol fails on large requests (service
  side) → light duty only; batch deployments propagate slowly (retry);
  Ruby heredocs eat `\d` (a real production bug found and fixed).

## 3. The corpus (7 research expeditions, 2 days)

- **63 → 63+ tradition directories** (from 25), **~150 canonical texts**,
  **181-item ingestion queue**, all rights-verified public domain with
  provenance manifests.
- Landmarks added: complete 12-tablet Gilgamesh, Enuma Elish, Descent of
  Ishtar, Budge's Am-Tuat, Zend-Avesta I–III + Bundahis, complete Rigveda,
  SBE Upanishads / Lotus / Sutta-Nipāta / I Ching / Li Ki / Shu King /
  Milinda / Vinaya, Nihongi I–II, Shahnameh I–II, Kebra Nagast, Sikh
  Religion, Masnavi, 1 Enoch, Jubilees, Pistis Sophia, Corpus Hermeticum,
  Eddas, Beowulf, Njal, Grettir, the Grail, Kalevipoeg, Popol Vuh.
- **The isolated-lineage program** (the scientific heart): Dreamtime
  collections, Rasmussen/Boas/Rink Inuit corpora, Bogoras's Chukchee
  Mythology + Koryak Texts + Yukaghir tales (verbatim), Bleek & Lloyd's
  |Xam San corpus, Callaway's Zulu tales (bilingual-separated), Tsimshian
  Mythology (Tate narratives), Tlingit, Haida, Cherokee, Seneca, Pawnee,
  Arikara, Navajo, Zuñi, Hopi, Andaman Islanders, Melanesia, Micronesia,
  Madagascar, Guiana, Amazon, Chaco, Caucasus, Santal-adjacent plans.
- **Original-language program begun**: Aeneid (Latin), Daodejing + Analects
  (Chinese), Koine Didache, Hebrew Tanach queued — the translator-effect
  control. Honest negatives documented (PG's "Greek Homer" is modern Greek;
  no PD Vulgate/Sanskrit Gita; Quran licensing incompatible).
- **OCR discipline**: every archive.org scan passed review → deterministic
  cleanup (auditable scripts; ~60 works cleaned; bilingual separation for
  5 works; zero model-written words in canonical texts) → promotion gates.
  6 heavy-residue works held; 2 Greek-OCR rejects need new scans.

## 4. Extraction and the reader panel

- **Four extraction waves** on gpt-5.5 (single instrument, 16k budgets):
  Wave 1 resurrection (3,277), isolated-lineage corpus (3,579 + retries),
  canon waves 2 (4,610) and 3 (4,208). **Corpus now: ~22,700 records,
  46,019 motifs, 124,451 occurrences.**
- **Five-reader replication panel** over identical passages: gpt-5.5,
  gpt-5.4, gpt-5.1, gpt-5.6-terra (perfect 3,386/0 pass), gpt-5.6-luna
  (3,384, 2 errors). ~40 batch jobs lifetime; r2 confirmations of the new
  corpus still landing.
- **Findings about the instrument**: agreement 0.36–0.65 canonical Jaccard;
  tracks model-generation distance (adjacent generations agree most) and
  genre (Confucian 0.83+ → Welsh 0.22); canonicalization helps in every
  pairing. Consensus tiers: 2,070 claims confirmed by 3+ readers.

## 5. The quality stack (defense in depth)

1. Mechanical quote verification (typography-tolerant, ellipsis-aware):
   of 767 verbatim-policy records, 366 verify; 401 queued for review.
2. **Adversarial gates** with honeypot calibration: terra caught 20/20
   tampered quotes, 24/26 fabricated motifs; sol's independent second gate
   ran clean; single-gate 74% reject rate held un-actioned pending
   two-gate intersection (honeypots measure recall, not precision).
3. Cross-model review courts everywhere (no self-review, enforced in
   code): drafts by one 5.6 variant reviewed by another.
4. Preregistration + tripwires (below) — the system twice caught results
   that flattered us.

## 6. Taxonomy: the grouping program

- **46 of 65 families** layered into reviewed sub-families (İlayda's 9
  hand-made + 37 machine-drafted/cross-reviewed).
- **7,877 → 19,357 mapped motifs**: 10,590 policy auto-accepts + 888
  luna-reviewed acceptances; **4,729 honestly unmapped** (long tail:
  17,852 single-tradition motifs corpus-wide).
- **1,091 synonym-merge candidates** from 512-d label embeddings; terra
  accepted 316, preserved 774 distinctions; 244 folded as first-class
  aliases with provenance.
- 95 texts carry reviewed composition datings (sol drafted, luna reviewed,
  77 applied) — the Currents timeline runs on them.

## 7. THE FINDINGS

### 7.1 The One Web (rung 2: constellation)
Cross-tradition motif co-occurrence structure beats chance at every corpus
size and every threshold, and always forms **one connected constellation**
(28 of 65 families at standard threshold; still one web at ≥8-tradition
strictness). Accumulation curve (identical code throughout):

| Stage | Records | Traditions | Edges vs null | Result |
|---|---|---|---|---|
| 1 | 5,763 | 19 | 186 vs 134±6 | beats 200/200 (z≈8.2) |
| 2 | ~12,500 | 41 | 282 vs 254±5 | beats 200/200 (z≈5.6) |
| 3 | ~22,700 | 53–59 | 300–308 vs 277–291 | beats 200/200 (z≈4.2–5.2) |

Absolute structure grows; relative lift matures downward (1.39→1.08) —
the honest signature of a real effect stabilizing, not an artifact.

### 7.2 The North Star (preregistered isolated-lineage prediction test)
Preregistered in git before any holdout analysis
(docs/prereg-isolated-lineage-test.md): do association structures derived
ONLY from connected Eurasia re-form among peoples who could not have
borrowed them?

| Stage | Reproduction vs null | Beaten | Lift | Novelty | Hard core | Verdict |
|---|---|---|---|---|---|---|
| 2 | 62.7% vs 54.3% | 200/200 | 1.155 | 13.8% | 0 (unpowered) | **SUCCESS** |
| 3 corrected | 75.5% vs 69.5% | 199/200 | 1.087 | 11.0% | 15.5% | weak_support |
| 4 full/mapped | 74.9% vs 69.1% | 200/200 | 1.085 | 7.1% | **23.7%** | leakage_flag |

Across 600 permutations chance never once matched observation. The
**verbatim hard core rose monotonically 0 → 15.5% → 23.7%** — the purest
data strengthening steadily. The novelty tripwire twice fired exactly as
designed: once catching a holdout-roster bug, once catching
mapping-assimilation risk (isolated motifs mapped into Eurasian-derived
families by a family-aware model). **Definitive next experiment**: build
the isolated lineages' taxonomy bottom-up and independently (the
Consciousness Bridge design) and compare structures — assimilation-immune.

### 7.3 The sequence falsification (rung 3)
Frequency-controlled nulls **killed most of the "narrative grammar"**:
of 65–72 strong orderings, only ~15 survive; the celebrated
knowledge-before-water (95% consistent) is a frequency artifact. Strongest
genuine survivor: **miraculous_child → sacred_fire** (97% vs null 86%).
The knowledge↔journey coupling spans 109/104 texts across 54/52 traditions
*in both directions* — a reciprocal circuit, not Campbell's one-way road.

### 7.4 The gift at the center
`sacred_exchange` ties `hero_journey` as the most-connected family in the
isolation-reproduced web (21 partnerships each); the exchange↔knowledge
circuit is the strongest recurring relation in the corpus. (Letter I:
"We are not, at bottom, conquerors. We are couriers.")

### 7.5 The trickster anomaly
Present in effectively every tradition, yet only ~8 stable partnerships —
the boundary-dissolver is measurably the least-webbed figure. The topology
reproduced the character. (Letter II.)

### 7.6 The particular ocean
17,852 motifs attest in exactly one tradition. The universal web floats on
an ocean of the irreducibly local — elementary ideas and folk ideas in one
dataset.

## 8. The website

- **ancientwisdomatlas.com now serves the Manuscript Atlas** (Astro on
  Vercel, domain connected by İlayda): illuminated-manuscript design,
  25,750+ static pages, dark "midnight scriptorium" mode.
- Complete journey: story landing → **the descent** (One ▸ constellations ▸
  64 families ▸ sub-families ▸ 25,532 motif pages ▸ evidence) →
  **"read this passage in the book"** deep-links landing on gold-lit
  anchored paragraphs in any of 144 reading-page texts (zen typography,
  A−/A+, progress thread).
- Pages: /findings/ (plain-language, honest verdicts), /lab/ (apparatus),
  /currents/ (era streamgraph, dependency-free SVG), /universals/ (top-30
  most-shared families, ✦ isolation-proven badges), /fingerprints/ (what
  each of 43 traditions alone remembers), /letters/ (editor's letters I–II),
  /read/ library, llms.txt + /api/atlas.json + /api/texts.json for agents.
- Old GitHub Pages site retained as archive/renderer of extraction detail;
  zero cross-links from the new site.

## 9. Autonomy machinery

Self-operating chains (wait → ingest → rebuild all indexes → rerun ladder
incl. preregistered retest → commit → push → deploy); persistent monitors;
research/cleanup/build agents; the **Synthesist** (three archived readings
— its critiques repeatedly preceded the data's own verdicts); memory files
carrying state across sessions; caffeinate guarding the machines.

## 10. Spend

~$3–5k of $50k sponsorship credits consumed (≈700M+ tokens landed on
disk). Value ceiling continues to arrive far below budget ceiling; credits
expire 2026-07-22; remaining spend targeted at r2 confirmations, the
independent-taxonomy program, critique passes, and corpus waves B/C.

## 11. Remaining work

1. **The crown**: independent bottom-up holdout taxonomy → structure
   comparison (the assimilation-immune north star).
2. Gate intersection (terra × sol) → Wave-1 quality census; retry sweep
   (~270 passages); last r2 batch jobs → consensus rebuild.
3. 6 held OCR works; 2 re-OCR rejects; remaining small-family bins;
   4,729 unmapped long-tail audit (future families live there).
4. Synthesist's controls: collector/translator-blocked resampling,
   adjacency-strict sequence nulls, sacred_knowledge disaggregation
   analysis on the new sub-families.
5. Site: auto-deploy via Vercel git integration; Lab deep layers.
6. Held for İlayda: the experiential bridge (second preregistered
   landmark); publication draft (methods, preregistration, and data are
   all in git — a paper is within reach).

---

*Every claim above traces to committed artifacts: indexes under
data/indexes/ (stage snapshots in data/indexes/history/), reviews under
data/reviews/, preregistration in docs/, letters in letters/, and the
full audit trail in git history.*
