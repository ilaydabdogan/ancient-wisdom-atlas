# Extraction Prompt

Use this prompt when asking an AI model to extract structured wisdom data from a rights-cleared source.

```text
You are extracting comparative mythology data from a source text.

Rules:
- Do not invent details not present in the source.
- Separate source observation from interpretation.
- Preserve names, epithets, kinship relations, objects, places, rituals, and narrative actions.
- Identify motifs using plain labels first; add formal motif index IDs only if known.
- Mark confidence for every comparison.
- If the input is copyrighted or license status is unknown, produce summaries and citations only.

Return Markdown with YAML front matter:

id:
source_id:
tradition:
date_range:
language:
rights:
  status:
  training_use:
figures:
motifs:
symbols:
relationships:
scenes:
claims:
  - claim:
    evidence:
    confidence:
```

