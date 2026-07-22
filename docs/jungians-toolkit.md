# The Jungian's Toolkit — what the measurements say to depth psychology

A bridge from the Ancient Wisdom Atlas to the desk of the analyst, the
therapist, and the student of depth psychology. Jung built his framework from
examples; the Atlas was built to *measure* — across **338 public-domain
texts** from **106 traditions** (39.4M words), distilled into **52,626
evidence-anchored extraction records**, with preregistered tests, permutation
nulls, and every claim traceable to a quoted line. Several of Jung's central
intuitions can now be checked against that corpus. Some survive. Some survive
only in a corrected form. One is cleanly refuted, and one cannot be tested at
all — and saying which is which is the whole point of this document.

**The honest caveat up front, and it is the load-bearing one.** The Atlas
measures **texts, not psyches**. Every result below is a fact about what the
world's recorded mythologies *say* — how their story-patterns cluster, recur,
and co-travel — not a fact about the structure of any mind, living or
ancestral. The strongest result here (the crown) shows that peoples with no
historical contact independently built the *same web of story-families*. That
is consistent with a collective unconscious. It is equally consistent with
deep common inheritance (all storytellers descend from the same small founding
population), with convergent cultural evolution under shared human bodies,
ecologies, and social problems, and with mixtures of these. **A conserved
motif-family web is not proof of a collective unconscious**; no test in this
corpus can separate "shared psychic substrate" from "shared history plus
shared constraints." What the evidence *can* carry is the form-level claim:
the patterns Jung said were universal either are, or are not, and now we can
say which. Verdicts used below: **SUPPORTED-IN-FORM** (the pattern recurs as
claimed, mechanism left open), **CORRECTED** (real, but not as Jung stated
it), **REFUTED**, **UNTESTABLE-AS-STATED**.

---

## 1. The collective unconscious (*das kollektive Unbewusste*)

**Jung's claim.** Beneath personal experience lies a shared, inherited layer
of the psyche, common to all humanity, which expresses itself in the
recurring symbols of myth — so the mythologies of unconnected peoples should
be built from the same elements, in the same relations.

**What the Atlas measured.** The crown experiment
(`data/indexes/crown-independent-taxonomy.yml`, preregistered in
`docs/prereg-crown-independent-taxonomy.md`): the corpus was split into
isolated lineages (Americas, Australia, Arctic, Khoisan — 7,709 records,
40,883 motif labels) and the connected Old World (41,236 records, 207,634
labels). Each pile's taxonomy was built **blind**, by KMeans, never
referencing the other. At the primary k=64, the two independently-built
co-occurrence webs align at cosine 0.8213 and reproduce each other's edge
structure at **0.525 against a permutation null of 0.365 ± 0.014 — beating
all 500 of 500 permutations (p = 0.002)**. The webs also share topology
(clustering 0.576 vs 0.584; degree distributions statistically
indistinguishable, KS p = 0.418), and 24 specific cross-world bonds match.
Verdict recorded in the index: **STRONG**.

**Verdict: SUPPORTED-IN-FORM.** Unconnected humanity demonstrably shares a
story-grammar — not just the same elements but the same *web of relations*
among them, beyond chance. That is the empirical content of Jung's claim, and
it held under the strictest test the Atlas can run. What is *not* supported
is the mechanism: nothing here distinguishes an inherited psychic stratum
from deep common ancestry or convergent invention. Read it as: the phenomenon
Jung pointed at is real; his explanation of it remains one hypothesis among
several.

**Ancient evidence** — the same bond, drawn twice by strangers
(death-restoration binding to the afterlife road is one of the 24 matched
cross-world bonds):
- Tlingit (Northwest Coast, isolated): "Then he put the bones of each of his
  brothers together, rubbed red paint on them, and shook his rattle over
  them, and they came to life" (L1404–1406). *Tlingit Myths and Texts.*
