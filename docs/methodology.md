# Methodology

The atlas should let you ask big Campbell- and Jung-shaped questions while keeping scholarly humility.

## Levels Of Claim

Use these levels when comparing myths:

1. **Same motif**
   Two traditions share a recognizable form: mother nursing child, world flood, sacred mountain, descent to the underworld.

2. **Same function**
   The motif performs a similar role: legitimizing kingship, mediating death, explaining suffering, initiating the hero.

3. **Historical contact**
   There is evidence that one tradition could have influenced another through conquest, trade, translation, migration, or shared ritual space.

4. **Common inheritance**
   Similarities may come from an older shared cultural or linguistic source.

5. **Independent recurrence**
   Similarities may arise because humans repeatedly face birth, death, fertility, fear, kinship, hunger, sky, sea, animals, dreams, and power.

6. **Archetypal reading**
   The pattern is interpreted as a recurring psychic structure, symbolic image, or mythic grammar.

## Confidence Scale

```yaml
confidence:
  motif_match: low | medium | high
  historical_link: none | speculative | plausible | strong
  archetypal_reading: speculative | plausible | strong
```

## Comparison Checklist

When making a pattern note, ask:

- What is the earliest attested version?
- What exact scene, image, phrase, or ritual is being compared?
- Are the figures equivalent, analogous, or only visually similar?
- Is there known contact between the cultures?
- Are we comparing primary sources, later art, or modern interpretations?
- Could the pattern come from ordinary human life rather than direct borrowing?
- What would disconfirm the comparison?

## Suggested Analytic Lenses

- folklore motif indexes
- comparative mythology
- depth psychology
- ritual studies
- art history and iconography
- philology and translation history
- anthropology and cross-cultural datasets
- network analysis and knowledge graphs

## Data Model

Think in triples:

```text
figure -> performs_role -> role
figure -> appears_in -> source
motif -> appears_in -> tradition
motif -> resembles -> motif
source -> dated_to -> date_range
claim -> has_confidence -> confidence_level
```

This makes the project ready for graph databases later.

