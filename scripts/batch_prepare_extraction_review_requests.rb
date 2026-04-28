#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

DEFAULT_MODEL = ENV.fetch("OPENAI_BATCH_MODEL", "gpt-5.2")
DEFAULT_REASONING_EFFORT = ENV.fetch("OPENAI_BATCH_REASONING_EFFORT", "high")

options = {
  model: DEFAULT_MODEL,
  endpoint: AtlasBatch::DEFAULT_ENDPOINT,
  prompt_path: "templates/batch-extraction-review-prompt.md",
  extraction_glob: "extractions/**/*.yml",
  coverage_statuses: [],
  coverage_priorities: [],
  reviewer_statuses: [],
  max_input_chars: 28_000,
  max_output_tokens: 4_000,
  reasoning_effort: DEFAULT_REASONING_EFFORT,
  max_requests_per_shard: 1_000,
  max_bytes_per_shard: 180 * 1024 * 1024,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_extraction_review_requests.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Extraction review batch run id") { |value| options[:run_id] = value }
  parser.on("--extraction-glob GLOB", "YAML extraction glob") { |value| options[:extraction_glob] = value }
  parser.on("--coverage PATH", "Use data/indexes/extraction-coverage.yml to select source texts") { |value| options[:coverage_path] = value }
  parser.on("--coverage-status STATUS", "Only review records from this coverage status; may be repeated") { |value| options[:coverage_statuses] << value }
  parser.on("--coverage-priority PRIORITY", "Only review records from this coverage priority; may be repeated") { |value| options[:coverage_priorities] << value }
  parser.on("--reviewer-status STATUS", "Only review records with this reviewer_status.status; may be repeated") { |value| options[:reviewer_statuses] << value }
  parser.on("--limit N", Integer, "Limit review inputs, useful for demos") { |value| options[:limit] = value }
  parser.on("--model MODEL", "OpenAI model id") { |value| options[:model] = value }
  parser.on("--endpoint ENDPOINT", "Batch endpoint; default /v1/responses") { |value| options[:endpoint] = value }
  parser.on("--prompt PATH", "Prompt template path") { |value| options[:prompt_path] = value }
  parser.on("--max-input-chars N", Integer, "Fail if a single review input exceeds this many chars") { |value| options[:max_input_chars] = value }
  parser.on("--max-output-tokens N", Integer, "Responses max_output_tokens") { |value| options[:max_output_tokens] = value }
  parser.on("--temperature N", Float, "Optional model temperature") { |value| options[:temperature] = value }
  parser.on("--reasoning-effort EFFORT", "Optional Responses reasoning effort") { |value| options[:reasoning_effort] = value }
  parser.on("--max-requests-per-shard N", Integer, "Shard request count limit") { |value| options[:max_requests_per_shard] = value }
  parser.on("--max-bytes-per-shard N", Integer, "Shard byte limit") { |value| options[:max_bytes_per_shard] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]
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

def extraction_review_response_schema
  {
    "type" => "object",
    "additionalProperties" => false,
    "properties" => {
      "review_id" => simple_string_field("Stable review id supplied in the request."),
      "extraction_path" => simple_string_field("Repository-relative extraction YAML path."),
      "record_id" => simple_string_field("Extraction record id."),
      "source_text_path" => simple_string_field("Repository-relative canonical source text path."),
      "overall_decision" => {
        "type" => "string",
        "enum" => %w[promote normalize revise reject no_motif front_matter_only]
      },
      "quality_flags" => string_array_field("Quality flags such as over_specific_motif, unsupported_claim, missing_evidence, weak_locator, front_matter, empty_motif_record."),
      "motif_reviews" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "original_label" => simple_string_field("Original candidate motif label."),
            "original_taxonomy_refs" => string_array_field("Original taxonomy refs."),
            "decision" => {
              "type" => "string",
              "enum" => %w[keep map_to_existing broaden narrow split remove needs_human_review]
            },
            "normalized_label" => simple_string_field("Recommended normalized label."),
            "canonical_taxonomy_refs" => string_array_field("Recommended existing taxonomy refs."),
            "parent_taxonomy_refs" => string_array_field("Parent taxonomy refs for hierarchy queries."),
            "specificity" => {
              "type" => "string",
              "enum" => %w[too_broad useful too_specific unclear]
            },
            "evidence_supported" => {
              "type" => "string",
              "enum" => %w[yes no partial unclear]
            },
            "basis" => simple_string_field("Short evidence-based rationale."),
            "cautions" => simple_string_field("Limits, uncertainties, or cultural-context cautions.")
          },
          "required" => %w[
            original_label original_taxonomy_refs decision normalized_label canonical_taxonomy_refs
            parent_taxonomy_refs specificity evidence_supported basis cautions
          ]
        }
      },
      "comparison_claim_reviews" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "claim" => simple_string_field("Original comparison claim."),
            "decision" => {
              "type" => "string",
              "enum" => %w[keep weaken strengthen remove needs_evidence needs_human_review]
            },
            "comparison_mode" => {
              "type" => "string",
              "enum" => %w[structural thematic historical_contact common_inheritance independent_emergence archetypal visual linguistic uncertain]
            },
            "basis" => simple_string_field("Why this decision fits the evidence."),
            "cautions" => simple_string_field("Limits or risks in the comparison.")
          },
          "required" => %w[claim decision comparison_mode basis cautions]
        }
      },
      "suggested_taxonomy_additions" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "motif_id" => simple_string_field("Suggested snake_case motif id."),
            "label" => simple_string_field("Suggested label."),
            "parent_refs" => string_array_field("Recommended parent taxonomy refs."),
            "reason" => simple_string_field("Why existing motifs are insufficient.")
          },
          "required" => %w[motif_id label parent_refs reason]
        }
      },
      "pattern_links" => string_array_field("Existing or plausible structured pattern ids this extraction could support."),
      "caution_notes" => string_array_field("Methodological cautions for this record."),
      "open_questions" => string_array_field("Questions for human review."),
      "reviewer_status" => {
        "type" => "object",
        "additionalProperties" => false,
        "properties" => {
          "status" => {
            "type" => "string",
            "enum" => %w[draft needs_human_review ready_for_promotion rejected]
          },
          "reviewer" => simple_string_field("Reviewer id."),
          "reviewed_at" => simple_string_field("Review date, empty before human review."),
          "notes" => simple_string_field("Review notes.")
        },
        "required" => %w[status reviewer reviewed_at notes]
      }
    },
    "required" => %w[
      review_id extraction_path record_id source_text_path overall_decision quality_flags
      motif_reviews comparison_claim_reviews suggested_taxonomy_additions pattern_links
      caution_notes open_questions reviewer_status
    ]
  }
