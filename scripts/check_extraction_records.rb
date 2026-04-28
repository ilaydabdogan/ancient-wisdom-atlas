#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "yaml"

ROOT = File.expand_path("..", __dir__)
EXTRACTION_GLOB = File.join(ROOT, "extractions", "**", "*.{yml,yaml}")
TAXONOMY_PATH = File.join(ROOT, "taxonomy", "motifs.yml")

REQUIRED_TOP_LEVEL = %w[
  record_id source_text_path passage_locator literal_observations figures roles
  symbols scenes candidate_motifs comparison_claims evidence confidence reviewer_status
].freeze

ARRAY_FIELDS = %w[
  literal_observations figures roles symbols scenes candidate_motifs comparison_claims evidence
].freeze

FIELDS_WITH_EVIDENCE_REFS = %w[
  literal_observations figures roles symbols scenes candidate_motifs comparison_claims
].freeze

def relative(path)
  path.sub("#{ROOT}/", "")
end

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def numeric_locator?(value)
  value.to_s.match?(/\A\d+\z/)
end

known_motif_refs = load_yaml(TAXONOMY_PATH).fetch("motif_families", {}).keys
errors = []
warnings = []

Dir.glob(EXTRACTION_GLOB).sort.each do |path|
  record = load_yaml(path)
  label = relative(path)

  REQUIRED_TOP_LEVEL.each do |key|
    errors << "#{label}: missing #{key}" unless record.key?(key)
  end

  ARRAY_FIELDS.each do |key|
    errors << "#{label}: #{key} must be an array" unless record[key].is_a?(Array)
  end

  unless record["passage_locator"].is_a?(Hash)
    errors << "#{label}: passage_locator must be an object"
  end

  unless record["confidence"].is_a?(Hash)
    errors << "#{label}: confidence must be an object"
  end

  unless record["reviewer_status"].is_a?(Hash)
    errors << "#{label}: reviewer_status must be an object"
  end

  source_path = record["source_text_path"].to_s
  absolute_source_path = File.join(ROOT, source_path)
  if source_path.empty?
    errors << "#{label}: source_text_path is empty"
  elsif !File.file?(absolute_source_path)
    errors << "#{label}: source_text_path does not exist: #{source_path}"
  elsif record["passage_locator"].is_a?(Hash)
    start_line = record.dig("passage_locator", "start")
    end_line = record.dig("passage_locator", "end")
    if numeric_locator?(start_line) && numeric_locator?(end_line)
      line_count = File.readlines(absolute_source_path).length
      if start_line.to_i < 1 || end_line.to_i < start_line.to_i || end_line.to_i > line_count
        errors << "#{label}: passage line range #{start_line}-#{end_line} is outside #{source_path} (#{line_count} lines)"
      end
    end
  end

  evidence_ids = Array(record["evidence"]).map do |evidence|
    evidence["id"] if evidence.is_a?(Hash)
  end.compact
  evidence_id_lookup = evidence_ids.to_h { |id| [id, true] }

  if evidence_ids.length != evidence_ids.uniq.length
    errors << "#{label}: duplicate evidence ids"
  end

  FIELDS_WITH_EVIDENCE_REFS.each do |field|
    Array(record[field]).each do |row|
      next unless row.is_a?(Hash)

      Array(row["evidence_refs"]).each do |ref|
        errors << "#{label}: #{field} #{row['id'] || row['label'] || row['claim']} references missing evidence #{ref}" unless evidence_id_lookup[ref]
      end
    end
  end

  Array(record["candidate_motifs"]).each do |motif|
    next unless motif.is_a?(Hash)

    Array(motif["taxonomy_refs"]).each do |motif_ref|
      warnings << "#{label}: unknown motif taxonomy ref #{motif_ref}" unless known_motif_refs.include?(motif_ref)
    end
  end
end

warnings.first(80).each { |warning| warn "warning: #{warning}" }
warn "warning: #{warnings.length - 80} additional extraction warning(s) omitted" if warnings.length > 80

if errors.empty?
  puts "extraction records ok (#{warnings.length} warning#{warnings.length == 1 ? "" : "s"})"
else
  warn errors.join("\n")
  exit 1
end
