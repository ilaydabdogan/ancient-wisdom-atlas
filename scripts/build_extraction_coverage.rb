#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "yaml"

require_relative "batch_common"

ROOT = AtlasBatch::ROOT
TODAY = Date.today.iso8601

TEXT_GLOBS = [
  "texts/public-domain/**/*.md",
  "texts/open-license/**/*.md",
  "texts/permissioned/**/*.md"
].freeze

EXTRACTION_GLOB = File.join(ROOT, "extractions", "**", "*.{yml,yaml}")
INDEX_PATH = File.join(ROOT, "data", "indexes", "extraction-coverage.yml")
MARKDOWN_PATH = File.join(ROOT, "docs", "extraction-coverage.md")

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def target_record_count(word_count)
  [[(word_count / 4_000.0).ceil, 2].max, 40].min
end

def coverage_status(record_count, target_count, candidate_motif_count, needs_review_count)
  return "no_extractions" if record_count.zero?

  ratio = record_count.to_f / target_count
  return "thin" if ratio < 0.25 || candidate_motif_count < 3
  return "developing" if ratio < 0.75
  return "dense_draft" if needs_review_count.positive?

  "dense_reviewed"
end

def priority_for(status)
  case status
  when "no_extractions", "thin"
    "high"
  when "developing", "dense_draft"
    "medium"
  else
    "low"
  end
end

def front_matter_and_body(path)
  parsed = AtlasBatch.read_markdown(path)
  [parsed.fetch("metadata"), parsed.fetch("body")]
end

extractions_by_source = Hash.new do |hash, key|
  hash[key] = {
    "record_count" => 0,
    "generated_record_count" => 0,
    "needs_review_count" => 0,
    "reviewed_count" => 0,
    "candidate_motif_count" => 0,
    "taxonomy_ref_count" => 0,
    "comparison_claim_count" => 0,
    "empty_motif_record_count" => 0,
    "extraction_paths" => []
  }
end

Dir.glob(EXTRACTION_GLOB).sort.each do |path|
  record = load_yaml(path)
  source_path = record["source_text_path"].to_s
  next if source_path.empty?

  bucket = extractions_by_source[source_path]
  motifs = record.fetch("candidate_motifs", [])
  taxonomy_refs = motifs.flat_map { |motif| motif.fetch("taxonomy_refs", []) }
  status = record.dig("reviewer_status", "status").to_s

  bucket["record_count"] += 1
  bucket["generated_record_count"] += 1 if AtlasBatch.relative_path(path).include?("/generated/")
  bucket["needs_review_count"] += 1 if status.empty? || status == "needs_review" || status == "draft"
  bucket["reviewed_count"] += 1 if status == "reviewed"
  bucket["candidate_motif_count"] += motifs.length
  bucket["taxonomy_ref_count"] += taxonomy_refs.length
  bucket["comparison_claim_count"] += record.fetch("comparison_claims", []).length
  bucket["empty_motif_record_count"] += 1 if motifs.empty?
  bucket["extraction_paths"] << AtlasBatch.relative_path(path)
end

text_paths = TEXT_GLOBS.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.sort

