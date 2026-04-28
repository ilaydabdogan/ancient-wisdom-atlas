#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

DEFAULT_MODEL = ENV.fetch("OPENAI_BATCH_MODEL", "gpt-5.2")
DEFAULT_REASONING_EFFORT = ENV.fetch("OPENAI_BATCH_REASONING_EFFORT", "low")

options = {
  model: DEFAULT_MODEL,
  endpoint: AtlasBatch::DEFAULT_ENDPOINT,
  prompt_path: "templates/batch-normalization-suggestion-prompt.md",
  gap_audit_path: "data/indexes/normalization-gap-audit.yml",
  normalization_path: "taxonomy/motif-normalization.yml",
  taxonomy_path: "taxonomy/motifs.yml",
  buckets: [],
  motifs_per_request: 10,
  max_input_chars: 120_000,
  max_output_tokens: 12_000,
  reasoning_effort: DEFAULT_REASONING_EFFORT,
  max_requests_per_shard: 2,
  max_bytes_per_shard: 180 * 1024 * 1024,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_normalization_suggestion_requests.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Normalization suggestion batch run id") { |value| options[:run_id] = value }
  parser.on("--gap-audit PATH", "Normalization gap audit YAML path") { |value| options[:gap_audit_path] = value }
  parser.on("--normalization PATH", "Motif normalization YAML path") { |value| options[:normalization_path] = value }
  parser.on("--taxonomy PATH", "Motif taxonomy YAML path") { |value| options[:taxonomy_path] = value }
  parser.on("--bucket ID", "Only include this gap-audit bucket; may be repeated") { |value| options[:buckets] << value }
  parser.on("--limit N", Integer, "Limit motif IDs, useful for demos") { |value| options[:limit] = value }
  parser.on("--motifs-per-request N", Integer, "How many unmapped motifs to ask about per request") { |value| options[:motifs_per_request] = value }
  parser.on("--model MODEL", "OpenAI model id") { |value| options[:model] = value }
  parser.on("--endpoint ENDPOINT", "Batch endpoint; default /v1/responses") { |value| options[:endpoint] = value }
  parser.on("--prompt PATH", "Prompt template path") { |value| options[:prompt_path] = value }
  parser.on("--max-input-chars N", Integer, "Fail if a single request input exceeds this many chars") { |value| options[:max_input_chars] = value }
  parser.on("--max-output-tokens N", Integer, "Responses max_output_tokens") { |value| options[:max_output_tokens] = value }
  parser.on("--temperature N", Float, "Optional model temperature") { |value| options[:temperature] = value }
  parser.on("--reasoning-effort EFFORT", "Optional Responses reasoning effort") { |value| options[:reasoning_effort] = value }
  parser.on("--max-requests-per-shard N", Integer, "Shard request count limit") { |value| options[:max_requests_per_shard] = value }
  parser.on("--max-bytes-per-shard N", Integer, "Shard byte limit") { |value| options[:max_bytes_per_shard] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]
AtlasBatch.die("--motifs-per-request must be positive", 64) unless options[:motifs_per_request].positive?
AtlasBatch.die("--max-requests-per-shard must be positive", 64) unless options[:max_requests_per_shard].positive?
AtlasBatch.die("--max-bytes-per-shard must be at least 1000000", 64) if options[:max_bytes_per_shard] < 1_000_000
AtlasBatch.die("--max-input-chars must be at least 4000", 64) if options[:max_input_chars] < 4_000

def simple_string_field(description)
  { "type" => "string", "description" => description }
end

def string_array_field(description)
  {
    "type" => "array",
    "description" => description,
    "items" => { "type" => "string" }
  }
end

def reviewer_status_schema
  {
    "type" => "object",
    "additionalProperties" => false,
    "properties" => {
      "status" => { "type" => "string", "enum" => %w[draft needs_human_review ready_for_taxonomy_review] },
      "reviewer" => simple_string_field("Reviewer id."),
      "reviewed_at" => simple_string_field("Review date, empty before human review."),
      "notes" => simple_string_field("Review notes.")
    },
    "required" => %w[status reviewer reviewed_at notes]
  }
end

def new_group_schema
  {
    "type" => "object",
    "additionalProperties" => false,
    "properties" => {
      "id" => simple_string_field("Suggested snake_case group id, or empty string."),
      "label" => simple_string_field("Suggested group label, or empty string."),
      "description" => simple_string_field("Suggested group description, or empty string."),
      "parent_group_ids" => string_array_field("Existing group ids that would sit above this candidate."),
      "related_group_ids" => string_array_field("Existing group ids related to this candidate."),
      "reason_existing_groups_insufficient" => simple_string_field("Why existing groups are insufficient, or empty string.")
    },
    "required" => %w[id label description parent_group_ids related_group_ids reason_existing_groups_insufficient]
  }
end

def normalization_suggestion_response_schema
  suggestion_schema = {
    "type" => "object",
    "additionalProperties" => false,
    "properties" => {
      "suggestion_id" => simple_string_field("Stable suggestion id supplied in the request."),
      "motif_id" => simple_string_field("Unmapped motif id supplied in the request."),
      "label" => simple_string_field("Motif label supplied in the request."),
      "occurrences" => { "type" => "integer", "description" => "Occurrence count supplied in the request." },
      "traditions" => string_array_field("Traditions supplied in the request."),
      "review_bucket_id" => simple_string_field("Rough semantic review bucket supplied in the request."),
      "suggested_action" => {
        "type" => "string",
        "enum" => %w[map_to_existing_group new_group_candidate needs_human_review exclude_from_pattern_queries]
      },
      "suggested_group_id" => simple_string_field("Existing canonical_motif_groups id, or empty string."),
      "suggested_group_label" => simple_string_field("Existing group label, proposed new group label, or empty string."),
      "relationship" => {
        "type" => "string",
        "enum" => %w[alias child narrower_than broader_label symbolic_variant functional_variant ritual_variant role_variant over_specific_label meta_artifact uncertain]
      },
      "confidence" => { "type" => "string", "enum" => %w[low medium high] },
      "rationale" => simple_string_field("Short reason for the suggested placement."),
      "cautions" => simple_string_field("Limits, ambiguity, or review cautions."),
      "suggested_aliases" => string_array_field("Alternative labels or aliases worth preserving."),
      "suggested_new_group" => new_group_schema
    },
    "required" => %w[
      suggestion_id motif_id label occurrences traditions review_bucket_id suggested_action
      suggested_group_id suggested_group_label relationship confidence rationale cautions
      suggested_aliases suggested_new_group
    ]
  }

  {
    "type" => "object",
    "additionalProperties" => false,
    "properties" => {
      "suggestion_batch_id" => simple_string_field("Stable batch suggestion id supplied in the request."),
      "gap_audit_path" => simple_string_field("Repository-relative gap audit path."),
      "normalization_path" => simple_string_field("Repository-relative normalization taxonomy path."),
      "suggestions" => {
        "type" => "array",
        "items" => suggestion_schema
      },
      "batch_notes" => string_array_field("Request-level notes for human reviewers."),
      "reviewer_status" => reviewer_status_schema
    },
    "required" => %w[suggestion_batch_id gap_audit_path normalization_path suggestions batch_notes reviewer_status]
  }
end

def compact_taxonomy_context(path)
  taxonomy = AtlasBatch.load_yaml(path, {})
  {
    "canonical_motif_families" => taxonomy.fetch("motif_families", {}).map do |motif_id, value|
      {
        "motif_id" => motif_id,
        "label" => value["label"],
        "description" => value["description"],
        "related" => Array(value["related"])
      }
    end
  }
end

def compact_normalization_context(path)
  normalization = AtlasBatch.load_yaml(path, {})
  {
    "normalization_version" => normalization["normalization_version"],
    "review_policy" => normalization["review_policy"],
    "comparison_modes" => normalization["comparison_modes"],
    "hierarchies" => normalization["hierarchies"],
    "aliases" => normalization.fetch("aliases", {}).map do |alias_id, value|
      {
        "alias_id" => alias_id,
        "canonical_refs" => Array(value["canonical_refs"]),
        "parent_refs" => Array(value["parent_refs"]),
        "relationship" => value["relationship"],
        "review_action" => value["review_action"],
        "notes" => value["notes"].to_s
      }
    end,
    "canonical_motif_group_policy" => normalization["canonical_motif_group_policy"],
    "canonical_motif_groups" => Array(normalization["canonical_motif_groups"]).map do |group|
      next nil unless group.is_a?(Hash)

      {
        "id" => group["id"],
        "label" => group["label"],
        "description" => group["description"].to_s.strip,
        "children" => Array(group["children"]),
        "aliases" => Array(group["aliases"]),
        "related" => Array(group["related"])
      }
    end.compact,
    "raw_motif_group_index_sample" => normalization.fetch("raw_motif_group_index", {}).first(80).map do |motif_id, value|
      {
        "motif_id" => motif_id,
        "group_id" => value["group_id"],
        "relationship" => value["relationship"],
        "notes" => value["notes"].to_s
      }
    end
  }
end

def selected_motifs(gap_audit, buckets)
  selected = []
  Array(gap_audit["buckets"]).each do |bucket|
    next if buckets.any? && !buckets.include?(bucket.fetch("id"))

    Array(bucket["motifs"]).each do |motif|
      selected << {
        "suggestion_id" => "normalization.suggestion.#{AtlasBatch.safe_slug(motif.fetch("motif_id"))}",
        "motif_id" => motif.fetch("motif_id"),
        "label" => motif["label"].to_s,
        "occurrences" => motif["occurrences"].to_i,
        "traditions" => Array(motif["traditions"]).map(&:to_s).sort,
        "review_bucket_id" => bucket.fetch("id"),
        "review_bucket_label" => bucket["label"].to_s
      }
    end
  end
  selected
end

def request_body(input, prompt, options)
  body = {
    "model" => options.fetch(:model),
    "input" => [
      { "role" => "system", "content" => prompt },
      { "role" => "user", "content" => JSON.pretty_generate(input) }
    ],
    "text" => {
      "format" => {
        "type" => "json_schema",
        "name" => "atlas_normalization_suggestion",
        "strict" => true,
        "schema" => normalization_suggestion_response_schema
      }
    },
    "max_output_tokens" => options.fetch(:max_output_tokens)
  }
  body["temperature"] = options[:temperature] if options.key?(:temperature)
  body["reasoning"] = { "effort" => options[:reasoning_effort] } if options[:reasoning_effort].to_s.strip != ""
  body
end

def shard_requests(requests, max_requests:, max_bytes:)
  shards = []
  current = []
  current_bytes = 0

  requests.each do |request|
    line = JSON.generate(request)
    line_bytes = line.bytesize + 1
    if current.any? && (current.length >= max_requests || current_bytes + line_bytes > max_bytes)
      shards << current
      current = []
      current_bytes = 0
    end

    AtlasBatch.die("single request exceeds shard byte limit: #{request.fetch("custom_id")}", 65) if line_bytes > max_bytes

    current << request
    current_bytes += line_bytes
  end

  shards << current if current.any?
  shards
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)
prompt_path = AtlasBatch.project_path(options[:prompt_path])
gap_audit_path = AtlasBatch.project_path(options[:gap_audit_path])
normalization_path = AtlasBatch.project_path(options[:normalization_path])
taxonomy_path = AtlasBatch.project_path(options[:taxonomy_path])

