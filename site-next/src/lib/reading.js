/**
 * Reading-page helpers: paragraph chunking with stable file-line anchors,
 * plus a small front-matter flattener for the folded metadata panel.
 *
 * Anchors are `l-<file line number>` where the number is the 1-based line
 * in the repo markdown file (front matter included), so extraction records
 * that carry passage_locator.start deep-link straight into the book.
 */
import { marked } from 'marked';
import { parseTextFile } from './atlas.js';

marked.setOptions({ gfm: true, breaks: false });

/**
 * Split a text's body into renderable chunks of consecutive non-blank
 * lines. Each chunk carries the 1-based file line of its first line.
 */
export function readingChunks(fullPath) {
  const { lines, bodyStart } = parseTextFile(fullPath);
  const chunks = [];
  let current = null;
  for (let i = bodyStart; i < lines.length; i += 1) {
    const line = lines[i];
    if (line.trim() === '') {
      if (current) {
        chunks.push(current);
        current = null;
      }
    } else {
      if (!current) current = { line: i + 1, text: [] };
      current.text.push(line);
    }
  }
  if (current) chunks.push(current);
  return chunks.map((c) => ({ line: c.line, html: marked.parse(c.text.join('\n')) }));
}

/** Render a standalone markdown string (letters, notes). */
export function renderMarkdown(text) {
  return marked.parse(text);
}

const META_SKIP = new Set(['title']);

/**
 * Flatten front matter into [label, value] pairs for a definition list.
 * Nested maps become `parent · child` labels; arrays of scalars join.
 */
export function flattenMeta(metadata, prefix = '') {
  const rows = [];
  for (const [key, value] of Object.entries(metadata ?? {})) {
    if (!prefix && META_SKIP.has(key)) continue;
    const label = prefix ? `${prefix} · ${key.replace(/_/g, ' ')}` : key.replace(/_/g, ' ');
    if (value === null || value === undefined) continue;
    if (Array.isArray(value)) {
      if (value.every((v) => typeof v !== 'object')) {
        rows.push([label, value.join(', ')]);
      } else {
        value.forEach((v, i) => rows.push(...flattenMeta(v, `${label} ${i + 1}`)));
      }
    } else if (typeof value === 'object' && !(value instanceof Date)) {
      rows.push(...flattenMeta(value, label));
    } else {
      const text = value instanceof Date ? value.toISOString().slice(0, 10) : String(value);
      if (text.trim() !== '') rows.push([label, text]);
    }
  }
  return rows;
}

export function fmtDate(value) {
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return value ? String(value) : null;
}
