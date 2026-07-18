#!/usr/bin/env ruby
# frozen_string_literal: true

# Runs a prepared batch run's request shards against the Responses API in
# real time (parallel HTTP) instead of the asynchronous Batch API. Produces
# the same results files, requests-index updates, and manifest state as
# batch_download_results.rb, so batch_ingest_* scripts work unchanged.
#
# Intended for OpenAI-compatible real-time endpoints where batch latency or
# batch quota is the bottleneck (e.g. Azure OpenAI GlobalStandard
# deployments via AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_KEY).

require_relative "batch_common"

$stdout.sync = true

options = {
  concurrency: 24,
  max_retries: 6,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_run_realtime.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--shard SHARD_ID", "Run one shard") { |value| options[:shard_id] = value }
  parser.on("--concurrency N", Integer, "Parallel requests (default 24)") { |value| options[:concurrency] = value }
  parser.on("--max-retries N", Integer, "Retries per request on 429/5xx (default 6)") { |value| options[:max_retries] = value }
  parser.on("--model MODEL", "Override body.model on every request (e.g. an Azure deployment name)") { |value| options[:model] = value }
  parser.on("--force", "Re-run shards whose output files already exist") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]
AtlasBatch.die("--concurrency must be positive", 64) unless options[:concurrency].positive?

class RealtimeClient < AtlasBatch::OpenAIClient
  RETRYABLE = [429, 500, 502, 503, 504].freeze

  def post_with_status(path, body)
    response = send(:request, :post, path, JSON.generate(body), "Content-Type" => "application/json")
    code = response.code.to_i
    parsed = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      { "raw" => response.body.to_s[0, 2000] }
    end
    [code, parsed, response["retry-after"]]
  end
end

def load_request_index(manifest)
  path = AtlasBatch.project_path(manifest.dig("artifacts", "requests_index_path").to_s)
  AtlasBatch.die("requests index not found; run a batch_prepare_* script first", 66) unless File.file?(path)

  [path, AtlasBatch.load_yaml(path)]
end

def run_request(client, request, model_override, max_retries)
  custom_id = request.fetch("custom_id")
  body = request.fetch("body")
  body = body.merge("model" => model_override) if model_override
  url = request.fetch("url", AtlasBatch::DEFAULT_ENDPOINT).sub(%r{\A/v1/}, "")

  attempt = 0
  loop do
    attempt += 1
    code, parsed, retry_after = client.post_with_status(url, body)

    if code.between?(200, 299)
      return [:ok, {
        "id" => "realtime-#{AtlasBatch.sha256_text(custom_id)[0, 16]}",
        "custom_id" => custom_id,
        "response" => { "status_code" => code, "body" => parsed },
        "error" => nil
      }]
    end

    retryable = RealtimeClient::RETRYABLE.include?(code)
    if retryable && attempt <= max_retries
      delay = retry_after.to_f.positive? ? retry_after.to_f : [2**attempt, 60].min + rand
      sleep(delay)
      next
    end

    return [:error, {
      "id" => "realtime-#{AtlasBatch.sha256_text(custom_id)[0, 16]}",
      "custom_id" => custom_id,
      "response" => { "status_code" => code, "body" => parsed },
      "error" => { "code" => code.to_s, "message" => "request failed after #{attempt} attempt(s)" }
    }]
  rescue StandardError => e
    if attempt <= max_retries
      sleep([2**attempt, 60].min + rand)
      retry
    end
    return [:error, {
      "custom_id" => custom_id,
      "response" => nil,
      "error" => { "code" => "exception", "message" => e.message.to_s[0, 500] }
    }]
  end
end

def run_shard(shard, results_dir, options)
  requests_path = AtlasBatch.project_path(shard.fetch("path"))
  requests = AtlasBatch.read_jsonl(requests_path)
  output_path = File.join(results_dir, "#{shard.fetch("shard_id")}.output.jsonl")
  errors_path = File.join(results_dir, "#{shard.fetch("shard_id")}.errors.jsonl")

  queue = Queue.new
  requests.each { |request| queue << request }
  outputs = []
  errors = []
  mutex = Mutex.new
  completed = 0

  workers = Array.new([options[:concurrency], requests.length].min.clamp(1, 256)) do
    Thread.new do
      client = RealtimeClient.new
      loop do
        request = begin
          queue.pop(true)
        rescue ThreadError
          break
        end
        kind, line = run_request(client, request, options[:model], options[:max_retries])
        mutex.synchronize do
          kind == :ok ? outputs << line : errors << line
          completed += 1
          if (completed % 50).zero? || completed == requests.length
            puts "  #{shard.fetch("shard_id")}: #{completed}/#{requests.length} (#{errors.length} errors)"
          end
        end
      end
    end
  end
  workers.each(&:join)

  order = requests.each_with_index.to_h { |request, index| [request.fetch("custom_id"), index] }
  outputs.sort_by! { |line| order.fetch(line["custom_id"], 0) }
  errors.sort_by! { |line| order.fetch(line["custom_id"], 0) }

  AtlasBatch.write_jsonl(output_path, outputs, force: true)
  shard["output_path"] = AtlasBatch.relative_path(output_path)
  shard["output_sha256"] = AtlasBatch.sha256_file(output_path)
  if errors.any?
    AtlasBatch.write_jsonl(errors_path, errors, force: true)
    shard["errors_path"] = AtlasBatch.relative_path(errors_path)
    shard["errors_sha256"] = AtlasBatch.sha256_file(errors_path)
  end
  shard["status"] = errors.empty? ? "completed" : "completed_with_errors"
  shard["runtime"] = "realtime"
  shard["request_count"] = requests.length
  shard["error_count"] = errors.length
  shard["last_checked_at"] = AtlasBatch.utc_now
  [outputs.length, errors.length]
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)
index_path, request_index = load_request_index(manifest)
results_dir = File.join(AtlasBatch.batch_dir(run_id), "results")
total_ok = 0
total_errors = 0

request_index.fetch("shards", []).each do |shard|
  next if options[:shard_id] && shard.fetch("shard_id") != options[:shard_id]

  existing = shard["output_path"].to_s
  if !options[:force] && !existing.empty? && File.file?(AtlasBatch.project_path(existing))
    puts "skip #{shard.fetch("shard_id")} (results exist; use --force to re-run)"
    next
  end

  puts "running #{shard.fetch("shard_id")} (#{AtlasBatch.relative_path(AtlasBatch.project_path(shard.fetch("path")))})"
  ok, failed = run_shard(shard, results_dir, options)
  total_ok += ok
  total_errors += failed

  request_index["updated_at"] = AtlasBatch.utc_now
  AtlasBatch.write_yaml(index_path, request_index)
end

manifest["status"] = "results_downloaded" if total_ok.positive?
manifest["artifacts"]["results_dir"] = AtlasBatch.relative_path(results_dir)
manifest["state"]["last_realtime_run_at"] = AtlasBatch.utc_now
manifest["state"]["realtime_concurrency"] = options[:concurrency]
AtlasBatch.save_manifest(manifest)

puts "realtime run complete: #{total_ok} ok, #{total_errors} errors"
