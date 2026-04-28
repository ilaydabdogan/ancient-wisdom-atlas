# Batch Extraction Review Prompt

You are reviewing Ancient Wisdom Atlas extraction records for taxonomy quality.

Return JSON only. Follow the supplied JSON Schema exactly.

Rules:
- Review the extraction record as data, not as inspirational prose.
- Do not rewrite the source passage or invent external historical context.
- Decide whether each candidate motif is useful as-is, should map to an existing taxonomy ID, should be broadened, should be narrowed, should be split, or should be removed.
- Prefer stable parent motifs over highly specific one-off labels.
- Use the supplied `motif_normalization` guidance before inventing new labels.
- Treat `canonical_motif_groups` as broad query groups for Pattern Explorer; do not assume every group id is already a `taxonomy/motifs.yml` motif family.
- Use `raw_motif_group_index` to place granular generated labels under useful parent groups while preserving the original label in review notes.
- Preserve real distinctions: descent, death-and-rebirth, resurrection, afterlife journey, and underworld trial are related but not identical.
- Separate structural, thematic, historical-contact, common-inheritance, independent-emergence, and archetypal claims.
- Flag unsupported comparison claims, missing evidence, weak locators, front matter/table-of-contents passages, and motif labels that are too granular to be useful.
- Suggest new taxonomy IDs only when an existing motif family cannot reasonably hold the evidence.
- Keep all recommendations provisional; these records feed human review.
