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

export function crownExperiment() {
  return loadYaml('indexes/crown-independent-taxonomy.yml');
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

/**
 * Recurring ordered chains from the sequences index, as stored (the index
 * ranks them by tradition spread, then text count). Pass a limit to take
 * the head of the ledger.
 */
export function recurringSequences(limit = null) {
  const doc = loadYaml('indexes/motif-sequences.yml');
  const list = doc.recurring_sequences ?? [];
  return typeof limit === 'number' ? list.slice(0, limit) : list;
}

/** Look up one recurring ordered chain by its exact sequence string. */
export function recurringSequenceByString(sequence) {
  return recurringSequences().find((r) => r.sequence === sequence) ?? null;
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

/** Link to this site's motif evidence pages. */
export function motifUrl(motifId) {
  const slug = motifSlugById().get(motifId) ?? slugify(motifId);
  return `/motifs/${slug}/`;
}

/* ------------------------------------------------------------------ */
/* Source texts (the readable corpus)                                  */
/* ------------------------------------------------------------------ */

const TEXTS_DIR = path.join(REPO_ROOT, 'texts', 'public-domain');

function* walkFiles(dir, ext) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) yield* walkFiles(full, ext);
    else if (entry.isFile() && entry.name.endsWith(ext)) yield full;
  }
}

/**
 * Split a markdown file into front matter + body, tracking the 1-based
 * file line on which each body line sits so reading anchors (#l-N) match
 * the line numbers extraction records point at.
 */
export function parseTextFile(fullPath) {
  const raw = fs.readFileSync(fullPath, 'utf8');
  const lines = raw.split('\n');
  let metadata = {};
  let bodyStart = 0; // 0-based index into `lines` where the body begins
  if (lines[0] === '---') {
    const close = lines.findIndex((l, i) => i > 0 && /^---\s*$/.test(l));
    if (close > 0) {
      try {
        metadata = yaml.load(lines.slice(1, close).join('\n')) ?? {};
      } catch {
        metadata = {};
      }
      bodyStart = close + 1;
    }
  }
  return { metadata, lines, bodyStart };
}

/**
 * Every public-domain text, with a stable slug derived from its repo path
 * (texts/public-domain/<tradition>/<source>/<name>.md → tradition-source-name).
 */
export function textRecords() {
  const key = '__texts__';
  if (cache.has(key)) return cache.get(key);
  const list = [];
  const seen = new Set();
  for (const full of walkFiles(TEXTS_DIR, '.md')) {
    const rel = path.relative(TEXTS_DIR, full);
    const repoPath = path.relative(REPO_ROOT, full);
    let slug = slugify(rel.replace(/\.md$/, ''));
    if (seen.has(slug)) {
      let n = 2;
      while (seen.has(`${slug}-${n}`)) n += 1;
      slug = `${slug}-${n}`;
    }
    seen.add(slug);
    const { metadata } = parseTextFile(full);
    list.push({
      slug,
      repoPath,
      fullPath: full,
      title: metadata.title ?? path.basename(rel, '.md'),
      tradition: metadata.tradition ?? null,
      translator: metadata?.provenance?.translator ?? null,
      metadata,
    });
  }
  cache.set(key, list);
  return list;
}

/** Map repo path (texts/public-domain/…md) → text record. */
export function textByRepoPath() {
  const key = '__texts_by_path__';
  if (cache.has(key)) return cache.get(key);
  const map = new Map(textRecords().map((t) => [t.repoPath, t]));
  cache.set(key, map);
  return map;
}

/* ------------------------------------------------------------------ */
/* Motif cache (written by scripts/prepass.mjs)                        */
/* ------------------------------------------------------------------ */

const CACHE_DIR = path.resolve(HERE, '..', '..', '.cache');

/** The prepass motif index: { motif_count, occurrence_count, motifs: [...] }. */
export function motifIndex() {
  const key = '__motif_index__';
  if (cache.has(key)) return cache.get(key);
  const doc = JSON.parse(fs.readFileSync(path.join(CACHE_DIR, 'motif-index.json'), 'utf8'));
  cache.set(key, doc);
  return doc;
}

