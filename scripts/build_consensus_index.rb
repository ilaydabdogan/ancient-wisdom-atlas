#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the consensus index: for every passage read by multiple models
# of the replication panel, how many independent readers asserted each
# canonical family? Hallucinations rarely replicate across model
# generations — reader count is a per-claim confidence tier:
#   3+ readers = multi-reader confirmed; 2 = corroborated; 1 = provisional.
# Keyed by record_id (via the passage run's request map) so the site can
# badge evidence pages. Replication runs stay quarantined: this index
# reads their raw results without ingesting them.

require_relative "batch_common"

options = {
  runs: [
    "motif-extraction-2026-07-17-azure-wave1",
    "replication-gpt54-2026-07-17",
    "replication-gpt56terra-2026-07-17",
    "replication-gpt56sol-2026-07-17",
    "replication-gpt51-2026-07-17"
  ],
  map_run: "motif-extraction-2026-07-17-azure-wave1",
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  output: "data/indexes/motif-consensus.yml"
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_consensus_index.rb [options]"
  parser.on("--run RUN_ID", "Reader run; may be repeated (replaces defaults)") { |value| (options[:custom_runs] ||= []) << value }
  parser.on("--output PATH", "Output index path") { |value| options[:output] = value }
end.parse!
runs = options[:custom_runs] || options[:runs]

frequency = AtlasBatch.load_yaml(AtlasBatch.project_path(options[:frequency_index]))
raw_to_canonical = {}
frequency.fetch("canonical_motifs", []).each do |group|
  canonical_id = group.fetch("canonical_motif_id")
  raw_to_canonical[canonical_id] ||= canonical_id
  group.fetch("mapped_motifs", []).each { |m| raw_to_canonical[m.fetch("motif_id")] ||= canonical_id }
end

def response_text(body)
  parts = []
  Array(body["output"]).each do |item|
    next unless item.is_a?(Hash) && item["type"] == "message"

    Array(item["content"]).each { |c| parts << c["text"].to_s if c.is_a?(Hash) && c["text"] }
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

# custom_id => family => reader count
counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
readers_seen = Hash.new(0)
runs.each do |run_id|
  results = Dir.glob(File.join(AtlasBatch.batch_dir(run_id), "results", "*.output.jsonl"))
  next if results.empty?

  results.sort.each do |path|
    AtlasBatch.read_jsonl(path).each do |line|
      body = line.dig("response", "body") || {}
      next unless body["status"] == "completed"

      payload = parse_payload(response_text(body))
      next unless payload

      families = Array(payload["candidate_motifs"]).flat_map { |m| Array(m["taxonomy_refs"]) }
                                                   .filter_map { |ref| raw_to_canonical[ref.to_s] }.uniq
      next if families.empty?

      custom_id = line["custom_id"].to_s
      readers_seen[custom_id] += 1
      families.each { |family| counts[custom_id][family] += 1 }
    end
  end
end

map_path = File.join(AtlasBatch.batch_dir(options[:map_run]), "request-map.jsonl")
record_for = File.file?(map_path) ? AtlasBatch.read_jsonl(map_path).to_h { |r| [r["custom_id"], r["record_id"]] } : {}

records = {}
tier_totals = Hash.new(0)
counts.each do |custom_id, family_counts|
  readers = readers_seen[custom_id]
  next if readers < 2

  tiers = family_counts.transform_values do |count|
    tier = count >= 3 ? "confirmed" : count == 2 ? "corroborated" : "provisional"
    tier_totals[tier] += 1
    { "readers" => count, "of" => readers, "tier" => tier }
  end
  records[record_for[custom_id] || custom_id] = tiers
end

output = {
  "motif_consensus_version" => "1",
  "generated_at" => AtlasBatch.utc_now,
  "runs" => runs,
  "summary" => {
    "passages_with_multiple_readers" => records.length,
    "family_claims" => tier_totals.values.sum,
    "tiers" => tier_totals
  },
  "records" => records
}

AtlasBatch.write_yaml(AtlasBatch.project_path(options[:output]), output)
puts "passages with 2+ readers: #{records.length}; claims: #{tier_totals.values.sum}; tiers: #{tier_totals.inspect}"
puts "wrote #{options[:output]}"
