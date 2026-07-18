# Preregistration: Isolated-Lineage Prediction Test

Registered: 2026-07-18, committed to git before any holdout analysis was run.

## Hypothesis
Motif-family co-occurrence structure derived exclusively from the
connected Eurasian corpus predicts co-occurrence structure in maximally
isolated lineages (Australian Aboriginal, Inuit/Arctic, Siberian,
Khoisan/San, Zulu, Melanesian, Guiana Amerindian, and other traditions
with no plausible pre-modern contact with the Eurasian corpus) beyond
chance expectation.

## Design
1. TRAINING SET: all extraction records from connected-lineage texts.
   Derive the top-K conserved edges (K = all edges independently
   significant in >= 4 connected traditions; PMI > 0, pair count >= 3
   per tradition — the thresholds already in build_motif_constellations).
2. HOLDOUT: extraction records from isolated-lineage texts ONLY.
   The holdout is never used for edge derivation or family definition
   tuning.
3. METRIC (primary): reproduction rate = fraction of training edges that
   are positively associated in the holdout (PMI > 0, pair count >= 2
   across >= 2 isolated lineages), compared against the distribution of
   that rate under 200 within-lineage permutations of the holdout
   (preserving per-record family-set sizes and per-lineage family
   frequencies).
4. SUCCESS CRITERION: reproduction rate exceeds all 200 permutation
   rates (empirical p < 0.005) AND lift (observed/null-mean) >= 1.15.
   WEAK SUPPORT: exceeds >= 190/200 with lift >= 1.05. FAILURE: anything
   less. All three outcomes will be published on the Findings page.
5. LEAKAGE CONTROLS (report alongside, whatever they show):
   a. Novelty rate: fraction of holdout-significant edges absent from
      the training set. If < 10%, flag probable mapping leakage and do
      not claim success regardless of the primary metric.
   b. Hard-core subset: repeat the primary metric on verbatim-recorded
      corpora only (Bleek & Lloyd, Bogoras Koryak texts, Rasmussen).
   c. Collector stratification: reproduction rate per collector; a
      single collector driving the result invalidates generalization.
6. MAPPING DISCIPLINE: isolated-lineage raw motifs map to canonical
   families through the standard normalization-suggestion pipeline with
   review; the mapper prompt must not be altered in response to interim
   holdout results.

## What would falsify the deeper claim
If the reproduction rate sits inside the permutation distribution, the
conserved Eurasian web is better explained by inheritance, contact, or
shared genre convention than by species-wide patterning, and the
Findings page will say so in plain language.

## Analysis code
scripts/build_isolated_prediction_test.rb (to be written to this spec;
any deviation from this spec must be documented in the commit that
introduces it, with reasons).
