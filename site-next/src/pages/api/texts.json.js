/** /api/texts.json — every corpus text mapped to its reading URL and repo path. */
import { textRecords, humanize } from '../../lib/atlas.js';

export function GET() {
  const texts = textRecords();
  const body = {
    generated_at: new Date().toISOString().replace(/\.\d+Z$/, 'Z'),
    count: texts.length,
    texts: texts.map((t) => ({
      title: t.title,
      tradition: t.tradition,
      tradition_label: t.tradition ? humanize(t.tradition) : null,
      translator: t.translator,
      repo_path: t.repoPath,
      html: `/read/${t.slug}/`,
    })),
  };
  return new Response(JSON.stringify(body, null, 2), {
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