AtlasBatch.die("Prompt template not found: #{AtlasBatch.relative_path(prompt_path)}", 66) unless File.file?(prompt_path)
AtlasBatch.die("Gap audit not found: #{AtlasBatch.relative_path(gap_audit_path)}", 66) unless File.file?(gap_audit_path)
AtlasBatch.die("Motif normalization file not found: #{AtlasBatch.relative_path(normalization_path)}", 66) unless File.file?(normalization_path)
AtlasBatch.die("Motif taxonomy file not found: #{AtlasBatch.relative_path(taxonomy_path)}", 66) unless File.file?(taxonomy_path)

gap_audit = AtlasBatch.load_yaml(gap_audit_path, {})
motifs = selected_motifs(gap_audit, options[:buckets])
motifs = motifs.first(options[:limit]) if options[:limit]
AtlasBatch.die("No unmapped motif IDs selected", 66) if motifs.empty?

taxonomy_context = compact_taxonomy_context(taxonomy_path)
normalization_context = compact_normalization_context(normalization_path)
prompt = File.read(prompt_path)
safe_run_id = AtlasBatch.safe_slug(run_id)

inputs = motifs.each_slice(options[:motifs_per_request]).each_with_index.map do |slice, index|
  suggestion_batch_id = "normalization.suggestion.#{safe_run_id}.batch-%04d" % (index + 1)
  {
    "task" => "motif_normalization_suggestion",
    "suggestion_batch_id" => suggestion_batch_id,
    "gap_audit_path" => AtlasBatch.relative_path(gap_audit_path),
    "normalization_path" => AtlasBatch.relative_path(normalization_path),
    "taxonomy_path" => AtlasBatch.relative_path(taxonomy_path),
    "gap_audit_summary" => {
      "generated_on" => gap_audit["generated_on"].to_s,
      "motif_count" => gap_audit["motif_count"].to_i,
      "mapped_count" => gap_audit["mapped_count"].to_i,
      "unmapped_count" => gap_audit["unmapped_count"].to_i,
      "bucket_counts" => Array(gap_audit["buckets"]).map { |bucket| { "id" => bucket["id"], "label" => bucket["label"], "count" => bucket["count"].to_i } }
    },
    "current_taxonomy" => taxonomy_context,
    "motif_normalization" => normalization_context,
    "unmapped_motifs" => slice
  }
