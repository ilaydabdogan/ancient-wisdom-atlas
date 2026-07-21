# Finding: The Grammar of Story — how stories are BUILT (the Sol expedition)

Run: 2026-07-20, model **gpt-5.6-sol** on Azure endpoint **ATLAS_AZURE_0**,
concurrency 4. Machine-readable results: `data/indexes/story-structure.yml`.
This is the crown question turned from *content* onto *form*.

## The question

The Atlas has measured what stories are *about* — the motif families, the
crown's blind cross-world convergence of content. This expedition measures
what stories are *made of*: their architecture. Two questions at once.

1. **Finding (form, not content):** do peoples who never met *build* their
   stories the same way — the same arc-shapes, the same grammar of moves —
   more than chance allows? The crown showed shared *content* across the
   isolated/connected divide; does *structure* cross it too?
2. **Toolkit:** what is the structural DNA the oldest stories share, and how
   does it map onto modern craft (three-act, Save-the-Cat, hero's-journey,
   Booker's plots)? See `docs/storytellers-toolkit.md`.

## Method

**Corpus.** From the 338 canonical texts we selected 198 genuinely *narrative*
books (folk-tale and myth collections, epics, saga/legend collections),
excluding non-narrative material — hymnals, law codes, sutras, philosophical
and ritual manuals — because a hymn has no arc. Selection was by `source_type`
(oral_tradition_collection, folktale_collection, retelling, myth/epic) plus
narrative title keywords, with a non-narrative keyword veto. A bounded scan set
of 99 texts across 82 traditions (1–2 per tradition) was carried forward.

**Isolated/connected split.** Reuses the crown list
(`scripts/crown_prep_records.rb`) plus post-crown directory variants and
same-doctrine additions (New-World, Oceanic, Arctic, Siberian, Andaman,
Ainu, Khoisan/Nguni peoples with little/no historic contact with the Eurasian
diffusion sphere). Placement of sub-Saharan Africa and Oceania is a judgment
call, recorded in the index and revisited in Limits.

**Four Sol passes, blind then reconciled.**
1. *Story-unit detection.* The corpus is passages, not discrete tales, so Sol
   was fed numbered windows of each book (front matter skipped, body sampled)
   and asked to mark self-contained story units with begin/end line numbers.
   **536 complete units** were detected across the 99 texts (0 window errors).
2. *Blind structural analysis.* We sampled **234 stories** (cap ~4/tradition;
   **71 traditions**, 32 isolated / 39 connected; 113 isolated / 121 connected
   stories) and passed Sol each story's *own* text with **no external
   framework**. For each it returned three layers: an **arc** (4–8 ordered
   beats, each with an emotional valence −3..+3 and a **verbatim anchor quote +
   line**), a **grammar** (the ordered functional moves in the story's own
   terms), and **craft** (central desire, stakes, obstacle, turning point,
   recognition, resolution type, tension source). Every anchored claim carries a
   quote: **94.5% of anchor quotes (1,550/1,641) verified as verbatim
   substrings** of the cited source lines.
3. *Framework reconciliation.* A separate Sol pass — given only the extracted
   structural record, never the raw text — scored each story's fit against
   Propp's morphology, Campbell's monomyth, Freytag's pyramid, Booker's Seven
   Basic Plots, and the modern three-act.
4. *Deterministic clustering + the convergence test.* Valence series were
   quantised into Vonnegut/Reagan arc-shapes; grammar moves were canonicalised;
   the isolated/connected convergence test used a **tradition-level permutation
   null** (2,000 shuffles of which traditions are isolated, cosine agreement
   between the two piles' frequency profiles).

## What recurs — the shared architecture

**Arc-shapes (n=234).** Excluding the plurality "complex" (multi-swing,
episodic — 90 stories, 55 traditions), the dominant *named* shape is
**Rise-Fall-Rise (the "Cinderella"/fall-recovery curve): 54 stories in 43 of 71
traditions**, almost perfectly balanced across the divide (iso 28 / con 26).
Next: Fall-Rise ("man-in-hole", 32 / 28 traditions) and Fall-Rise-Fall
(reciprocal or tragic swing, 27 / 22 traditions). Steady Rise (15), Icarus
Rise-Fall (11) and pure Fall (5) are the minority. The honest nuance: real oral
narrative is messier than the clean Vonnegut curves — the single largest class
is *multi-swing*, i.e. episodic stacking of small arcs, not one grand line.

**Grammar-moves — the true universals.** Ranked by how many of the 71
traditions use them, in *both* piles: **departure (50 traditions), recognition
(46), interdiction (45), return (44)**, then pursuit (37), lack (35), death
(34), helper (30), creation (27), reward (26), transformation (24), test (24).
The departure→return frame and the recognition/interdiction pair are the
load-bearing walls of story worldwide.

**Resolution & tension.** The single most universal ending is
**transformation** — an *irreversible* change of state (127 stories, 59
traditions, iso 70 / con 57): the "and that is why…" clamp of oral narrative.
Restoration (50) and tragedy (29) follow. Dominant tensions: survival (57),
deception (55), desire (52).

## The isolated/connected verdict — an honest split result

In **absolute magnitude the architecture is strikingly shared**: the two piles'
arc-shape profiles agree at cosine **0.993** and their move profiles at
**0.941**. The same small repertoire builds stories on both sides of the
contact divide.

But the crown's question is sharper than magnitude: is the isolated/connected
*boundary* a real structural fault line — do the piles converge *beyond chance*?
The permutation null says **no, not decisively**:

| profile | real agreement | null mean (sd) | p |
|---|---|---|---|
| arc-shape | 0.993 | 0.976 (0.016) | **0.081** |
| grammar-move | 0.941 | 0.967 (0.012) | **0.967** |

The arc-shape split is *marginally* more convergent than random tradition
relabelings (92nd percentile) but does **not** clear p<0.05. The grammar-move
split is, if anything, *slightly less* alike than a random cut (p=0.97).

**Verdict.** Story *form* is universal enough that the contact divide does not
register as special — which is the opposite failure mode from the crown. There,
content bonds re-formed across independent worlds *beyond* a permutation null
(verdict STRONG). Here the profiles are so concentrated and so widely shared
that even random halves of the corpus look convergent, so this
profile-agreement design **cannot certify contact-independent convergence** the
way the crown did. We report it as an **honest negative on the significance
claim**: architecture is broadly pan-human, but we did not demonstrate that its
sharing is stronger than chance *specifically across the isolated/connected
line*.

Where a real pile-level difference does exist, it is one of **genre emphasis,
not deep architecture**: isolated oral corpora skew toward **creation/etiological**
moves and **survival** tension (creation iso 19 / con 8; survival iso 36 / con
21), connected corpora toward **lack→reward quest** moves and **deception**
tension (reward iso 7 / con 19; deception 21 / 34). The bones are shared; the
diet differs.

## Which framework fits — and which fails

Scored over all 234 stories (mean fit, 0–1):

| framework | mean fit | best-fit for N stories |
|---|---|---|
| modern three-act | **0.699** | 64 |
| Booker (Seven Basic Plots) | **0.697** | **91** |
| Freytag's pyramid | 0.677 | 56 |
| Propp's morphology | 0.507 | 22 |
| **Campbell's monomyth** | **0.391** | **1** |

**Booker's Seven Basic Plots is the best-covering single lens** (best-fit for 91
stories); the modern three-act fits about as well on average. The dominant
Booker plots are **the Quest (66), Overcoming the Monster (49), and Tragedy
(47)**. The striking negative: **Campbell's monomyth fits *worst*** — mean 0.39,
the single best framework for exactly *one* story of 234. At the grain of the
world's actual oral tales, the "hero's journey" is not the universal skeleton
the popular telling claims; most tales are short reciprocity, trickster,
etiology, or overcoming plots that never leave the ordinary world. And **57
stories (24.4%) exceed *every* framework** — the multi-swing, cyclical, and
nested-etiological oral structures that Western plot theory never modelled.

## Three striking examples (verbatim)

- **Guiana Carib, "The Flood"** (isolated Amazon): a Rise-Fall-Rise flood-and-
  rebirth in seven beats. "the water flowed out and covered the whole world."
  (L2937) → the brothers throw seeds that "fell into the water thus building up
  the land." (L2943). Booker *overcoming-the-monster*; **exceeds all
  frameworks**. The flood-and-remade-world content rhymes with Genesis and
  Deucalion — a content echo riding a shared arc.
- **Australian Aboriginal, "Dinewan the Emu and Goomblegubbon"** (isolated): a
  Fall-Rise-Fall of deception and reciprocal justice. A trick strips the emu of
  its wings — "I have my wings yet." (L408) — answered by a counter-trick and
  the perfect recognition line, "We are quits now." (L474). Reciprocity as plot
  engine, with no hero's journey in sight.
- **Akan, "How Wisdom Became the Property of the Human Race"** (connected):
  Anansi hoards all wisdom "beyond the reach of every one but himself" (L539)
  until his child's plain question — "not hang the pot on your back?" (L545) —
  forces the recognition "All my wisdom was insufficient to show me what to do" (L547) and the pot
  breaks, scattering wisdom "throughout the" world (L551). A hoarder's tragedy
  that is humanity's gift — the Prometheus shape, told of a spider.

## Limits (name them)

- **"Story unit" is a model judgment.** Sol decided where tales begin and end,
  over bounded windows (front matter skipped, body sampled) — a *sample, not a
  census*. Per-text scanned ranges are logged; coverage is never claimed as
  exhaustive.
- **Translation flattens craft.** These are 19th–20th-century English
  renderings. Rhythm, register, formulaic openings and much verbal texture are
  the translator's; we measure structure that survives translation, not style.
- **Arc-shape quantisation is coarse** (8 classes), and its permutation null has
  a high ceiling *because* the vocabulary is small and shared — that ceiling is
  exactly why the iso/con test lacks power, and we say so rather than spin 0.99
  as a positive.
- **Grammar canonicalisation is lossy.** Descriptive move labels that contain no
  canonical keyword fall back to a first-word token; these idiosyncratic tokens
  fragment (they do not accumulate across stories, so they sink below the real
  moves) but they thin the sequence-level signal. Ordered move *bigrams* are
  therefore diffuse (top bigram spans only 4 traditions) — the *set* of moves is
  universal, the exact *order* is not resolvable at this sample size. `grammar_raw`
  is retained in the index for audit.
- **Pile assignment of Africa/Oceania is debatable** and follows the crown's
  doctrine plus documented additions; the finding's verdict (a null on the
  significance claim) is robust to it because both piles are large and mixed.

## Falsifiers

- A larger, deeper-sampled corpus with a **finer structural vocabulary** (more
  arc classes, canonical move sequences) that lifts the isolated/connected
  arc-shape agreement **above** its permutation null at p<0.05 would upgrade this
  from "universal but not certifiably contact-independent" to a positive crown-
  style structural result.
- Conversely, a pile-stratified re-analysis showing the two worlds favour
  *different* dominant arc-shapes (not merely different move emphasis) would
  break the "shared architecture" claim outright.
- If a blind second model (e.g. a non-Sol reader) disagreed with Sol's unit
  boundaries or valence series enough to move the shape distribution materially,
  the shapes would need re-derivation. Single-reader structure is the standing
  caveat.
