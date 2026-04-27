# Extraction Protocol

Use `templates/extraction-record.yml` for one passage-level motif/symbol extraction record, and validate completed JSON records against `schemas/extraction.schema.json`.

## Core Rules

- Record what the passage says before explaining what it means.
- Keep `canonical_text` and `literal_observations` free of symbolic, psychological, historical, theological, or comparative interpretation.
- Put interpretation only in `candidate_motifs` or `comparison_claims`.
- Every observation, candidate motif, role, symbol, scene, and comparison claim must link to one or more `evidence_refs`.
- Do not make a comparison claim unless the evidence list contains the quote, summary, citation, translator note, or secondary note that supports it.
- Use confidence values conservatively: `high`, `medium`, `low`, or `uncertain`.

## Field Guide

- `source_text_path`: repository-relative path to the text or source metadata record.
- `passage_locator`: precise location within the source, such as chapter/verse, line range, page, folio, section, or timestamp.
- `canonical_text`: exact excerpt when rights allow, otherwise a neutral summary. This is not the place for interpretation.
- `literal_observations`: direct details visible in the passage, such as actions, objects, settings, speech, attributes, relationships, or sequence.
- `figures`: named or described agents in the passage.
- `roles`: evidence-based labels for what figures do in the passage.
- `symbols`: objects, beings, places, numbers, gestures, colors, or images that may matter later. Describe their literal form first.
- `scenes`: discrete settings or actions that group figures, symbols, and observations.
- `candidate_motifs`: possible motif labels derived from the evidence. Treat these as provisional.
- `comparison_claims`: explicit comparisons to other motifs, texts, artifacts, traditions, or patterns. Claims must state their level and link evidence.
- `evidence`: reusable evidence units. Use quotes only when allowed; otherwise use neutral summaries or citations.
- `reviewer_status`: workflow state for human review.

## Claim Discipline

Use the weakest claim level that fits the evidence:

- `same_motif`: recognizable shared form.
- `same_function`: similar role or effect, even if the form differs.
- `historical_contact`: supported contact, transmission, translation, trade, conquest, migration, or shared ritual space.
- `common_inheritance`: possible descent from an older shared source.
- `independent_recurrence`: plausible recurrence from common human experience.
- `archetypal_reading`: interpretive psychological or symbolic reading.
- `visual_similarity`: similar appearance without stronger narrative or historical claim.
- `linguistic_similarity`: similarity in terms, names, or phrasing.

If a claim needs external context, add that context as its own evidence item and link it from `comparison_claims[].evidence_refs`.
