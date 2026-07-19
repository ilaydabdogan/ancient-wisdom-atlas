#!/bin/sh
# Canonical regeneration of every AUTO-COMPUTED index the website reads, in
# dependency order. Run after any corpus/extraction/mapping change so no
# site-read index can go stale. (Review-gated sources — cultural-timeline,
# sub-family bins, crown — are refreshed by their own review pipelines.)
set -e
cd "$(dirname "$0")/.."
ruby scripts/build_extraction_coverage.rb
ruby scripts/build_similarity_index.rb          # -> motif-occurrences.yml
ruby scripts/audit_normalization_gaps.rb
ruby scripts/build_canonical_motif_frequency.rb
ruby scripts/build_motif_era_flow.rb
ruby scripts/build_motif_constellations.rb --force
ruby scripts/build_null_model.rb
ruby scripts/build_motif_sequence_index.rb --force
ruby scripts/build_isolated_prediction_test.rb
ruby scripts/build_consensus_index.rb --run motif-extraction-2026-07-17-azure-wave1 --run replication-gpt54-2026-07-17 --run replication-gpt56terra-2026-07-17 --run replication-gpt51-2026-07-17 --run replication-gpt56luna-2026-07-18 || true
ruby scripts/build_replication_agreement.rb --run-id motif-extraction-2026-07-17-azure-wave1 --run-id replication-gpt54-2026-07-17 --run-id replication-gpt56terra-2026-07-17 --run-id replication-gpt51-2026-07-17 || true
echo "REGEN-DONE"
