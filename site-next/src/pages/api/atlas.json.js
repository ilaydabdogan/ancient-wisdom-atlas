/** /api/atlas.json — machine-readable summary of the atlas. */
import {
  corpusOverview,
  corpusStats,
  motifIndex,
  isolatedPredictionTest,
  textRecords,
} from '../../lib/atlas.js';

const REPO = 'https://github.com/ilaydabdogan/ancient-wisdom-atlas';
const RAW = 'https://raw.githubusercontent.com/ilaydabdogan/ancient-wisdom-atlas/main';

export function GET() {
  const corpus = corpusOverview();
  const stats = corpusStats();
  const index = motifIndex();
  const iso = isolatedPredictionTest();
  const body = {
    name: 'Ancient Wisdom Atlas',
    generated_at: new Date().toISOString().replace(/\.\d+Z$/, 'Z'),
    counts: {
      texts: textRecords().length,
      traditions: corpus.traditionCount,
      motifs: index.motif_count,
      occurrences: index.occurrence_count,
      canonical_families: stats.canonicalFamilyCount,
    },
    preregistered_isolated_lineage_test: {
      reproduction_rate: iso.result?.reproduction_rate ?? null,
      null_mean: iso.result?.null_mean ?? null,
      permutations_beaten: iso.result?.permutations_beaten ?? null,
      verdict: iso.result?.verdict ?? null,
    },
    site: {
      findings: '/findings/',
      descent: '/descent/',
      motifs: '/motifs/{motif-id}/',
      reading: '/read/{text-slug}/',
      currents: '/currents/',
      letters: '/letters/',
      lab: '/lab/',
      texts_catalog: '/api/texts.json',
    },
    data: {
      repository: REPO,
      motif_occurrences: `${RAW}/data/indexes/motif-occurrences.yml`,
      canonical_families: `${RAW}/data/indexes/canonical-motif-frequency.yml`,
      replication_agreement: `${RAW}/data/indexes/replication-agreement.yml`,
      isolated_prediction_test: `${RAW}/data/indexes/isolated-prediction-test.yml`,
      extraction_schema: `${RAW}/schemas/extraction.schema.json`,
    },
  };
  return new Response(JSON.stringify(body, null, 2), {
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