end

too_long = inputs.select { |input| JSON.generate(input).length > options[:max_input_chars] }
if too_long.any?
  examples = too_long.first(10).map { |input| "#{input.fetch("suggestion_batch_id")} chars=#{JSON.generate(input).length}" }
  AtlasBatch.die("Normalization suggestion input(s) exceed --max-input-chars #{options[:max_input_chars]}:\n#{examples.join("\n")}", 65)
end

requests = inputs.map do |input|
  {
    "custom_id" => "normalization_suggestion:#{AtlasBatch.safe_slug(input.fetch("suggestion_batch_id"))}",
    "method" => "POST",
    "url" => options.fetch(:endpoint),
    "body" => request_body(input, prompt, options)
  }
end

request_map = inputs.zip(requests).map do |input, request|
  {
    "custom_id" => request.fetch("custom_id"),
    "suggestion_batch_id" => input.fetch("suggestion_batch_id"),
    "gap_audit_path" => input.fetch("gap_audit_path"),
    "normalization_path" => input.fetch("normalization_path"),
    "taxonomy_path" => input.fetch("taxonomy_path"),
    "bucket_ids" => input.fetch("unmapped_motifs").map { |motif| motif.fetch("review_bucket_id") }.uniq.sort,
    "motif_ids" => input.fetch("unmapped_motifs").map { |motif| motif.fetch("motif_id") },
    "motifs" => input.fetch("unmapped_motifs"),
    "input_sha256" => AtlasBatch.sha256_text(JSON.generate(input))
  }
