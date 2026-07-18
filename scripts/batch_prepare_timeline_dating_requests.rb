#!/usr/bin/env ruby
# frozen_string_literal: true

# Prepares timeline-dating requests for corpus texts missing from
# data/indexes/cultural-timeline.yml. The model receives each text's
# front-matter metadata and opening lines and drafts a timeline entry
# (approximate composition/recording date range with an explicit
# uncertainty note) matching the timeline schema. Drafts feed human
# review via docs/timeline-methodology.md conventions — never merged
# automatically. For ethnographer-recorded oral traditions the model is
# instructed to date the RECORDING and say so.

require_relative "batch_common"

options = {
  timeline_index: "data/indexes/cultural-timeline.yml",
  texts_glob: "texts/public-domain/**/*.md",
  model: ENV.fetch("OPENAI_BATCH_MODEL", "gpt-5.6-sol"),
  endpoint: AtlasBatch::DEFAULT_ENDPOINT,
  max_output_tokens: 8_000,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_timeline_dating_requests.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--model MODEL", "Model / deployment id") { |value| options[:model] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

timeline = AtlasBatch.load_yaml(AtlasBatch.project_path(options[:timeline_index]))
dated = timeline.fetch("entries", []).flat_map { |entry| Array(entry["current_text_paths"]) }.to_set

requests = []
request_map = []
Dir.glob(AtlasBatch.project_path(options[:texts_glob])).sort.each do |path|
  rel = AtlasBatch.relative_path(path)
  next if dated.include?(rel)

  parsed = AtlasBatch.read_markdown(path)
  metadata = parsed["metadata"]
  opening = parsed["body_entries"].first(60).map { |_, line| line }.join("\n")[0, 4000]
  custom_id = "timeline_dating:#{AtlasBatch.safe_slug(rel)}"

  prompt = <<~PROMPT
    You are drafting a cultural-timeline entry for the Ancient Wisdom
    Atlas. Draft an approximate composition/recording date range for this
    text, following these rules:
    - Use scholarly consensus ranges for textual composition, redaction,
      or earliest recoverable written form. Broad honest ranges beat
      falsely precise ones.
    - For ethnographer-recorded oral traditions (e.g. 19th-century
      collections of Aboriginal, Inuit, African, Native American tales),
      date the RECORDING/publication and state clearly in the uncertainty
      note that the oral tradition itself is far older and undatable.
    - Negative years = BCE.

    TEXT METADATA (from the file's front matter):
    #{metadata.to_yaml}

    OPENING LINES:
    #{opening}

    Output ONLY a YAML object with exactly these keys (no code fences):
    id: a short dotted id like tradition.work_slug
    title: the work's title
    tradition_cluster: from the metadata
    culture: short slug
    region: short slug
    approximate_date_range:
      start_year: integer (negative for BCE)
      end_year: integer
      display: human-readable, e.g. "ca. 1550-1070 BCE" or "recorded 1896 CE"
    timeline_label: one-line scholarly label
    current_text_paths:
    - #{rel}
    uncertainty: 2-3 sentences of honest dating caveats
  PROMPT

  requests << {
    "custom_id" => custom_id,
    "method" => "POST",
    "url" => options[:endpoint],
    "body" => {
      "model" => options[:model],
      "input" => prompt,
      "max_output_tokens" => options[:max_output_tokens],
      "reasoning" => { "effort" => "high" }
    }
  }
  request_map << { "custom_id" => custom_id, "text_path" => rel }
end

AtlasBatch.die("no undated texts found", 66) if requests.empty?

run_id = options[:run_id]
requests_dir = File.join(AtlasBatch.batch_dir(run_id), "requests")
FileUtils.mkdir_p(requests_dir)
shard_path = File.join(requests_dir, "shard-0001.jsonl")
AtlasBatch.write_jsonl(shard_path, requests, force: options[:force])
AtlasBatch.write_jsonl(File.join(AtlasBatch.batch_dir(run_id), "request-map.jsonl"), request_map, force: options[:force])

index_path = File.join(requests_dir, "index.yml")
AtlasBatch.write_yaml(index_path, {
  "batch_request_index_version" => "1",
  "run_id" => run_id,
  "created_at" => AtlasBatch.utc_now,
  "updated_at" => AtlasBatch.utc_now,
  "endpoint" => options[:endpoint],
  "model" => options[:model],
  "shards" => [{
    "shard_id" => "shard-0001",
    "path" => AtlasBatch.relative_path(shard_path),
    "request_count" => requests.length,
    "bytes" => File.size(shard_path),
    "sha256" => AtlasBatch.sha256_file(shard_path),
    "endpoint" => options[:endpoint],
    "model" => options[:model],
    "status" => "prepared"
  }]
})

manifest = AtlasBatch.load_manifest(run_id)
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["status"] = "requests_prepared"
AtlasBatch.save_manifest(manifest)

puts "prepared #{requests.length} timeline-dating request(s)"
