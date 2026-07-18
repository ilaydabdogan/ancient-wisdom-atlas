# Methods finding: two quality instruments disagree, and the disagreement is the answer

**Date:** 2026-07-18. **Status:** committed; feeds the re-extraction queue.

## The setup
Wave-1 extractions (the resurrected April run, 3,277 records) were judged
by two *independent* adversarial gates — gpt-5.6-terra and gpt-5.6-sol —
each shown the true source passage and prompted to refute the draft.
Neither saw the other's verdicts. Separately, every passage was read by
up to five independent models (the replication panel), giving a
multi-reader **consensus tier** per record: confirmed (3+ readers agree),
corroborated (2), provisional (1).

## The numbers
- The two gates **agree 77.6%** of the time on reject/not-reject.
- **1,036 records (67%) were rejected by BOTH gates** — a startling raw
  "bad rate".
- But the gate honeypots only ever measured *recall* (they catch ~100%
  of deliberately-corrupted decoys); precision was never calibrated, and
  the gate prompt is deliberately harsh ("when uncertain, flag it").

## The decisive cross-check
Records both gates rejected are **enriched for high consensus**:
**89.5%** of them sit in the confirmed tier (3+ independent readers
agreed) versus **52.9%** of the overall population. A true fabrication
would not draw independent readers to the same motifs. The enrichment
means the gates are preferentially rejecting *rich, confident, detailed*
extractions — exactly the ones that (a) earn high reader consensus and
(b) trip a skeptic's "confidence inflation" and "projection" flags
because there is simply more to flag.

**Conclusion:** the adversarial gate is an excellent *recall* instrument
and a poor *precision* instrument. Multi-reader consensus is the more
trustworthy per-record quality signal. The 67% is an artifact of gate
harshness, not the corpus's true condition.

## The trustworthy verdict (3-signal intersection)
A record is treated as genuinely suspect only if **both gates reject it
AND no other reader corroborates it** (provisional consensus or unread by
other models). That set is **86 records — 2.6% of Wave 1** — now queued
for re-extraction (`data/reviews/genuinely-suspect-wave1.yml`). Nothing
is deleted.

## Why this matters beyond Wave 1
1. It is a live demonstration of why the Atlas runs *multiple independent
   quality instruments*: either gate alone would have condemned 67% of a
   wave. Only by cross-referencing an orthogonal signal (reader
   consensus) did the true ~3% surface.
2. It recalibrates doctrine: the adversarial gate is retained as a
   high-recall screen, but per-record trust is anchored on multi-reader
   consensus, and action requires the 3-signal intersection.
3. It leaves the aggregate findings untouched: they rest on co-occurrence
   structure across tens of thousands of records and on multi-reader
   consensus, both robust to a 2.6% suspect fraction.
