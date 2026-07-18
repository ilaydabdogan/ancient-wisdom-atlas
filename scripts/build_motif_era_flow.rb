#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the motif era-flow index: each canonical family's presence across
# historical era buckets, using the cultural timeline's composition-date
# ranges per source text. Powers the "Currents" visualization — how motif
# families surface, swell, and fade across recorded time. Occurrences are
# assigned to the midpoint year of their text's composition range; texts
# absent from the timeline are counted in the summary, not guessed.
#
# Ancient corpus only; pure local analysis.

require_relative "batch_common"

options = {
  extraction_glob: "extractions/**/*.{yml,yaml}",
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  timeline_index: "data/indexes/cultural-timeline.yml",
  output: "data/indexes/motif-era-flow.yml"
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_motif_era_flow.rb [options]"
  parser.on("--output PATH", "Output index path") { |value| options[:output] = value }
end.parse!

ROOT = AtlasBatch::ROOT

ERAS = [
  { "id" => "deep_bronze", "label" => "before 1500 BCE", "start" => -10_000, "end" => -1500 },
  { "id" => "late_bronze_iron", "label" => "1500-800 BCE", "start" => -1500, "end" => -800 },
  { "id" => "axial", "label" => "800-300 BCE (Axial Age)", "start" => -800, "end" => -300 },
  { "id" => "classical", "label" => "300 BCE-200 CE", "start" => -300, "end" => 200 },
  { "id" => "late_antique", "label" => "200-800 CE", "start" => 200, "end" => 800 },
  { "id" => "medieval", "label" => "800-1500 CE", "start" => 800, "end" => 1500 },
  { "id" => "early_modern_recorded", "label" => "1500 CE onward (incl. recorded oral traditions)", "start" => 1500, "end" => 2100 }
].freeze

def era_for(year)
  ERAS.find { |era| year >= era["start"] && year < era["end"] }
end

frequency = AtlasBatch.load_yaml(File.join(ROOT, options[:frequency_index]))
raw_to_canonical = {}
family_labels = {}
frequency.fetch("canonical_motifs", []).each do |group|
  canonical_id = group.fetch("canonical_motif_id")
  family_labels[canonical_id] = group["label"]
  raw_to_canonical[canonical_id] ||= canonical_id
  group.fetch("mapped_motifs", []).each do |mapped|
    raw_to_canonical[mapped.fetch("motif_id")] ||= canonical_id
  end
end

timeline = AtlasBatch.load_yaml(File.join(ROOT, options[:timeline_index]))
text_years = {}
timeline.fetch("entries", []).each do |entry|
  range = entry["approximate_date_range"] || {}
  next unless range["start_year"] && range["end_year"]

  midpoint = (range["start_year"].to_i + range["end_year"].to_i) / 2
  Array(entry["current_text_paths"]).each { |path| text_years[path] = midpoint }
end

# family => era_id => { count:, traditions: Set }
flow = Hash.new { |hash, key| hash[key] = Hash.new { |h2, k2| h2[k2] = { "count" => 0, "traditions" => Set.new } } }
first_attestation = {}
undated_texts = Hash.new(0)
record_count = 0

Dir.glob(File.join(ROOT, options[:extraction_glob])).sort.each do |path|
  record = AtlasBatch.load_yaml(path)
  next if record.empty? || !record.is_a?(Hash)

  source = record["source_text_path"].to_s
  next if source.empty?

  record_count += 1
  year = text_years[source]
  if year.nil?
    undated_texts[source] += 1
    next
  end
  era = era_for(year)
  next unless era

  tradition = source.split("/")[2].to_s
  families = Array(record["candidate_motifs"])
             .flat_map { |motif| Array(motif["taxonomy_refs"]) }
             .filter_map { |ref| raw_to_canonical[ref.to_s] }
             .uniq
  families.each do |family|
    cell = flow[family][era["id"]]
    cell["count"] += 1
    cell["traditions"] << tradition
    if first_attestation[family].nil? || year < first_attestation[family]["year"]
      first_attestation[family] = { "year" => year, "text" => source, "tradition" => tradition }
    end
  end
end

families_out = flow.map do |family, eras|
  {
    "family" => family,
    "label" => family_labels[family] || family,
    "total" => eras.values.sum { |cell| cell["count"] },
    "first_attestation" => first_attestation[family],
    "eras" => ERAS.map do |era|
      cell = eras[era["id"]]
      {
        "era" => era["id"],
        "count" => cell["count"],
        "tradition_count" => cell["traditions"].size,
        "traditions" => cell["traditions"].sort
      }
    end
  }
end.sort_by { |entry| -entry["total"] }

output = {
  "motif_era_flow_version" => "1",
  "generated_at" => AtlasBatch.utc_now,
  "eras" => ERAS,
  "summary" => {
    "records_seen" => record_count,
    "dated_texts" => text_years.length,
    "undated_texts" => undated_texts.length,
    "undated_record_count" => undated_texts.values.sum,
    "families" => families_out.length
  },
  "families" => families_out
}

AtlasBatch.write_yaml(File.join(ROOT, options[:output]), output)
puts "families: #{families_out.length}; dated texts: #{text_years.length}; undated texts skipped: #{undated_texts.length}"
puts "wrote #{options[:output]}"
