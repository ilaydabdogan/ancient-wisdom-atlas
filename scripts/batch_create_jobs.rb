#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

options = {
  completion_window: AtlasBatch::DEFAULT_COMPLETION_WINDOW,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_create_jobs.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--shard SHARD_ID", "Create only one shard job") { |value| options[:shard_id] = value }
  parser.on("--completion-window WINDOW", "Batch completion window; currently 24h") { |value| options[:completion_window] = value }
  parser.on("--force", "Create a new job even if batch_id is already recorded") { options[:force] = true }
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

created = 0
skipped = 0

request_index.fetch("shards", []).each do |shard|
  next if options[:shard_id] && shard.fetch("shard_id") != options[:shard_id]

  AtlasBatch.die("#{shard.fetch("shard_id")} has no input_file_id; upload inputs first", 65) unless shard["input_file_id"]

  if shard["batch_id"] && !options[:force]
    skipped += 1
    puts "skip #{shard.fetch("shard_id")} already has batch #{shard.fetch("batch_id")}"
    next
  end

  payload = {
    "input_file_id" => shard.fetch("input_file_id"),
    "endpoint" => shard.fetch("endpoint", request_index.fetch("endpoint")),
    "completion_window" => options.fetch(:completion_window),
    "metadata" => {
      "repo" => "ancient-wisdom-atlas",
      "run_id" => run_id,
      "shard_id" => shard.fetch("shard_id"),
      "pipeline" => manifest.fetch("pipeline", "motif_extraction")
    }
  }

  response = client.post_json("batches", payload)
  shard["batch_id"] = response.fetch("id")
  shard["batch"] = response
  shard["batch_created_at"] = AtlasBatch.utc_now
  shard["status"] = response.fetch("status", "submitted")
  created += 1
  puts "created #{shard.fetch("shard_id")} -> #{response.fetch("id")} (#{shard.fetch("status")})"
end

request_index["updated_at"] = AtlasBatch.utc_now
AtlasBatch.write_yaml(index_path, request_index)

manifest["status"] = created.positive? ? "jobs_created" : manifest["status"]
manifest["counts"] ||= {}
manifest["counts"]["batch_jobs_created"] = request_index.fetch("shards", []).count { |shard| shard["batch_id"] }
AtlasBatch.save_manifest(manifest)

puts "created #{created} job(s), skipped #{skipped}"