rows = text_paths.map do |path|
  relative_path = AtlasBatch.relative_path(path)
  metadata, body = front_matter_and_body(path)
  extraction_stats = extractions_by_source[relative_path]
  word_count = body.scan(/\S+/).length
  target_count = target_record_count(word_count)
  record_count = extraction_stats.fetch("record_count")
  candidate_motif_count = extraction_stats.fetch("candidate_motif_count")
  needs_review_count = extraction_stats.fetch("needs_review_count")
  status = coverage_status(record_count, target_count, candidate_motif_count, needs_review_count)

  {
    "source_text_path" => relative_path,
    "source_text_id" => metadata["id"],
    "title" => metadata["title"] || File.basename(path, ".md"),
    "tradition" => metadata["tradition"],
    "culture" => metadata["culture"],
    "region" => metadata["region"],
    "date_range" => metadata["date_range"],
    "word_count" => word_count,
    "target_extraction_records" => target_count,
    "coverage_ratio" => (target_count.positive? ? (record_count.to_f / target_count).round(3) : 0.0),
    "status" => status,
    "priority" => priority_for(status),
    "needs_full_extraction" => %w[no_extractions thin developing].include?(status),
    "needs_review_or_normalization" => needs_review_count.positive?,
    "extraction_record_count" => record_count,
    "generated_record_count" => extraction_stats.fetch("generated_record_count"),
    "needs_review_count" => needs_review_count,
    "reviewed_count" => extraction_stats.fetch("reviewed_count"),
    "candidate_motif_count" => candidate_motif_count,
    "taxonomy_ref_count" => extraction_stats.fetch("taxonomy_ref_count"),
    "comparison_claim_count" => extraction_stats.fetch("comparison_claim_count"),
    "empty_motif_record_count" => extraction_stats.fetch("empty_motif_record_count"),
    "extraction_paths" => extraction_stats.fetch("extraction_paths")
  }
end

priority_order = { "high" => 0, "medium" => 1, "low" => 2 }
status_order = {
  "no_extractions" => 0,
  "thin" => 1,
  "developing" => 2,
  "dense_draft" => 3,
  "dense_reviewed" => 4
}

rows.sort_by! do |row|
  [
    priority_order.fetch(row["priority"], 9),
    status_order.fetch(row["status"], 9),
    row["tradition"].to_s,
    row["title"].to_s
  ]
end

summary = {
  "generated_on" => TODAY,
  "source_text_globs" => TEXT_GLOBS,
  "extraction_glob" => "extractions/**/*.{yml,yaml}",
  "text_count" => rows.length,
  "texts_with_extractions" => rows.count { |row| row["extraction_record_count"].positive? },
  "texts_without_extractions" => rows.count { |row| row["extraction_record_count"].zero? },
  "texts_needing_full_extraction" => rows.count { |row| row["needs_full_extraction"] },
  "texts_needing_review_or_normalization" => rows.count { |row| row["needs_review_or_normalization"] },
  "extraction_record_count" => rows.sum { |row| row["extraction_record_count"] },
  "candidate_motif_count" => rows.sum { |row| row["candidate_motif_count"] },
  "taxonomy_ref_count" => rows.sum { |row| row["taxonomy_ref_count"] },
  "comparison_claim_count" => rows.sum { |row| row["comparison_claim_count"] },
  "status_counts" => rows.group_by { |row| row["status"] }.transform_values(&:length).sort.to_h,
  "priority_counts" => rows.group_by { |row| row["priority"] }.transform_values(&:length).sort.to_h
}

FileUtils.mkdir_p(File.dirname(INDEX_PATH))
File.write(
  INDEX_PATH,
  YAML.dump(
    {
      "generated_on" => TODAY,
      "summary" => summary,
      "texts" => rows
    }
  )
)

def table_row(values)
  "| #{values.join(' | ')} |"
end

def display_status(status)
  status.to_s.tr("_", " ")
end

high_priority = rows.select { |row| row["priority"] == "high" }
review_queue = rows.select { |row| row["needs_review_or_normalization"] }

