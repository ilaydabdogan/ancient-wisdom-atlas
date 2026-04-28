#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TODAY = Date.today.iso8601

EXTRACTION_GLOB = File.join(ROOT, "extractions", "**", "*.{yml,yaml}")
INDEX_PATH = File.join(ROOT, "data", "indexes", "motif-occurrences.yml")
MARKDOWN_PATH = File.join(ROOT, "comparisons", "motif-index.md")
TAXONOMY_PATH = File.join(ROOT, "taxonomy", "motifs.yml")
MOTIF_LABELS = begin
  motifs = YAML.safe_load(File.read(TAXONOMY_PATH), permitted_classes: [Date], aliases: false)
  motifs.fetch("motif_families", {}).transform_values { |value| value["label"] }
end.freeze

def relative(path)
  path.sub("#{ROOT}/", "")
end

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def front_matter(path)
  return {} unless path && File.file?(path)

  raw = File.read(path)
  return {} unless raw.start_with?("---\n")

  parts = raw.split(/^---\s*$/, 3)
  YAML.safe_load(parts[1] || "", permitted_classes: [Date], aliases: false) || {}
end

def slugify(value)
  value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
end

def display_motif(motif, motif_id)
  taxonomy_label = MOTIF_LABELS[motif_id.to_s]
  return taxonomy_label if taxonomy_label && !taxonomy_label.empty?

  label = motif["label"].to_s.strip
  label.empty? ? motif_id.to_s.tr("_", " ") : label.tr("_", " ")
end

def tradition_from(record, source_meta)
  source_meta["tradition"] || record.fetch("source_text_path", "").split("/")[2] || "unknown"
end

def evidence_for(record, refs)
  evidence = record.fetch("evidence", [])
  selected = evidence.select { |item| refs.include?(item["id"]) }
  selected.map do |item|
    {
      "id" => item["id"],
      "locator" => item["locator"],
      "type" => item["type"],
      "quote_or_summary" => item["quote_or_summary"]
    }
  end
end

groups = {}

Dir.glob(EXTRACTION_GLOB).sort.each do |path|
  record = load_yaml(path)
  source_path = record["source_text_path"]
  source_meta = front_matter(File.join(ROOT, source_path.to_s))
  tradition = tradition_from(record, source_meta)
  source_title = source_meta["title"] || File.basename(source_path.to_s, ".md")
  locator = record.dig("passage_locator", "label")

  record.fetch("candidate_motifs", []).each do |motif|
    refs = motif.fetch("taxonomy_refs", [])
    refs = [slugify(motif["label"])] if refs.empty?

    refs.each do |motif_id|
      motif_id = slugify(motif_id)
      groups[motif_id] ||= {
        "motif_id" => motif_id,
        "label" => display_motif(motif, motif_id),
        "traditions" => {},
        "occurrences" => []
      }

      groups[motif_id]["traditions"][tradition] ||= 0
      groups[motif_id]["traditions"][tradition] += 1
      groups[motif_id]["occurrences"] << {
        "record_id" => record["record_id"],
        "extraction_path" => relative(path),
        "source_text_path" => source_path,
        "source_title" => source_title,
        "tradition" => tradition,
        "culture" => source_meta["culture"],
        "region" => source_meta["region"],
        "passage_locator" => locator,
        "motif_label" => motif["label"],
        "basis" => motif["basis"],
        "confidence" => motif["confidence"],
        "evidence" => evidence_for(record, motif.fetch("evidence_refs", []))
      }
    end
  end
end

sorted_groups = groups.values.sort_by { |group| [-group["occurrences"].length, group["motif_id"]] }

FileUtils.mkdir_p(File.dirname(INDEX_PATH))
File.write(
  INDEX_PATH,
  YAML.dump(
    {
      "generated_on" => TODAY,
      "source" => "extractions",
      "motif_count" => sorted_groups.length,
      "occurrence_count" => sorted_groups.sum { |group| group["occurrences"].length },
      "motifs" => sorted_groups
    }
  )
)

FileUtils.mkdir_p(File.dirname(MARKDOWN_PATH))

markdown = []
markdown << "---"
markdown << "id: comparison.motif_index"
markdown << "title: Motif Occurrence Index"
markdown << "pattern_type: generated_index"
markdown << "generated_on: '#{TODAY}'"
markdown << "source: data/indexes/motif-occurrences.yml"
markdown << "rights:"
markdown << "  training_use: allowed"
markdown << "---"
markdown << ""
markdown << "# Motif Occurrence Index"
markdown << ""
markdown << "> Generated from extraction records. This page shows where motifs appear; it does not claim direct borrowing or shared origin."
markdown << ""
markdown << "## Summary"
markdown << ""
markdown << "| Motif | Occurrences | Traditions |"
markdown << "| --- | ---: | --- |"

sorted_groups.each do |group|
  traditions = group["traditions"].sort.map { |name, count| "#{name} (#{count})" }.join(", ")
  markdown << "| `#{group["motif_id"]}` | #{group["occurrences"].length} | #{traditions} |"
end

sorted_groups.each do |group|
  markdown << ""
  markdown << "## #{group["label"].split.map(&:capitalize).join(' ')}"
  markdown << ""
  markdown << "- Motif id: `#{group["motif_id"]}`"
  markdown << "- Occurrences: #{group["occurrences"].length}"
  markdown << "- Traditions: #{group["traditions"].keys.sort.join(', ')}"
  markdown << ""
  markdown << "| Tradition | Source | Passage | Motif Label | Confidence | Extraction |"
  markdown << "| --- | --- | --- | --- | --- | --- |"

  group["occurrences"].sort_by { |occ| [occ["tradition"].to_s, occ["source_title"].to_s, occ["passage_locator"].to_s] }.each do |occ|
    link = "[record](../#{occ["extraction_path"]})"
    source = "[#{occ["source_title"]}](../#{occ["source_text_path"]})"
    markdown << "| #{occ["tradition"]} | #{source} | #{occ["passage_locator"]} | #{occ["motif_label"]} | #{occ["confidence"]} | #{link} |"
  end
end

File.write(MARKDOWN_PATH, markdown.join("\n") + "\n")

puts "wrote #{relative(INDEX_PATH)}"
puts "wrote #{relative(MARKDOWN_PATH)}"
