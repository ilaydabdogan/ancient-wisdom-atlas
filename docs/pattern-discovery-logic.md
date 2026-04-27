# Pattern Discovery Logic

This project should find recurring human patterns without flattening cultures into one vague universal myth.

## Core Objects

Use these as separate data types:

- `text`: a complete source unit such as a book, tablet, chapter, hymn, surah, chant, tale, or section
- `figure`: a named being, deity, human, animal, spirit, ancestor, or symbolic person
- `role`: mother, child, king, trickster, messenger, monster, guide, beloved, rival, healer
- `symbol`: serpent, milk, tree, mountain, cave, flood, fire, sun, moon, bread, blood, road
- `scene`: nursing child, descent, combat, sacrifice, exile, birth, flood survival, recognition
- `motif`: a repeatable pattern made from roles, symbols, and actions
- `claim`: a comparison with evidence and confidence

## Extraction Layers

### 1. Literal Layer

What does the source actually say or depict?

Example:

```text
mother -> nurses -> child
hero -> descends_to -> underworld
serpent -> guards -> tree
flood -> destroys -> old_world
```

### 2. Structural Layer

What function does the scene perform in the story?

Examples:

- legitimation
- protection
- initiation
- temptation
- renewal
- sacrifice
- boundary crossing
- divine-human mediation

### 3. Historical Layer

Could there be transmission?

Track:

- date range
- geography
- trade routes
- conquest
- translation history
- shared empire
- shared language family
- ritual contact
- manuscript transmission

### 4. Psychological / Archetypal Layer

What recurring human experience might the pattern express?

Examples:

- birth and dependency
- fear of death
- desire for immortality
- separation from parents
- initiation into adulthood
- grief and return
- union of opposites
- shadow, trickster, double, or guide

## Comparison Claim Levels

Use the weakest accurate claim.

1. `same_image`: visually similar image or iconography
2. `same_scene`: similar narrative scene
3. `same_function`: similar role in ritual, social, or theological life
4. `plausible_contact`: cultures could have influenced each other
5. `documented_contact`: there is specific evidence of transmission
6. `common_inheritance`: likely inherited from an older shared source
7. `independent_recurrence`: similar human pressures produced similar symbols
8. `archetypal_reading`: useful psychological or symbolic interpretation

## Confidence Fields

Every comparison should carry:

```yaml
confidence:
  motif_match: low | medium | high
  historical_link: none | speculative | plausible | strong
  source_quality: weak | mixed | strong
  archetypal_reading: speculative | plausible | strong
```

## Symbol Families

Start with these high-yield families:

| Family | Core Symbols | Questions |
| --- | --- | --- |
| Mother and Child | milk, womb, lap, breast, cradle, cave | Who nourishes the future? |
| World Center | tree, mountain, pillar, temple, ladder | Where do worlds meet? |
| Descent | cave, sea, night, underworld, tomb | What must be entered before transformation? |
| Death and Return | seed, corpse, moon, season, resurrection | What dies and returns changed? |
| Trickster | road, crossroads, theft, disguise, joke | How does disorder create culture? |
| Serpent / Dragon | poison, healing, water, treasure, chaos | Is the hidden power enemy, healer, or guardian? |
| Sacred Birth | star, prophecy, virgin, hidden child | How does destiny enter the world? |
| Flood / Dissolution | water, ark, mountain, remnant | What survives when the old world dissolves? |
| Twins / Doubles | brothers, rivals, shadow, companion | How does identity split or pair? |
| Sacrifice | blood, fire, altar, food, vow | What must be given up to bind a larger order? |

## Graph Shape

Eventually every extraction should become graph-like:

```text
Text -> contains_scene -> Scene
Scene -> uses_symbol -> Symbol
Scene -> contains_figure -> Figure
Figure -> has_role -> Role
Motif -> appears_in -> Text
Claim -> compares -> Motif
Claim -> supported_by -> Evidence
Claim -> has_confidence -> Confidence
```

## AI Extraction Protocol

For each text:

1. Extract literal figures, actions, places, objects, and relationships.
2. Extract candidate motifs with evidence quotes or passage references.
3. Ask a second pass to challenge overreach.
4. Store uncertain ideas as hypotheses.
5. Link every motif to exact source location.
6. Never let Jungian or Campbell-style interpretation overwrite local meaning.

## Anti-Flattening Rules

- Similarity is not identity.
- A symbol can mean opposite things in different traditions.
- A goddess is not automatically equivalent to Mary, a bodhisattva, or a queen mother.
- Historical transmission and archetypal recurrence are different claims.
- Living traditions require cultural context, not just text mining.
- The comparison should make each culture sharper, not blurrier.

