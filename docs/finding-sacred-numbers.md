# Finding: Sacred Numbers — the Pauli Question

Run: 2026-07-19, deterministic scripts, seed 137, 1000-permutation nulls.
Machine-readable results: `data/indexes/number-patterns.yml`.

## The question

Wolfgang Pauli was haunted by 137; Jung by the recurrence of certain numbers
in dream and myth. Empirically: do the world's mythologies favor the SAME
numbers — 3, 7, 12, 40, 108 — beyond what language and chance produce? And
the falsifiable core, reusing the Atlas's isolated/connected split: do
peoples with no historical contact with the Old World favor the same numbers
the connected world favors?

## Method

Deterministic extraction over all 338 canonical texts (39.4M words, 106
tradition directories; `comparative/` excluded from statistics). Both
numerals and spelled-out English forms were captured: cardinals and
compounds ("one hundred and eight", "threescore and ten", "fourscore",
"a dozen", "twain"), multiplicatives ("twice", "thrice", "sevenfold"),
and ordinals gated on a mythic-noun whitelist ("seventh heaven", "third
day"). 604,281 raw mentions survived the structural filters; 484,982 after
final noise passes; 319,420 in the primary channel.

Structural-noise filters (all deterministic, all listed in the yml method
block): frontmatter, headings and all-caps lines, TOC dot-leaders,
chapter/verse/page/figure/section reference contexts with a 5-token
lookback, comma-chain propagation of reference drops ("sect. 5, 6, 7"),
bracketed footnote refs, d:d verse refs and d–d ranges, line-initial
numerals (verse numbering), number-only lines, trailing page-number runs
(back-of-book indexes), standalone 4-digit years, Gutenberg/copyright
lines, high symbol-density OCR lines, enumeration lines, and pronoun uses
of "one". Dropped mentions of the famous constants were logged with
reasons, so absence claims are auditable.

**Primary channel = spelled forms only** (cardinal + multiplicative +
ordinal, 319,420 mentions). In 19th-century translations digits are
overwhelmingly editorial apparatus; words are what the translator wrote as
prose. The numeral channel is retained as a sensitivity check.

**Key metric — prominence ratio**: observed count ÷ count predicted at n by
a power-law fit over its neighbors. Two variants: *local* (nearest nonzero
neighbors, ≤4/side — "is 7 special compared to 6 and 8?") and
*roundness-matched* (peers share n's count of trailing zeros — 40 is judged
against 20, 30, 50…, not against 39 and 41, because language favors round
numbers everywhere). The roundness-matched variant is the stricter one, and
it matters: 40's local prominence is 27.8× but its roundness-matched
prominence is 1.04 — famous forty is just an ordinary decade once you
control for roundness (its fame is Abrahamic, not universal).

**Cross-world test**: Spearman ρ between the isolated pile's prominence
profile and the connected pile's (74 numbers with ≥5 mentions in each
pile), against a null of 1000 random tradition→pile shuffles at fixed pile
sizes. Iso list = the crown list (`scripts/crown_prep_records.rb`) plus
post-crown directory variants and same-doctrine additions
(aboriginal-australian, arctic-inuit, native-american-california,
native-american-plateau, chaco-amerindian, inca, khoekhoe): 31 isolated vs
74 connected traditions. The strict crown-only split is reported as a
sensitivity.

## Result

**The world's mythologies do NOT favor the same numbers. The isolated and
connected worlds favor different ones.**

1. **Absolute agreement is high but meaningless.** Iso and con prominence
   profiles correlate at ρ = 0.845 — but ANY random split of the 105
   traditions correlates at 0.885 ± 0.026. The agreement is carried by the
   shared decay of number use in language (global exponent ≈ −2.2), not by
   shared sacredness.

2. **On the stricter roundness-matched metric, the real iso/con split
   agrees significantly LESS than random splits**: ρ = 0.616 vs null
   0.736 ± 0.048, p_deficit = 0.016 (strict crown split: p = 0.031;
   local-prominence primary: p = 0.062). The maximally
   culturally-separated split is also the maximally number-divergent one.

3. **The divergence is interpretable and robust.** The connected Old World
   elevates **3** (roundness-matched prominence 1.36 vs iso 0.68),
   **7** (2.13 vs 1.27), and **9** (1.43 vs 0.76). The isolated pile
   (Americas, Australia, Arctic, Khoisan) elevates **4** (2.20 vs con
   0.88) — the four directions — and mildly 40 (1.64). Four beats three
   outright in 9 of 26 isolated traditions (Navajo 326:88, Hopi 245:97,
   Zuni 77:20) but only 5 of 70 connected ones. Seven is elevated above
   its neighbors in 49/70 connected traditions but only 9/26 isolated
   ones. No single tradition drives either side.

