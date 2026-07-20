# Finding: Astral Lore — What Every People Said About the Same Sky

Run: 2026-07-18/19. Stage-1 harvest deterministic (no model); stage-2/3
syntheses by gpt-5.6-terra (Azure ATLAS_AZURE_0) reading verbatim quotes only.
Machine-readable results: `data/indexes/astral-lore.yml`.

## The question

Every people watched the same sky. The sacred-numbers run showed the one
numerical grammar both the isolated and connected worlds share is
astronomical (12 lunations, the Pleiades' seasonal calendar). This
expedition maps the astral lore itself: what the sun, moon, and stars ARE
in each tradition, the named asterisms and their stories, calendrical
practice, and astrology proper (the sky as message) — and asks which
celestial ideas recur across peoples with no historical contact.

## Method

**Stage 1 (deterministic, no model).** Scan of all 338 canonical texts in
`texts/public-domain/` (105 tradition dirs + `comparative/`, excluded from
statistics as in the numbers run). 20 celestial term families (sun, moon,
star, planet, Venus/morning star, Pleiades incl. native names appearing in
translations, Orion, Great Bear/Dipper, Milky Way, pole star, eclipse,
comet, meteor, zodiac, constellation, lunar mansion, new/full moon,
solstice, equinox, and celestial-only "heavens" phrases: firmament / host
of heaven / vault of heaven), matched case-insensitively with ~80-word
contexts, path+line recorded for every hit. Noise filters carried over from
the numbers run: frontmatter, all-caps headings, TOC dot-leaders, index
tails, footnote refs, Gutenberg boilerplate, high-symbol OCR lines. Known
homonyms gated on context: "eclipsed" (metaphor) requires sun/moon nearby;
"Venus" (goddess) requires planetary context; "great bear"/"dipper"
(animals, ladles) require sky context. **40,004 passages** survived, in
104 of 105 tradition dirs (the only zero is `christian/`, which holds a
single short Greek-text Didache with no English celestial vocabulary).

**Stage 2 (terra, evidence only).** For each of the **103 traditions with
>= 5 passages** (30 isolated / 73 connected, same iso list as
`number-patterns.yml`), an evidence pack of numbered verbatim quotes (all
rare-family quotes up to 8/family, evenly spaced; sun/moon/star ranked by
mythic-keyword relevance, top 12/12/10 + evenly-spaced extras — a
documented selection bias, see limits) was sent to gpt-5.6-terra
(concurrency 4, max_output_tokens 4000, Azure Responses API per
`scripts/run_trickster_comparison.rb`). Terra was instructed: no outside
knowledge, cite quote indices [Q#] for every claim, output `absent` for
unsupported categories. All 103 syntheses returned, 0 errors; stored
verbatim with model + timestamp in the yml.

**Stage 3.** Deterministic cross-tradition tables (term-family spread,
Pleiades, Milky Way, Orion, sun/moon gender, sky omens, each with iso/con
counts); regex flags on terra's cited details, hand-adjudicated where the
regex misread negations ("gives no sisters" is not sisterhood) — every
override recorded with its reason in the yml. One final terra call over the
whole table for the honest scholarly summary (verbatim in the yml).

## Result

**There is no single worldwide sky-story. What recurs across the isolated
and connected worlds is attention, calendar, and omen — not content.**

1. **Term-family spread.** Sun reaches 104 traditions, moon 103, star 99.
   Beyond those: new/full moon 72, morning/evening star 57, constellation
   53, **Pleiades 51 (17 iso / 34 con)** — the most widely named asterism
   in the corpus, ahead of the Milky Way (43; 16 iso) and Orion (31; 8
   iso). At the other end, the formal astral sciences are connected-world
   property: **zodiac 24 traditions but only 1 isolated** — and that lone
   hit (zuni-folk-tales-cushing.md:399) is the ethnographer's own framing
   prose ("festivals... fixed at times indicated by signs of the zodiac"),
   not Zuni lore — and **lunar mansions 7 traditions, 0 isolated** (all
   dharmic/Persian/Chinese-corridor). Effectively: zodiac and mansions
   have zero indigenous isolated attestation, exactly like 108 and 360 in
   the numbers run.

2. **The Pleiades verdict: the famous "seven sisters" does NOT hold as a
   universal in our corpus; the calendar does.** 48 traditions have a
   terra-supported Pleiades story (17 iso / 31 con). Explicit seven-ness:
   17 traditions (7 iso / 10 con) — but the isolated seven includes the
   duplicate Australian directories (same Parker texts) and a Navajo
   "seven stars we behold in the north" that is more plausibly the Great
   Bear, so the independent isolated seven-count is ~5. Sisterhood
   (adjudicated, negations removed): **only Australia in the isolated
   pile**; connected: the Greek/Roman classical complex, Norse, Melanesian
   ("company of maidens") — and "oceanic" is Dixon's survey retelling the
   same Australian tale. Against the sisters: Inuit "little foxes" (fox
   cubs), Cherokee "The Boys" (Ani'tsutsa), Blackfoot/Plains six
   *brothers*, Basque and Ekoi "hen and chickens", Mongol seven sparks,
   Finnic sieve-holes, Guiana scattered entrails of a murdered man. What
   DOES recur independently is **calendrical use — 11 traditions (3 iso:
   Chaco spring feasts, Guiana new year, Aztec 52-year zenith watch; 8
   con: Greek harvest/ploughing, Roman, Hermetic sowing month, Confucian
   equinox observation, Bantu tilling season, Mangaian/Melanesian new
   year)** — plus omen use (Aztec end-of-world watch; Pima "Seven Stars"
   prayed to). The seasonal instrument is the universal; the seven sisters
   are a regional story that Greek and Australian tellers happen to share.

3. **The Milky Way verdict: "a track someone left" is the bilateral idea;
   the specific substance varies wildly.** 39 traditions carry a
   conception (16 iso / 23 con). Road/path/track dominates on both sides —
   and a specifically **path-of-the-dead** reading is densest in isolated
   North America (Menomini "spirit road", Omaha "path of the dead" with a
   judge at the forks, Skidi Pawnee dim road for warriors vs. broad road
   for those who die of old age, Blackfoot "Wolf Road", Chaco path of the
   kilyikhama), with connected analogues that differ in kind (Hermetic
   soul-descent at the Galaxy, Egyptian heavenly Nile). River: Australia
   (warrambool overflow lined with campfires), Siberia ("river of the
   gods"), China (Han river), Korea. And gloriously unshared: San wood
   ashes thrown into the sky, Zuni "Great Snow-drift of the Skies", Inuit
   Raven's snowshoe track, Algonquin "bird's path" guiding migrations,
   Cherokee "Where the dog ran". Diversity is the finding.

4. **Orion is a connected-world favorite** (31 traditions, only 8
   isolated), and the isolated readings owe nothing to the hunter: an emu
   (Australia), "Great stretchers" (Inuit belt), a severed leg (Guiana),
   Sun Father's warriors (Pima/Zuni). The hunter-hero Orion is
   Greek-corridor property.

5. **Sun/moon gender: no worldwide default.** Of traditions where terra
   could gender both from evidence: sun-male/moon-female 24 (6 iso / 18
   con), sun-male/moon-male 16 (6/10), sun-female/moon-male 5 (1 iso —
   Inuit sister-sun fleeing her brother — plus Japanese/Shinto Amaterasu,
   Germanic Sol, Georgian, Hausa, Ainu con), sun-female/moon-female 0.
   The male-sun/female-moon "default" is a connected-world plurality, not
   a law; the isolated pile splits evenly between it and all-male.

6. **Sky omens: omen-reading is bilateral; astrology proper is not.** 62
   traditions read something in the sky (15 iso / 47 con). The isolated
   pile reads it richly — Inuit eclipse foretelling epidemics (duration =
   severity), Australian falling star = a death, San falling star = a
   heart falling in death, Chaco red moon = witnessed bloodshed, Guiana
   comet = pestilence, Plateau moon-with-one-star = imminent widow, Aztec
   birth-fate specialists weighing luminaries. But the **technical
   apparatus** — zodiacal houses, nativities, lunar mansions, planetary
   benefics — exists only on the connected corridor (Mesopotamia, Persia,
   India, Islam, China, Hermetica). Verdict: watching the sky for fate is
   plausibly universal; *systematized* astrology is a connected-world
   invention that never independently appears in the isolated pile.

7. **Honest negatives.** No isolated zodiac or lunar mansion (see 1). The
   Pleiades are not "seven" in most traditions that name them (31 of 48
   stories never say seven). Terra returned `absent` for entire categories
   in dozens of traditions rather than embellish — e.g. sun_identity:
   absent for aboriginal-australian despite 100+ sun passages (the
   passages are time-of-day markers, not a story), and Inca Pleiades:
   "the proposed meaning is not understood," nothing more.

## Example quotes (verbatim, path:line under texts/public-domain/)

- "And there, if you look, you may see the seven sisters together. You
  perhaps know them as the Pleiades, but the black fellows call them the
  Meamei." — australian-aboriginal (iso),
  australian-legendary-tales-parker.md:1438
- "The Pleiades are called the 'Little foxes,' and are said to be a litter
  of fox cubs." — arctic-inuit (iso),
  eskimo-about-bering-strait-nelson.md:27337
- "she threw up the wood ashes into the sky. She said to the wood ashes:
  'The wood ashes which are here, they must altogether become the Milky
  Way... They must white lie along in the sky'" — san (iso),
  specimens-of-bushman-folklore-bleek-lloyd.md:2409
- "If the dead man had been a warrior, he was put on the dim Milky Way; if
  he died of old age, or if it was a woman, they were put upon the wide
  travelled road." — native-american-plains (iso),
  traditions-skidi-pawnee-dorsey.md:3314
- "Let his spirit accompany the soul of the deceased over the spirit road
  (the milky way) to the hereafter." — native-american-great-lakes (iso),
  ceremonial-bundles-menomini-skinner.md:3951
- "The re-appearance of Pleiades above the horizon at sunset, i.e. the
  beginning of a new year, was in many islands a time of extravagant
  rejoicing." — mangaian (iso-adjacent Polynesia, classed con),
  myths-and-songs-south-pacific-gill.md:2578
- "the scattered entrails of the murdered man floated upward to the skies,
  and assumed the appearance of the Seven Stars" — guiana-amerindian
  (iso), animism-folklore-guiana-indians-roth.md:8277
- "An eclipse of the moon is said to foretell an epidemic... The length of
  duration of an eclipse is said to indicate the severity of the
  visitation to follow." — arctic-inuit (iso),
  eskimo-about-bering-strait-nelson.md:26229
- "The boy has pursued her ever since, becoming the sun, and sometimes
  overtakes and embraces her, thus causing an eclipse." — arctic-inuit
  (iso), eskimo-about-bering-strait-nelson.md:29172

## Limits — read before citing

- **Translation vocabulary is the largest risk, named plainly:**
  "Pleiades," "Orion," "Milky Way," "zodiac" are Greek/English labels
  applied by translators and collectors. A tradition "has" the Pleiades
  in this corpus when its translator identified a native cluster with
  them; misidentification (which cluster is "the Seven Stars"?) is real —
  the Navajo case (seven stars "in the north") is flagged in the yml as
  probably the Great Bear.
- **Collector prose:** ethnographic monographs (Nelson, Roth, Spencer &
  Gillen, Skinner) mix native narrative with the collector's own
  comparative asides; the lone isolated "zodiac" hit is exactly such an
  aside. Terra saw quotes without speaker attribution.
- **Evidence-pack selection bias:** sun/moon/star quotes were ranked by
  mythic-keyword relevance before sampling, which favors deity/kinship
  readings over mundane uses; rare families were sampled evenly, not
  ranked. Identity claims are therefore ceiling estimates; `absent` calls
  are the more trustworthy direction.
- **Duplicate directories:** australian-aboriginal / indigenous-australian
  share the Parker texts, and oceanic (Dixon) retells the same Australian
  material; nahua-maya-inca overlaps maya/inca/nahua. Raw counts in the
  tables count directories; the finding text counts independent
  attestations (adjudications recorded in the yml).
- **Gender via English:** terra genders sun/moon from translated pronouns
  and kinship terms; source-language grammatical gender (German die Sonne,
  etc.) can leak through translators. The iso/con contrast is more robust
  than any single tradition's classification.
- The isolated pile is 30 of 103 synthesized traditions and dominated by
  North America + Australia; "isolated" follows the crown-list doctrine
  (Hawaiian iso, Maori/Mangaian con) with its judgment calls inherited.
- Term-list bias: families we did not search (Southern Cross, Magellanic
  Clouds, Venus native names, "sky window") exist in the texts — the
  Southern Cross appears inside harvested contexts — but were not
  systematically harvested; southern-hemisphere asterisms are undercounted.

## What would falsify this

- **Pleiades-as-calendar universality:** source-language checks showing
  the ethnographers, not the peoples, supplied the season-marker framing;
  or added isolated corpora whose Pleiades carry no seasonal role.
- **"Seven sisters" as regional, not universal:** finding independent
  isolated seven-sisters stories (more Australian-language texts, Andean
  originals — Quechua qutu material is absent here) would push it back
  toward archetype; conversely, showing Parker's "as usual" gloss shaped
  her translation would weaken even the Australian case.
- **Milky-Way road-of-souls:** demonstrating the "road/path" wording is
  translator idiom (all corpus texts are English) would collapse the
  bilateral road; original-language terms (Menomini, Pawnee) preserving
  "road" would harden it.
- **Astrology-as-connected-specialty:** any indigenous zodiac, mansion
  system, or natal calculation in a pre-contact isolated text would kill
  the cleanest split in this finding and is hereby invited (Maya
  codical astronomy is the obvious place to look — our Maya holdings are
  thin: 24 passages).

## Reproduction

Scratchpad scripts (session d42cd906, to be reviewed into `scripts/`):
`harvest_astral.py` → `astral_mentions.jsonl` (40,004 passages) +
`astral_summary.json`; `build_packs.py` → `astral_packs.json` (103 packs);
`run_terra_synthesis.py` (gpt-5.6-terra, ATLAS_AZURE_0, concurrency 4) →
`astral_syntheses.json`; `stage3_patterns.py` → `astral_patterns.json`;
`run_final_synthesis.py` → `astral_final_synthesis.json`;
`build_astral_yml.py` → `data/indexes/astral-lore.yml`.
