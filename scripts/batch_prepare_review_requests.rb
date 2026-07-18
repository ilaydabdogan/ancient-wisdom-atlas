#!/usr/bin/env ruby
# frozen_string_literal: true

# Generic reviewer stage: a model DIFFERENT from the drafter reviews every
# item a drafting run produced, with a queue-specific rubric. Verdicts:
# accept | revise (with corrected draft) | reject. Accepted items may then
# be applied by queue-specific apply scripts; nothing applies un-reviewed.
#
# usage: ruby scripts/batch_prepare_review_requests.rb \
#          --run-id review-timeline-luna --source-run timeline-dating-sol-2026-07-18 \
#          --queue-type timeline_dating --model gpt-5.6-luna

require_relative "batch_common"

RUBRICS = {
  "timeline_dating" => <<~R,
    You are reviewing a proposed cultural-timeline entry. Check: (1) the
    date range against scholarly consensus for this work; (2) that
    ethnographer-recorded oral traditions are dated by RECORDING with the
    caveat stated; (3) schema completeness (id, title, tradition_cluster,
    culture, region, approximate_date_range with integer start/end,
    display, timeline_label, current_text_paths, uncertainty); (4) that
    the uncertainty note is honest, not boilerplate. Prefer widening a
    range over false precision.
  R
  "subfamily_binning" => <<~R,
    You are reviewing a proposed sub-family binning of a canonical motif
    family. Check: (1) every child motif appears in exactly one
    sub-family and none are invented or dropped (verify counts); (2)
    sub-families carve at natural evidential joints, not theory-first
    categories; (3) no giant catch-all hiding structure; (4) ids follow
    family_<snake_case>; (5) labels are concrete. If child assignment
    errors exist, fix them in the corrected draft.
  R
  "edge_comparison" => <<~R
    You are reviewing a drafted comparison record for a conserved motif-
    family pair. Check: (1) claim_level is the strongest DEFENSIBLE level
    given tradition spread (downgrade if inflated — independent_recurrence
    requires isolated lineages, historical_contact requires plausible
    routes); (2) the shared-function hypothesis follows from the data
    shown, not outside lore; (3) disconfirming_considerations are real
    alternatives, not strawmen; (4) confidence is low or medium, never
    high. Downgrade generously.
  R
}.freeze

options = {
  model: "gpt-5.6-luna",
  endpoint: AtlasBatch::DEFAULT_ENDPOINT,
  max_output_tokens: 10_000,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_review_requests.rb --run-id RUN_ID --source-run RUN_ID --queue-type TYPE [options]"
  parser.on("--run-id RUN_ID", "Review batch run id") { |value| options[:run_id] = value }
  parser.on("--source-run RUN_ID", "Drafting run to review") { |value| options[:source_run] = value }
  parser.on("--queue-type TYPE", RUBRICS.keys.join("|")) { |value| options[:queue_type] = value }
  parser.on("--model MODEL", "Reviewer model (must differ from drafter)") { |value| options[:model] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]
AtlasBatch.die("--source-run is required", 64) unless options[:source_run]
rubric = RUBRICS[options[:queue_type]] or AtlasBatch.die("unknown --queue-type", 64)

source_index = AtlasBatch.load_yaml(File.join(AtlasBatch.batch_dir(options[:source_run]), "requests", "index.yml"))
drafter_model = source_index["model"].to_s
AtlasBatch.die("reviewer model equals drafter model (#{drafter_model}); self-review is not allowed", 65) if drafter_model == options[:model]

def response_text(body)
  parts = []
  Array(body["output"]).each do |item|
    next unless item.is_a?(Hash) && item["type"] == "message"

    Array(item["content"]).each { |c| parts << c["text"].to_s if c.is_a?(Hash) && c["text"] }
  end
  text = parts.join("\n").strip
  text.empty? ? body["output_text"].to_s.strip : text
end

requests = []
request_map = []
Dir.glob(File.join(AtlasBatch.batch_dir(options[:source_run]), "results", "*.output.jsonl")).sort.each do |path|
  AtlasBatch.read_jsonl(path).each do |line|
    body = line.dig("response", "body") || {}
    next unless body["status"] == "completed"

    draft = response_text(body)
    next if draft.empty?

    custom_id = "review:#{line["custom_id"]}"
    requests << {
      "custom_id" => custom_id,
      "method" => "POST",
      "url" => options[:endpoint],
      "body" => {
        "model" => options[:model],
        "input" => <<~PROMPT,
          You are an independent reviewer for the Ancient Wisdom Atlas.
          A different model drafted the item below. Apply this rubric
          strictly:

          #{rubric}

          DRAFT:
          ---
          #{draft[0, 14_000]}
          ---

          Output ONLY YAML, no code fences:
          verdict: accept | revise | reject
          issues:
          - one line per issue found (empty list if none)
          corrected_draft: |
            (full corrected item if verdict is revise, else omit this key)
        PROMPT
        "max_output_tokens" => options[:max_output_tokens],
        "reasoning" => { "effort" => "high" }
      }
    }
    request_map << { "custom_id" => custom_id, "source_custom_id" => line["custom_id"], "queue_type" => options[:queue_type] }
  end
end

AtlasBatch.die("no completed drafts to review", 66) if requests.empty?

run_id = options[:run_id]
requests_dir = File.join(AtlasBatch.batch_dir(run_id), "requests")
FileUtils.mkdir_p(requests_dir)
shard_entries = []
requests.each_slice(1000).with_index do |slice, index|
  shard_id = "shard-%04d" % (index + 1)
  path = File.join(requests_dir, "#{shard_id}.jsonl")
  AtlasBatch.write_jsonl(path, slice, force: options[:force])
  shard_entries << { "shard_id" => shard_id, "path" => AtlasBatch.relative_path(path), "request_count" => slice.length,
                     "bytes" => File.size(path), "sha256" => AtlasBatch.sha256_file(path),
                     "endpoint" => options[:endpoint], "model" => options[:model], "status" => "prepared" }
end
AtlasBatch.write_jsonl(File.join(AtlasBatch.batch_dir(run_id), "request-map.jsonl"), request_map, force: options[:force])
index_path = File.join(requests_dir, "index.yml")
AtlasBatch.write_yaml(index_path, {
  "batch_request_index_version" => "1", "run_id" => run_id, "source_run" => options[:source_run],
  "queue_type" => options[:queue_type], "drafter_model" => drafter_model,
  "created_at" => AtlasBatch.utc_now, "updated_at" => AtlasBatch.utc_now,
  "endpoint" => options[:endpoint], "model" => options[:model], "shards" => shard_entries
})
manifest = AtlasBatch.load_manifest(run_id)
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["status"] = "requests_prepared"
AtlasBatch.save_manifest(manifest)
puts "prepared #{requests.length} review request(s) (#{options[:queue_type]}, drafter #{drafter_model} -> reviewer #{options[:model]})"