- Egyptian (connected): the priest assures the dead, "Thy bones are gathered
  together for thee, thy members are prepared for thee... The tomb is opened
  for thee, the coffin is broken open for thee" (L2162–2165). *Development of
  Religion and Thought in Ancient Egypt.*

**For the consulting room:** when a patient's dream or active imagination
produces material with no biographical source, it is empirically respectable
to say the *pattern* is pan-human — and empirically careless to present that
as proof of a transpersonal mind. The honest framing ("humans everywhere,
independently, have built this image-web") loses nothing clinically and
overclaims nothing.

## 2. Archetypes — fixed primordial images?

**Jung's claim.** The collective unconscious is organized into archetypes.
Jung himself oscillated between two readings: the *archetype as such* (an
empty formal disposition) and the *archetypal image* (the mother, the wise
old man, the serpent — recurring contents). Popular Jungianism mostly
inherited the second: universal *images*.

**What the Atlas measured.** What actually recurs is almost never the image
and almost always the **family**. Of the corpus's raw motif labels — the
specific image as one text states it — **98–99% are singletons**, said once,
in one book (in the canonical index, 89,449 of 120,114 indexed raw motifs
remain unmapped, and 88,194 of those occur exactly once). Universality lives
one level up, in the **44 curated motif families** (`taxonomy/motifs.yml`;
65 canonical groups in the working normalization layer), where the reach is
enormous: Death-Rebirth-and-Transformation appears in **97 of 97** tradition
groups (8,501 records), Sacred Knowledge in 97, the Hero's Journey in 97,
Initiation in 95. The Atlas's own discipline reflects this: universality
claims are *only* made at family level, never at raw-motif level.

**Verdict: CORRECTED.** The archetype survives — as a **family of variants**,
not a fixed image. "Raven steals daylight from a box" exists once, in one
tradition; *theft of the withheld sacred* exists nearly everywhere. This is,
notably, closer to Jung's own stricter formulation (the archetype-as-such as
an empty form that each culture fills) than to the archetypal-image
Jungianism built on top of it. The data refutes the fixed image and supports
the abstract form.

**Ancient evidence** (one local mask of a near-universal family — Tlingit,
isolated): "At this Raven opened his box just a little and shed so great a
light on them that they were nearly thrown down"; then he "opened the box
completely, when the sun flew up into the sky" (L565–566, L568–569).
*Tlingit Myths and Texts.*

**For the consulting room:** expect the family, not the image. A patient's
"shadow figure" need not look like anything in Jung's illustrations — the
data says the surface content is almost always idiosyncratic (singleton),
while the structural role recurs. Amplification is on firmest ground when it
connects at the level of *what the figure does*, not what it looks like.

## 3. The quaternity

**Jung's claim.** Four is the natural form of wholeness — quaternity
structures (four functions, mandala quadration, 3+1 completing to 4) express
the Self, and the fourfold is a universal ordering schema of the psyche.

**What the Atlas measured.** The sacred-numbers study
(`data/indexes/number-patterns.yml`, `docs/finding-sacred-numbers.md`;
319,420 spelled number mentions after fourteen deterministic noise filters,
prominence measured against roundness-matched peers). The fourfold is
**real — and local**. The isolated world (Americas, Australia, Arctic,
Khoisan) elevates **4** at roundness-matched prominence 2.20 versus the
connected world's 0.88 — the four directions, the four winds. Four beats
three outright in 9 of 26 isolated traditions (**Navajo 326:88**, Hopi
245:97, Zuni 77:20) but in only 5 of 70 connected ones. The connected Old
World's signature is instead **3** (1.36 vs iso 0.68), **7** (2.13 vs 1.27),
and **9** (1.43 vs 0.76); seven is elevated in 49/70 connected traditions
but only 9/26 isolated ones.

