#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "optparse"
require "set"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TODAY = Date.today.iso8601
RUN_ID = "normalization-suggestions-2026-04-29-blank-retry"
REVIEW_PATH = File.join(ROOT, "data", "reviews", "normalization-suggestions", RUN_ID, "auto-acceptance.yml")
TAXONOMY_PATH = File.join(ROOT, "taxonomy", "motif-normalization.yml")
REPORT_PATH = File.join(ROOT, "docs", "normalization-blank-retry-final-review.md")
DATA_PATH = File.join(ROOT, "data", "reviews", "normalization-suggestions", RUN_ID, "final-review-policy.yml")

STOPWORDS = %w[
  a an and are as at be by for from in into is its of on or the their through to under with without
  after before during whose who whom which this that these those
  motif motifs sacred divine human mythic supernatural ritual family group pattern
].to_set.freeze

options = { dry_run: false }
OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/process_blank_retry_review_policy.rb [options]"
  parser.on("--dry-run", "Print counts without writing files") { options[:dry_run] = true }
end.parse!

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def write_yaml(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "#{YAML.dump(data)}\n")
end

def compact_text(value)
  value.to_s.gsub(/\s+/, " ").strip
end

def tokens(value)
  value.to_s.downcase.split(/[^a-z0-9]+/).reject do |token|
    token.empty? || token.length < 3 || STOPWORDS.include?(token)
  end
end

def markdown_escape(value)
  compact_text(value).gsub("|", "\\|")
end

def code(value)
  text = value.to_s
  text.empty? ? "" : "`#{text}`"
end

def groups_by_id(normalization)
  Array(normalization["canonical_motif_groups"]).each_with_object({}) do |group, memo|
    next unless group.is_a?(Hash)

    memo[group.fetch("id").to_s] = group
  end
end

def family_name_tokens(group)
  tokens([group["id"], group["label"]].join(" "))
end

def family_name_match(motif_id, group)
  motif_id_text = motif_id.to_s.downcase
  group_id = group["id"].to_s.downcase
  label_slug = group["label"].to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
  return "group_id_substring" if !group_id.empty? && motif_id_text.include?(group_id)
  return "label_substring" if !label_slug.empty? && motif_id_text.include?(label_slug)

  motif_tokens = tokens(motif_id).to_set
  overlaps = motif_tokens & family_name_tokens(group).to_set
  return "two_family_name_keywords:#{overlaps.to_a.sort.join(",")}" if overlaps.length >= 2

  long_overlap = overlaps.find { |token| token.length >= 7 }
  return "distinctive_family_keyword:#{long_overlap}" if long_overlap

  nil
end

def best_family_name_match(row, groups)
  groups.reject { |group_id, _group| group_id.start_with?("_") }.map do |group_id, group|
    basis = family_name_match(row.fetch("motif_id"), group)
    next unless basis

    score =
      case basis
      when "group_id_substring" then 100
      when "label_substring" then 90
      when /\Atwo_family_name_keywords/ then 60
      else 30
      end
    [group_id, group, basis, score]
  end.compact.max_by { |_group_id, _group, _basis, score| score }
end

def row_notes(row, suffix = nil)
  parts = []
  parts << row["rationale"].to_s unless row["rationale"].to_s.empty?
  parts << "Caution: #{row["cautions"]}" unless row["cautions"].to_s.empty?
  parts << suffix if suffix
  parts.join(" ")
end

def raw_mapping(normalization, row, group, status, action, relationship: nil, provisional: true, notes_suffix: nil)
  motif_id = row.fetch("motif_id").to_s
  normalization["raw_motif_group_index"] ||= {}
  normalization["raw_motif_group_index"][motif_id] = {
    "group_id" => group.fetch("id").to_s,
    "group_label" => group.fetch("label").to_s,
    "relationship" => relationship || row["relationship"].to_s,
    "confidence" => row["confidence"].to_s.empty? ? "heuristic" : row["confidence"].to_s,
    "review_status" => status,
    "review_action" => action,
    "provisional" => provisional,
    "source" => "data/reviews/normalization-suggestions/#{RUN_ID}/auto-acceptance.yml",
    "accepted_on" => TODAY,
    "notes" => row_notes(row, notes_suffix),
    "suggested_aliases" => Array(row["suggested_aliases"]).map(&:to_s)
  }
end

