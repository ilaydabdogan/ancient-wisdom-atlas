#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the narrative-sequence index: per-text ordered chains of canonical
# motif families, recurring cross-tradition n-grams, and a family precedence
# matrix. This is the empirical ground for the "monomyth" question — whether
# motif ORDER (not just presence) recurs across traditions without contact.
#
# Ancient corpus only. Ordering comes from passage_locator start positions;
# records whose locator cannot be ordered numerically are excluded from
# chains (counted in the summary) rather than guessed.

require_relative "batch_common"

options = {
  extraction_glob: "extractions/**/*.{yml,yaml}",
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  output: "data/indexes/motif-sequences.yml",
  min_traditions: 3,
  max_ngram: 4,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_motif_sequence_index.rb [options]"
  parser.on("--extraction-glob GLOB", "Extraction records glob") { |value| options[:extraction_glob] = value }
  parser.on("--output PATH", "Output index path") { |value| options[:output] = value }
  parser.on("--min-traditions N", Integer, "Minimum traditions for a recurring n-gram (default 3)") { |value| options[:min_traditions] = value }
  parser.on("--max-ngram N", Integer, "Longest n-gram to mine (default 4)") { |value| options[:max_ngram] = value }
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

def numeric_position(locator)
  return nil unless locator.is_a?(Hash)

  value = locator["start"]
  if value.to_s.match?(/\A\d+\z/)
    return value.to_i
  end

  label = locator["label"].to_s
  if (match = label.match(/(\d+)[:.](\d+)/))
    return match[1].to_i * 10_000 + match[2].to_i
  end
  if (match = label.match(/(\d+)/))
    return match[1].to_i
  end
  nil
end

texts = Hash.new { |hash, key| hash[key] = [] }
unordered = Hash.new(0)
unmapped_refs = Hash.new(0)
record_count = 0

Dir.glob(File.join(ROOT, options[:extraction_glob])).sort.each do |path|
  record = AtlasBatch.load_yaml(path)
  next if record.empty? || !record.is_a?(Hash)

  source = record["source_text_path"].to_s
  next if source.empty?

  record_count += 1
  position = numeric_position(record["passage_locator"])
  families = Array(record["candidate_motifs"]).flat_map { |motif| Array(motif["taxonomy_refs"]) }.map(&:to_s)
  canonical = families.filter_map do |ref|
    mapped = raw_to_canonical[ref]
    unmapped_refs[ref] += 1 unless mapped
    mapped
  end.uniq
  next if canonical.empty?

  if position.nil?
    unordered[source] += 1
    next
  end

  texts[source] << { "position" => position, "families" => canonical, "record_id" => record["record_id"].to_s }
end

def tradition_for(source_path)
  parts = source_path.split("/")
  parts.length >= 3 ? parts[2] : "unknown"
end

chains = {}
texts.each do |source, steps|
  ordered = steps.sort_by { |step| step["position"] }
  stream = []
  ordered.each do |step|
    step["families"].each do |family|
      stream << family unless stream.last == family
    end
  end
  chains[source] = {
    "tradition" => tradition_for(source),
    "step_count" => ordered.length,
    "chain" => stream,
    "steps" => ordered.map { |step| { "position" => step["position"], "families" => step["families"] } }
  }
end

ngram_hits = Hash.new { |hash, key| hash[key] = {} }
chains.each do |source, data|
  stream = data["chain"]
  tradition = data["tradition"]
  (2..options[:max_ngram]).each do |n|
    next if stream.length < n

    stream.each_cons(n) do |gram|
      next if gram.uniq.length != n

      key = gram.join(" > ")
      ngram_hits[key][source] = tradition
    end
  end
end

recurring = ngram_hits.filter_map do |gram, sources|
  traditions = sources.values.uniq.sort
  next if traditions.length < options[:min_traditions]

  {
    "sequence" => gram,
    "length" => gram.split(" > ").length,
    "text_count" => sources.length,
    "tradition_count" => traditions.length,
    "traditions" => traditions,
    "texts" => sources.keys.sort
  }
end.sort_by { |entry| [-entry["tradition_count"], -entry["text_count"], -entry["length"]] }

precedence = Hash.new { |hash, key| hash[key] = Hash.new(0) }
chains.each_value do |data|
  seen = {}
  data["chain"].each_with_index { |family, index| seen[family] ||= index }
  families = seen.keys
  families.combination(2).each do |a, b|
    if seen[a] < seen[b]
      precedence[a][b] += 1
    else
      precedence[b][a] += 1
    end
  end
end

# Frequency-controlled null: shuffle each text's family stream (destroying
# order, preserving membership and length), recompute first-occurrence
# precedence. A pair's ordering only counts as grammar if its observed
# consistency beats what shuffled chains produce — this controls for the
# bias where frequent families merely APPEAR early.
NULL_PERMUTATIONS = 100
null_rng = Random.new(7)
null_forward = Hash.new { |hash, key| hash[key] = [] }
NULL_PERMUTATIONS.times do
  perm_precedence = Hash.new { |hash, key| hash[key] = Hash.new(0) }
  chains.each_value do |data|
    shuffled = data["chain"].shuffle(random: null_rng)
    seen = {}
    shuffled.each_with_index { |family, index| seen[family] ||= index }
    seen.keys.combination(2).each do |a, b|
      if seen[a] < seen[b]
        perm_precedence[a][b] += 1
      else
        perm_precedence[b][a] += 1
      end
    end
  end
  perm_precedence.each do |a, row|
    row.each do |b, forward|
      backward = perm_precedence.key?(b) ? perm_precedence[b].fetch(a, 0) : 0
      total = forward + backward
      next if total < 8

      key = [a, b].sort
      null_forward[key] << [forward, backward].max.to_f / total
    end
  end
end

asymmetries = []
seen_pairs = {}
precedence.keys.each do |a|
  precedence[a].keys.each do |b|
    key = [a, b].sort
    next if seen_pairs[key]

    seen_pairs[key] = true
    forward = precedence[a][b]
    backward = precedence.key?(b) ? precedence[b].fetch(a, 0) : 0
    total = forward + backward
    next if total < 8

    winner, loser, wins = forward >= backward ? [a, b, forward] : [b, a, backward]
    ratio = wins.to_f / total
    next if ratio < 0.75

    null_scores = null_forward.fetch(key, [])
    null_mean = null_scores.empty? ? nil : (null_scores.sum / null_scores.length).round(3)
    beats_null = null_scores.empty? ? nil : (null_scores.count { |score| score >= ratio }.to_f / null_scores.length).round(3)
    asymmetries << {
      "before" => winner,
      "after" => loser,
      "before_count" => wins,
      "after_count" => total - wins,
      "text_count" => total,
      "consistency" => ratio.round(3),
      "null_consistency_mean" => null_mean,
      "null_fraction_as_extreme" => beats_null
    }
  end
end
asymmetries.sort_by! { |entry| [-entry["consistency"], -entry["text_count"]] }

output = {
  "motif_sequence_index_version" => "1",
  "generated_at" => AtlasBatch.utc_now,
  "summary" => {
    "extraction_records_seen" => record_count,
    "texts_with_chains" => chains.length,
    "unordered_records" => unordered.values.sum,
    "unordered_by_text" => unordered.sort_by { |_, count| -count }.first(20).to_h,
    "distinct_unmapped_taxonomy_refs" => unmapped_refs.length,
    "recurring_sequences" => recurring.length,
    "strong_precedence_pairs" => asymmetries.length,
    "min_traditions" => options[:min_traditions]
  },
  "recurring_sequences" => recurring.first(500),
  "precedence_pairs" => asymmetries.first(300),
  "chains" => chains
}

path = File.join(ROOT, options[:output])
AtlasBatch.write_yaml(path, output)
puts "texts with chains: #{chains.length}; recurring cross-tradition sequences (>=#{options[:min_traditions]} traditions): #{recurring.length}; strong precedence pairs: #{asymmetries.length}"
puts "wrote #{options[:output]}"