**Verdict: CORRECTED.** The quaternity is a genuine deep ordering schema —
of *one* of the world's two independent mythological hemispheres. It is the
signature of the isolated Americas-Australia-Arctic mind-world, not of
everyone: the civilizations Jung actually drew his comparative material from
(the connected Eurasian braid) run on 3, 7, and 9. Jung was right that the
fourfold is somebody's signature of wholeness; wrong that it is the psyche's
universal one. See `letters/the-numbers-refused-to-be-universal.md`.

**Ancient evidence** (Navajo, isolated): on the last night of the great
night chant, "four singers, after long and careful instruction by the
priest, come forth painted, adorned, and masked as gods to sing this song"
(L788–790). *Navaho Legends.*

**For the consulting room:** treat quaternity symbolism as a cultural
dialect, not a diagnostic constant. A patient's mandala completing to four
is meaningful *within the symbolic language they inherit*; its absence — or
a triadic or sevenfold organization instead — is not a defect of
individuation. The data says wholeness has more than one grammar.

## 4. Number archetypes — and Pauli's 137

**Jung's claim.** Natural numbers are archetypes — "archetypes of order
which have become conscious" — so the same small numbers should carry
sacred charge in every mythology; with Pauli he pursued 137, the fine-
structure constant, as a possible bridge between psyche and matter.

**What the Atlas measured.** The full test: do isolated and connected
traditions elevate the *same* numbers? **No — they diverge more than chance
allows.** On the roundness-matched metric the real iso/con split agrees
*less* than random splits of the same traditions (ρ = 0.616 vs null
0.736 ± 0.048, p_deficit = 0.016): the maximally culture-separated split is
the maximally number-divergent one. There is no universal table of sacred
numbers. The one number both worlds elevate is **12** (iso 2.96, con 3.44;
elevated in 97 of 106 traditions) — and the isolated-world twelves are
calendrical: twelve-ish lunations per solar year, independently observed
astronomy, not archetype. And **137 never occurs as a symbolic number in
39.4 million words** — its only genuine narrative appearances are three
biblical patriarch lifespans and one Buddhist chronological note; it never
appears at all in any isolated tradition. Even famous 40 collapses under the
roundness control (local prominence 27.8×, roundness-matched 1.04 — an
ordinary decade whose fame is Abrahamic, not universal).

**Verdict: REFUTED** (as a claim about universal sacred numbers; the
translation-artifact caveat in `docs/finding-sacred-numbers.md` applies to
individual absolute prominences, but the divergence result is conservative
against it). Where humanity does agree on a number, the author is the sky,
not the psyche.

**Ancient evidence** — 137 as mere lifespan, 12 as the moon's:
- Biblical (connected): "These are the years of the life of Ishmael: one
  hundred thirty-seven years" (L1557). *Genesis*, World English Bible.
- Cree (Northeast Woodlands, isolated): "The Cree year is divided into eight
  seasons and twelve months, or moons" (L2439). *Notes on the Eastern Cree
  and Northern Saulteaux.*

**For the consulting room:** a patient's charged number deserves personal
and cultural amplification, not an appeal to universal number-archetypes —
the universality claim is the one part of the theory that measurement
killed. If a number recurs in their material, ask what *their* tradition and
biography count with it; the corpus says that is where the charge lives.

## 5. The trickster — Jung's shadow of order

**Jung's claim.** In his commentary on Radin, Jung read the trickster as an
archetypal figure — a collective shadow, a "psychologem," the same
primordial character (Coyote, Raven, Hermes, Loki) surfacing everywhere.

**What the Atlas measured.** Present almost everywhere: the trickster family
spans **92 of the 97 tradition groups** in the canonical motif index (4,886
records; the letter's tally, 94 of 106 traditions, nearly five thousand
appearances). His strongest ordinary-web bond is with sacred knowledge — the
thief of fire — across 41 traditions, 800+ co-occurrences. But in the crown,
the blind cross-world test, he holds only **2 of the 24 matched bonds**, and
both are *the same act*: "trickster obtains food by deception" and the
crafty acquisition of what force cannot take. His *characters* never
converge — the masks (spider, raven, coyote, the god at the crossroads) stay
stubbornly local, and none of his figure-level pairings reproduce across the
divide. See `letters/the-trickster-refused-our-net.md`.

