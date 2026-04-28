#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

DEFAULT_MODEL = ENV.fetch("OPENAI_EMBEDDING_MODEL", "text-embedding-3-large")
EMBEDDINGS_ENDPOINT = "/v1/embeddings"

options = {
  source: "passages",
  model: DEFAULT_MODEL,
  endpoint: EMBEDDINGS_ENDPOINT,
  encoding_format: "float",
  extraction_glob: "extractions/**/*.yml",
  max_input_chars: 24_000,
  max_requests_per_shard: 10_000,
  max_bytes_per_shard: 180 * 1024 * 1024,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_embedding_requests.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Embedding batch run id") { |value| options[:run_id] = value }
  parser.on("--source SOURCE", "Input source: passages or extractions") { |value| options[:source] = value }
  parser.on("--passages PATH", "Passages JSONL path for --source passages") { |value| options[:passages_path] = value }
  parser.on("--extraction-glob GLOB", "YAML extraction glob for --source extractions") { |value| options[:extraction_glob] = value }
  parser.on("--model MODEL", "Embedding model id") { |value| options[:model] = value }
  parser.on("--dimensions N", Integer, "Optional embedding dimensions") { |value| options[:dimensions] = value }
  parser.on("--encoding-format FORMAT", "Embedding encoding_format") { |value| options[:encoding_format] = value }
  parser.on("--limit N", Integer, "Limit embedding inputs, useful for demos") { |value| options[:limit] = value }
  parser.on("--max-input-chars N", Integer, "Fail if a single input exceeds this many chars") { |value| options[:max_input_chars] = value }
  parser.on("--max-requests-per-shard N", Integer, "Shard request count limit") { |value| options[:max_requests_per_shard] = value }
  parser.on("--max-bytes-per-shard N", Integer, "Shard byte limit") { |value| options[:max_bytes_per_shard] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]
AtlasBatch.die("--source must be passages or extractions", 64) unless %w[passages extractions].include?(options[:source])
AtlasBatch.die("--max-requests-per-shard must be positive", 64) unless options[:max_requests_per_shard].positive?
AtlasBatch.die("--max-requests-per-shard cannot exceed the embeddings batch input cap of 50000", 64) if options[:max_requests_per_shard] > 50_000
AtlasBatch.die("--max-bytes-per-shard must be at least 1000000", 64) if options[:max_bytes_per_shard] < 1_000_000

def compact_text(value)
  value.to_s.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip
end

def embedding_id_for(source_type, stable_parts)
  "#{source_type}.#{AtlasBatch.safe_slug(stable_parts.join("."), fallback: "item")}"
end

def apply_limit(records, limit)
  limit ? records.first(limit) : records
end

def passage_inputs(passages_path, limit)
  apply_limit(AtlasBatch.read_jsonl(passages_path), limit).map do |passage|
    locator = passage.fetch("locator")
    text = [
      "Source: #{passage["source_title"]}",
      "Tradition: #{passage["tradition"]}",
      "Locator: #{locator["label"]}",
      "",
      passage.fetch("text")
    ].join("\n")
    embedding_id = embedding_id_for("passage", [passage.fetch("passage_id")])

    {
      "embedding_id" => embedding_id,
      "source_type" => "passage",
      "source_path" => passage.fetch("source_text_path"),
      "source_text_path" => passage.fetch("source_text_path"),
      "source_text_id" => passage["source_text_id"],
      "source_title" => passage["source_title"],
      "locator" => locator,
      "content_sha256" => passage.fetch("sha256"),
      "metadata" => {
        "tradition" => passage["tradition"],
        "culture" => passage["culture"],
        "text_language" => passage["text_language"],
        "passage_id" => passage.fetch("passage_id")
      },
      "text" => compact_text(text)
    }
  end
end

def extraction_summary(record)
  parts = []
  parts << "Record: #{record["record_id"]}"
  parts << "Source: #{record["source_text_path"]}"
  if record["passage_locator"].is_a?(Hash)
    parts << "Locator: #{record["passage_locator"]["label"]}"
  end

  canonical = record["canonical_text"].is_a?(Hash) ? record["canonical_text"] : {}
  parts << "Canonical summary: #{canonical["summary"]}" unless canonical["summary"].to_s.strip.empty?
  parts << "Canonical quote: #{canonical["quote"]}" unless canonical["quote"].to_s.strip.empty?

  {
    "Observations" => record["literal_observations"],
    "Figures" => record["figures"],
    "Symbols" => record["symbols"],
    "Scenes" => record["scenes"],
    "Candidate motifs" => record["candidate_motifs"],
    "Comparison claims" => record["comparison_claims"]
  }.each do |label, rows|
    next unless rows.is_a?(Array) && rows.any?

    parts << ""
    parts << "#{label}:"
    rows.each do |row|
      next unless row.is_a?(Hash)

      text = row["text"] || row["summary"] || row["label"] || row["claim"] || row["name_or_label"]
      parts << "- #{text}" unless text.to_s.strip.empty?
    end
  end

  compact_text(parts.join("\n"))
end

def extraction_inputs(glob, limit)
  paths = apply_limit(Dir.glob(File.join(AtlasBatch::ROOT, glob)).sort, limit)
  paths.map do |path|
    relative = AtlasBatch.relative_path(path)
    record = AtlasBatch.load_yaml(path)
    record_id = record["record_id"].to_s.empty? ? AtlasBatch.safe_slug(relative) : record["record_id"].to_s
    locator = record["passage_locator"].is_a?(Hash) ? record["passage_locator"] : {}
    text = extraction_summary(record)

    {
      "embedding_id" => embedding_id_for("extraction", [record_id]),
      "source_type" => "extraction",
      "source_path" => relative,
      "source_text_path" => record["source_text_path"],
      "source_text_id" => nil,
      "source_title" => nil,
      "locator" => locator,
      "content_sha256" => AtlasBatch.sha256_file(path),
      "metadata" => {
        "record_id" => record_id,
        "reviewer_status" => record.dig("reviewer_status", "status")
      },
      "text" => text
    }
  end
end

def request_for(input, options)
  body = {
    "model" => options.fetch(:model),
    "input" => input.fetch("text"),
    "encoding_format" => options.fetch(:encoding_format)
  }
  body["dimensions"] = options[:dimensions] if options[:dimensions]

  {
    "custom_id" => "embedding:#{input.fetch("embedding_id")}",
    "method" => "POST",
    "url" => options.fetch(:endpoint),
    "body" => body
  }
end

def shard_requests(requests, max_requests:, max_bytes:)
  shards = []
  current = []
  current_bytes = 0

  requests.each do |request|
    line = JSON.generate(request)
    line_bytes = line.bytesize + 1
    if current.any? && (current.length >= max_requests || current_bytes + line_bytes > max_bytes)
      shards << current
      current = []
      current_bytes = 0
    end

    AtlasBatch.die("single request exceeds shard byte limit: #{request.fetch("custom_id")}", 65) if line_bytes > max_bytes

    current << request
    current_bytes += line_bytes
  end

  shards << current if current.any?
  shards
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)

