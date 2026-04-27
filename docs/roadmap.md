# Roadmap

## Phase 1: Foundation

Goal: make the repo trustworthy before it becomes large.

- define source metadata
- define motif and pattern templates
- record rights status for every source
- start with a small number of high-value pattern notes
- keep modern copyrighted thinkers in citation-and-summary form

Suggested first patterns:

- Divine Mother and Holy Child: started
- Descent Into The Underworld: started
- Flood And Renewal: started
- Death And Return: started
- Sacred Tree / Axis Mundi: started
- Trickster At The Boundary: started
- Miraculous Birth: started
- Sacred Twins: started
- Serpent Of Wisdom Or Chaos: started
- Hero Leaves Home And Returns Transformed: started
- Sacrifice And Covenant: started

## Phase 2: Corpus Buildout

Goal: collect rights-cleared primary material.

Priority source families:

- public-domain sacred texts and translations
- public-domain mythology collections
- open classics corpora
- folklore motif indexes
- public-domain ethnographic and anthropological collections
- open metadata from museums and libraries

Each imported work should become:

- one `work` note
- many extracted motif notes
- source-level rights metadata
- citation trail back to edition and translator

## Phase 3: AI Extraction

Goal: use models to speed annotation while preserving human auditability.

For each source:

1. Chunk the text by chapter, hymn, passage, scene, or artifact.
2. Extract figures, kinship, objects, places, rituals, actions, motifs, and claims.
3. Ask a second model pass to critique overreach.
4. Store uncertain claims as hypotheses, not facts.
5. Keep direct quotes short unless rights explicitly allow full reuse.

## Phase 4: Pattern Atlas

Goal: move from collection to discovery.

Build pattern pages that compare:

- motif similarity
- narrative function
- ritual or theological function
- date span
- geography
- likely transmission routes
- archetypal interpretation
- objections and disconfirming evidence

## Phase 5: Machine Exports

Goal: make the repo usable for retrieval, graph analysis, and training.

Planned exports:

- `exports/atlas.jsonl` for model ingestion
- `exports/sources.jsonl` for provenance and rights
- `exports/motifs.jsonl` for retrieval
- `exports/claims.jsonl` for comparison and graph edges
- graph format for Neo4j, RDF, or network analysis

The first JSONL exporter lives at `scripts/export_jsonl.rb`.

## Phase 6: Research Questions

Examples:

- Which motifs appear independently across geographically separated cultures?
- Which mother-child images are royal, salvific, devotional, or domestic?
- Which motifs intensify during empire, migration, collapse, or religious transition?
- Which symbols cluster around death and rebirth?
- Which motifs have strong historical transmission evidence versus archetypal recurrence?
