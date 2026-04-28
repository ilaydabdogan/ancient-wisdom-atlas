#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

options = {
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_download_results.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--shard SHARD_ID", "Download one shard") { |value| options[:shard_id] = value }
  parser.on("--force", "Replace already downloaded files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

def load_request_index(manifest)
  path = AtlasBatch.project_path(manifest.dig("artifacts", "requests_index_path").to_s)
  AtlasBatch.die("requests index not found; run scripts/batch_prepare_motif_requests.rb first", 66) unless File.file?(path)

  [path, AtlasBatch.load_yaml(path)]
end

def download_file(client, file_id, output_path, force:)
  if File.file?(output_path) && !force
    return :skipped
  end

  content = client.download_file(file_id)
  FileUtils.mkdir_p(File.dirname(output_path))
  File.binwrite(output_path, content)
  :downloaded
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)
index_path, request_index = load_request_index(manifest)
client = AtlasBatch::OpenAIClient.new
results_dir = File.join(AtlasBatch.batch_dir(run_id), "results")
downloaded = 0
skipped = 0

request_index.fetch("shards", []).each do |shard|
  next if options[:shard_id] && shard.fetch("shard_id") != options[:shard_id]
  next unless shard["batch_id"]

  response = client.get_json("batches/#{URI.encode_www_form_component(shard.fetch("batch_id"))}")
  shard["batch"] = response
  shard["status"] = response.fetch("status", shard["status"])
  shard["output_file_id"] = response["output_file_id"]
  shard["error_file_id"] = response["error_file_id"]
  shard["last_checked_at"] = AtlasBatch.utc_now

  {
    "output" => shard["output_file_id"],
    "errors" => shard["error_file_id"]
  }.each do |kind, file_id|
    next if file_id.to_s.empty?

    output_path = File.join(results_dir, "#{shard.fetch("shard_id")}.#{kind}.jsonl")
    result = download_file(client, file_id, output_path, force: options[:force])
    shard["#{kind}_path"] = AtlasBatch.relative_path(output_path)
    shard["#{kind}_sha256"] = AtlasBatch.sha256_file(output_path) if File.file?(output_path)
    if result == :downloaded
      downloaded += 1
      puts "downloaded #{kind} for #{shard.fetch("shard_id")} -> #{AtlasBatch.relative_path(output_path)}"
    else
      skipped += 1
      puts "skip existing #{AtlasBatch.relative_path(output_path)}"
    end
  end
end

request_index["updated_at"] = AtlasBatch.utc_now
AtlasBatch.write_yaml(index_path, request_index)

manifest["status"] = downloaded.positive? ? "results_downloaded" : manifest["status"]
manifest["artifacts"]["results_dir"] = AtlasBatch.relative_path(results_dir)
manifest["state"]["last_download_at"] = AtlasBatch.utc_now if downloaded.positive?
AtlasBatch.save_manifest(manifest)

puts "downloaded #{downloaded} file(s), skipped #{skipped}"
