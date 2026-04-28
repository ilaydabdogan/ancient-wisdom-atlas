#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

options = {
  output_dir: nil,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_ingest_extraction_review_results.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Extraction review batch run id") { |value| options[:run_id] = value }
  parser.on("--output-dir PATH", "Review output directory") { |value| options[:output_dir] = value }
  parser.on("--force", "Replace changed review files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

REQUIRED_TOP_LEVEL = %w[
  review_id extraction_path record_id source_text_path overall_decision quality_flags
  motif_reviews comparison_claim_reviews suggested_taxonomy_additions pattern_links
  caution_notes open_questions reviewer_status
].freeze

ARRAY_FIELDS = %w[
  quality_flags motif_reviews comparison_claim_reviews suggested_taxonomy_additions
  pattern_links caution_notes open_questions
].freeze

def load_request_index(manifest)
  path = AtlasBatch.project_path(manifest.dig("artifacts", "requests_index_path").to_s)
  AtlasBatch.die("requests index not found; run scripts/batch_prepare_extraction_review_requests.rb first", 66) unless File.file?(path)

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

def validate_review(review)
  errors = []
  REQUIRED_TOP_LEVEL.each do |key|
    errors << "missing #{key}" unless review.key?(key)
  end
  ARRAY_FIELDS.each do |key|
    errors << "#{key} must be an array" unless review[key].is_a?(Array)
  end
  errors << "reviewer_status must be an object" unless review["reviewer_status"].is_a?(Hash)
  errors
end

def normalize_review(review, mapping, manifest, request_index)
  review["review_id"] = mapping.fetch("review_id")
  review["extraction_path"] = mapping.fetch("extraction_path")
  review["record_id"] = mapping["record_id"].to_s
  review["source_text_path"] = mapping["source_text_path"].to_s

  ARRAY_FIELDS.each do |key|
    review[key] = [] unless review[key].is_a?(Array)
  end

  review["reviewer_status"] = {
    "status" => review.dig("reviewer_status", "status").to_s.empty? ? "needs_human_review" : review.dig("reviewer_status", "status"),
    "reviewer" => review.dig("reviewer_status", "reviewer").to_s,
    "reviewed_at" => review.dig("reviewer_status", "reviewed_at").to_s,
    "notes" => review.dig("reviewer_status", "notes").to_s
  }
  review["reviewed_by"] = "openai_batch:#{request_index["model"] || manifest.dig("config", "extraction_review_request_generation", "model") || "unknown"}"
  review["reviewed_at"] = Date.today.iso8601
  review["batch"] = {
    "run_id" => manifest.fetch("run_id"),
    "custom_id" => mapping.fetch("custom_id"),
    "input_sha256" => mapping["input_sha256"]
  }
  review
end

def merge_by_review_id(existing, incoming)
  merged = {}
  existing.each { |record| merged[record["review_id"]] = record if record["review_id"] }
  incoming.each { |record| merged[record["review_id"]] = record if record["review_id"] }
  merged.values.sort_by { |record| record["review_id"] }
end

def review_output_path(output_dir, review)
  filename = "#{AtlasBatch.safe_filename(review.fetch("review_id"))}.yml"
  File.join(output_dir, "records", filename)
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)
_index_path, request_index = load_request_index(manifest)
request_map_path = AtlasBatch.project_path(manifest.dig("artifacts", "extraction_review_request_map_path").to_s)
AtlasBatch.die("extraction review request map not found: #{AtlasBatch.relative_path(request_map_path)}", 66) unless File.file?(request_map_path)

request_map = AtlasBatch.read_jsonl(request_map_path).to_h { |record| [record.fetch("custom_id"), record] }
output_dir = AtlasBatch.project_path(options[:output_dir] || File.join("data", "reviews", "extraction-quality", run_id))
reviews_jsonl_path = File.join(output_dir, "reviews.jsonl")
manifest_path = File.join(output_dir, "manifest.yml")
ingest_index_path = File.join(AtlasBatch.batch_dir(run_id), "extraction-review-ingested-results.jsonl")

existing_reviews = File.file?(reviews_jsonl_path) ? AtlasBatch.read_jsonl(reviews_jsonl_path) : []
ingest_records = File.file?(ingest_index_path) ? AtlasBatch.read_jsonl(ingest_index_path) : []
new_reviews = []
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
        { "custom_id" => custom_id, "status" => "failed", "error" => "custom_id missing from extraction review request map", "updated_at" => AtlasBatch.utc_now },
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
      normalized = normalize_review(parsed, mapping, manifest, request_index)
      validation_errors = validate_review(normalized)
      raise validation_errors.join("; ") if validation_errors.any?

      yaml = "#{YAML.dump(normalized)}\n"
      review_path = review_output_path(output_dir, normalized)
      result = AtlasBatch.write_if_changed(review_path, yaml, force: options[:force])
      new_reviews << normalized

      ingest_records = AtlasBatch.append_unique(
        ingest_records,
        {
          "custom_id" => custom_id,
          "status" => "ingested",
          "review_id" => normalized.fetch("review_id"),
          "output_path" => AtlasBatch.relative_path(review_path),
          "review_sha256" => AtlasBatch.sha256_text(yaml),
          "updated_at" => AtlasBatch.utc_now
        },
        "custom_id"
      )

      status = result == :unchanged ? "unchanged" : "ingested"
      puts "#{status} #{custom_id} -> #{AtlasBatch.relative_path(review_path)}"
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

merged_reviews = merge_by_review_id(existing_reviews, new_reviews)
AtlasBatch.write_jsonl(reviews_jsonl_path, merged_reviews, force: options[:force] || new_reviews.any?)
AtlasBatch.write_jsonl(ingest_index_path, ingest_records, force: true)

collection_manifest = {
  "extraction_review_collection_version" => "1",
  "run_id" => run_id,
  "pipeline" => "extraction_review",
  "model" => request_index["model"],
  "review_count" => merged_reviews.length,
  "reviews_jsonl_path" => AtlasBatch.relative_path(reviews_jsonl_path),
  "request_map_path" => AtlasBatch.relative_path(request_map_path),
  "updated_at" => AtlasBatch.utc_now
}
AtlasBatch.write_yaml(manifest_path, collection_manifest)

manifest["status"] = "extraction_reviews_ingested" if failed.zero? && new_reviews.any?
manifest["artifacts"]["extraction_review_results_path"] = AtlasBatch.relative_path(reviews_jsonl_path)
manifest["artifacts"]["extraction_review_collection_manifest_path"] = AtlasBatch.relative_path(manifest_path)
manifest["artifacts"]["extraction_review_ingested_results_path"] = AtlasBatch.relative_path(ingest_index_path)
manifest["counts"] ||= {}
manifest["counts"]["extraction_reviews_ingested"] = merged_reviews.length
manifest["counts"]["failed_extraction_review_ingestions"] = ingest_records.count { |record| record["status"] == "failed" }
manifest["state"]["last_extraction_review_ingest_at"] = AtlasBatch.utc_now
AtlasBatch.save_manifest(manifest)

puts "extraction review records total=#{merged_reviews.length}, new=#{new_reviews.length}, failed=#{failed}"
exit 1 if failed.positive?