4. **The one number both worlds elevate is 12** (iso 2.96, con 3.44) — and
   the isolated quotes are calendrical ("The Cree year is divided into
   eight seasons and twelve months, or moons"), consistent with
   independent astronomy — twelve-ish lunations per solar year — rather
   than contact or archetype.

5. **137 does not appear.** In 39.4M words, Pauli's number occurs as a
   symbolic quantity exactly nowhere. Its only genuine narrative
   occurrences are three biblical patriarch lifespans — Ishmael, Levi, and
   Amram each live "one hundred thirty-seven years" — and one Buddhist
   chronological note ("137 years after the Nirvana"). All 1,100+ other
   raw occurrences are page indexes, section numbers, verse refs, figure
   captions. It never appears in any isolated tradition. Absence is the
   finding.

6. **What IS globally or regionally elevated** (roundness-matched, spelled
   channel): 12 (3.34, 97 traditions), 7 (1.91, all 105), 9 (1.28), 4
   (1.17), 3 (1.12); and regionally: 99 (8.6, 25 traditions — the
   round-number-minus-one intensifier: 99 Tengeri provinces, Duryodhana's
   99 brothers, the Koran's 99 ewes), 360 (13.5, 12 traditions, all on the
   connected astronomical corridor), 108 (9.6, 8 traditions, all dharmic),
   77 (Uralic/Slavic/Siberian repdigit intensifier), 42 (3.3 — Egyptian
   assessors among others), 33 (3.0), 49 = 7×7 (3.1), 72 (3.0).
   108 and 360 have zero isolated-pile occurrences.

7. **Pairs**: the commonest same-passage pairs are idiomatic counting
   spans (2–3, 3–4, 2–4). The commonest non-adjacent mythic pairs: 3–7
   (193 passages, 55 traditions), 5–10, 3–9, 10–12, 4–8. "Seven days and
   seven nights" style doubling dominates within-value pairing.

## Example quotes (verbatim, path:line in yml)

- "The Tao produced One; One produced Two; Two produced Three; Three
  produced All things." — daoist, tao-teh-king-legge.md:813
- "Forty nights and days they are hidden and appear again as the year
  moves round" (the Pleiades) — greek, hesiod-homeric-hymns-homerica.md:1906
- "the forty spirits came out of the sacred room" — kwakiutl (isolated),
  ethnology-kwakiutl-2-boas-hunt.md:9625
- "listen to the one hundred and eight names (of the sun)" — hindu,
  mahabharata-ganguli-vol1.md:29335
- "a hundred and eight headed Mangathai" — buryat-mongol,
  journey-in-southern-siberia-curtin.md:13771
- "seventy-seven stars are above my head" — finnic charm,
  pre-and-proto-historic-finns-v2-abercromby.md:751
- "In the heavens there are ninety-nine Tengeri provinces" — buryat-mongol,
  journey-in-southern-siberia-curtin.md:5913
- "These are the years of the life of Ishmael: one hundred thirty-seven
  years." — biblical, world-english-bible-classic/genesis.md:1557
- "when four singers, after long and careful instruction by the priest,
  come forth painted, adorned, and masked as gods" — navajo,
  navaho-legends-matthews.md:788

## Limits — read before citing

- **Translation artifact risk, named prominently:** every text in this
  corpus is an ENGLISH translation. English number idiom ("forty winks",
  "a thousand times", KJV-inflected "threescore and ten") can inflate or
  reshape a tradition's apparent profile. The iso/con DIVERGENCE result is
  robust to this (a shared-English artifact would push the piles together,
  not apart — the observed deficit is therefore conservative), but
  absolute prominences of individual numbers, especially 40 and 1000, are
  not safely attributable to source languages without checking originals.
- Ethnographic monographs (Boas, Roth, Spencer & Gillen) mix native
  narrative with collector prose; the spelled channel does not distinguish
  a Kwakiutl teller's "forty" from Boas's own.
- The isolated pile is 28% of spelled mentions and dominated by North
  America; "isolated" follows the crown list doctrine (e.g. Hawaiian iso,
  Maori con) and inherits its judgment calls.
- Ordinals are whitelist-gated; multiplicative "once" was excluded as
  un-parseable idiom; value 1 is pronoun-contaminated and excluded from
  prominence targets; roman numerals never parsed.
- Numeral-channel residue: citation apparatus survives filters at low
  rates; that is why the primary channel is spelled forms.
- The permutation null preserves the corpus's overall number profile; it
  tests pile assignment, not English itself. No test here can separate
  "universal cognition" from "shared translation language" for numbers
  BOTH piles elevate (i.e. 12); the divergent numbers (3/7/9 vs 4) are
  where the signal is.

## What would falsify this

- Source-language recount (Hebrew, Sanskrit, Nahuatl, Quechua originals)
  showing the iso/con divergence disappears when English idiom is removed.
- Adding isolated-tradition corpora (more Australian, Amazonian, Khoisan
  primary texts) that elevate 3/7/9 at connected-world levels would kill
  the divergence claim; more four-cornered cosmologies in the OLD world
  (there are some: Egyptian four sons of Horus) narrowing the 4-gap would
  weaken it.
- A single symbolic use of 137 anywhere in a pre-contact tradition would
  be delightful and is hereby invited.

## Reproduction

Scratchpad scripts (session d42cd906, to be reviewed into `scripts/`):
`extract_numbers.py` → `mentions.jsonl` + `dropped_constants.jsonl`;
`analyze_numbers.py` → `analysis.json` (seed 137, 1000 perms);
`supplement.py` (robustness tabulations, quote candidates);
`build_yml.py` → `data/indexes/number-patterns.yml`.