def exclude_mapping(normalization, row, status, reason)
  motif_id = row.fetch("motif_id").to_s
  normalization["excluded_from_pattern_queries"] ||= {}
  normalization["excluded_from_pattern_queries"][motif_id] = {
    "label" => row["label"].to_s,
    "reason" => row_notes(row, reason),
    "confidence" => row["confidence"].to_s,
    "accepted_on" => TODAY,
    "source" => "data/reviews/normalization-suggestions/#{RUN_ID}/auto-acceptance.yml"
  }
  normalization["raw_motif_group_index"] ||= {}
  normalization["raw_motif_group_index"][motif_id] = {
    "group_id" => "_excluded_from_pattern_queries",
    "relationship" => "excluded_episode_specific_or_meta",
    "confidence" => row["confidence"].to_s.empty? ? "heuristic" : row["confidence"].to_s,
    "review_status" => status,
    "review_action" => "exclude_from_pattern_queries",
    "provisional" => false,
    "source" => "data/reviews/normalization-suggestions/#{RUN_ID}/auto-acceptance.yml",
    "accepted_on" => TODAY,
    "notes" => row_notes(row, reason),
    "suggested_aliases" => Array(row["suggested_aliases"]).map(&:to_s)
  }
end

def row_for_report(row, extra = {})
  {
    "motif_id" => row.fetch("motif_id").to_s,
    "label" => row["label"].to_s,
    "occurrences" => row["occurrences"].to_i,
    "traditions" => Array(row["traditions"]).map(&:to_s).sort,
    "suggested_action" => row["suggested_action"].to_s,
    "suggested_group_id" => row["suggested_group_id"].to_s,
    "suggested_group_label" => row["suggested_group_label"].to_s,
    "confidence" => row["confidence"].to_s,
    "previous_reason" => row["reason"].to_s
  }.merge(extra)
end

review = load_yaml(REVIEW_PATH)
normalization = load_yaml(TAXONOMY_PATH)
groups = groups_by_id(normalization)
rows = Array(review["review_needed"])

accepted_existing = []
accepted_model_exclusions = []
keyword_mapped = []
episode_excluded = []
kept_for_review = []

rows.sort_by { |row| row["motif_id"].to_s }.each do |row|
  motif_id = row.fetch("motif_id").to_s
  suggested_group_id = row["suggested_group_id"].to_s
  suggested_group = groups[suggested_group_id]
  action = row["suggested_action"].to_s

  if action == "exclude_from_pattern_queries" || suggested_group_id == "_meta_textual"
    exclude_mapping(normalization, row, "human_policy_accepted_suggested_exclusion", "Accepted model exclusion from blank-retry review.")
    accepted_model_exclusions << row_for_report(row, "final_action" => "accepted_suggested_exclusion")
  elsif suggested_group
    raw_mapping(
      normalization,
      row,
      suggested_group,
      "human_policy_accepted_existing_group_any_confidence",
      "accepted_existing_group_any_confidence",
      provisional: true,
      notes_suffix: "Accepted by blank-retry final policy: existing suggested family at any confidence."
    )
    accepted_existing << row_for_report(row, "final_action" => "accepted_existing_group", "accepted_group_id" => suggested_group_id)
  elsif (match = best_family_name_match(row, groups))
    group_id, group, basis, = match
    raw_mapping(
      normalization,
      row,
      group,
      "human_policy_keyword_matched_family_name",
      "keyword_matched_family_name",
      relationship: "heuristic_family_name_match",
      provisional: true,
      notes_suffix: "Accepted by blank-retry final policy: motif id matched existing family name by #{basis}."
    )
    keyword_mapped << row_for_report(row, "final_action" => "keyword_mapped", "accepted_group_id" => group_id, "fit_basis" => basis)
  elsif row["occurrences"].to_i >= 2 && Array(row["traditions"]).map(&:to_s).uniq.length >= 2
    kept_for_review << row_for_report(row, "final_action" => "kept_for_cross_tradition_review")
  else
    exclude_mapping(normalization, row, "human_policy_excluded_episode_specific", "Excluded by blank-retry final policy: no existing suggested family or family-name keyword match, and not recurring across 2+ traditions.")
    episode_excluded << row_for_report(row, "final_action" => "excluded_episode_specific")
  end

  abort "empty motif id" if motif_id.empty?
end

