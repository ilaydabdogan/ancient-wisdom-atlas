/**
 * Build-time data loader for the Ancient Wisdom Atlas.
 *
 * Everything the site displays flows from the repo's YAML indexes under
 * ../data — no statistic, family list, sub-family layer, or edge list is
 * hardcoded here. Rebuild the site and it follows the data.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';

const HERE = path.dirname(fileURLToPath(import.meta.url));
// site-next/src/lib -> repo root
const REPO_ROOT = path.resolve(HERE, '..', '..', '..');
const DATA = path.join(REPO_ROOT, 'data');

const cache = new Map();

function loadYaml(relPath) {
  if (cache.has(relPath)) return cache.get(relPath);
  const full = path.join(DATA, relPath);
  const doc = yaml.load(fs.readFileSync(full, 'utf8'));
  cache.set(relPath, doc);
  return doc;
}

/* ------------------------------------------------------------------ */
/* Canonical families                                                  */
/* ------------------------------------------------------------------ */

export function canonicalFrequency() {
  return loadYaml('indexes/canonical-motif-frequency.yml');
}

/** All non-meta canonical families, enriched with totals, sorted by reach. */
export function families() {
  const key = '__families__';
  if (cache.has(key)) return cache.get(key);
  const doc = canonicalFrequency();
  const bins = subFamilyBinsByFamily();
  const constellationSet = new Set(
    (constellations().constellations ?? []).flatMap((c) => c.families ?? []),
  );
  const list = (doc.canonical_motifs ?? [])
    .filter((m) => !m.is_meta_group)
    .map((m) => {
      const traditions = m.traditions ?? {};
      const traditionCount = Object.keys(traditions).length;
      const occurrenceTotal = Object.values(traditions).reduce((a, b) => a + b, 0);
      const bin = bins.get(m.canonical_motif_id) ?? null;
      return {
        id: m.canonical_motif_id,
        label: m.label,
        description: m.description ?? '',
        related: m.related ?? [],
        traditions,
        traditionCount,
        occurrenceTotal,
        mappedMotifs: m.mapped_motifs ?? [],
        subFamilies: bin ? bin.sub_families : null,
        inConstellation: constellationSet.has(m.canonical_motif_id),
      };
    })
    .sort((a, b) => b.traditionCount - a.traditionCount || b.occurrenceTotal - a.occurrenceTotal);
  cache.set(key, list);
  return list;
}

export function familyById(id) {
  return families().find((f) => f.id === id) ?? null;
}

/** Corpus-wide headline numbers derived from the frequency index. */
export function corpusStats() {
  const doc = canonicalFrequency();
  return {
    indexedMotifCount: doc.indexed_motif_count,
    indexedOccurrenceCount: doc.indexed_occurrence_count,
    canonicalFamilyCount: (doc.canonical_motifs ?? []).filter((m) => !m.is_meta_group).length,
    mappedMotifCount: doc.mapped_motif_count,
  };
}

/* ------------------------------------------------------------------ */
/* Sub-family bins                                                     */
/* ------------------------------------------------------------------ */

/** Map canonical family id -> parsed bin document (family, total_motifs, sub_families). */
export function subFamilyBinsByFamily() {
  const key = '__bins__';
  if (cache.has(key)) return cache.get(key);
  const dir = path.join(DATA, 'normalization');
  const map = new Map();
  for (const file of fs.readdirSync(dir)) {
    if (!file.startsWith('sub-family-bins-') || !file.endsWith('.yml')) continue;
    const doc = yaml.load(fs.readFileSync(path.join(dir, file), 'utf8'));
    if (!doc?.family || doc.family.startsWith('_')) continue; // skip meta bins
    map.set(doc.family, doc);
  }
  cache.set(key, map);
  return map;
}

/* ------------------------------------------------------------------ */
/* Constellation web                                                   */
/* ------------------------------------------------------------------ */

export function constellations() {
  return loadYaml('indexes/motif-constellations.yml');
}

