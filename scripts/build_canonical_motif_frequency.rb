#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TODAY = Date.today.iso8601

MOTIF_INDEX_PATH = File.join(ROOT, "data", "indexes", "motif-occurrences.yml")
NORMALIZATION_PATH = File.join(ROOT, "taxonomy", "motif-normalization.yml")
OUTPUT_YAML = File.join(ROOT, "data", "indexes", "canonical-motif-frequency.yml")
OUTPUT_MARKDOWN = File.join(ROOT, "docs", "canonical-motif-frequency.md")

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def group_id_for(motif_id, normalization, group_ids)
  raw_index = normalization.fetch("raw_motif_group_index", {})
  aliases = normalization.fetch("aliases", {})
  groups = Array(normalization["canonical_motif_groups"])

  return raw_index.fetch(motif_id).fetch("group_id") if raw_index.key?(motif_id)
  return motif_id if group_ids.include?(motif_id)

  groups.each do |group|
    next unless group.is_a?(Hash)
    next unless Array(group["aliases"]).include?(motif_id) || Array(group["children"]).include?(motif_id)

    return group.fetch("id")
  end

  alias_entry = aliases[motif_id]
  return nil unless alias_entry

  (Array(alias_entry["canonical_refs"]) + Array(alias_entry["parent_refs"])).each do |ref|
    mapped_group = group_id_for(ref, normalization, group_ids)
    return mapped_group if mapped_group
  end

  nil
end

motif_index = load_yaml(MOTIF_INDEX_PATH)
normalization = load_yaml(NORMALIZATION_PATH)

groups = Array(normalization["canonical_motif_groups"]).each_with_object({}) do |group, memo|
  next unless group.is_a?(Hash)

  memo[group.fetch("id")] = {
    "canonical_motif_id" => group.fetch("id"),
    "label" => group.fetch("label"),
    "description" => group["description"].to_s.strip,
    "related" => Array(group["related"]),
    "is_meta_group" => group.fetch("id").start_with?("_meta"),
    "traditions" => Hash.new(0),
    "mapped_motifs" => []
  }
end

group_ids = groups.keys
raw_index = normalization.fetch("raw_motif_group_index", {})

motif_index.fetch("motifs", []).each do |motif|
  motif_id = motif.fetch("motif_id")
  group_id = group_id_for(motif_id, normalization, group_ids)
  next unless group_id && groups[group_id]

  tradition_counts = motif.fetch("traditions", {})
  tradition_counts.each do |tradition, count|
    groups.fetch(group_id).fetch("traditions")[tradition] += count.to_i
  end

  groups.fetch(group_id).fetch("mapped_motifs") << {
    "motif_id" => motif_id,
    "label" => motif["label"],
    "relationship" => raw_index.dig(motif_id, "relationship") || (motif_id == group_id ? "canonical_group" : "alias"),
    "occurrence_count" => Array(motif["occurrences"]).length,
    "tradition_count" => tradition_counts.keys.length,
    "traditions" => tradition_counts.sort.to_h
  }
end

frequency_records = groups.values.map do |group|
  traditions = group.fetch("traditions").sort.to_h
  mapped_motifs = group.fetch("mapped_motifs").sort_by do |motif|
    [-motif.fetch("tradition_count"), -motif.fetch("occurrence_count"), motif.fetch("motif_id")]
  end

  group.merge(
    "traditions" => traditions,
    "tradition_count" => traditions.keys.length,
    "occurrence_count" => traditions.values.sum,
    "mapped_motif_count" => mapped_motifs.length,
    "mapped_motifs" => mapped_motifs
  )
end.sort_by do |record|
  [
    record.fetch("is_meta_group") ? 1 : 0,
    -record.fetch("tradition_count"),
    -record.fetch("occurrence_count"),
    record.fetch("canonical_motif_id")
  ]
end

