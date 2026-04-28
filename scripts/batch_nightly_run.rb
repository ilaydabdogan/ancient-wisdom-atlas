#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "optparse"
require_relative "batch_common"

DEFAULT_RUN_ID = "motif-extraction-#{Date.today.iso8601}-nightly"
TERMINAL_STATUSES = %w[completed failed expired cancelled canceled].freeze

options = {
  run_id: DEFAULT_RUN_ID,
  mode: "prepare",
  glob: "texts/public-domain/**/*.md",
  max_chars: 6_000,
  min_chars: 500,
  model: ENV.fetch("OPENAI_BATCH_MODEL", "gpt-5.5"),
  reasoning_effort: ENV.fetch("OPENAI_BATCH_REASONING_EFFORT", "medium"),
  max_output_tokens: 12_000,
  max_requests_per_shard: 500,
  max_bytes_per_shard: 180 * 1024 * 1024,
  completion_window: AtlasBatch::DEFAULT_COMPLETION_WINDOW,
  poll_seconds: 900,
  max_polls: 96,
  force: false,
  canary: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_nightly_run.rb [options]"
  parser.on("--run-id RUN_ID", "Batch run id, default: #{DEFAULT_RUN_ID}") { |value| options[:run_id] = value }
  parser.on("--mode MODE", "prepare, submit, watch, all; default: prepare") { |value| options[:mode] = value }
  parser.on("--glob GLOB", "Canonical text glob") { |value| options[:glob] = value }
  parser.on("--limit N", Integer, "Limit passage count; useful for canaries") { |value| options[:limit] = value }
  parser.on("--max-chars N", Integer, "Segment max characters") { |value| options[:max_chars] = value }
  parser.on("--min-chars N", Integer, "Segment min characters") { |value| options[:min_chars] = value }
  parser.on("--model MODEL", "OpenAI model id") { |value| options[:model] = value }
  parser.on("--reasoning-effort EFFORT", "Responses reasoning effort") { |value| options[:reasoning_effort] = value }
  parser.on("--max-output-tokens N", Integer, "Responses max_output_tokens") { |value| options[:max_output_tokens] = value }
  parser.on("--max-requests-per-shard N", Integer, "Request count per shard") { |value| options[:max_requests_per_shard] = value }
  parser.on("--max-bytes-per-shard N", Integer, "Byte limit per shard") { |value| options[:max_bytes_per_shard] = value }
  parser.on("--skip-ingested-from-run-id RUN_ID", "Skip custom_ids already ingested by a prior run") { |value| options[:skip_ingested_from_run_id] = value }
  parser.on("--completion-window WINDOW", "Batch completion window") { |value| options[:completion_window] = value }
  parser.on("--poll-seconds N", Integer, "Seconds between watch polls") { |value| options[:poll_seconds] = value }
  parser.on("--max-polls N", Integer, "Maximum watch polls") { |value| options[:max_polls] = value }
  parser.on("--canary", "Use a small canary configuration unless explicitly overridden") { options[:canary] = true }
  parser.on("--force", "Replace generated local files where supported") { options[:force] = true }
end.parse!

AtlasBatch.die("--mode must be one of prepare, submit, watch, all", 64) unless %w[prepare submit watch all].include?(options[:mode])
AtlasBatch.die("--poll-seconds must be positive", 64) unless options[:poll_seconds].positive?
AtlasBatch.die("--max-polls must be positive", 64) unless options[:max_polls].positive?

if options[:canary]
  options[:run_id] = "#{options[:run_id]}-canary" if options[:run_id] == DEFAULT_RUN_ID
  options[:limit] ||= 20
  options[:max_requests_per_shard] = [options[:max_requests_per_shard], 20].min
end

def run_stage(command)
  puts "==> #{command.join(' ')}"
  success = system(*command)
  AtlasBatch.die("stage failed: #{command.join(' ')}") unless success
end

def require_api_key!
  AtlasBatch.die("OPENAI_API_KEY is required for submit/watch modes; set it in your shell, not in repo files") if ENV["OPENAI_API_KEY"].to_s.strip.empty?
end

def request_index_for(run_id)
  manifest = AtlasBatch.load_manifest(run_id)
  path = AtlasBatch.project_path(manifest.dig("artifacts", "requests_index_path").to_s)
  AtlasBatch.die("requests index not found for #{run_id}; run --mode prepare first", 66) unless File.file?(path)

  AtlasBatch.load_yaml(path)
end

def terminal?(run_id)
  index = request_index_for(run_id)
  shards = index.fetch("shards", [])
  return false if shards.empty?

  shards.all? do |shard|
    status = shard.fetch("status", "not_submitted")
    TERMINAL_STATUSES.include?(status)
  end
end

def prepare(options)
  segment_args = [
    "ruby", "scripts/batch_segment_passages.rb",
    "--run-id", options.fetch(:run_id),
    "--glob", options.fetch(:glob),
    "--max-chars", options.fetch(:max_chars).to_s,
    "--min-chars", options.fetch(:min_chars).to_s
  ]
  segment_args += ["--limit", options[:limit].to_s] if options[:limit]
  segment_args << "--force" if options[:force]

  prepare_args = [
    "ruby", "scripts/batch_prepare_motif_requests.rb",
    "--run-id", options.fetch(:run_id),
    "--model", options.fetch(:model),
    "--reasoning-effort", options.fetch(:reasoning_effort),
    "--max-output-tokens", options.fetch(:max_output_tokens).to_s,
    "--max-requests-per-shard", options.fetch(:max_requests_per_shard).to_s,
    "--max-bytes-per-shard", options.fetch(:max_bytes_per_shard).to_s
  ]
  prepare_args += ["--skip-ingested-from-run-id", options[:skip_ingested_from_run_id]] if options[:skip_ingested_from_run_id]
  prepare_args << "--force" if options[:force]

  run_stage(segment_args)
  run_stage(prepare_args)
end

def submit(options)
  require_api_key!
  base = ["--run-id", options.fetch(:run_id)]
  run_stage(["ruby", "scripts/batch_upload_inputs.rb", *base])
  run_stage(["ruby", "scripts/batch_create_jobs.rb", *base, "--completion-window", options.fetch(:completion_window)])
  run_stage(["ruby", "scripts/batch_status.rb", *base])
end

def watch(options)
  require_api_key!
  base = ["--run-id", options.fetch(:run_id)]

  1.upto(options.fetch(:max_polls)) do |poll|
    puts "nightly watch poll #{poll}/#{options.fetch(:max_polls)} for #{options.fetch(:run_id)}"
    run_stage(["ruby", "scripts/batch_status.rb", *base])
    run_stage(["ruby", "scripts/batch_download_results.rb", *base])
    run_stage(["ruby", "scripts/batch_ingest_motif_results.rb", *base])

    if terminal?(options.fetch(:run_id))
      puts "all shards reached terminal status"
      return
    end

    sleep options.fetch(:poll_seconds)
  end

  puts "watch reached max polls; rerun --mode watch to continue"
end

case options.fetch(:mode)
when "prepare"
  prepare(options)
when "submit"
  submit(options)
when "watch"
  watch(options)
when "all"
  prepare(options)
  submit(options)
  watch(options)
end
