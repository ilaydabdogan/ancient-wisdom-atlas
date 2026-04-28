# Timeline Methodology

The cultural timeline is a compact index for comparison and future visualization.
It gives each ingested tradition a cautious working range, not a final scholarly
date.

## Date Representation

Timeline entries use `approximate_date_range` with numeric `start_year` and
`end_year` values plus a human-readable `display` label.

```yaml
approximate_date_range:
  start_year: -400
  end_year: -250
  display: ca. 400-250 BCE
```

Negative years represent approximate BCE dates as sortable keys. Positive years
represent CE dates. Every range should be read with the entry's `uncertainty`
note, especially when a text has oral antecedents, layered composition, later
redaction, or a surviving manuscript that is much later than the material it
preserves.

## Comparison Limits

The timeline can help motif pages ask useful questions: which motifs recur before,
after, or alongside one another in different regions and traditions? It should not
be used by itself to argue direct influence.

Motif recurrence does not imply direct borrowing. Similar images can arise through
documented contact, shared inheritance, translation, ritual exchange, common human
concerns, independent literary development, or modern categorization. Claims of
historical influence need additional evidence such as plausible routes of contact,
chronological fit, linguistic or textual parallels, transmission history, and clear
limits on what is being compared.

Use the timeline as orientation, not proof.