mapped_motif_ids = frequency_records.flat_map { |record| record.fetch("mapped_motifs").map { |motif| motif.fetch("motif_id") } }.uniq
audit = {
  "generated_on" => TODAY,
  "source" => "data/indexes/motif-occurrences.yml",
  "normalization_source" => "taxonomy/motif-normalization.yml",
  "method" => "Counts distinct traditions for indexed motif IDs that map to canonical_motif_groups through raw_motif_group_index, group children/aliases, or normalization aliases.",
  "indexed_motif_count" => motif_index.fetch("motif_count"),
  "indexed_occurrence_count" => motif_index.fetch("occurrence_count"),
  "canonical_motif_group_count" => frequency_records.length,
  "mapped_motif_count" => mapped_motif_ids.length,
  "unmapped_motif_count" => motif_index.fetch("motif_count") - mapped_motif_ids.length,
  "canonical_motifs" => frequency_records
}

FileUtils.mkdir_p(File.dirname(OUTPUT_YAML))
File.write(OUTPUT_YAML, YAML.dump(audit))

markdown = []
markdown << "# Canonical Motif Frequency By Tradition"
markdown << ""
markdown << "Generated on #{TODAY} from `data/indexes/motif-occurrences.yml` and `taxonomy/motif-normalization.yml`."
markdown << ""
markdown << "This report counts only motif IDs that already map to a canonical normalization group. It is meant to show which normalized patterns are appearing across many traditions, not to make transmission claims."
markdown << ""
markdown << "## Summary"
markdown << ""
markdown << "- Indexed motif IDs: #{audit.fetch("indexed_motif_count")}"
markdown << "- Indexed motif occurrences: #{audit.fetch("indexed_occurrence_count")}"
markdown << "- Canonical motif groups: #{audit.fetch("canonical_motif_group_count")}"
markdown << "- Mapped motif IDs counted: #{audit.fetch("mapped_motif_count")}"
markdown << "- Unmapped motif IDs excluded: #{audit.fetch("unmapped_motif_count")}"
markdown << ""
markdown << "## Ranked Canonical Motifs"
markdown << ""
markdown << "| Rank | Canonical Motif | Distinct Traditions | Occurrences | Mapped Motif IDs | Top Traditions |"
markdown << "| ---: | --- | ---: | ---: | ---: | --- |"
frequency_records.each_with_index do |record, index|
  top_traditions = record.fetch("traditions").sort_by { |_tradition, count| -count }.first(5).map { |tradition, count| "#{tradition} (#{count})" }.join(", ")
  label = record.fetch("is_meta_group") ? "#{record.fetch("label")} [meta]" : record.fetch("label")
  markdown << "| #{index + 1} | `#{record.fetch("canonical_motif_id")}` #{label} | #{record.fetch("tradition_count")} | #{record.fetch("occurrence_count")} | #{record.fetch("mapped_motif_count")} | #{top_traditions} |"
end

frequency_records.each do |record|
  next if record.fetch("mapped_motifs").empty?

  markdown << ""
  markdown << "## #{record.fetch("label")}"
  markdown << ""
  markdown << "- Canonical motif ID: `#{record.fetch("canonical_motif_id")}`"
  markdown << "- Distinct traditions: #{record.fetch("tradition_count")}"
  markdown << "- Occurrences: #{record.fetch("occurrence_count")}"
  markdown << "- Mapped motif IDs: #{record.fetch("mapped_motif_count")}"
  markdown << ""
  markdown << "| Mapped Motif ID | Relationship | Traditions | Occurrences |"
  markdown << "| --- | --- | ---: | ---: |"
  record.fetch("mapped_motifs").each do |motif|
    markdown << "| `#{motif.fetch("motif_id")}` | #{motif.fetch("relationship")} | #{motif.fetch("tradition_count")} | #{motif.fetch("occurrence_count")} |"
  end
end

FileUtils.mkdir_p(File.dirname(OUTPUT_MARKDOWN))
File.write(OUTPUT_MARKDOWN, markdown.join("\n") + "\n")

puts "wrote #{OUTPUT_YAML.sub("#{ROOT}/", "")}"
puts "wrote #{OUTPUT_MARKDOWN.sub("#{ROOT}/", "")}"
puts "mapped=#{audit.fetch("mapped_motif_count")} unmapped=#{audit.fetch("unmapped_motif_count")}"
