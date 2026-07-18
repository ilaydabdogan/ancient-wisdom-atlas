#!/usr/bin/env ruby
# frozen_string_literal: true

# The preregistered isolated-lineage prediction test
# (docs/prereg-isolated-lineage-test.md). Training: connected-lineage
# records only -> conserved edges (>=4 traditions, PMI>0, count>=3).
# Holdout: isolated-lineage records only. Primary metric: fraction of
# training edges reproduced in the holdout (PMI>0, count>=2, >=2
# lineages) vs 200 within-lineage permutations. Leakage controls:
# novelty rate, per-lineage rates, verbatim hard-core subset.

require_relative "batch_common"

ISOLATED = %w[
  australian-aboriginal indigenous-australian inuit khoisan-south-african
  san zulu siberian guiana-amerindian amazonian andamanese maya
  mesoamerican nahua nahua-maya-inca navajo zuni hopi hawaiian
  native-american-great-lakes native-american-northwest-coast
  native-american-plains native-american-southeast
  native-american-southwest tsimshian
].freeze
EXCLUDED = %w[comparative].freeze
HARD_CORE = %w[inuit siberian khoisan-south-african san
               native-american-northwest-coast andamanese].freeze

options = {
  extraction_glob: "extractions/**/*.{yml,yaml}",
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  output: "data/indexes/isolated-prediction-test.yml",
  permutations: 200,
  seed: 42
}
OptionParser.new do |parser|
  parser.on("--output PATH") { |value| options[:output] = value }
  parser.on("--permutations N", Integer) { |value| options[:permutations] = value }
end.parse!

ROOT = AtlasBatch::ROOT

frequency = AtlasBatch.load_yaml(File.join(ROOT, options[:frequency_index]))
raw_to_canonical = {}
frequency.fetch("canonical_motifs", []).each do |group|
  canonical_id = group.fetch("canonical_motif_id")
  raw_to_canonical[canonical_id] ||= canonical_id
  group.fetch("mapped_motifs", []).each { |m| raw_to_canonical[m.fetch("motif_id")] ||= canonical_id }
end

training = Hash.new { |h, k| h[k] = [] }   # tradition => [family sets]
holdout = Hash.new { |h, k| h[k] = [] }    # lineage => [family sets]
Dir.glob(File.join(ROOT, options[:extraction_glob])).sort.each do |path|
  record = AtlasBatch.load_yaml(path)
  next if record.empty? || !record.is_a?(Hash)

  source = record["source_text_path"].to_s
  next if source.empty?

  tradition = source.split("/")[2].to_s
  next if EXCLUDED.include?(tradition)

  families = Array(record["candidate_motifs"]).flat_map { |m| Array(m["taxonomy_refs"]) }
                                              .filter_map { |ref| raw_to_canonical[ref.to_s] }.uniq
  next if families.empty?

  (ISOLATED.include?(tradition) ? holdout : training)[tradition] << families
end

def edges_for(records_by_group, min_pair, min_groups)
  per_group = {}
  records_by_group.each do |group, records|
    next if records.length < 10

    total = records.length.to_f
    fam = Hash.new(0)
    pair = Hash.new(0)
    records.each do |families|
      families.each { |f| fam[f] += 1 }
      families.sort.combination(2).each { |p| pair[p] += 1 }
    end
    sig = {}
    pair.each do |p, count|
      next if count < min_pair

      pmi = Math.log((count / total) / ((fam[p[0]] / total) * (fam[p[1]] / total)))
      sig[p] = true if pmi.positive?
    end
    per_group[group] = sig
  end
  counts = Hash.new(0)
  per_group.each_value { |sig| sig.each_key { |p| counts[p] += 1 } }
  counts.select { |_, c| c >= min_groups }.keys.to_set
end

training_edges = edges_for(training, 3, 4)
holdout_edges = edges_for(holdout, 2, 2)
reproduced = training_edges & holdout_edges
observed_rate = training_edges.empty? ? 0.0 : reproduced.size.to_f / training_edges.size
novelty = holdout_edges - training_edges
novelty_rate = holdout_edges.empty? ? nil : novelty.size.to_f / holdout_edges.size

rng = Random.new(options[:seed])
null_rates = []
options[:permutations].times do
  permuted = {}
  holdout.each do |lineage, records|
    tokens = records.flatten.shuffle(random: rng)
    offset = 0
    permuted[lineage] = records.map do |families|
      slice = tokens[offset, families.length] || []
      offset += families.length
      slice.uniq
    end
  end
  perm_edges = edges_for(permuted, 2, 2)
  null_rates << (training_edges.empty? ? 0.0 : (training_edges & perm_edges).size.to_f / training_edges.size)
end
null_mean = null_rates.sum / null_rates.length
null_sd = Math.sqrt(null_rates.sum { |r| (r - null_mean)**2 } / null_rates.length)
beaten = null_rates.count { |r| r < observed_rate }
lift = null_mean.zero? ? nil : (observed_rate / null_mean).round(3)

per_lineage = holdout.keys.sort.to_h do |lineage|
  solo_edges = edges_for({ lineage => holdout[lineage] }, 2, 1)
  [lineage, { "records" => holdout[lineage].length,
              "training_edges_present" => (training_edges & solo_edges).size }]
end

hard = holdout.select { |lineage, _| HARD_CORE.include?(lineage) }
hard_edges = edges_for(hard, 2, 2)
hard_rate = training_edges.empty? ? nil : ((training_edges & hard_edges).size.to_f / training_edges.size).round(4)

verdict =
  if novelty_rate && novelty_rate < 0.10
    "leakage_flag"
  elsif beaten == options[:permutations] && lift && lift >= 1.15
    "success"
  elsif beaten >= 190 && lift && lift >= 1.05
    "weak_support"
  else
    "failure"
  end

output = {
  "isolated_prediction_test_version" => "1",
  "preregistration" => "docs/prereg-isolated-lineage-test.md",
  "generated_at" => AtlasBatch.utc_now,
  "training" => { "traditions" => training.keys.sort, "records" => training.values.sum(&:length), "conserved_edges" => training_edges.size },
  "holdout" => { "lineages" => holdout.keys.sort, "records" => holdout.values.sum(&:length), "significant_edges" => holdout_edges.size },
  "result" => {
    "reproduced_edges" => reproduced.size,
    "reproduction_rate" => observed_rate.round(4),
    "null_mean" => null_mean.round(4),
    "null_sd" => null_sd.round(4),
    "null_max" => null_rates.max.round(4),
    "permutations_beaten" => "#{beaten}/#{options[:permutations]}",
    "lift" => lift,
    "novelty_rate" => novelty_rate&.round(4),
    "hard_core_rate" => hard_rate,
    "verdict" => verdict
  },
  "per_lineage" => per_lineage,
  "reproduced_edge_list" => reproduced.to_a.sort.first(200),
  "novel_edge_list" => novelty.to_a.sort.first(100)
}
AtlasBatch.write_yaml(File.join(ROOT, options[:output]), output)
puts "training: #{training.keys.length} traditions, #{training_edges.size} conserved edges"
puts "holdout: #{holdout.keys.length} lineages, #{holdout.values.sum(&:length)} records, #{holdout_edges.size} significant edges"
puts "REPRODUCTION: #{reproduced.size}/#{training_edges.size} = #{observed_rate.round(4)} | null #{null_mean.round(4)}+/-#{null_sd.round(4)} (max #{null_rates.max.round(4)}) | beaten #{beaten}/#{options[:permutations]} | lift #{lift}"
puts "novelty rate: #{novelty_rate&.round(4)} | hard-core rate: #{hard_rate} | VERDICT: #{verdict}"