**Verdict: CORRECTED.** The trickster is not universal as a *figure* — no
shared image, no stable companions, exactly what a fixed-archetype reading
predicts and does not find. He is universal as an **act**: obtaining by
cunning, at a boundary, what cannot be taken by strength. Strip the costume
and every unconnected people independently arrives at theft-at-the-
threshold. Jung's functional intuition (the necessary violator of order)
survives; the character-archetype does not.

**Ancient evidence** (Tlingit, isolated — the act itself): caught in the
grease box, "Raven, however, called out, 'My brother, do not tie me up with
a strong rope, but take a straw such as our forefathers used to employ.' He
did so. Then Raven drank up all the grease in the box" (L1130–1132).
*Tlingit Myths and Texts.*

**For the consulting room:** look for trickster *behavior*, not a trickster
*figure*. The data says the invariant is the maneuver — rule-evasion in the
service of a real hunger, at a real boundary — and that its costume will be
cut from the patient's own cloth. A patient's "trickster energy" is better
tracked by asking *what is being smuggled past which guard* than by pattern-
matching to Coyote tales.

## 6. The Self and the *unio mystica*

**Jung's claim.** The Self is the psyche's totality and telos; the mystical
union — dissolution of the ego in a greater whole — is its paradigmatic
direct experience, and its symbolism recurs across traditions and in modern
individuals alike.

**What the Atlas measured.** Two independent results. (a) In the ancient
corpus alone, the Mystical Quest family spans 88 of 97 tradition groups
(9,723 records), and the crown's very first matched bond pairs the isolated
world's *shamanic initiation through illness and recovery* with the
connected world's *mystical discipline toward emancipation / union with the
divine and dissolution of distinctions* — the two hemispheres' technologies
of self-transcendence cluster as structural counterparts. (b) The
consciousness-bridge comparison
(`data/indexes/cross-corpus-taxonomy-comparison.yml`): 28 phenomenological
families were derived bottom-up from a **small, strictly separate** corpus
of 12 modern experiential texts (NDE, contemplative, psychedelic), blind to
the ancient taxonomy. Laid side by side, **12 of 28 map strong and 10
moderate** onto ancient families, and the strongest convergences are
precisely Jung's territory: luminous presence, dissolution of self,
death-rebirth struggle, threshold-and-return, transformation of values.

**Verdict: SUPPORTED-IN-FORM — explicitly preliminary.** The convergence is
real and was not designed in (neither taxonomy was built to fit the other),
but the experiential corpus is 12 texts and the mapping is a post-hoc human
reading. What it carries: the structure of self-dissolution reported by
modern experiencers is the same structure the world's oldest texts
narrativize. What it does not carry: any claim about what the Self *is*, or
that the experience is veridical.

**Ancient evidence** (Hindu, connected — Mundaka Upanishad): "As the flowing
rivers disappear in the sea, losing their name and their form, thus a wise
man, freed from name and form, goes to the divine Person, who is greater
than the great" (L3674–3677). *The Upanishads*, Part II (Müller).

**For the consulting room:** when a patient reports an ego-dissolution
experience — in meditation, near death, or otherwise — both the world's
oldest literature and its newest first-person reports treat the *form* as
central, recurrent, and not in itself pathological. That is a citable,
measured fact. Its interpretation — Self, neurology, grace — is not the
data's to give, and the clinical work is in the integration either way.

## 7. The descent to the underworld (*nekyia*)

**Jung's claim.** The nekyia — the ego's descent into the underworld of the
unconscious, its ordeal there, and the return — is a universal pattern, and
the psychological template of every deep transformation (his own *Red Book*
period included).