inputs =
  if options[:source] == "passages"
    passages_path = AtlasBatch.project_path(options[:passages_path] || manifest.dig("artifacts", "passages_path").to_s)
    AtlasBatch.die("--passages is required for passage embeddings unless this run already has artifacts.passages_path", 64) if passages_path == AtlasBatch::ROOT
    AtlasBatch.die("passages file not found: #{AtlasBatch.relative_path(passages_path)}", 66) unless File.file?(passages_path)

    manifest["artifacts"]["embedding_source_passages_path"] = AtlasBatch.relative_path(passages_path)
    passage_inputs(passages_path, options[:limit])
  else
    extraction_inputs(options[:extraction_glob], options[:limit])
  end

AtlasBatch.die("No embedding inputs selected", 66) if inputs.empty?

too_long = inputs.select { |input| input.fetch("text").length > options[:max_input_chars] }
if too_long.any?
  examples = too_long.first(10).map { |input| "#{input.fetch("embedding_id")} chars=#{input.fetch("text").length}" }
  AtlasBatch.die("Embedding input(s) exceed --max-input-chars #{options[:max_input_chars]}:\n#{examples.join("\n")}", 65)
end

requests = inputs.map { |input| request_for(input, options) }
request_map = inputs.map do |input|
  input.reject { |key, _value| key == "text" }.merge(
    "custom_id" => "embedding:#{input.fetch("embedding_id")}",
    "text_sha256" => AtlasBatch.sha256_text(input.fetch("text")),
    "char_count" => input.fetch("text").length,
    "word_count" => input.fetch("text").scan(/\S+/).length
  )
end

shards = shard_requests(
  requests,
  max_requests: options[:max_requests_per_shard],
  max_bytes: options[:max_bytes_per_shard]
)

requests_dir = File.join(AtlasBatch.batch_dir(run_id), "requests")
FileUtils.mkdir_p(requests_dir)

shard_entries = []
shards.each_with_index do |records, index|
  shard_id = "shard-%04d" % (index + 1)
  path = File.join(requests_dir, "#{shard_id}.jsonl")
  AtlasBatch.write_jsonl(path, records, force: options[:force])
  shard_entries << {
    "shard_id" => shard_id,
    "path" => AtlasBatch.relative_path(path),
    "request_count" => records.length,
    "embedding_input_count" => records.length,
    "bytes" => File.size(path),
    "sha256" => AtlasBatch.sha256_file(path),
    "endpoint" => options[:endpoint],
    "model" => options[:model],
    "status" => "prepared"
  }
end

request_map_path = File.join(AtlasBatch.batch_dir(run_id), "embedding-request-map.jsonl")
AtlasBatch.write_jsonl(request_map_path, request_map, force: options[:force])

index_path = File.join(requests_dir, "index.yml")
request_index = {
  "batch_request_index_version" => "1",
  "run_id" => run_id,
  "created_at" => AtlasBatch.utc_now,
  "updated_at" => AtlasBatch.utc_now,
  "pipeline" => "embeddings",
  "endpoint" => options[:endpoint],
  "model" => options[:model],
  "encoding_format" => options[:encoding_format],
  "dimensions" => options[:dimensions],
  "source" => options[:source],
  "request_map_path" => AtlasBatch.relative_path(request_map_path),
  "shards" => shard_entries
}
AtlasBatch.write_yaml(index_path, request_index)

manifest["pipeline"] = "embeddings"
manifest["status"] = "requests_prepared"
manifest["config"] ||= {}
manifest["config"]["embedding_request_generation"] = {
  "source" => options[:source],
  "model" => options[:model],
  "endpoint" => options[:endpoint],
  "encoding_format" => options[:encoding_format],
  "dimensions" => options[:dimensions],
  "limit" => options[:limit],
  "max_input_chars" => options[:max_input_chars],
  "max_requests_per_shard" => options[:max_requests_per_shard],
  "max_bytes_per_shard" => options[:max_bytes_per_shard]
}
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["artifacts"]["embedding_request_map_path"] = AtlasBatch.relative_path(request_map_path)
manifest["counts"] ||= {}
manifest["counts"]["embedding_inputs_prepared"] = inputs.length
manifest["counts"]["request_shards"] = shard_entries.length
AtlasBatch.save_manifest(manifest)

puts "prepared #{inputs.length} embedding request(s) in #{shard_entries.length} shard(s)"
puts "wrote #{AtlasBatch.relative_path(index_path)}"
