#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the constellation index: which canonical motif families CO-OCCUR
# within passages, per tradition — and which co-occurrence structures recur
# across traditions. The archetype hypothesis, operationalized: a
# "constellation" is a cluster of families whose mutual affinity survives
# lineage isolation. Edges are kept per tradition (PMI > 0 with a minimum
# co-occurrence count), then an edge is "conserved" when independently
# significant in enough traditions. Conserved-edge components are the
# candidate constellations.
#
# Ancient corpus only. Pure local analysis — no API calls.

require_relative "batch_common"

options = {
  extraction_glob: "extractions/**/*.{yml,yaml}",
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  output: "data/indexes/motif-constellations.yml",
  min_pair_count: 3,
  min_traditions: 4,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_motif_constellations.rb [options]"
  parser.on("--extraction-glob GLOB", "Extraction records glob") { |value| options[:extraction_glob] = value }
  parser.on("--output PATH", "Output index path") { |value| options[:output] = value }
  parser.on("--min-pair-count N", Integer, "Min within-tradition co-occurrences for an edge (default 3)") { |value| options[:min_pair_count] = value }
  parser.on("--min-traditions N", Integer, "Min traditions for a conserved edge (default 4)") { |value| options[:min_traditions] = value }
  parser.on("--force", "Replace changed output") { options[:force] = true }
end.parse!

ROOT = AtlasBatch::ROOT

frequency = AtlasBatch.load_yaml(File.join(ROOT, options[:frequency_index]))
AtlasBatch.die("canonical frequency index missing or empty", 66) if frequency.empty?

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

# tradition => { "records" => n, "family_counts" => {f=>n}, "pair_counts" => {[a,b]=>n} }
per_tradition = Hash.new do |hash, key|
  hash[key] = { "records" => 0, "family_counts" => Hash.new(0), "pair_counts" => Hash.new(0) }
end

Dir.glob(File.join(ROOT, options[:extraction_glob])).sort.each do |path|
  record = AtlasBatch.load_yaml(path)
  next if record.empty? || !record.is_a?(Hash)

  source = record["source_text_path"].to_s
  next if source.empty?

  families = Array(record["candidate_motifs"])
             .flat_map { |motif| Array(motif["taxonomy_refs"]) }
             .filter_map { |ref| raw_to_canonical[ref.to_s] }
             .uniq
             .sort
  next if families.empty?

  bucket = per_tradition[tradition_for(source)]
  bucket["records"] += 1
  families.each { |family| bucket["family_counts"][family] += 1 }
  families.combination(2).each { |pair| bucket["pair_counts"][pair] += 1 }
end

# Per-tradition significant edges: count >= min_pair_count and PMI > 0.
tradition_edges = {}
per_tradition.each do |tradition, bucket|
  records = bucket["records"].to_f
  next if records < 20

  edges = bucket["pair_counts"].filter_map do |(a, b), count|
    next if count < options[:min_pair_count]

    p_a = bucket["family_counts"][a] / records
    p_b = bucket["family_counts"][b] / records
    p_ab = count / records
    pmi = Math.log(p_ab / (p_a * p_b))
    next if pmi <= 0

    { "pair" => [a, b], "count" => count, "pmi" => pmi.round(4) }
  end
  tradition_edges[tradition] = edges.sort_by { |edge| -edge["pmi"] }
end

# Conserved edges: significant in >= min_traditions traditions independently.
edge_traditions = Hash.new { |hash, key| hash[key] = {} }
tradition_edges.each do |tradition, edges|
  edges.each { |edge| edge_traditions[edge["pair"]][tradition] = edge["count"] }
end

conserved = edge_traditions.filter_map do |pair, traditions|
  next if traditions.length < options[:min_traditions]

  {
    "pair" => pair,
    "tradition_count" => traditions.length,
    "traditions" => traditions.keys.sort,
    "total_cooccurrences" => traditions.values.sum
  }
end.sort_by { |entry| -entry["tradition_count"] }

# Constellations: connected components of the conserved-edge graph, refined
# by one pass of label propagation weighted by tradition_count.
adjacency = Hash.new { |hash, key| hash[key] = {} }
conserved.each do |entry|
  a, b = entry["pair"]
  adjacency[a][b] = entry["tradition_count"]
  adjacency[b][a] = entry["tradition_count"]
end

labels = adjacency.keys.to_h { |node| [node, node] }
10.times do
  changed = false
  adjacency.keys.shuffle(random: Random.new(42)).each do |node|
    weights = Hash.new(0)
    adjacency[node].each { |neighbor, weight| weights[labels[neighbor]] += weight }
    next if weights.empty?

    best = weights.max_by { |label, weight| [weight, label] }.first
    if best != labels[node]
      labels[node] = best
      changed = true
    end
  end
  break unless changed
end

constellations = labels.group_by { |_, label| label }.map do |label, members|
  nodes = members.map(&:first).sort
  internal = conserved.select { |entry| (entry["pair"] & nodes).length == 2 }
  {
    "constellation_id" => "constellation_#{label}",
    "families" => nodes,
    "size" => nodes.length,
    "internal_edges" => internal.length,
    "mean_edge_traditions" => internal.empty? ? 0 : (internal.sum { |entry| entry["tradition_count"] }.to_f / internal.length).round(2)
  }
end.select { |entry| entry["size"] >= 2 }.sort_by { |entry| -entry["size"] }

output = {
  "motif_constellation_index_version" => "1",
  "generated_at" => AtlasBatch.utc_now,
  "summary" => {
    "traditions_analyzed" => tradition_edges.length,
    "traditions_skipped_small" => per_tradition.length - tradition_edges.length,
    "conserved_edges" => conserved.length,
    "constellations" => constellations.length,
    "min_pair_count" => options[:min_pair_count],
    "min_traditions" => options[:min_traditions]
  },
  "constellations" => constellations,
  "conserved_edges" => conserved.first(500),
  "tradition_edge_counts" => tradition_edges.transform_values(&:length)
}

path = File.join(ROOT, options[:output])
AtlasBatch.write_yaml(path, output)
puts "traditions: #{tradition_edges.length}; conserved edges (>=#{options[:min_traditions]} traditions): #{conserved.length}; constellations: #{constellations.length}"
constellations.first(8).each { |c| puts "  #{c["constellation_id"]}: #{c["families"].join(", ")}" }
puts "wrote #{options[:output]}"
