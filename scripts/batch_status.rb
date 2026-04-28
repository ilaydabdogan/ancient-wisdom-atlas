#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

options = {
  refresh: true
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_status.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--shard SHARD_ID", "Inspect one shard") { |value| options[:shard_id] = value }
  parser.on("--local", "Print recorded local state without calling OpenAI") { options[:refresh] = false }
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
client = options[:refresh] ? AtlasBatch::OpenAIClient.new : nil

status_counts = Hash.new(0)

request_index.fetch("shards", []).each do |shard|
  next if options[:shard_id] && shard.fetch("shard_id") != options[:shard_id]

  if options[:refresh] && shard["batch_id"]
    response = client.get_json("batches/#{URI.encode_www_form_component(shard.fetch("batch_id"))}")
    shard["batch"] = response
    shard["status"] = response.fetch("status", shard["status"])
    shard["output_file_id"] = response["output_file_id"]
    shard["error_file_id"] = response["error_file_id"]
    shard["last_checked_at"] = AtlasBatch.utc_now
  end

  status = shard.fetch("status", "not_submitted")
  status_counts[status] += 1
  counts = shard.dig("batch", "request_counts") || {}
  puts [
    shard.fetch("shard_id"),
    "status=#{status}",
    ("batch=#{shard["batch_id"]}" if shard["batch_id"]),
    ("requests=#{counts["completed"]}/#{counts["total"]} failed=#{counts["failed"]}" if counts.any?),
    ("output_file=#{shard["output_file_id"]}" if shard["output_file_id"]),
    ("error_file=#{shard["error_file_id"]}" if shard["error_file_id"])
  ].compact.join(" ")
end

if options[:refresh]
  request_index["updated_at"] = AtlasBatch.utc_now
  AtlasBatch.write_yaml(index_path, request_index)
  manifest["state"]["last_status_check_at"] = AtlasBatch.utc_now
  manifest["state"]["batch_status_counts"] = status_counts.sort.to_h
  AtlasBatch.save_manifest(manifest)
end

puts "status counts: #{status_counts.sort.map { |status, count| "#{status}=#{count}" }.join(", ")}"