normalization["updated_on"] = TODAY
normalization["blank_retry_final_review_policy"] = {
  "updated_on" => TODAY,
  "run_id" => RUN_ID,
  "source" => "data/reviews/normalization-suggestions/#{RUN_ID}/auto-acceptance.yml",
  "policy" => "Accept suggested existing-family placements at any confidence; accept suggested exclusions; map blank or invalid suggestions by clear family-name keyword matches; exclude remaining episode-specific rows unless they recur across 2+ traditions.",
  "counts" => {
    "review_rows_processed" => rows.length,
    "accepted_existing_group_any_confidence" => accepted_existing.length,
    "accepted_suggested_exclusions" => accepted_model_exclusions.length,
    "keyword_mapped_to_family_name" => keyword_mapped.length,
    "excluded_episode_specific" => episode_excluded.length,
    "kept_for_cross_tradition_review" => kept_for_review.length
  },
  "report_path" => "docs/normalization-blank-retry-final-review.md",
  "review_data_path" => "data/reviews/normalization-suggestions/#{RUN_ID}/final-review-policy.yml"
}

review_data = {
  "blank_retry_final_review_policy_version" => "1",
  "run_id" => RUN_ID,
  "generated_on" => TODAY,
  "source" => "data/reviews/normalization-suggestions/#{RUN_ID}/auto-acceptance.yml",
  "normalization_path" => "taxonomy/motif-normalization.yml",
  "policy" => normalization["blank_retry_final_review_policy"]["policy"],
  "counts" => normalization["blank_retry_final_review_policy"]["counts"],
  "accepted_existing_group_any_confidence" => accepted_existing,
  "accepted_suggested_exclusions" => accepted_model_exclusions,
  "keyword_mapped_to_family_name" => keyword_mapped,
  "excluded_episode_specific" => episode_excluded,
  "kept_for_cross_tradition_review" => kept_for_review
}

def table(lines, rows, columns)
  lines << "| #{columns.map(&:first).join(" | ")} |"
  lines << "| #{columns.map { |name, _key| name.end_with?("Count") || name == "Occurrences" ? "---:" : "---" }.join(" | ")} |"
  rows.each do |row|
    lines << "| #{columns.map { |_name, key|
      value = row[key]
      value = Array(value).join(", ") if value.is_a?(Array)
      key.end_with?("_id") || key == "motif_id" ? code(value) : markdown_escape(value)
    }.join(" | ")} |"
  end
end

markdown = []
markdown << "# Blank-Retry Normalization Final Review"
markdown << ""
markdown << "Generated on #{TODAY} from `data/reviews/normalization-suggestions/#{RUN_ID}/auto-acceptance.yml`."
markdown << ""
markdown << "Policy: #{normalization["blank_retry_final_review_policy"]["policy"]}"
markdown << ""
markdown << "## Summary"
markdown << ""
normalization["blank_retry_final_review_policy"]["counts"].each do |key, value|
  markdown << "- #{key.tr("_", " ")}: #{value}"
end
markdown << ""
markdown << "## Accepted Existing Groups"
markdown << ""
table(markdown, accepted_existing, [["Motif ID", "motif_id"], ["Label", "label"], ["Accepted Group", "accepted_group_id"], ["Confidence", "confidence"], ["Occurrences", "occurrences"], ["Traditions", "traditions"]])
markdown << ""
markdown << "## Keyword Mapped"
markdown << ""
table(markdown, keyword_mapped, [["Motif ID", "motif_id"], ["Label", "label"], ["Accepted Group", "accepted_group_id"], ["Basis", "fit_basis"], ["Occurrences", "occurrences"], ["Traditions", "traditions"]])
markdown << ""
markdown << "## Accepted Exclusions"
markdown << ""
table(markdown, accepted_model_exclusions + episode_excluded, [["Motif ID", "motif_id"], ["Label", "label"], ["Reason", "final_action"], ["Occurrences", "occurrences"], ["Traditions", "traditions"]])
markdown << ""
markdown << "## Kept For Cross-Tradition Review"
markdown << ""
table(markdown, kept_for_review, [["Motif ID", "motif_id"], ["Label", "label"], ["Previous Reason", "previous_reason"], ["Occurrences", "occurrences"], ["Traditions", "traditions"]])

unless options[:dry_run]
  write_yaml(TAXONOMY_PATH, normalization)
  write_yaml(DATA_PATH, review_data)
  FileUtils.mkdir_p(File.dirname(REPORT_PATH))
  File.write(REPORT_PATH, markdown.join("\n") + "\n")
end

puts "review_rows_processed=#{rows.length}"
puts "accepted_existing_group_any_confidence=#{accepted_existing.length}"
puts "accepted_suggested_exclusions=#{accepted_model_exclusions.length}"
puts "keyword_mapped_to_family_name=#{keyword_mapped.length}"
puts "excluded_episode_specific=#{episode_excluded.length}"
puts "kept_for_cross_tradition_review=#{kept_for_review.length}"
