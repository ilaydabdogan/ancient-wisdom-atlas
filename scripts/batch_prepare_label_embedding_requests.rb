#!/usr/bin/env ruby
# frozen_string_literal: true

# Prepares embedding requests for every mapped motif LABEL (id + label,
# with its canonical family as context), at reduced dimensions — the
# substrate for within-family synonym-merge proposals.

require_relative "batch_common"

options = {
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  model: ENV.fetch("OPENAI_EMBEDDING_MODEL", "text-embedding-3-large"),
  dimensions: 512,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_label_embedding_requests.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!
AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

frequency = AtlasBatch.load_yaml(AtlasBatch.project_path(options[:frequency_index]))
requests = []
request_map = []
frequency.fetch("canonical_motifs", []).each do |group|
  family = group["canonical_motif_id"]
  group.fetch("mapped_motifs", []).each do |motif|
    custom_id = "label_embed:#{motif["motif_id"]}"
    next if request_map.any? { |r| r["custom_id"] == custom_id }

    requests << {
      "custom_id" => custom_id,
      "method" => "POST",
      "url" => "/v1/embeddings",
      "body" => {
        "model" => options[:model],
        "input" => "#{motif["label"]} (motif in family: #{group["label"]})",
        "dimensions" => options[:dimensions]
      }
    }
    request_map << { "custom_id" => custom_id, "motif_id" => motif["motif_id"], "family" => family, "occurrences" => motif["occurrence_count"] }
  end
end

run_id = options[:run_id]
requests_dir = File.join(AtlasBatch.batch_dir(run_id), "requests")
FileUtils.mkdir_p(requests_dir)
shard_entries = []
requests.each_slice(3000).with_index do |slice, index|
  shard_id = "shard-%04d" % (index + 1)
  path = File.join(requests_dir, "#{shard_id}.jsonl")
  AtlasBatch.write_jsonl(path, slice, force: options[:force])
  shard_entries << { "shard_id" => shard_id, "path" => AtlasBatch.relative_path(path), "request_count" => slice.length,
                     "bytes" => File.size(path), "sha256" => AtlasBatch.sha256_file(path),
                     "endpoint" => "/v1/embeddings", "model" => options[:model], "status" => "prepared" }
end
AtlasBatch.write_jsonl(File.join(AtlasBatch.batch_dir(run_id), "request-map.jsonl"), request_map, force: options[:force])
index_path = File.join(requests_dir, "index.yml")
AtlasBatch.write_yaml(index_path, {
  "batch_request_index_version" => "1", "run_id" => run_id,
  "created_at" => AtlasBatch.utc_now, "updated_at" => AtlasBatch.utc_now,
  "endpoint" => "/v1/embeddings", "model" => options[:model], "shards" => shard_entries
})
manifest = AtlasBatch.load_manifest(run_id)
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["status"] = "requests_prepared"
AtlasBatch.save_manifest(manifest)
puts "prepared #{requests.length} label embedding request(s) in #{shard_entries.length} shard(s)"
