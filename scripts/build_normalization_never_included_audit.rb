#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "json"
require "optparse"
require "set"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DEFAULT_OUTPUT = File.join(ROOT, "tmp", "normalization-never-included-audit-#{Date.today.iso8601}.yml")

options = {
  motif_index_path: "data/indexes/motif-occurrences.yml",
  output_path: DEFAULT_OUTPUT
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_normalization_never_included_audit.rb [options]"
  parser.on("--motif-index PATH", "Motif occurrence index YAML path") { |value| options[:motif_index_path] = value }
  parser.on("--output PATH", "Output audit YAML path") { |value| options[:output_path] = value }
end.parse!

def project_path(path)
  File.expand_path(path, ROOT)
end

def relative_path(path)
  File.expand_path(path, ROOT).sub("#{ROOT}/", "")
end

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def read_jsonl(path)
  File.readlines(path, chomp: true).map do |line|
    next if line.strip.empty?

    JSON.parse(line)
  rescue JSON::ParserError
    nil
  end.compact
end

def collect_motif_ids(value, ids)
  case value
  when Hash
    motif_id = value["motif_id"]
    ids.add(motif_id.to_s) unless motif_id.to_s.empty?

    Array(value["motif_ids"]).each { |id| ids.add(id.to_s) unless id.to_s.empty? }
    Array(value["motifs"]).each { |motif| collect_motif_ids(motif, ids) }
    Array(value["suggestions"]).each { |suggestion| collect_motif_ids(suggestion, ids) }
    Array(value["review_needed"]).each { |row| collect_motif_ids(row, ids) }
    Array(value["accepted"]).each { |row| collect_motif_ids(row, ids) }
    Array(value["auto_accepted"]).each { |row| collect_motif_ids(row, ids) }
  when Array
    value.each { |item| collect_motif_ids(item, ids) }
  end
end

def normalization_run_files
  patterns = [
    File.join(ROOT, "data", "batches", "normalization-suggestions-*", "normalization-suggestion-request-map.jsonl"),
    File.join(ROOT, "data", "reviews", "normalization-suggestions", "*", "suggestion-batches.jsonl"),
    File.join(ROOT, "data", "reviews", "normalization-suggestions", "*", "suggestions.jsonl"),
    File.join(ROOT, "data", "reviews", "normalization-suggestions", "*", "auto-acceptance.yml")
  ]
  patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq.sort
end

motif_index_path = project_path(options.fetch(:motif_index_path))
output_path = project_path(options.fetch(:output_path))

abort "Motif index not found: #{relative_path(motif_index_path)}" unless File.file?(motif_index_path)

included_ids = Set.new
source_files = normalization_run_files
source_files.each do |path|
  if File.extname(path) == ".jsonl"
    read_jsonl(path).each { |record| collect_motif_ids(record, included_ids) }
  else
    collect_motif_ids(load_yaml(path), included_ids)
  end
end

motif_index = load_yaml(motif_index_path)
motifs = Array(motif_index["motifs"]).map do |motif|
  motif_id = motif.fetch("motif_id").to_s
  next if motif_id.empty? || included_ids.include?(motif_id)

  traditions = motif.fetch("traditions", {})
  {
    "motif_id" => motif_id,
    "label" => motif["label"].to_s,
    "occurrences" => Array(motif["occurrences"]).length,
    "traditions" => traditions.is_a?(Hash) ? traditions.keys.map(&:to_s).sort : Array(traditions).map(&:to_s).sort
  }
end.compact.sort_by { |motif| [-motif["occurrences"].to_i, motif["motif_id"]] }

audit = {
  "generated_on" => Date.today.iso8601,
  "source" => relative_path(motif_index_path),
  "method" => "Motifs are selected when their motif_id is absent from all normalization-suggestion request maps and ingested normalization-suggestion review outputs found under data/batches and data/reviews.",
  "normalization_run_sources_scanned" => source_files.map { |path| relative_path(path) },
  "motif_count" => Array(motif_index["motifs"]).length,
  "included_in_prior_normalization_count" => included_ids.length,
  "never_included_count" => motifs.length,
  "mapped_count" => Array(motif_index["motifs"]).length - motifs.length,
  "unmapped_count" => motifs.length,
  "buckets" => [
    {
      "id" => "never_included_in_normalization",
      "label" => "Never Included In Any Normalization Run",
      "count" => motifs.length,
      "motifs" => motifs
    }
  ]
}

FileUtils.mkdir_p(File.dirname(output_path))
File.write(output_path, "#{YAML.dump(audit)}\n")

puts "wrote #{relative_path(output_path)}"
puts "motif_count=#{audit["motif_count"]}"
puts "included_in_prior_normalization_count=#{audit["included_in_prior_normalization_count"]}"
puts "never_included_count=#{audit["never_included_count"]}"
