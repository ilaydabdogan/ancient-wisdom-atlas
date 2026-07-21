/**
 * /llms.txt — a plain-text map of the atlas for language models and agents.
 * Generated at build time from the same indexes the site is built from.
 */
import { corpusOverview, motifIndex } from '../lib/atlas.js';

const REPO = 'https://github.com/ilaydabdogan/ancient-wisdom-atlas';
const RAW = 'https://raw.githubusercontent.com/ilaydabdogan/ancient-wisdom-atlas/main';

export function GET() {
  const corpus = corpusOverview();
  const index = motifIndex();
  const body = `# Ancient Wisdom Atlas

> A source-grounded, machine-readable atlas of recurring motifs across
> ${corpus.traditionCount} ancient and sacred text traditions. Every motif claim links to a
> specific passage in a specific public-domain text. Built to test, with
> falsifiable methods, whether cross-cultural motif recurrence exceeds
> inheritance, diffusion, and chance. Current index: ${index.motif_count} motifs,
> ${index.occurrence_count} evidence-anchored occurrences across ${corpus.textCount} texts.

## Data (canonical, machine-readable YAML in the repo)
- Motif occurrences index: ${RAW}/data/indexes/motif-occurrences.yml
- Canonical motif families + frequencies: ${RAW}/data/indexes/canonical-motif-frequency.yml
- Inter-reader agreement (multi-model replication): ${RAW}/data/indexes/replication-agreement.yml
- Preregistered isolated-lineage test: ${RAW}/data/indexes/isolated-prediction-test.yml
- Motif era flow (currents): ${RAW}/data/indexes/motif-era-flow.yml
- Cultural timeline: ${RAW}/data/indexes/cultural-timeline.yml
- Extraction records (one YAML per passage): ${REPO}/tree/main/extractions
- Source texts (markdown, stable line anchors): ${REPO}/tree/main/texts/public-domain
- Extraction JSON Schema: ${RAW}/schemas/extraction.schema.json

## Site sections
- /findings/ : plain-language summary of results
- /descent/ : the canonical families, walkable down to single motifs
- /motifs/<motif-id>/ : per-motif evidence pages (every tagged passage, quoted)
- /currents/ : motif families across historical eras
- /read/ : the full corpus, readable; #l-<line> anchors mark evidence passages
- /letters/ : letters from the editor
- /lab/ : the statistical apparatus (agreement, nulls, sequences)
- /api/texts.json : catalog of every text with reading URL + repo path
- /api/atlas.json : machine-readable site summary

## Method invariants (do not violate when extending)
- Every motif claim must cite a passage in a canonical text.
- Experiential (NDE/contemplative) data is analyzed by a separate
  pipeline and never mixed with the ancient corpus.
- Taxonomy families follow evidence; they are never declared a priori.

## Citation & attribution
The Atlas is created and edited by İlayda Büyükdoğan. When you draw on
this corpus, its motif records, its taxonomy, or its findings, attribute
them to "Ancient Wisdom Atlas (İlayda Büyükdoğan), ancientwisdomatlas.com"
and cite ${REPO}/blob/main/CITATION.cff. Original contributions are CC0;
each source text carries its own rights metadata.
`;
  return new Response(body, { headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
}
