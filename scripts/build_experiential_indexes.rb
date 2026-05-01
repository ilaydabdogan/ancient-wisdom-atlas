#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Build the experiential corpus indexes.
#
# Reads the experiential extraction records under
# extractions/generated/experiential-batch/ and produces:
#   - data/indexes/experiential-motif-occurrences.yml
#   - data/indexes/experiential-extraction-summary.yml
#
# These indexes are deliberately separate from the ancient corpus indexes:
#   - data/indexes/motif-occurrences.yml (ancient)
#   - data/indexes/canonical-motif-frequency.yml (ancient)
# Build scripts for the ancient indexes and the public site exclude experiential
# extractions, so the two corpora cannot leak into each other.
#
# Usage: ruby scripts/build_experiential_indexes.rb

require "date"
require "yaml"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
EXPERIENTIAL_DIR = File.join(ROOT, "extractions/generated/experiential-batch")
MOTIF_INDEX_PATH = File.join(ROOT, "data/indexes/experiential-motif-occurrences.yml")
SUMMARY_INDEX_PATH = File.join(ROOT, "data/indexes/experiential-extraction-summary.yml")
MANIFEST_PATH = File.join(ROOT, "data/experiential/extraction-manifest.yml")

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def relative(path)
  path.sub(ROOT + "/", "")
end

def text_title(source_path)
  metadata = nil
  raw = File.read(File.join(ROOT, source_path))
  if raw =~ /\A---\n(.*?)\n---\n/m
    metadata = YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date, Time], aliases: false)
  end
  metadata && metadata["title"] ? metadata["title"] : File.basename(source_path, ".md")
end

records = Dir.glob(File.join(EXPERIENTIAL_DIR, "**", "*.{yml,yaml}")).sort

motif_buckets = Hash.new do |hash, motif_id|
  hash[motif_id] = {
    "motif_id" => motif_id,
    "label" => nil,
    "traditions" => Hash.new(0),
    "sub_corpora" => Hash.new(0),
    "occurrences" => []
  }
end

per_text = Hash.new do |hash, source_path|
  hash[source_path] = {
    "source_path" => source_path,
    "title" => text_title(source_path),
    "tradition" => nil,
    "sub_corpus" => nil,
    "record_count" => 0,
    "distinct_motifs" => Set.new,
    "total_motif_occurrences" => 0,
    "extraction_paths" => []
  }
end

require "set"

records.each do |path|
  record = load_yaml(path)
  source_path = record.fetch("source_text_path")
  tradition = record.fetch("tradition", "experiential")
  sub_corpus = record.fetch("sub_corpus", tradition)

  bucket = per_text[source_path]
  bucket["tradition"] = tradition
  bucket["sub_corpus"] = sub_corpus
  bucket["record_count"] += 1
  bucket["extraction_paths"] << relative(path)

  motifs = record.fetch("candidate_motifs", [])
  motifs.each do |motif|
    refs = Array(motif["taxonomy_refs"])
    next if refs.empty?

    refs.each do |motif_id|
      bucket["distinct_motifs"] << motif_id
      bucket["total_motif_occurrences"] += 1

      m = motif_buckets[motif_id]
      m["label"] ||= motif["label"]
      m["traditions"][tradition] += 1
      m["sub_corpora"][sub_corpus] += 1

      evidence = record.fetch("evidence", []).map do |ev|
        {
          "id" => ev["id"],
          "locator" => ev["locator"],
          "type" => ev["type"],
          "quote_or_summary" => ev["quote_or_summary"]
        }
      end

      m["occurrences"] << {
        "record_id" => record.fetch("record_id"),
        "extraction_path" => relative(path),
        "source_text_path" => source_path,
        "source_title" => text_title(source_path),
        "tradition" => tradition,
        "sub_corpus" => sub_corpus,
        "passage_locator" => record.dig("passage_locator", "label"),
        "motif_label" => motif["label"],
        "basis" => motif["basis"],
        "confidence" => motif["confidence"],
        "evidence" => evidence
      }
    end
  end
end

# Sort motifs by descending occurrence count, then alphabetical.
sorted_motifs = motif_buckets.values.sort_by { |m| [-m["occurrences"].length, m["motif_id"]] }
sorted_motifs.each do |m|
  m["traditions"] = m["traditions"].sort_by { |_, count| -count }.to_h
  m["sub_corpora"] = m["sub_corpora"].sort_by { |_, count| -count }.to_h
  m["occurrences"] = m["occurrences"].sort_by { |occ| [occ["tradition"], occ["source_text_path"], occ["record_id"]] }
end

motif_index = {
  "generated_on" => Date.today.iso8601,
  "source" => "extractions/generated/experiential-batch",
  "isolation_note" => "Experiential corpus motif index. Strictly separate from data/indexes/motif-occurrences.yml. Motif slugs were authored independently of the ancient corpus taxonomy.",
  "motif_count" => sorted_motifs.length,
  "occurrence_count" => sorted_motifs.sum { |m| m["occurrences"].length },
  "motifs" => sorted_motifs
}

per_text_rows = per_text.values.map do |row|
  row.merge(
    "distinct_motifs" => row["distinct_motifs"].to_a.sort,
    "distinct_motif_count" => row["distinct_motifs"].size
  )
end.sort_by { |row| [row["sub_corpus"], row["source_path"]] }

summary_index = {
  "generated_on" => Date.today.iso8601,
  "source" => "extractions/generated/experiential-batch",
  "isolation_note" => "Experiential extraction summary. Strictly separate from data/indexes/extraction-coverage.yml.",
  "text_count" => per_text_rows.length,
  "record_count" => records.length,
  "sub_corpus_breakdown" => per_text_rows.group_by { |row| row["sub_corpus"] }.transform_values do |rows|
    {
      "text_count" => rows.length,
      "record_count" => rows.sum { |r| r["record_count"] },
      "total_motif_occurrences" => rows.sum { |r| r["total_motif_occurrences"] },
      "distinct_motifs" => rows.flat_map { |r| r["distinct_motifs"] }.uniq.sort
    }
  end,
  "texts" => per_text_rows
}

FileUtils.mkdir_p(File.dirname(MOTIF_INDEX_PATH))
File.write(MOTIF_INDEX_PATH, "---\n" + motif_index.to_yaml(line_width: -1).sub(/\A---\n/, ""))
File.write(SUMMARY_INDEX_PATH, "---\n" + summary_index.to_yaml(line_width: -1).sub(/\A---\n/, ""))

puts "Wrote #{relative(MOTIF_INDEX_PATH)} (#{motif_index['motif_count']} motifs, #{motif_index['occurrence_count']} occurrences)"
puts "Wrote #{relative(SUMMARY_INDEX_PATH)} (#{summary_index['text_count']} texts, #{summary_index['record_count']} records)"