/** Full per-motif data (occurrence rows) for one motif slug. */
export function motifData(slug) {
  return JSON.parse(fs.readFileSync(path.join(CACHE_DIR, 'motifs', `${slug}.json`), 'utf8'));
}

/** Map extraction repo path → start line hint in its source text. */
export function extractionStarts() {
  const key = '__extraction_starts__';
  if (cache.has(key)) return cache.get(key);
  const doc = JSON.parse(fs.readFileSync(path.join(CACHE_DIR, 'extraction-starts.json'), 'utf8'));
  cache.set(key, doc);
  return doc;
}

/** Map motif id → slug from the prepass index. */
export function motifSlugById() {
  const key = '__motif_slug_by_id__';
  if (cache.has(key)) return cache.get(key);
  const map = new Map(motifIndex().motifs.map((m) => [m.id, m.slug]));
  cache.set(key, map);
  return map;
}

/**
 * Where each motif sits in the descent:
 * motif id → { familyId, familyLabel, subFamilyId, subFamilyLabel }.
 */
export function motifPlacement() {
  const key = '__motif_placement__';
  if (cache.has(key)) return cache.get(key);
  const map = new Map();
  const bins = subFamilyBinsByFamily();
  for (const family of families()) {
    const bin = bins.get(family.id);
    const subByChild = new Map();
    if (bin) {
      for (const sf of bin.sub_families ?? []) {
        for (const child of sf.children ?? []) {
          subByChild.set(child, sf);
        }
      }
    }
    for (const m of family.mappedMotifs) {
      if (map.has(m.motif_id)) continue; // first (widest-reach) family wins
      const sf = subByChild.get(m.motif_id) ?? null;
      map.set(m.motif_id, {
        familyId: family.id,
        familyLabel: family.label,
        subFamilyId: sf?.id ?? null,
        subFamilyLabel: sf?.label ?? null,
      });
    }
  }
  cache.set(key, map);
  return map;
}

/**
 * The read-in-the-book link for an occurrence row, or null when its source
 * text is not part of the public corpus.
 */
export function occurrenceReadLink(occ) {
  const text = occ.source_text_path ? textByRepoPath().get(occ.source_text_path) : null;
  if (!text) return null;
  const start = occ.extraction_path ? extractionStarts()[occ.extraction_path] : undefined;
  return typeof start === 'number' ? `/read/${text.slug}/#l-${start}` : `/read/${text.slug}/`;
}

/* ------------------------------------------------------------------ */
/* Single extraction records (for the walkthrough)                     */
/* ------------------------------------------------------------------ */

/**
 * Load one extraction YAML by its repo-relative path
 * (e.g. `extractions/mesoamerican/.../record.yml`). Used by the /how/
 * explainer so its worked example is read from the real record at build
 * time — quote, motif labels, and taxonomy refs are never retyped.
 */
export function extractionRecord(repoRelPath) {
  const full = path.join(REPO_ROOT, repoRelPath);
  return yaml.load(fs.readFileSync(full, 'utf8'));
}

/* ------------------------------------------------------------------ */
/* Letters                                                             */
/* ------------------------------------------------------------------ */

export function letters() {
  const key = '__letters__';
  if (cache.has(key)) return cache.get(key);
  const dir = path.join(REPO_ROOT, 'letters');
  const list = [];
  if (fs.existsSync(dir)) {
    for (const full of walkFiles(dir, '.md')) {
      const { metadata, lines, bodyStart } = parseTextFile(full);
      list.push({
        slug: slugify(path.basename(full, '.md')),
        title: metadata.title ?? path.basename(full, '.md'),
        number: metadata.letter ?? null,
        date: metadata.date ?? null,
        author: metadata.author ?? null,
        writtenWith: metadata.written_with ?? null,
        body: lines.slice(bodyStart).join('\n').trim(),
      });
    }
  }
  list.sort((a, b) => (a.number ?? 999) - (b.number ?? 999));
  cache.set(key, list);
  return list;
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
