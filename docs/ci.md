# CI

GitHub Actions runs the repository's existing Ruby quality checks on pushes to `main` and on pull requests.

The workflow uses the system Ruby provided by the runner and does not install external gems. It runs the same local quality suite used before pushing:

```sh
ruby scripts/check_all.rb
```

## What CI Verifies

CI verifies that:

- Markdown corpus files have required YAML metadata.
- Pattern metadata references known taxonomy motifs and traditions.
- The first 500 corpus collection has the expected shape, item count, and required fields.
- YAML and JSON data/schema files parse cleanly.
- Canonical Markdown is clean enough for review and machine export.
- JSONL exports can be generated successfully from the current repository state.

## Export Handling

The export step writes JSONL files under `exports/` during the CI run. These generated files are build artifacts for validation only and are not committed by the workflow.