end

def load_taxonomy_context
  motifs = AtlasBatch.load_yaml(File.join(AtlasBatch::ROOT, "taxonomy", "motifs.yml"), {})
  {
    "motif_families" => (motifs["motif_families"] || {}).map do |motif_id, value|
      {
        "motif_id" => motif_id,
        "label" => value["label"],
        "description" => value["description"],
        "related" => value["related"] || []
      }
    end
  }
end

def coverage_source_paths(options)
  return nil unless options[:coverage_path]

  coverage_path = AtlasBatch.project_path(options.fetch(:coverage_path))
  AtlasBatch.die("Coverage index not found: #{AtlasBatch.relative_path(coverage_path)}", 66) unless File.file?(coverage_path)

  coverage = AtlasBatch.load_yaml(coverage_path, {})
  statuses = options.fetch(:coverage_statuses)
  priorities = options.fetch(:coverage_priorities)

  coverage.fetch("texts", []).select do |row|
    status_match = statuses.empty? || statuses.include?(row["status"].to_s)
    priority_match = priorities.empty? || priorities.include?(row["priority"].to_s)
    status_match && priority_match
  end.map { |row| row.fetch("source_text_path") }.to_h { |path| [path, true] }
end

def compact_record(record)
  record.slice(
    "record_id",
    "source_text_path",
    "passage_locator",
    "canonical_text",
    "literal_observations",
    "figures",
    "roles",
    "symbols",
    "scenes",
    "candidate_motifs",
    "comparison_claims",
    "evidence",
    "confidence",
    "reviewer_status",
    "notes"
  )
end

def review_input_for(path, record, taxonomy_context)
  relative = AtlasBatch.relative_path(path)
  review_id = "review.extraction.#{AtlasBatch.safe_slug(record["record_id"].to_s.empty? ? relative : record["record_id"])}"
  {
    "task" => "extraction_quality_review_and_motif_normalization",
    "review_id" => review_id,
    "extraction_path" => relative,
    "record_id" => record["record_id"],
    "source_text_path" => record["source_text_path"],
    "available_taxonomy" => taxonomy_context,
    "extraction_record" => compact_record(record)
  }
end

