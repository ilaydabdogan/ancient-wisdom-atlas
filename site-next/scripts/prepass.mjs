#!/usr/bin/env node
/**
 * Build prepass for the Ancient Wisdom Atlas site.
 *
 * 1. Streams data/indexes/motif-occurrences.yml (~110 MB) without ever
 *    holding the parsed document in memory, splitting it into one small
 *    JSON file per motif under site-next/.cache/motifs/.
 * 2. Scans extractions/**\/*.yml for passage_locator.start line hints so
 *    motif pages can deep-link into the reading pages (/read/…#l-N).
 *
 * The cache is stamped with the source file's mtime; unchanged sources
 * skip the work so incremental builds stay fast.
 */
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SITE = path.resolve(HERE, '..');
const ROOT = path.resolve(SITE, '..');
const CACHE = path.join(SITE, '.cache');
const MOTIF_CACHE = path.join(CACHE, 'motifs');
const OCCURRENCES = path.join(ROOT, 'data', 'indexes', 'motif-occurrences.yml');
const EXTRACTIONS = path.join(ROOT, 'extractions');

function slugify(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

function stampPath(name) {
  return path.join(CACHE, `${name}.stamp`);
}

function isFresh(name, sourceMtimeMs) {
  try {
    return fs.readFileSync(stampPath(name), 'utf8') === String(sourceMtimeMs);
  } catch {
    return false;
  }
}

function writeStamp(name, sourceMtimeMs) {
  fs.writeFileSync(stampPath(name), String(sourceMtimeMs));
}

/* ------------------------------------------------------------------ */
/* 1. Split motif-occurrences.yml into per-motif JSON                  */
/* ------------------------------------------------------------------ */

function trimOccurrence(occ) {
  const ev = Array.isArray(occ.evidence) && occ.evidence.length > 0 ? occ.evidence[0] : null;
  return {
    record_id: occ.record_id ?? null,
    extraction_path: occ.extraction_path ?? null,
    source_text_path: occ.source_text_path ?? null,
    source_title: occ.source_title ?? null,
    tradition: occ.tradition ?? null,
    passage_locator: typeof occ.passage_locator === 'object' && occ.passage_locator !== null
      ? (occ.passage_locator.label ?? null)
      : (occ.passage_locator ?? null),
    basis: occ.basis ?? null,
    confidence: occ.confidence ?? null,
    quote: ev ? (ev.quote_or_summary ?? null) : null,
  };
}

async function splitOccurrences() {
  const mtime = fs.statSync(OCCURRENCES).mtimeMs;
  if (isFresh('motifs', mtime) && fs.existsSync(path.join(CACHE, 'motif-index.json'))) {
    console.log('[prepass] motif cache fresh — skipping split');
    return;
  }
  fs.rmSync(MOTIF_CACHE, { recursive: true, force: true });
  fs.mkdirSync(MOTIF_CACHE, { recursive: true });

  const index = [];
  const usedSlugs = new Map();
  let header = [];
  let chunk = null;
  let inMotifs = false;
  let count = 0;

  const flush = () => {
    if (!chunk) return;
    const doc = yaml.load(chunk.join('\n'));
    const motif = Array.isArray(doc) ? doc[0] : null;
    chunk = null;
    if (!motif || !motif.motif_id) return;
    let slug = slugify(motif.motif_id);
    if (usedSlugs.has(slug)) {
      let n = 2;
      while (usedSlugs.has(`${slug}-${n}`)) n += 1;
      slug = `${slug}-${n}`;
    }
    usedSlugs.set(slug, motif.motif_id);
    const occurrences = (motif.occurrences ?? []).map(trimOccurrence);
    const traditions = motif.traditions ?? {};
    fs.writeFileSync(
      path.join(MOTIF_CACHE, `${slug}.json`),
      JSON.stringify({
        motif_id: motif.motif_id,
        slug,
        label: motif.label ?? motif.motif_id,
        traditions,
        occurrences,
      }),
    );
    index.push({
      id: motif.motif_id,
      slug,
      label: motif.label ?? motif.motif_id,
      occurrenceCount: occurrences.length,
      traditionCount: Object.keys(traditions).length,
    });
    count += 1;
    if (count % 5000 === 0) console.log(`[prepass] split ${count} motifs…`);
  };

  const rl = readline.createInterface({
    input: fs.createReadStream(OCCURRENCES, { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });
  for await (const line of rl) {
    if (!inMotifs) {
      if (line === 'motifs:') {
        inMotifs = true;
      } else {
        header.push(line);
      }
      continue;
    }
    if (line.startsWith('- motif_id:')) {
      flush();
      chunk = [line];
    } else if (chunk && (line.startsWith(' ') || line.startsWith('-') || line === '')) {
      chunk.push(line);
    } else if (chunk) {
      // A new top-level key after the motifs list: stop collecting.
      flush();
      inMotifs = false;
    }
  }
  flush();

  const meta = yaml.load(header.join('\n')) ?? {};
  fs.writeFileSync(
    path.join(CACHE, 'motif-index.json'),
    JSON.stringify({
      generated_on: meta.generated_on ?? null,
      motif_count: meta.motif_count ?? count,
      occurrence_count: meta.occurrence_count ?? null,
      motifs: index,
    }),
  );
  writeStamp('motifs', mtime);
  console.log(`[prepass] wrote ${count} per-motif JSON files`);
}

/* ------------------------------------------------------------------ */
/* 2. Extraction start-line hints                                      */
/* ------------------------------------------------------------------ */

function* walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(full);
    else if (entry.isFile() && /\.ya?ml$/.test(entry.name)) yield full;
  }
}

function startLineFrom(raw) {
  const at = raw.indexOf('passage_locator:');
  if (at === -1) return null;
  const block = raw.slice(at, at + 800);
  const lines = block.split('\n').slice(1);
  for (const line of lines) {
    if (!line.startsWith('  ')) break; // left the locator mapping
    const m = line.match(/^\s{2}start:\s*['"]?(\d+)['"]?\s*$/);
    if (m) return Number(m[1]);
  }
  return null;
}

function harvestExtractionStarts() {
  const outPath = path.join(CACHE, 'extraction-starts.json');
  // Freshness: newest mtime among extraction dirs is expensive to compute
  // perfectly; use dir count + newest top-level mtime as a cheap signature.
  let signature = 0;
  let fileCount = 0;
  const starts = {};
  for (const file of walk(EXTRACTIONS)) {
    fileCount += 1;
    signature = Math.max(signature, fs.statSync(file).mtimeMs);
  }
  const sig = `${fileCount}:${Math.round(signature)}`;
  try {
    if (fs.readFileSync(stampPath('starts'), 'utf8') === sig && fs.existsSync(outPath)) {
      console.log('[prepass] extraction-starts cache fresh — skipping');
      return;
    }
  } catch {}
  let found = 0;
  for (const file of walk(EXTRACTIONS)) {
    const rel = path.relative(ROOT, file);
    const raw = fs.readFileSync(file, 'utf8');
    const start = startLineFrom(raw);
    if (start !== null) {
      starts[rel] = start;
      found += 1;
    }
  }
  fs.writeFileSync(outPath, JSON.stringify(starts));
  fs.writeFileSync(stampPath('starts'), sig);
  console.log(`[prepass] ${found}/${fileCount} extractions carry a start-line hint`);
}

fs.mkdirSync(CACHE, { recursive: true });
await splitOccurrences();
harvestExtractionStarts();
console.log('[prepass] done');
