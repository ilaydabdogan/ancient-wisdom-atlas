#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

options = {
  output_dir: nil,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_ingest_embedding_results.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Embedding batch run id") { |value| options[:run_id] = value }
  parser.on("--output-dir PATH", "Embedding output directory") { |value| options[:output_dir] = value }
  parser.on("--force", "Replace existing embedding JSONL") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

def load_request_index(manifest)
  path = AtlasBatch.project_path(manifest.dig("artifacts", "requests_index_path").to_s)
  AtlasBatch.die("requests index not found; run scripts/batch_prepare_embedding_requests.rb first", 66) unless File.file?(path)

  [path, AtlasBatch.load_yaml(path)]
end

def embedding_body(response)
  body = response.fetch("body")
  data = body["data"]
  raise "embedding response body has no data array" unless data.is_a?(Array) && data.first.is_a?(Hash)

  [body, data.first]
end

def merge_by_custom_id(existing, incoming)
  merged = {}
  existing.each { |record| merged[record["custom_id"]] = record if record["custom_id"] }
  incoming.each { |record| merged[record["custom_id"]] = record if record["custom_id"] }
  merged.values.sort_by { |record| record["custom_id"] }
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)
_index_path, request_index = load_request_index(manifest)
request_map_path = AtlasBatch.project_path(manifest.dig("artifacts", "embedding_request_map_path").to_s)
AtlasBatch.die("embedding request map not found: #{AtlasBatch.relative_path(request_map_path)}", 66) unless File.file?(request_map_path)

request_map = AtlasBatch.read_jsonl(request_map_path).each_with_object({}) do |record, map|
  map[record.fetch("custom_id")] = record
end

output_dir = AtlasBatch.project_path(options[:output_dir] || File.join("data", "embeddings", run_id))
embeddings_path = File.join(output_dir, "embeddings.jsonl")
manifest_path = File.join(output_dir, "manifest.yml")
ingest_index_path = File.join(AtlasBatch.batch_dir(run_id), "embedding-ingested-results.jsonl")

existing_embeddings = File.file?(embeddings_path) ? AtlasBatch.read_jsonl(embeddings_path) : []
ingest_records = File.file?(ingest_index_path) ? AtlasBatch.read_jsonl(ingest_index_path) : []
new_embeddings = []
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
        { "custom_id" => custom_id, "status" => "failed", "error" => "custom_id missing from embedding request map", "updated_at" => AtlasBatch.utc_now },
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

    begin
      body, first_embedding = embedding_body(response)
      vector = first_embedding["embedding"]
      raise "embedding vector missing or empty" unless vector.is_a?(Array) && vector.any?

      record = {
        "embedding_id" => mapping.fetch("embedding_id"),
        "custom_id" => custom_id,
        "source_type" => mapping.fetch("source_type"),
        "source_path" => mapping["source_path"],
        "source_text_path" => mapping["source_text_path"],
        "source_text_id" => mapping["source_text_id"],
        "source_title" => mapping["source_title"],
        "locator" => mapping["locator"],
        "content_sha256" => mapping.fetch("content_sha256"),
        "text_sha256" => mapping.fetch("text_sha256"),
        "metadata" => mapping.fetch("metadata", {}),
        "model" => body["model"] || request_index["model"],
        "dimensions" => vector.length,
        "encoding_format" => request_index["encoding_format"],
        "embedding" => vector,
        "usage" => body["usage"] || {},
        "batch" => {
          "run_id" => run_id,
          "batch_id" => shard["batch_id"],
          "shard_id" => shard.fetch("shard_id"),
          "output_path" => output_path
        },
        "created_at" => AtlasBatch.utc_now
      }
      new_embeddings << record
      ingest_records = AtlasBatch.append_unique(
        ingest_records,
        {
          "custom_id" => custom_id,
          "status" => "ingested",
          "embedding_id" => mapping.fetch("embedding_id"),
          "dimensions" => vector.length,
          "updated_at" => AtlasBatch.utc_now
        },
        "custom_id"
      )
      puts "ingested #{custom_id} dimensions=#{vector.length}"
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

merged_embeddings = merge_by_custom_id(existing_embeddings, new_embeddings)
AtlasBatch.write_jsonl(embeddings_path, merged_embeddings, force: options[:force] || new_embeddings.any?)
AtlasBatch.write_jsonl(ingest_index_path, ingest_records, force: true)

embedding_manifest = {
  "embedding_collection_version" => "1",
  "run_id" => run_id,
  "pipeline" => "embeddings",
  "model" => request_index["model"],
  "encoding_format" => request_index["encoding_format"],
  "dimensions" => request_index["dimensions"],
  "source" => request_index["source"],
  "embedding_count" => merged_embeddings.length,
  "embeddings_path" => AtlasBatch.relative_path(embeddings_path),
  "request_map_path" => AtlasBatch.relative_path(request_map_path),
  "updated_at" => AtlasBatch.utc_now
}
AtlasBatch.write_yaml(manifest_path, embedding_manifest)

manifest["status"] = "embeddings_ingested" if failed.zero? && new_embeddings.any?
manifest["artifacts"]["embedding_results_path"] = AtlasBatch.relative_path(embeddings_path)
manifest["artifacts"]["embedding_collection_manifest_path"] = AtlasBatch.relative_path(manifest_path)
manifest["artifacts"]["embedding_ingested_results_path"] = AtlasBatch.relative_path(ingest_index_path)
manifest["counts"] ||= {}
manifest["counts"]["embeddings_ingested"] = merged_embeddings.length
manifest["counts"]["failed_embedding_ingestions"] = ingest_records.count { |record| record["status"] == "failed" }
manifest["state"]["last_embedding_ingest_at"] = AtlasBatch.utc_now
AtlasBatch.save_manifest(manifest)

puts "embedding records total=#{merged_embeddings.length}, new=#{new_embeddings.length}, failed=#{failed}"
exit 1 if failed.positive?