def custom_id_for(input)
  "extraction_review:#{AtlasBatch.safe_slug(input.fetch("extraction_path"), fallback: "record")}"
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
        "name" => "atlas_extraction_review",
        "strict" => true,
        "schema" => extraction_review_response_schema
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
AtlasBatch.die("Prompt template not found: #{AtlasBatch.relative_path(prompt_path)}", 66) unless File.file?(prompt_path)

source_path_lookup = coverage_source_paths(options)
taxonomy_context = load_taxonomy_context
prompt = File.read(prompt_path)

inputs = []
Dir.glob(File.join(AtlasBatch::ROOT, options[:extraction_glob])).sort.each do |path|
  record = AtlasBatch.load_yaml(path)
  next unless record.is_a?(Hash)
  next if source_path_lookup && !source_path_lookup[record["source_text_path"]]
  next if options[:reviewer_statuses].any? && !options[:reviewer_statuses].include?(record.dig("reviewer_status", "status").to_s)

  inputs << review_input_for(path, record, taxonomy_context)
end
inputs = inputs.first(options[:limit]) if options[:limit]
AtlasBatch.die("No extraction review inputs selected", 66) if inputs.empty?

too_long = inputs.select { |input| JSON.generate(input).length > options[:max_input_chars] }
if too_long.any?
  examples = too_long.first(10).map { |input| "#{input.fetch("extraction_path")} chars=#{JSON.generate(input).length}" }
  AtlasBatch.die("Extraction review input(s) exceed --max-input-chars #{options[:max_input_chars]}:\n#{examples.join("\n")}", 65)
end

requests = inputs.map do |input|
  {
    "custom_id" => custom_id_for(input),
    "method" => "POST",
    "url" => options.fetch(:endpoint),
    "body" => request_body(input, prompt, options)
  }
end

request_map = inputs.map do |input|
  {
    "custom_id" => custom_id_for(input),
    "review_id" => input.fetch("review_id"),
    "extraction_path" => input.fetch("extraction_path"),
    "record_id" => input["record_id"],
    "source_text_path" => input["source_text_path"],
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

request_map_path = File.join(AtlasBatch.batch_dir(run_id), "extraction-review-request-map.jsonl")
AtlasBatch.write_jsonl(request_map_path, request_map, force: options[:force])

index_path = File.join(requests_dir, "index.yml")
request_index = {
  "batch_request_index_version" => "1",
  "run_id" => run_id,
  "created_at" => AtlasBatch.utc_now,
  "updated_at" => AtlasBatch.utc_now,
  "pipeline" => "extraction_review",
  "endpoint" => options[:endpoint],
  "model" => options[:model],
  "prompt_path" => AtlasBatch.relative_path(prompt_path),
  "request_map_path" => AtlasBatch.relative_path(request_map_path),
  "coverage_path" => options[:coverage_path],
  "coverage_statuses" => options[:coverage_statuses],
  "coverage_priorities" => options[:coverage_priorities],
  "reviewer_statuses" => options[:reviewer_statuses],
  "shards" => shard_entries
}
AtlasBatch.write_yaml(index_path, request_index)

manifest["pipeline"] = "extraction_review"
manifest["status"] = "requests_prepared"
manifest["config"] ||= {}
manifest["config"]["extraction_review_request_generation"] = {
  "model" => options[:model],
  "endpoint" => options[:endpoint],
  "prompt_path" => AtlasBatch.relative_path(prompt_path),
  "extraction_glob" => options[:extraction_glob],
  "coverage_path" => options[:coverage_path],
  "coverage_statuses" => options[:coverage_statuses],
  "coverage_priorities" => options[:coverage_priorities],
  "reviewer_statuses" => options[:reviewer_statuses],
  "limit" => options[:limit],
  "max_input_chars" => options[:max_input_chars],
  "max_output_tokens" => options[:max_output_tokens],
  "temperature" => options[:temperature],
  "reasoning_effort" => options[:reasoning_effort],
  "max_requests_per_shard" => options[:max_requests_per_shard],
  "max_bytes_per_shard" => options[:max_bytes_per_shard]
}
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["artifacts"]["extraction_review_request_map_path"] = AtlasBatch.relative_path(request_map_path)
manifest["counts"] ||= {}
manifest["counts"]["review_requests_prepared"] = inputs.length
manifest["counts"]["request_shards"] = shard_entries.length
AtlasBatch.save_manifest(manifest)

puts "prepared #{inputs.length} extraction review request(s) in #{shard_entries.length} shard(s)"
puts "wrote #{AtlasBatch.relative_path(index_path)}"