**What the Atlas measured.** Descent-and-Underworld-Journey spans **76 of 97
tradition groups** (1,146 records); its sibling families are wider still —
Afterlife Navigation and Passage in 87 of 97 (4,338 records),
Death-Rebirth-and-Transformation in **all 97** (8,501 records, tied for the
widest reach in the corpus). And the descent is crown-hard: among the 24
cross-world bonds, the isolated world's *death followed by bodily
restoration* + *afterlife journey across a world-edge abyss* is matched by
the connected world's *death as rebirth* + *afterlife passage through
guarded thresholds* (iso weight 1.244, con 0.839) — both hemispheres
independently bound the death-and-restoration idea to a mapped, guarded road
through the below.

**Verdict: SUPPORTED-IN-FORM.** Of all Jung's structural claims, this one
measures best: the descent-ordeal-return arc, with its guarded threshold, is
pan-human at family level and reproduces across the isolated/connected
divide. (The corpus also preserves the pattern's dark honesty: the
near-universal *failed* retrieval — Orpheus in Rome, the empty box in
Cherokee country — the descent that does not give back what was lost.)

**Ancient evidence** (Cherokee, Southeast — isolated): the seven men carry
the Sun's daughter home from the Ghost country in a box they must not open;
they lift the lid, and "when they got there and opened the box it was empty"
— "now when they die we can never bring them back" (L12154, L12159–12160).
*Myths of the Cherokee.*

**For the consulting room:** the nekyia frame for a depressive or
disintegrative episode has real comparative footing — descent *with* ordeal,
threshold, and return is how the species has always narrated this passage.
But honor the corpus's whole finding: the traditions also insist that some
retrievals fail. Framing every descent as guaranteed-return is not the
ancient pattern; accompanying the descent, and grieving what the box does
not bring back, is.

## 8. Synchronicity

**Jung's claim.** An acausal connecting principle: meaningful coincidences
between inner state and outer event, connected by meaning rather than cause,
pointing (with Pauli) to a psychoid level where psyche and matter meet.

**What the Atlas measured.** Nothing — and the honest entry says so. The
Atlas is a corpus of texts; it contains no event-pairs, no base rates of
coincidence, no way to distinguish an acausal connection from selective
narration. **Verdict: UNTESTABLE-AS-STATED** in this corpus (and the one
adjacent number-claim that *was* testable — 137 as psyche-matter bridge —
failed; see entry 4). What the Atlas *can* measure is the human instinct
synchronicity is built from: reading outer events as meaning-bearing signs.
In the astral survey (`data/indexes/astral-lore.yml`; 40,004 celestial
passages, 103 traditions synthesized), **sky-omen reading appears in 62
traditions — 15 isolated, 47 connected**: comets, meteors, and eclipses read
as deaths, wars, and warnings on both sides of every ocean. But its
*systematization* — the zodiac, the horoscope, fate calculated from the sky
— was invented once, on the connected Babylon→Greece→India→China corridor,
and never independently recurs (`docs/finding-astral-lore.md`).

**Verdict: UNTESTABLE-AS-STATED.** The pan-human floor is real: humans
everywhere, independently, treat the world as legible for meaning. Whether
any coincidence is *acausally connected* is a question no text corpus can
answer, and this toolkit will not pretend otherwise.

**Ancient evidence** (Euahlayi, Australia — isolated): "Meteors always mean
death; should a trail follow them, the dead person has left a large family"
(L4281–4282). *The Euahlayi Tribe.*

**For the consulting room:** a patient's synchronicity experience sits on a
measurable universal — the meaning-reading instinct — and clinical work with
the *meaning* needs no verdict on the metaphysics. The data licenses "humans
have always read events this way, and what you read in it matters"; it does
not license "the universe arranged this." Keeping those separate is not
skepticism; it is the same discipline the isolated traditions kept, who read
the sky for omens yet never once built a horoscope.

## 9. The Great Mother and the Divine Child

**Jung's claim.** The mother archetype and the divine child (the *puer*, the
miraculous birth heralding renewal) are among the primary archetypal images,
universal across mythologies (Jung & Kerényi, *Essays on a Science of
Mythology*).