markdown = []
markdown << "# Extraction Coverage"
markdown << ""
markdown << "> Generated from canonical text metadata and extraction YAML. This tells us where token-heavy extraction and review should go next."
markdown << ""
markdown << "## Summary"
markdown << ""
markdown << "- Generated on: #{TODAY}"
markdown << "- Canonical texts checked: #{summary['text_count']}"
markdown << "- Texts with extraction records: #{summary['texts_with_extractions']}"
markdown << "- Texts without extraction records: #{summary['texts_without_extractions']}"
markdown << "- Texts needing full extraction: #{summary['texts_needing_full_extraction']}"
markdown << "- Texts needing review or normalization: #{summary['texts_needing_review_or_normalization']}"
markdown << "- Extraction records counted: #{summary['extraction_record_count']}"
markdown << "- Candidate motifs counted: #{summary['candidate_motif_count']}"
markdown << ""
markdown << "## Status Logic"
markdown << ""
markdown << "- `no_extractions`: no passage-level extraction records exist yet."
markdown << "- `thin`: records exist, but coverage is far below the rough target or motif count is very small."
markdown << "- `developing`: meaningful coverage exists, but more passage coverage is still needed."
markdown << "- `dense_draft`: extraction density is acceptable, but records still need review or normalization."
markdown << "- `dense_reviewed`: extraction density is acceptable and records are marked reviewed."
markdown << ""
markdown << "The target is intentionally rough: about one extraction record per 4,000 words, with a minimum of two and a cap of forty per text. It is a planning signal, not a scholarly claim."
markdown << ""
markdown << "## High-Priority Extraction Targets"
markdown << ""
markdown << table_row(["Status", "Records", "Target", "Motifs", "Tradition", "Text"])
markdown << table_row(["---", "---:", "---:", "---:", "---", "---"])
high_priority.each do |row|
  markdown << table_row([
    "`#{row['status']}`",
    row["extraction_record_count"],
    row["target_extraction_records"],
    row["candidate_motif_count"],
    row["tradition"],
    "[#{row['title']}](../#{row['source_text_path']})"
  ])
end
markdown << ""
markdown << "## Review And Normalization Queue"
markdown << ""
markdown << table_row(["Status", "Needs Review", "Generated", "Motifs", "Tradition", "Text"])
markdown << table_row(["---", "---:", "---:", "---:", "---", "---"])
review_queue.sort_by { |row| [-row["needs_review_count"], row["tradition"].to_s, row["title"].to_s] }.each do |row|
  markdown << table_row([
    "`#{row['status']}`",
    row["needs_review_count"],
    row["generated_record_count"],
    row["candidate_motif_count"],
    row["tradition"],
    "[#{row['title']}](../#{row['source_text_path']})"
  ])
end
markdown << ""
markdown << "## Batch Targeting"
markdown << ""
markdown << "Build the latest coverage index:"
markdown << ""
markdown << "```sh"
markdown << "ruby scripts/build_extraction_coverage.rb"
markdown << "```"
markdown << ""
markdown << "Prepare passage segmentation only for high-priority texts:"
markdown << ""
markdown << "```sh"
markdown << "ruby scripts/batch_segment_passages.rb \\"
markdown << "  --run-id motif-extraction-YYYY-MM-DD-high-priority \\"
markdown << "  --coverage data/indexes/extraction-coverage.yml \\"
markdown << "  --coverage-priority high \\"
markdown << "  --force"
markdown << "```"
markdown << ""
markdown << "Then prepare motif extraction requests from those passages:"
markdown << ""
markdown << "```sh"
markdown << "ruby scripts/batch_prepare_motif_requests.rb \\"
markdown << "  --run-id motif-extraction-YYYY-MM-DD-high-priority \\"
markdown << "  --model \"$OPENAI_BATCH_MODEL\" \\"
markdown << "  --max-output-tokens 12000 \\"
markdown << "  --force"
markdown << "```"
markdown << ""
markdown << "## All Texts"
markdown << ""
markdown << table_row(["Priority", "Status", "Records", "Target", "Needs Review", "Tradition", "Text"])
markdown << table_row(["---", "---", "---:", "---:", "---:", "---", "---"])
rows.each do |row|
  markdown << table_row([
    row["priority"],
    "`#{display_status(row['status'])}`",
    row["extraction_record_count"],
    row["target_extraction_records"],
    row["needs_review_count"],
    row["tradition"],
    "[#{row['title']}](../#{row['source_text_path']})"
  ])
end

FileUtils.mkdir_p(File.dirname(MARKDOWN_PATH))
File.write(MARKDOWN_PATH, markdown.join("\n") + "\n")

puts "wrote #{AtlasBatch.relative_path(INDEX_PATH)}"
puts "wrote #{AtlasBatch.relative_path(MARKDOWN_PATH)}"