export function nullModel() {
  return loadYaml('indexes/null-model.yml');
}

export function isolatedPredictionTest() {
  return loadYaml('indexes/isolated-prediction-test.yml');
}

export function replicationAgreement() {
  return loadYaml('indexes/replication-agreement.yml');
}

export function eraFlow() {
  return loadYaml('indexes/motif-era-flow.yml');
}

export function culturalTimeline() {
  return loadYaml('indexes/cultural-timeline.yml');
}

/* ------------------------------------------------------------------ */
/* Sequence grammar (falsification test)                               */
/* ------------------------------------------------------------------ */

/**
 * The sequence-grammar test: candidate strong precedence pairs and the
 * survivors after the permutation null (null_fraction_as_extreme <= alpha).
 * Loads only the summary + precedence_pairs sections of the (large)
 * sequences index.
 */
export function sequenceGrammar(alpha = 0.05) {
  const key = `__seq_${alpha}__`;
  if (cache.has(key)) return cache.get(key);
  const doc = loadYaml('indexes/motif-sequences.yml');
  const pairs = doc.precedence_pairs ?? [];
  const survivors = pairs.filter((p) => p.null_fraction_as_extreme <= alpha);
  const out = {
    candidateCount: pairs.length,
    strongPairCount: doc.summary?.strong_precedence_pairs ?? pairs.length,
    recurringSequences: doc.summary?.recurring_sequences,
    minTraditions: doc.summary?.min_traditions,
    survivors,
    pairs,
  };
  cache.set(key, out);
  return out;
}

/* ------------------------------------------------------------------ */
/* Corpus (texts + traditions)                                         */
/* ------------------------------------------------------------------ */

/**
 * Corpus overview from the extraction-coverage index.
 * `comparative` is a cross-tradition scholarly category, not a lineage,
 * so it is excluded from the tradition count.
 */
export function corpusOverview() {
  const key = '__corpus__';
  if (cache.has(key)) return cache.get(key);
  const doc = loadYaml('indexes/extraction-coverage.yml');
  const s = doc.summary ?? {};
  const traditions = new Map();
  for (const t of doc.texts ?? []) {
    if (!t.tradition || t.tradition === 'comparative') continue;
    traditions.set(t.tradition, (traditions.get(t.tradition) ?? 0) + 1);
  }
  const out = {
    textCount: s.text_count,
    textsWithExtractions: s.texts_with_extractions,
    extractionRecordCount: s.extraction_record_count,
    candidateMotifCount: s.candidate_motif_count,
    traditionCount: traditions.size,
    traditions: [...traditions.entries()]
      .map(([id, textCount]) => ({ id, textCount }))
      .sort((a, b) => b.textCount - a.textCount || a.id.localeCompare(b.id)),
  };
  cache.set(key, out);
  return out;
}

/** Earliest first attestation across families (from the era-flow index). */
export function earliestAttestation() {
  const doc = eraFlow();
  let best = null;
  for (const f of doc.families ?? []) {
    const fa = f.first_attestation;
    if (!fa || typeof fa.year !== 'number') continue;
    if (!best || fa.year < best.year) best = { ...fa, family: f.family, familyLabel: f.label };
  }
  return best;
}

/* ------------------------------------------------------------------ */
/* Formatting + linking helpers                                        */
/* ------------------------------------------------------------------ */

export function slugify(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

/** Link into the current live site's motif evidence pages. */
export function liveMotifUrl(motifId) {
  return `https://ancientwisdomatlas.com/motifs/${slugify(motifId)}.html`;
}

export function humanize(id) {
  return String(id).replace(/[_-]+/g, ' ');
}

export function fmtInt(n) {
  return typeof n === 'number' ? n.toLocaleString('en-US') : String(n ?? '—');
}

export function fmtPct(x, digits = 1) {
  return typeof x === 'number' ? `${(x * 100).toFixed(digits)}%` : '—';
}
