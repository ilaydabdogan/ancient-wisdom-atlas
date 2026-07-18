#!/usr/bin/env ruby
# frozen_string_literal: true

# The null model — the falsifiability rung of the evidence ladder.
#
# Question: does cross-tradition motif structure (conserved co-occurrence
# edges) exceed what chance would produce given each tradition's motif
# base rates? Permutation scheme: within each tradition, pool all family
# occurrence tokens, shuffle, and redeal to records preserving each
# record's family-set size. This preserves (a) per-tradition family
# frequencies and (b) per-record motif density, while destroying which
# families co-occur — so any surviving edge structure in the null runs is
# pure base-rate artifact. Observed structure is significant only where it
# beats the null distribution.
#
# Deterministic seed; pure local analysis; ancient corpus only.

require_relative "batch_common"

options = {
  extraction_glob: "extractions/**/*.{yml,yaml}",
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  output: "data/indexes/null-model.yml",
  permutations: 200,
  min_pair_count: 3,
  min_traditions: 4,
  seed: 42
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_null_model.rb [options]"
  parser.on("--permutations N", Integer, "Null permutations (default 200)") { |value| options[:permutations] = value }
  parser.on("--min-pair-count N", Integer, "Min within-tradition co-occurrences for an edge (default 3)") { |value| options[:min_pair_count] = value }
  parser.on("--min-traditions N", Integer, "Conserved-edge tradition threshold (default 4)") { |value| options[:min_traditions] = value }
  parser.on("--seed N", Integer, "Random seed (default 42)") { |value| options[:seed] = value }
  parser.on("--output PATH", "Output index path") { |value| options[:output] = value }
end.parse!

ROOT = AtlasBatch::ROOT

frequency = AtlasBatch.load_yaml(File.join(ROOT, options[:frequency_index]))
raw_to_canonical = {}
frequency.fetch("canonical_motifs", []).each do |group|
  canonical_id = group.fetch("canonical_motif_id")
  raw_to_canonical[canonical_id] ||= canonical_id
  group.fetch("mapped_motifs", []).each do |mapped|
    raw_to_canonical[mapped.fetch("motif_id")] ||= canonical_id
  end
end

def tradition_for(source_path)
  parts = source_path.split("/")
  parts.length >= 3 ? parts[2] : "unknown"
end

# tradition => array of family-sets (one per record)
tradition_records = Hash.new { |hash, key| hash[key] = [] }
Dir.glob(File.join(ROOT, options[:extraction_glob])).sort.each do |path|
  record = AtlasBatch.load_yaml(path)
  next if record.empty? || !record.is_a?(Hash)

  source = record["source_text_path"].to_s
  next if source.empty?

  families = Array(record["candidate_motifs"])
             .flat_map { |motif| Array(motif["taxonomy_refs"]) }
             .filter_map { |ref| raw_to_canonical[ref.to_s] }
             .uniq
  next if families.empty?

  tradition_records[tradition_for(source)] << families
end
tradition_records.select! { |_, records| records.length >= 20 }

# Count conserved edges for a {tradition => [family-set,...]} corpus.
def conserved_edge_stats(tradition_records, min_pair_count, min_traditions)
  edge_traditions = Hash.new(0)
  tradition_records.each_value do |records|
    total = records.length.to_f
    family_counts = Hash.new(0)
    pair_counts = Hash.new(0)
    records.each do |families|
      families.each { |family| family_counts[family] += 1 }
      families.sort.combination(2).each { |pair| pair_counts[pair] += 1 }
    end
    pair_counts.each do |(a, b), count|
      next if count < min_pair_count

      pmi = Math.log((count / total) / ((family_counts[a] / total) * (family_counts[b] / total)))
      edge_traditions[[a, b]] += 1 if pmi.positive?
    end
  end
  conserved = edge_traditions.select { |_, count| count >= min_traditions }
  { "conserved_count" => conserved.length, "edges" => conserved }
end

observed = conserved_edge_stats(tradition_records, options[:min_pair_count], options[:min_traditions])

rng = Random.new(options[:seed])
null_counts = []
null_edge_hits = Hash.new(0)
options[:permutations].times do |index|
  permuted = {}
  tradition_records.each do |tradition, records|
    tokens = records.flatten.shuffle(random: rng)
    offset = 0
    permuted[tradition] = records.map do |families|
      slice = tokens[offset, families.length] || []
      offset += families.length
      slice.uniq
    end
  end
  stats = conserved_edge_stats(permuted, options[:min_pair_count], options[:min_traditions])
  null_counts << stats["conserved_count"]
  stats["edges"].each_key { |pair| null_edge_hits[pair] += 1 }
  warn "permutation #{index + 1}/#{options[:permutations]}: #{stats["conserved_count"]} conserved" if ((index + 1) % 50).zero?
end

null_mean = null_counts.sum.to_f / null_counts.length
null_sd = Math.sqrt(null_counts.sum { |count| (count - null_mean)**2 } / null_counts.length)
p_value = (null_counts.count { |count| count >= observed["conserved_count"] } + 1).to_f / (null_counts.length + 1)

# Per-edge empirical significance: how often did this exact edge appear
# conserved in null runs?
edge_details = observed["edges"].map do |pair, tradition_count|
  {
    "pair" => pair,
    "observed_traditions" => tradition_count,
    "null_hit_rate" => (null_edge_hits[pair].to_f / options[:permutations]).round(4)
  }
end.sort_by { |entry| [entry["null_hit_rate"], -entry["observed_traditions"]] }

output = {
  "null_model_version" => "1",
  "generated_at" => AtlasBatch.utc_now,
  "config" => {
    "permutations" => options[:permutations],
    "min_pair_count" => options[:min_pair_count],
    "min_traditions" => options[:min_traditions],
    "seed" => options[:seed],
    "traditions_analyzed" => tradition_records.length
  },
  "result" => {
    "observed_conserved_edges" => observed["conserved_count"],
    "null_mean" => null_mean.round(2),
    "null_sd" => null_sd.round(2),
    "null_max" => null_counts.max,
    "z_score" => null_sd.zero? ? nil : ((observed["conserved_count"] - null_mean) / null_sd).round(2),
    "p_value" => p_value.round(5)
  },
  "edges" => edge_details.first(300)
}

AtlasBatch.write_yaml(File.join(ROOT, options[:output]), output)
puts "observed conserved edges: #{observed["conserved_count"]}; null mean: #{null_mean.round(1)} (sd #{null_sd.round(1)}, max #{null_counts.max}); p = #{p_value.round(5)}"
puts "wrote #{options[:output]}"
