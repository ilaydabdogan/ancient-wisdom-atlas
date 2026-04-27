# Source Prioritization

This plan turns Wave A from a list of desired corpus units into a practical acquisition sequence. It is intentionally conservative: a source family is only a place to look, not a clearance decision. Every work still needs edition-level rights review before full-text ingestion.

The candidate inventory lives in `data/sources/wave-a-source-candidates.yml`.

## Operating Rules

- Prefer primary texts over modern interpretation.
- Prefer public-domain or clearly open texts before permissioned or ambiguous texts.
- Verify rights per work, translation, edition, platform, and metadata layer.
- Keep source text, translator notes, introductions, commentary, and platform metadata separate when rights differ.
- Record provenance before cleanup: source URL, scan URL when available, edition, translator, publication year, and access date.
- Use citation-only records when rights, license terms, or cultural permissions are not clear enough for full-text ingestion.

## Ingestion Order

### 1. Easiest Public-Domain Translations

Start with works that are likely to clear quickly and exercise the complete Markdown workflow:

- Project Gutenberg candidates with public-domain translations and simple text formats.
- Wikisource candidates with scan-backed public-domain editions and clear page-level license information.
- Public-domain biblical translation candidates only after confirming translation and edition status.
- Sacred Texts candidates only when the specific work, translator, and edition can be independently verified.

This lane should produce the first working set of complete Markdown files because it has the lowest conversion complexity and the most immediate value for motif extraction. Good early targets are complete books, hymns, tablets, or natural sections that map cleanly to the `first_500_corpus` units.

### 2. Scan-Backed Verification And OCR

Use Internet Archive and HathiTrust-style scan sources to verify exact editions, publication years, translators, and page structure. Scans should support provenance even when the actual text is acquired from a cleaner source.

OCR-derived text can enter the corpus only after:

- item-level rights review,
- correction against page images,
- front matter records the transcription mode,
- omissions and cleanup decisions are tracked.

This lane is especially useful for older translations of Egyptian, Mesopotamian, South Asian, Buddhist, classical, and Northern European materials where clean digital text may be incomplete or poorly attributed.

### 3. Original-Language Corpora

Next, ingest original-language corpora where rights and licenses allow. This includes Open Greek and Latin / Perseus-style Greek and Latin sources, public-domain or open biblical originals, Pali and other Buddhist canonical originals, and classical Chinese originals.

Original-language ingestion should preserve canonical references and stable structural identifiers. Pair translations later when the translation rights are clear. If translation rights are uncertain, an original-language source can still be valuable as a complete citable witness, provided the edition and platform terms allow reuse.

### 4. Open-License Texts With Conditions

After the first public-domain pass, add open-license texts that have compatible terms. These may be very useful, but they need more metadata discipline than public-domain texts.

Before ingesting, confirm:

- attribution requirements,
- ShareAlike or downstream license obligations,
- whether training, embeddings, and redistribution are allowed,
- whether modified Markdown needs change notices,
- whether the license applies to the text, metadata, API output, or only selected files.

### 5. Culturally Sensitive Living Traditions

Delay large-scale ingestion of culturally sensitive living-tradition materials until the project has a stable review process. This includes materials that may be technically public domain because of age but still require care around community context, ritual restrictions, colonial collection history, sacred names, or oral-tradition provenance.

For this lane, prefer planning records, bibliographic metadata, and citation-only entries until rights and cultural context are reviewed. When full text is eventually added, include context notes that prevent flattened or decontextualized comparison.

## Practical Batch Plan

Batch 1 should prove the pipeline with low-risk public-domain translations. Choose a small, balanced set across Greek/Roman, biblical, South Asian, Buddhist, and Northern European candidates. Each item should have clear edition metadata and a straightforward structure.

Batch 2 should add scan-backed provenance for the same or adjacent works. The goal is to improve trust in editions and prepare corrected OCR workflows without expanding rights risk too quickly.

Batch 3 should add original-language corpora for high-priority Wave A traditions, especially Greek, Latin, Hebrew, Greek New Testament, Pali, Sanskrit where available, and classical Chinese where platform terms allow.

Batch 4 should expand breadth after the workflow is stable: Mesopotamian, Egyptian, Islamic/Persianate, Daoist/Confucian, and other traditions that may require more careful edition selection or translation review.

Batch 5 should remain a review queue for living and culturally sensitive traditions until legal and cultural permission practices are mature enough for full-text inclusion.

## Stop Conditions

Do not ingest full text when:

- the translator or edition is modern and no compatible license or permission is recorded,
- the platform terms are unclear or conflict with redistribution/training goals,
- the source mixes public-domain text with copyrighted notes in a way that cannot be separated,
- only non-consumptive features are available,
- cultural permission review is needed and has not happened.

In those cases, create or keep a citation-only planning record and move to the next candidate.
