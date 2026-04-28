# Structured Pattern Records

Use `templates/pattern-record.yml` for one pattern-level record that can later feed the Pattern Explorer. Validate completed JSON records against `schemas/pattern-record.schema.json`.

Pattern records sit above passage-level extraction records and below long-form comparison essays. They should group evidence-backed occurrences without turning similarity into identity.

## Core Rules

- Use the weakest accurate `comparison_mode`: `structural`, `thematic`, `historical_contact`, `common_inheritance`, `independent_emergence`, or `archetypal`.
- Keep `summary`, `occurrences`, `shared_features`, `differences`, and `evidence` close to observable source material.
- Put symbolic, psychological, historical, ritual, or comparative explanation only in `interpretive_lenses`.
- Link every occurrence, shared feature, difference, and interpretive lens to one or more `evidence_refs`.
- Use `caution_notes` for anti-flattening limits, counterexamples, and reasons not to make a stronger claim.
- Use `open_questions` for missing sources, dating problems, possible transmission paths, or disconfirming evidence.
- Track rights and provenance before quoting. If rights are mixed or uncertain, summarize and cite.

## Field Guide

- `record_id`: stable identifier for the pattern record.
- `summary.short`: one or two careful sentences. Do not overstate contact or equivalence here.
- `summary.scope_note`: what this record includes, excludes, or treats as provisional.
- `comparison_mode`: the main claim posture for the whole record.
- `cultures`, `traditions`, `eras`: normalized context labels. Prefer taxonomy references when available.
- `motifs`: motif labels and taxonomy links used by the record.
- `occurrences`: source-level appearances of the pattern, optionally pointing to extraction records.
- `shared_features`: evidence-linked common elements that justify grouping occurrences.
- `differences`: evidence-linked distinctions that keep the comparison precise.
- `evidence`: quotes, summaries, citations, extraction references, translator notes, or secondary notes.
- `interpretive_lenses`: explicitly marked readings such as structural, historical, ritual, philological, iconographic, psychological archetypal, folklore, or network analysis.
- `confidence`: conservative confidence values for grouping, historical links, source quality, and interpretation.
- `rights`: quote/summarize/citation constraints for the record as a whole.
- `provenance`: who created the record, when, and from which repo sources or notes.

## Comparison Mode Discipline

- `structural`: sources share arrangement, sequence, roles, or narrative function.
- `thematic`: sources share a broad concern or image, but not necessarily the same structure.
- `historical_contact`: evidence supports possible transmission through contact, translation, migration, trade, conquest, or shared ritual space.
- `common_inheritance`: evidence suggests descent from an older shared cultural, linguistic, textual, or ritual source.
- `independent_emergence`: similar forms plausibly arose separately from recurring human situations or environments.
- `archetypal`: a psychological or symbolic reading is being offered as interpretation, not as proof of origin.

If more than one mode is useful, choose the top-level mode that best describes the record and add the others as separate `interpretive_lenses`.

## Evidence Pattern

Prefer small reusable evidence units:

```yaml
evidence:
  - id: ev:1
    type: summary
    locator: "Genesis 6-9"
    quote_or_summary: "A flood destroys the old world; a preserved remnant survives and renews human life."
    source_text_path: texts/public-domain/biblical/world-english-bible-classic/genesis.md
    tradition_refs: [biblical]
    rights_note: "Public-domain source; summarize unless quotation is needed."
```

Then link claims back to those IDs:

```yaml
shared_features:
  - id: feature:1
    label: Preserving vessel
    description: A protected container or refuge carries life through catastrophe.
    feature_type: image
    evidence_refs: [ev:1, ev:2]
    confidence: medium
```

## Anti-Flattening Checks

Before marking a record reviewed, ask:

- Are local meanings preserved for each tradition?
- Are historical-contact claims separated from structural or archetypal claims?
- Are later receptions separated from earlier attestations?
- Are living or Indigenous traditions described with specific community context where possible?
- Does every interpretive statement point to evidence and include cautions when needed?
