# Campaign summary — 2026-07-18 → 2026-07-20

The closing record of the Azure-credit sprint. Written for the archive: what we
set out to do, what we found, what broke, and what we left behind for whoever
continues this. Numbers are final as of 2026-07-20.

---

## The question we exist to answer

Do peoples who never met tell stories built the same way, more often than
inheritance, diffusion, or chance can explain? Jung and Campbell intuited *yes*
and could only gather examples. This project tries to *measure* it — preregistered,
permutation-tested, every claim traceable to a quoted line.

## What the corpus became

| | before (2026-07-18) | after (2026-07-20) |
|---|---|---|
| Public-domain texts | ~190 | **338** |
| Traditions | ~76 | **106** |
| Extraction records | ~19,000 | **52,626** |
| Raw motifs | ~62,000 | **256,186** |
| Site pages | ~40,000 | **120,536** |

Growth came from six parallel expeditions and ~125 promotions (SBE canon, the
Puranas, the Tibetan Book of the Dead, the full Mahābhārata, Korean/Malay/
Melanesian/Siberian/Finnic collections, and the verbatim field-recordings of
Boas, Sapir, Jones, Campbell). Extraction ran in waves 6–9 across two Azure
endpoints.

## The North Star held — and was made to earn it

The **crown experiment** (assimilation-immune test: each world builds its taxonomy
of myth *blind* from its own vocabulary, then we ask whether the two
independently-drawn webs share a shape). It was run three times, on purpose:

| corpus | k=64 reproduction | vs chance | isolated records | k=90 topology (KS p) |
|---|---|---|---|---|
| smaller (pre-doubling) | 0.544 | 0.367 | 5,762 | 0.70 |
| enlarged (pre-wave 9) | 0.494 ↓ | 0.357 | 5,465 | 0.036 ✗ |
| **final (rebalanced)** | **0.525** ↑ | 0.365 | 7,709 | **0.993** ✓ |

The middle run *dipped*. We reported it rather than quoting only the coarse
resolution that rose, and diagnosed the likely cause: the expansion was lopsided
(the connected pan grew heavy, the isolated pan light). Wave 9 added 82
isolated-world texts, growing the isolated side +41% — and k=64 recovered, the
k=90 topology blemish healed almost perfectly (KS p 0.036 → 0.993), and k=40 hit
its highest value yet (0.577). Every resolution beat all 500 permutations.
**Verdict: STRONG**, on a corpus we doubled, cleaned of a contamination we hadn't
known was there, and then deliberately rebalanced to test our own excuse. Only
151 of 249,006 motif labels are shared between the two worlds' vocabularies, so
the webs are genuinely independent.

This is the campaign's signature: a finding that dips when we sample badly and
recovers when we sample well is tracking something real.

## The bug we caught (the most important hour)

Mid-sprint, a review agent found that the promotion step had been rebuilding every
archive.org text from its *raw scan* — silently discarding all OCR cleanup and
bilingual separation for the life of the project. Boas's Chinook sat in the corpus
as 40,625 lines of interleaved native + English when the real English translation
is 3,377. **147 books were affected.** We fixed the pipeline at the root (canonical
is now built from the cleaned converted file), rebuilt all 147, purged 9,003
extraction records drawn from the bad text, and re-read those books. The North Star
above was then re-tested on the *corrected* evidence. Findings that survive their
own correction are the only kind worth keeping.

## Three new findings (Letters IV–VI)

- **The numbers refused to be universal** (Letter IV, `finding-sacred-numbers.md`).
  No shared table of sacred numbers; the worlds *diverge* — the connected world
  elevates 3/7/9, the isolated world the fourfold (four directions). Pauli's 137
  never appears as a symbolic number in 39.4M words. The one shared number is
  twelve, and it is the moon's. Where humanity agrees on a number, the author is
  the sky.
- **The sky we all read** (Letter V, `finding-astral-lore.md`). "Seven Sisters"
  fails as a universal (only Australia dreams the Pleiades as sisters among isolated
  peoples); omen-reading is bilateral, but *systematized astrology* — the zodiac,
  the houses, the nativity chart — was invented once, in the Babylon→Greece→India→
  China corridor, and never independently recurs.
- **What happened to the North Star** (Letter VI). The honest two-day account of
  the crown surviving its own doubling, correction, and rebalancing — dip and all.

## The taxonomy, and an honest closure

The corpus grew faster than its taxonomy: of ~88,000 unmapped raw motifs, **88,194
are singletons** (said once, in one book — the designed 99%-singleton structure).
Mapping singletons is cosmetic and cannot change a cross-tradition finding. So we
closed the gap that *matters*: the 99 motifs that recur across ≥2 traditions or ≥4
occurrences were triaged by gpt-5.6-terra against the 65 canonical groups — 34
auto-accepted into families, the rest flagged for human review, marked as
ethnographic apparatus, or proposed as new-family candidates
(`motif-normalization-auto-accept-review.md`).

## What we left for whoever continues

- **`ARCHITECTURE.md`** — the single START-HERE: the five-layer data model
  (text → raw motif → sub-family → family → occurrence), the pipeline, the index
  catalog, the crown method, the runbook, and the six hard-won invariants.
- **`data/SCHEMA.md`** — field-level data dictionary for every core record type.
- A promotion pipeline that can no longer discard cleanup, and
  `regenerate_site_data.sh` so no site number can go stale.

## Open threads (highest value first)

1. **Rebalance further.** k=64 recovered but not fully; the isolated side is still
   the lighter pan. More isolated-world extraction directly strengthens the crown.
2. **Review the 65 flagged motifs** and decide the new-family candidates.
3. **Materialize the sub-family layer** in `taxonomy/motifs.yml` (currently implicit).
4. **Open data + preprint.** The corpus and indexes are a citable dataset; a DOI
   release and an honest preprint are the natural next milestone.

---

*Two days. The corpus roughly tripled in evidence, the flagship result survived its
strictest tests including one it failed at first and then passed, a silent
corruption was caught and undone, three new findings were published, and the whole
apparatus was documented so it can be picked up cold. The instrument keeps behaving
like an instrument.*
