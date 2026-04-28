#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

options = {
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_upload_inputs.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--shard SHARD_ID", "Upload only one shard") { |value| options[:shard_id] = value }
  parser.on("--force", "Upload again even if file_id is already recorded") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

def load_request_index(manifest)
  path = AtlasBatch.project_path(manifest.dig("artifacts", "requests_index_path").to_s)
  AtlasBatch.die("requests index not found; run scripts/batch_prepare_motif_requests.rb first", 66) unless File.file?(path)

  [path, AtlasBatch.load_yaml(path)]
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)
index_path, request_index = load_request_index(manifest)
client = AtlasBatch::OpenAIClient.new

uploaded = 0
skipped = 0

persist_state = lambda do
  request_index["updated_at"] = AtlasBatch.utc_now
  AtlasBatch.write_yaml(index_path, request_index)

  manifest["status"] = uploaded.positive? ? "inputs_uploaded" : manifest["status"]
  manifest["counts"] ||= {}
  manifest["counts"]["request_shards_uploaded"] = request_index.fetch("shards", []).count { |entry| entry["input_file_id"] }
  AtlasBatch.save_manifest(manifest)
end

request_index.fetch("shards", []).each do |shard|
  next if options[:shard_id] && shard.fetch("shard_id") != options[:shard_id]

  path = AtlasBatch.project_path(shard.fetch("path"))
  AtlasBatch.die("shard file missing: #{shard.fetch("path")}", 66) unless File.file?(path)

  checksum = AtlasBatch.sha256_file(path)
  if shard["input_file_id"] && shard["sha256"] == checksum && !options[:force]
    skipped += 1
    puts "skip #{shard.fetch("shard_id")} already uploaded as #{shard.fetch("input_file_id")}"
    next
  end

  response = client.upload_file(path, purpose: "batch")
  shard["input_file_id"] = response.fetch("id")
  shard["input_file"] = response
  shard["sha256"] = checksum
  shard["bytes"] = File.size(path)
  shard["uploaded_at"] = AtlasBatch.utc_now
  shard["status"] = "uploaded"
  uploaded += 1
  puts "uploaded #{shard.fetch("shard_id")} -> #{response.fetch("id")}"
  persist_state.call
end

persist_state.call

puts "uploaded #{uploaded} shard(s), skipped #{skipped}"
