# Preregistration: The Crown Experiment — Independent Taxonomy Structure Test

Registered 2026-07-18, committed to git before any result was computed.
Supersedes the assimilation-vulnerable step of the first isolated-lineage
test (docs/prereg-isolated-lineage-test.md) by removing the shared,
Eurasian-derived family taxonomy from the pipeline entirely.

## The question
Does the co-occurrence structure of motifs among maximally isolated
peoples match the structure among the connected Eurasian corpus, when
BOTH taxonomies are built independently and blind (never using the
project's 64 hand/evidence-curated families)?

## Why this is stronger than the first test
The first test mapped isolated-lineage raw motifs INTO the Eurasian
family taxonomy using a family-aware model. That risks "assimilation":
the mapper forcing isolated motifs into Eurasian boxes, manufacturing
convergence. Its novelty tripwire fired for this reason. This experiment
never maps into the Eurasian taxonomy at all.

## Design
1. SPLIT (raw labels only, family assignments discarded):
   - ISOLATED pile: extraction records from isolated-lineage traditions
     (australian-aboriginal, indigenous-australian, inuit,
     khoisan-south-african, san, zulu, siberian, guiana-amerindian,
     amazonian, andamanese, maya, mesoamerican, nahua, nahua-maya-inca,
     navajo, zuni, hopi, hawaiian, tsimshian, and native-american-*).
   - CONNECTED pile: all other traditions except `comparative`.
2. EMBED every distinct raw motif label (both piles) into a fixed
   embedding space (text-embedding-3-large, 512-d).
3. BLIND CLUSTER each pile independently with the SAME algorithm
   (agglomerative / community detection on the cosine-similarity graph),
   choosing cluster count data-drivenly (report sensitivity over a range).
   Neither clustering may see the other pile or the 64 Eurasian families.
4. BUILD a per-pile co-occurrence web: nodes = that pile's blind clusters;
   an edge when two clusters co-occur within passages across >= N
   traditions of that pile (PMI > 0).
5. PRIMARY TEST (alignment + null):
   - Align each isolated cluster to its nearest connected cluster by
     centroid cosine similarity (a semantic, not human-taxonomic, map).
   - For every pair of isolated clusters, compare its edge weight to the
     edge weight of the aligned connected-cluster pair. Metric = rank
     correlation (Spearman) of edge weights across aligned pairs.
   - NULL: permute the isolated->connected alignment 500 times; the
     observed correlation must exceed the 97.5th percentile of the null.
6. BACKUP TEST (label-free, fully assimilation-immune):
   - Compare global topology of the two webs: connectedness, degree
     distribution (KS test), clustering coefficient, modularity. Report
     whether they are the same KIND of structure independent of any
     node correspondence.

## Success criteria (frozen)
- STRONG: primary rank correlation beats all/97.5% of 500 permutations
  AND backup topology metrics are statistically indistinguishable.
- PARTIAL: primary passes but topology differs, or vice versa.
- NULL: primary correlation sits inside the permutation distribution.
All three outcomes will be published on the Findings page in plain
language, whatever they are.

## Leakage controls / honest limitations (stated before running)
- The alignment step (5) uses embeddings, which encode broad
  cross-cultural semantics and are therefore NOT perfectly blind. The
  label-free backup (6) exists precisely because of this; a claim of
  STRONG support requires BOTH to agree.
- Cluster-count sensitivity: rerun primary across several cluster
  granularities; a result that only holds at one granularity is reported
  as fragile.
- Collector/translation mediation persists in the isolated corpus; a
  hard-core subset (verbatim-recorded: inuit, siberian, san,
  native-american-northwest-coast, andamanese) is run separately.
- The connected clustering is the control: if blind clustering of the
  connected pile fails to reproduce known Eurasian structure, the method
  is underpowered and no isolated claim is made.

## Analysis code
scripts/build_crown_independent_taxonomy.rb (to this spec; deviations
documented in the introducing commit).
