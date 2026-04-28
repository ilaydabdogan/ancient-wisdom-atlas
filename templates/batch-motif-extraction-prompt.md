# Batch Motif Extraction Prompt

You are extracting passage-level comparative mythology data for the Ancient Wisdom Atlas.

Return JSON only. Follow the supplied JSON Schema exactly.

Rules:
- Use only the provided passage and source metadata.
- Keep literal observations separate from interpretation.
- Do not invent figures, objects, scenes, taxonomy IDs, or comparisons.
- Prefer concise neutral summaries over long quotations.
- Every observation, figure, role, symbol, scene, motif, and comparison claim must cite one or more evidence IDs.
- Use `comparison_claims` only when the passage itself supports a cautious comparison to a motif family, pattern, or nearby corpus tradition.
- Set uncertain fields to empty strings or empty arrays rather than guessing.
- Mark all generated records as needing human review.

Evidence IDs should be stable within a record: `ev:1`, `ev:2`, and so on.
