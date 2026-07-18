#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures inter-reader agreement between two or more extraction runs over
# the SAME passages (same custom_ids) — the LLM analogue of inter-rater
# reliability. For every passage extracted by multiple runs, compares the
# taxonomy_refs sets (raw) and their canonical-family projections:
# Jaccard overlap, exact-match rate, and per-tradition breakdowns.
#
# Runs are compared from their raw results JSONL — nothing here touches the
# primary extraction index, so replication runs stay quarantined.
#
# usage: ruby scripts/build_replication_agreement.rb \
#          --run-id motif-extraction-2026-07-17-azure-wave1 \
#          --run-id replication-gpt54-2026-07-17 \
#          --run-id replication-gpt56terra-2026-07-17

require_relative "batch_common"

options = {
  run_ids: [],
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  output: "data/indexes/replication-agreement.yml"
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_replication_agreement.rb --run-id RUN_A --run-id RUN_B [options]"
  parser.on("--run-id RUN_ID", "Run to compare; repeat 2+ times") { |value| options[:run_ids] << value }
  parser.on("--output PATH", "Output index path") { |value| options[:output] = value }
end.parse!

AtlasBatch.die("need at least two --run-id values", 64) if options[:run_ids].length < 2

frequency = AtlasBatch.load_yaml(AtlasBatch.project_path(options[:frequency_index]))
raw_to_canonical = {}
frequency.fetch("canonical_motifs", []).each do |group|
  canonical_id = group.fetch("canonical_motif_id")
  raw_to_canonical[canonical_id] ||= canonical_id
  group.fetch("mapped_motifs", []).each do |mapped|
    raw_to_canonical[mapped.fetch("motif_id")] ||= canonical_id
  end
end

def response_text(body)
  parts = []
  Array(body["output"]).each do |item|
    next unless item.is_a?(Hash) && item["type"] == "message"

    Array(item["content"]).each do |content|
      parts << content["text"].to_s if content.is_a?(Hash) && content["text"]
    end
  end
  text = parts.join("\n").strip
  text.empty? ? body["output_text"].to_s.strip : text
end

def parse_payload(text)
  cleaned = text.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
  JSON.parse(cleaned)
rescue JSON::ParserError
  match = cleaned.match(/\{.*\}/m)
  return nil unless match

  begin
    JSON.parse(match[0])
  rescue JSON::ParserError
    nil
  end
end

def tradition_for(source_path)
  parts = source_path.to_s.split("/")
  parts.length >= 3 ? parts[2] : "unknown"
end

# run_id => { custom_id => {refs:, canonical:, tradition:} }
runs = {}
parse_stats = {}
options[:run_ids].each do |run_id|
  map_path = File.join(AtlasBatch.batch_dir(run_id), "request-map.jsonl")
  AtlasBatch.die("request map missing for #{run_id}", 66) unless File.file?(map_path)

  sources = AtlasBatch.read_jsonl(map_path).to_h { |entry| [entry["custom_id"], entry["source_text_path"]] }
  results_dir = File.join(AtlasBatch.batch_dir(run_id), "results")
  extracted = {}
  failed = 0
  Dir.glob(File.join(results_dir, "*.output.jsonl")).sort.each do |path|
    AtlasBatch.read_jsonl(path).each do |line|
      custom_id = line["custom_id"].to_s
      body = line.dig("response", "body") || {}
      payload = parse_payload(response_text(body))
      unless payload.is_a?(Hash)
        failed += 1
        next
      end

      refs = Array(payload["candidate_motifs"]).flat_map { |motif| Array(motif["taxonomy_refs"]) }.map(&:to_s).uniq.sort
      extracted[custom_id] = {
        "refs" => refs,
        "canonical" => refs.filter_map { |ref| raw_to_canonical[ref] }.uniq.sort,
        "tradition" => tradition_for(sources[custom_id])
      }
    end
  end
  runs[run_id] = extracted
  parse_stats[run_id] = { "parsed" => extracted.length, "parse_failed" => failed }
end

def jaccard(a, b)
  return 1.0 if a.empty? && b.empty?

  union = (a | b).length
  union.zero? ? 0.0 : (a & b).length.to_f / union
end

pairs = options[:run_ids].combination(2).map do |run_a, run_b|
  shared = runs[run_a].keys & runs[run_b].keys
  per_tradition = Hash.new { |hash, key| hash[key] = [] }
  raw_scores = []
  canonical_scores = []
  exact = 0

  shared.each do |custom_id|
    a = runs[run_a][custom_id]
    b = runs[run_b][custom_id]
    raw_scores << jaccard(a["refs"], b["refs"])
    score = jaccard(a["canonical"], b["canonical"])
    canonical_scores << score
    exact += 1 if a["canonical"] == b["canonical"]
    per_tradition[a["tradition"]] << score
  end

  mean = ->(list) { list.empty? ? nil : (list.sum / list.length).round(4) }
  {
    "run_a" => run_a,
    "run_b" => run_b,
    "shared_passages" => shared.length,
    "mean_raw_jaccard" => mean.call(raw_scores),
    "mean_canonical_jaccard" => mean.call(canonical_scores),
    "exact_canonical_match_rate" => shared.empty? ? nil : (exact.to_f / shared.length).round(4),
    "per_tradition_canonical_jaccard" => per_tradition.transform_values { |list| mean.call(list) }.sort_by { |_, value| -(value || 0) }.to_h
  }
end

output = {
  "replication_agreement_version" => "1",
  "generated_at" => AtlasBatch.utc_now,
  "runs" => parse_stats,
  "pairwise" => pairs
}

AtlasBatch.write_yaml(AtlasBatch.project_path(options[:output]), output)
pairs.each do |pair|
  puts "#{pair["run_a"]} vs #{pair["run_b"]}: shared=#{pair["shared_passages"]} canonical-jaccard=#{pair["mean_canonical_jaccard"]} exact=#{pair["exact_canonical_match_rate"]}"
end
puts "wrote #{options[:output]}"
