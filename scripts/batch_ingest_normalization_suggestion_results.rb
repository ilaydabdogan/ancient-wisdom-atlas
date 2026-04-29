#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

options = {
  output_dir: nil,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_ingest_normalization_suggestion_results.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Normalization suggestion batch run id") { |value| options[:run_id] = value }
  parser.on("--output-dir PATH", "Normalization suggestion output directory") { |value| options[:output_dir] = value }
  parser.on("--force", "Replace changed suggestion files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

REQUIRED_BATCH_FIELDS = %w[
  suggestion_batch_id gap_audit_path normalization_path suggestions batch_notes reviewer_status
].freeze

REQUIRED_SUGGESTION_FIELDS = %w[
  suggestion_id motif_id label occurrences traditions review_bucket_id suggested_action
  suggested_group_id suggested_group_label relationship confidence rationale cautions
  suggested_aliases suggested_new_group
].freeze

VALID_ACTIONS = %w[map_to_existing_group new_group_candidate needs_human_review exclude_from_pattern_queries].freeze
VALID_RELATIONSHIPS = %w[alias child narrower_than broader_label symbolic_variant functional_variant ritual_variant role_variant over_specific_label meta_artifact uncertain].freeze
VALID_CONFIDENCE = %w[low medium high].freeze

def load_request_index(manifest)
  path = AtlasBatch.project_path(manifest.dig("artifacts", "requests_index_path").to_s)
  AtlasBatch.die("requests index not found; run scripts/batch_prepare_normalization_suggestion_requests.rb first", 66) unless File.file?(path)

  [path, AtlasBatch.load_yaml(path)]
end

def response_text(body)
  return body["output_text"] if body["output_text"].is_a?(String)

  Array(body["output"]).each do |output_item|
    Array(output_item["content"]).each do |content|
      return content["text"] if content["text"].is_a?(String)
      return content["content"] if content["content"].is_a?(String)
    end
  end

  choice = body.dig("choices", 0, "message", "content")
  return choice if choice.is_a?(String)

  nil
end

def parse_json_text(text)
  cleaned = text.to_s.strip
  cleaned = cleaned.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
  JSON.parse(cleaned)
rescue JSON::ParserError
  if (match = cleaned.match(/\{.*\}/m))
    JSON.parse(match[0])
  else
    raise
  end
end

def default_new_group
  {
    "id" => "",
    "label" => "",
    "description" => "",
    "parent_group_ids" => [],
    "related_group_ids" => [],
    "reason_existing_groups_insufficient" => ""
  }
end

def public_suggestion_id(value)
  value.to_s.gsub(/sk-([A-Za-z0-9_-]{20,})/, 'sk_\1')
end

def default_suggestion(motif)
  {
    "suggestion_id" => public_suggestion_id(motif.fetch("suggestion_id")),
    "motif_id" => motif.fetch("motif_id"),
    "label" => motif["label"].to_s,
    "occurrences" => motif["occurrences"].to_i,
    "traditions" => Array(motif["traditions"]).map(&:to_s).sort,
    "review_bucket_id" => motif["review_bucket_id"].to_s,
    "suggested_action" => "needs_human_review",
    "suggested_group_id" => "",
    "suggested_group_label" => "",
    "relationship" => "uncertain",
    "confidence" => "low",
    "rationale" => "No usable model suggestion was returned for this motif.",
    "cautions" => "Needs human review.",
    "suggested_aliases" => [],
    "suggested_new_group" => default_new_group
  }
end

def normalize_suggestion(suggestion, motif)
  normalized = default_suggestion(motif).merge(suggestion.is_a?(Hash) ? suggestion : {})
  normalized["suggestion_id"] = public_suggestion_id(motif.fetch("suggestion_id"))
  normalized["motif_id"] = motif.fetch("motif_id")
  normalized["label"] = motif["label"].to_s
  normalized["occurrences"] = motif["occurrences"].to_i
  normalized["traditions"] = Array(motif["traditions"]).map(&:to_s).sort
  normalized["review_bucket_id"] = motif["review_bucket_id"].to_s
  normalized["suggested_action"] = VALID_ACTIONS.include?(normalized["suggested_action"]) ? normalized["suggested_action"] : "needs_human_review"
  normalized["relationship"] = VALID_RELATIONSHIPS.include?(normalized["relationship"]) ? normalized["relationship"] : "uncertain"
  normalized["confidence"] = VALID_CONFIDENCE.include?(normalized["confidence"]) ? normalized["confidence"] : "low"
  normalized["suggested_group_id"] = normalized["suggested_group_id"].to_s
  normalized["suggested_group_label"] = normalized["suggested_group_label"].to_s
  normalized["rationale"] = normalized["rationale"].to_s
  normalized["cautions"] = normalized["cautions"].to_s
  normalized["suggested_aliases"] = Array(normalized["suggested_aliases"]).map(&:to_s)
  normalized["suggested_new_group"] = default_new_group.merge(normalized["suggested_new_group"].is_a?(Hash) ? normalized["suggested_new_group"] : {})
  normalized["suggested_new_group"]["parent_group_ids"] = Array(normalized["suggested_new_group"]["parent_group_ids"]).map(&:to_s)
  normalized["suggested_new_group"]["related_group_ids"] = Array(normalized["suggested_new_group"]["related_group_ids"]).map(&:to_s)
  normalized
end

def normalize_batch(parsed, mapping, manifest, request_index)
  suggestions_by_id = {}
  suggestions_by_motif = {}
  Array(parsed["suggestions"]).each do |suggestion|
    next unless suggestion.is_a?(Hash)

    suggestions_by_id[suggestion["suggestion_id"].to_s] = suggestion if suggestion["suggestion_id"]
    suggestions_by_motif[suggestion["motif_id"].to_s] = suggestion if suggestion["motif_id"]
  end

  suggestions = mapping.fetch("motifs").map do |motif|
    normalize_suggestion(
      suggestions_by_id[motif.fetch("suggestion_id")] || suggestions_by_motif[motif.fetch("motif_id")] || {},
      motif
    )
  end

  reviewer_status = parsed["reviewer_status"].is_a?(Hash) ? parsed["reviewer_status"] : {}
  {
    "suggestion_batch_id" => mapping.fetch("suggestion_batch_id"),
    "gap_audit_path" => mapping.fetch("gap_audit_path"),
    "normalization_path" => mapping.fetch("normalization_path"),
    "taxonomy_path" => mapping["taxonomy_path"].to_s,
    "suggestions" => suggestions,
    "batch_notes" => Array(parsed["batch_notes"]).map(&:to_s),
    "reviewer_status" => {
      "status" => reviewer_status["status"].to_s.empty? ? "needs_human_review" : reviewer_status["status"].to_s,
      "reviewer" => reviewer_status["reviewer"].to_s,
      "reviewed_at" => reviewer_status["reviewed_at"].to_s,
      "notes" => reviewer_status["notes"].to_s
    },
    "suggested_by" => "openai_batch:#{request_index["model"] || manifest.dig("config", "normalization_suggestion_request_generation", "model") || "unknown"}",
    "suggested_at" => Date.today.iso8601,
    "batch" => {
      "run_id" => manifest.fetch("run_id"),
      "custom_id" => mapping.fetch("custom_id"),
      "input_sha256" => mapping["input_sha256"]
    }
  }
end

def validate_batch(record)
  errors = []
  REQUIRED_BATCH_FIELDS.each do |key|
    errors << "missing #{key}" unless record.key?(key)
  end
  errors << "suggestions must be an array" unless record["suggestions"].is_a?(Array)
  errors << "batch_notes must be an array" unless record["batch_notes"].is_a?(Array)
  errors << "reviewer_status must be an object" unless record["reviewer_status"].is_a?(Hash)

  Array(record["suggestions"]).each do |suggestion|
    REQUIRED_SUGGESTION_FIELDS.each do |key|
      errors << "suggestion #{suggestion["motif_id"] || "unknown"} missing #{key}" unless suggestion.key?(key)
    end
    errors << "suggestion traditions must be an array" unless suggestion["traditions"].is_a?(Array)
    errors << "suggested_aliases must be an array" unless suggestion["suggested_aliases"].is_a?(Array)
    errors << "suggested_new_group must be an object" unless suggestion["suggested_new_group"].is_a?(Hash)
  end

  errors
end

def merge_by_id(existing, incoming, key)
  merged = {}
  existing.each { |record| merged[record[key]] = record if record[key] }
  incoming.each { |record| merged[record[key]] = record if record[key] }
  merged.values.sort_by { |record| record[key] }
end

def batch_output_path(output_dir, record)
  filename = "#{AtlasBatch.safe_filename(record.fetch("suggestion_batch_id"))}.yml"
  File.join(output_dir, "records", filename)
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)
_index_path, request_index = load_request_index(manifest)
request_map_path = AtlasBatch.project_path(manifest.dig("artifacts", "normalization_suggestion_request_map_path").to_s)
AtlasBatch.die("normalization suggestion request map not found: #{AtlasBatch.relative_path(request_map_path)}", 66) unless File.file?(request_map_path)

request_map = AtlasBatch.read_jsonl(request_map_path).to_h { |record| [record.fetch("custom_id"), record] }
output_dir = AtlasBatch.project_path(options[:output_dir] || File.join("data", "reviews", "normalization-suggestions", run_id))
suggestions_jsonl_path = File.join(output_dir, "suggestions.jsonl")
batches_jsonl_path = File.join(output_dir, "suggestion-batches.jsonl")
manifest_path = File.join(output_dir, "manifest.yml")
ingest_index_path = File.join(AtlasBatch.batch_dir(run_id), "normalization-suggestion-ingested-results.jsonl")

existing_batches = File.file?(batches_jsonl_path) ? AtlasBatch.read_jsonl(batches_jsonl_path) : []
existing_suggestions = File.file?(suggestions_jsonl_path) ? AtlasBatch.read_jsonl(suggestions_jsonl_path) : []
ingest_records = File.file?(ingest_index_path) ? AtlasBatch.read_jsonl(ingest_index_path) : []
new_batches = []
new_suggestions = []
failed = 0

request_index.fetch("shards", []).each do |shard|
  output_path = shard["output_path"]
  next if output_path.to_s.empty?

  AtlasBatch.read_jsonl(AtlasBatch.project_path(output_path)).each do |line|
    custom_id = line["custom_id"]
    mapping = request_map[custom_id]
    unless mapping
      failed += 1
      ingest_records = AtlasBatch.append_unique(
        ingest_records,
        { "custom_id" => custom_id, "status" => "failed", "error" => "custom_id missing from normalization suggestion request map", "updated_at" => AtlasBatch.utc_now },
        "custom_id"
      )
      next
    end

    if line["error"]
      failed += 1
      ingest_records = AtlasBatch.append_unique(
        ingest_records,
        { "custom_id" => custom_id, "status" => "failed", "error" => line["error"], "updated_at" => AtlasBatch.utc_now },
        "custom_id"
      )
      next
    end

    response = line["response"] || {}
    if response["status_code"] && response["status_code"].to_i != 200
      failed += 1
      ingest_records = AtlasBatch.append_unique(
        ingest_records,
        { "custom_id" => custom_id, "status" => "failed", "error" => response, "updated_at" => AtlasBatch.utc_now },
        "custom_id"
      )
      next
    end

    body = response["body"] || {}
    if body["status"] == "incomplete" || body["incomplete_details"]
      failed += 1
      ingest_records = AtlasBatch.append_unique(
        ingest_records,
        {
          "custom_id" => custom_id,
          "status" => "failed",
          "error" => {
            "type" => "incomplete_response",
            "response_status" => body["status"],
            "incomplete_details" => body["incomplete_details"],
            "max_output_tokens" => body["max_output_tokens"],
            "model" => body["model"]
          },
          "updated_at" => AtlasBatch.utc_now
        },
        "custom_id"
      )
      next
    end

    begin
      text = response_text(body)
      raise "empty response text" if text.to_s.strip.empty?

      parsed = parse_json_text(text)
      normalized = normalize_batch(parsed, mapping, manifest, request_index)
      validation_errors = validate_batch(normalized)
      raise validation_errors.join("; ") if validation_errors.any?

      yaml = "#{YAML.dump(normalized)}\n"
      output_path_for_record = batch_output_path(output_dir, normalized)
      result = AtlasBatch.write_if_changed(output_path_for_record, yaml, force: options[:force])
      new_batches << normalized
      new_suggestions.concat(normalized.fetch("suggestions").map do |suggestion|
        suggestion.merge(
          "suggestion_batch_id" => normalized.fetch("suggestion_batch_id"),
          "gap_audit_path" => normalized.fetch("gap_audit_path"),
          "normalization_path" => normalized.fetch("normalization_path"),
          "suggested_by" => normalized.fetch("suggested_by"),
          "suggested_at" => normalized.fetch("suggested_at"),
          "batch" => normalized.fetch("batch")
        )
      end)

      ingest_records = AtlasBatch.append_unique(
        ingest_records,
        {
          "custom_id" => custom_id,
          "status" => "ingested",
          "suggestion_batch_id" => normalized.fetch("suggestion_batch_id"),
          "output_path" => AtlasBatch.relative_path(output_path_for_record),
          "suggestion_sha256" => AtlasBatch.sha256_text(yaml),
          "updated_at" => AtlasBatch.utc_now
        },
        "custom_id"
      )

      status = result == :unchanged ? "unchanged" : "ingested"
      puts "#{status} #{custom_id} -> #{AtlasBatch.relative_path(output_path_for_record)}"
    rescue StandardError => e
      failed += 1
      ingest_records = AtlasBatch.append_unique(
        ingest_records,
        { "custom_id" => custom_id, "status" => "failed", "error" => e.message, "updated_at" => AtlasBatch.utc_now },
        "custom_id"
      )
      warn "failed #{custom_id}: #{e.message}"
    end
  end
end

merged_batches = merge_by_id(existing_batches, new_batches, "suggestion_batch_id")
merged_suggestions = merge_by_id(existing_suggestions, new_suggestions, "motif_id")
AtlasBatch.write_jsonl(batches_jsonl_path, merged_batches, force: options[:force] || new_batches.any?)
AtlasBatch.write_jsonl(suggestions_jsonl_path, merged_suggestions, force: options[:force] || new_suggestions.any?)
AtlasBatch.write_jsonl(ingest_index_path, ingest_records, force: true)

collection_manifest = {
  "normalization_suggestion_collection_version" => "1",
  "run_id" => run_id,
  "pipeline" => "normalization_suggestion",
  "model" => request_index["model"],
  "suggestion_batch_count" => merged_batches.length,
  "suggestion_count" => merged_suggestions.length,
  "suggestions_jsonl_path" => AtlasBatch.relative_path(suggestions_jsonl_path),
  "suggestion_batches_jsonl_path" => AtlasBatch.relative_path(batches_jsonl_path),
  "request_map_path" => AtlasBatch.relative_path(request_map_path),
  "updated_at" => AtlasBatch.utc_now
}
AtlasBatch.write_yaml(manifest_path, collection_manifest)

manifest["status"] = "normalization_suggestions_ingested" if failed.zero? && new_batches.any?
manifest["artifacts"]["normalization_suggestion_results_path"] = AtlasBatch.relative_path(suggestions_jsonl_path)
manifest["artifacts"]["normalization_suggestion_batches_path"] = AtlasBatch.relative_path(batches_jsonl_path)
manifest["artifacts"]["normalization_suggestion_collection_manifest_path"] = AtlasBatch.relative_path(manifest_path)
manifest["artifacts"]["normalization_suggestion_ingested_results_path"] = AtlasBatch.relative_path(ingest_index_path)
manifest["counts"] ||= {}
manifest["counts"]["normalization_suggestions_ingested"] = merged_suggestions.length
manifest["counts"]["normalization_suggestion_batches_ingested"] = merged_batches.length
manifest["counts"]["failed_normalization_suggestion_ingestions"] = ingest_records.count { |record| record["status"] == "failed" }
manifest["state"]["last_normalization_suggestion_ingest_at"] = AtlasBatch.utc_now
AtlasBatch.save_manifest(manifest)

puts "normalization suggestions total=#{merged_suggestions.length}, batches=#{merged_batches.length}, new=#{new_suggestions.length}, failed=#{failed}"
exit 1 if failed.positive?