**What the Atlas measured.** The two halves of the claim measure very
differently. **Miraculous Child and Sacred Birth spans 92 of 97 tradition
groups (8,340 records)** — near the ceiling, in the same reach-class as the
trickster. **Sacred Feminine and Mother Goddess spans 50 of 97 (809
records)** — half the map, one seventeenth the record depth of
death-and-transformation. The wondrous child is close to pan-human; a
*goddess-figured* Great Mother, as a named mythological presence, is a
strong regional pattern rather than a universal. (Neither family has an
experiential-corpus counterpart; both are narrative archetypes, which is
consistent with the cross-corpus finding that character archetypes are what
first-person experience does *not* reproduce.)

**Verdict: SUPPORTED-IN-FORM for the child; CORRECTED for the mother.** The
divine-child pattern recurs at near-universal reach. The Great Mother, as
image, is real but regional — which again favors Jung's form-level reading
over his image-level one: mothering, birth, and origin are everywhere, but
the *personified goddess* is one cultural crystallization of them, not the
recurring unit itself.

**Ancient evidence** (Blackfoot, Plains — isolated; the child who arrives
from nowhere to overturn the order): "When the pot began to boil, the old
woman heard a child crying. She looked all around, but saw nothing. Then she
heard it again. This time it seemed to be in the pot. She looked in quickly,
and saw a boy baby" (L2865–2869) — Blood-Clot, born of a buffalo's blood,
who grows in days and frees the oppressed household. *Mythology of the
Blackfoot Indians.*

**For the consulting room:** child imagery — the new, endangered, wondrous
thing demanding protection — has near-universal comparative standing and
deserves the weight Jung gave it. Mother imagery should be read with more
cultural care than the classical Jungian literature suggests: where the
patient's tradition never personified a Great Mother, forcing the goddess
frame imports an image the pattern-data does not make universal.

---

## What survived, in one paragraph

Jung's *forms* did strikingly well: the shared story-grammar of unconnected
peoples (crown, p = 0.002), the descent-and-return, the death-rebirth arc,
the dissolution of self, the divine child, the trickster's act. His *images*
did poorly: no fixed archetypal pictures (99% of raw motifs are singletons),
no universal quaternity, no universal Great Mother, no universal trickster
figure, no sacred numbers at all. The pattern in the pattern: wherever Jung
claimed an abstract structure, measurement tends to find it; wherever he (or
his popularizers) claimed a specific content, measurement finds local
dialects. And on mechanism — the collective unconscious as inherited psychic
stratum, synchronicity as acausal principle — the corpus is, and will remain,
silent. That silence is not a verdict. It is the boundary of what texts can
carry.

---

*Data sources: `data/indexes/crown-independent-taxonomy.yml` (k=64 blind
taxonomies, matched bonds, permutation statistics),
`data/indexes/canonical-motif-frequency.yml` (65 canonical motif families,
284,307 indexed occurrences across 97 tradition groups),
`data/indexes/number-patterns.yml` and `docs/finding-sacred-numbers.md`
(sacred-numbers study, seed 137, 1000-permutation nulls),
`data/indexes/astral-lore.yml` (40,004 celestial passages, 103 traditions),
`data/indexes/cross-corpus-taxonomy-comparison.yml` (experiential ↔ ancient
mapping), `taxonomy/motifs.yml` and `ARCHITECTURE.md` (family layers,
singleton structure), and the letters
`the-numbers-refused-to-be-universal.md`,
`the-trickster-refused-our-net.md`, and `the-sky-we-all-read.md`. All quotes
are from public-domain texts in `texts/public-domain/`; line references
(Lnnn) point into the repository markdown sources, with OCR spacing
normalized. Assembled from the Atlas's indexes and evidence records by
Claude (Anthropic); every quote verified verbatim against source lines.
2026-07-21.*