end

shards = shard_requests(
  requests,
  max_requests: options[:max_requests_per_shard],
  max_bytes: options[:max_bytes_per_shard]
)

requests_dir = File.join(AtlasBatch.batch_dir(run_id), "requests")
FileUtils.mkdir_p(requests_dir)

shard_entries = []
shards.each_with_index do |records, index|
  shard_id = "shard-%04d" % (index + 1)
  path = File.join(requests_dir, "#{shard_id}.jsonl")
  AtlasBatch.write_jsonl(path, records, force: options[:force])
  shard_entries << {
    "shard_id" => shard_id,
    "path" => AtlasBatch.relative_path(path),
    "request_count" => records.length,
    "bytes" => File.size(path),
    "sha256" => AtlasBatch.sha256_file(path),
    "endpoint" => options[:endpoint],
    "model" => options[:model],
    "status" => "prepared"
  }
end

request_map_path = File.join(AtlasBatch.batch_dir(run_id), "normalization-suggestion-request-map.jsonl")
AtlasBatch.write_jsonl(request_map_path, request_map, force: options[:force])

index_path = File.join(requests_dir, "index.yml")
request_index = {
  "batch_request_index_version" => "1",
  "run_id" => run_id,
  "created_at" => AtlasBatch.utc_now,
  "updated_at" => AtlasBatch.utc_now,
  "pipeline" => "normalization_suggestion",
  "endpoint" => options[:endpoint],
  "model" => options[:model],
  "prompt_path" => AtlasBatch.relative_path(prompt_path),
  "gap_audit_path" => AtlasBatch.relative_path(gap_audit_path),
  "normalization_path" => AtlasBatch.relative_path(normalization_path),
  "taxonomy_path" => AtlasBatch.relative_path(taxonomy_path),
  "request_map_path" => AtlasBatch.relative_path(request_map_path),
  "buckets" => options[:buckets],
  "motifs_per_request" => options[:motifs_per_request],
  "shards" => shard_entries
}
AtlasBatch.write_yaml(index_path, request_index)

manifest["pipeline"] = "normalization_suggestion"
manifest["status"] = "requests_prepared"
manifest["config"] ||= {}
manifest["config"]["normalization_suggestion_request_generation"] = {
  "model" => options[:model],
  "endpoint" => options[:endpoint],
  "prompt_path" => AtlasBatch.relative_path(prompt_path),
  "gap_audit_path" => AtlasBatch.relative_path(gap_audit_path),
  "normalization_path" => AtlasBatch.relative_path(normalization_path),
  "taxonomy_path" => AtlasBatch.relative_path(taxonomy_path),
  "buckets" => options[:buckets],
  "limit" => options[:limit],
  "motifs_per_request" => options[:motifs_per_request],
  "max_input_chars" => options[:max_input_chars],
  "max_output_tokens" => options[:max_output_tokens],
  "temperature" => options[:temperature],
  "reasoning_effort" => options[:reasoning_effort],
  "max_requests_per_shard" => options[:max_requests_per_shard],
  "max_bytes_per_shard" => options[:max_bytes_per_shard]
}
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["artifacts"]["normalization_suggestion_request_map_path"] = AtlasBatch.relative_path(request_map_path)
manifest["counts"] ||= {}
manifest["counts"]["normalization_suggestion_requests_prepared"] = inputs.length
manifest["counts"]["unmapped_motifs_covered"] = motifs.length
manifest["counts"]["request_shards"] = shard_entries.length
AtlasBatch.save_manifest(manifest)

puts "prepared #{inputs.length} normalization suggestion request(s) covering #{motifs.length} motif id(s) in #{shard_entries.length} shard(s)"
puts "wrote #{AtlasBatch.relative_path(index_path)}"
