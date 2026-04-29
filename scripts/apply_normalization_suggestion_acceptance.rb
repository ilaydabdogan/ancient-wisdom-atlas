#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "json"
require "optparse"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TODAY = Date.today.iso8601

options = {
  run_id: nil,
  suggestions_path: nil,
  normalization_path: "taxonomy/motif-normalization.yml",
  report_path: nil,
  review_data_path: nil,
  dry_run: false
}

AUTO_ACCEPT_CONFIDENCE = %w[medium high].freeze

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/apply_normalization_suggestion_acceptance.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Normalization suggestion run id") { |value| options[:run_id] = value }
  parser.on("--suggestions PATH", "Suggestions JSONL path") { |value| options[:suggestions_path] = value }
  parser.on("--normalization PATH", "Normalization YAML to update") { |value| options[:normalization_path] = value }
  parser.on("--report PATH", "Markdown review report path") { |value| options[:report_path] = value }
  parser.on("--review-data PATH", "Machine-readable review YAML path") { |value| options[:review_data_path] = value }
  parser.on("--dry-run", "Preview changes without writing files") { options[:dry_run] = true }
end.parse!

abort "--run-id is required" unless options[:run_id]

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
  end.compact
end

def existing_group_ids(normalization)
  Array(normalization["canonical_motif_groups"]).map do |group|
    group["id"] if group.is_a?(Hash)
  end.compact.to_h { |id| [id, true] }
end

def current_mapped_ids(normalization)
  ids = []
  ids.concat(normalization.fetch("aliases", {}).keys)
  ids.concat(normalization.fetch("raw_motif_group_index", {}).keys)
  Array(normalization["canonical_motif_groups"]).each do |group|
    next unless group.is_a?(Hash)

    ids << group["id"]
    ids.concat(Array(group["children"]))
    ids.concat(Array(group["aliases"]))
  end
  ids.compact.uniq.to_h { |id| [id, true] }
end

def review_row(suggestion, reason)
  {
    "motif_id" => suggestion.fetch("motif_id"),
    "label" => suggestion["label"].to_s,
    "occurrences" => suggestion["occurrences"].to_i,
    "traditions" => Array(suggestion["traditions"]).map(&:to_s).sort,
    "review_bucket_id" => suggestion["review_bucket_id"].to_s,
    "suggested_action" => suggestion["suggested_action"].to_s,
    "suggested_group_id" => suggestion["suggested_group_id"].to_s,
    "suggested_group_label" => suggestion["suggested_group_label"].to_s,
    "relationship" => suggestion["relationship"].to_s,
    "confidence" => suggestion["confidence"].to_s,
    "reason" => reason,
    "rationale" => suggestion["rationale"].to_s,
    "cautions" => suggestion["cautions"].to_s,
    "suggested_aliases" => Array(suggestion["suggested_aliases"]).map(&:to_s),
    "suggested_new_group" => suggestion["suggested_new_group"].is_a?(Hash) ? suggestion["suggested_new_group"] : {}
  }
end

run_id = options.fetch(:run_id)
suggestions_path = project_path(
  options[:suggestions_path] || File.join("data", "reviews", "normalization-suggestions", run_id, "suggestions.jsonl")
)
normalization_path = project_path(options.fetch(:normalization_path))
report_path = project_path(
  options[:report_path] || File.join("docs", "motif-normalization-auto-accept-review.md")
)
review_data_path = project_path(
  options[:review_data_path] || File.join("data", "reviews", "normalization-suggestions", run_id, "auto-acceptance.yml")
)

abort "suggestions file not found: #{relative_path(suggestions_path)}" unless File.file?(suggestions_path)
abort "normalization file not found: #{relative_path(normalization_path)}" unless File.file?(normalization_path)

normalization = load_yaml(normalization_path)
suggestions = read_jsonl(suggestions_path)
known_groups = existing_group_ids(normalization)
known_motifs = current_mapped_ids(normalization)
raw_index = normalization["raw_motif_group_index"] ||= {}

accepted = []
review_needed = []

suggestions.sort_by { |suggestion| suggestion["motif_id"].to_s }.each do |suggestion|
  motif_id = suggestion.fetch("motif_id")
  action = suggestion["suggested_action"].to_s
  confidence = suggestion["confidence"].to_s
  group_id = suggestion["suggested_group_id"].to_s

  if known_motifs[motif_id]
    review_needed << review_row(suggestion, "already mapped in main taxonomy")
    next
  end

  if action == "map_to_existing_group" && AUTO_ACCEPT_CONFIDENCE.include?(confidence) && known_groups[group_id]
    raw_index[motif_id] = {
      "group_id" => group_id,
      "relationship" => suggestion["relationship"].to_s,
      "confidence" => confidence,
      "review_status" => "model_auto_accepted_medium_or_high_confidence",
      "source" => relative_path(suggestions_path),
      "accepted_on" => TODAY,
      "notes" => [suggestion["rationale"].to_s, suggestion["cautions"].to_s].reject(&:empty?).join(" Caution: "),
      "suggested_aliases" => Array(suggestion["suggested_aliases"]).map(&:to_s)
    }
    accepted << review_row(suggestion, "auto-accepted medium-or-high-confidence existing-group placement")
  else
    reason =
      if action == "new_group_candidate"
        "new group candidate"
      elsif confidence == "low"
        "low confidence"
      elsif action == "exclude_from_pattern_queries"
        "suggested exclusion"
      elsif action == "needs_human_review"
        "model requested human review"
      elsif action == "map_to_existing_group" && !known_groups[group_id]
        "suggested group is not present in main taxonomy"
      else
        "not medium-or-high-confidence existing-group placement"
      end
    review_needed << review_row(suggestion, reason)
  end
end

normalization["updated_on"] = TODAY if accepted.any?
normalization["normalization_suggestion_acceptance"] = {
  "updated_on" => TODAY,
  "latest_run_id" => run_id,
  "policy" => "Auto-accept medium-or-high-confidence map_to_existing_group suggestions whose target group already exists. Stage all new-group, exclusion, low-confidence, and human-review suggestions separately.",
  "latest_suggestions_path" => relative_path(suggestions_path),
  "latest_review_data_path" => relative_path(review_data_path),
  "latest_report_path" => relative_path(report_path),
  "latest_suggestion_count" => suggestions.length,
  "latest_auto_accepted_count" => accepted.length,
  "latest_review_needed_count" => review_needed.length
}

review_data = {
  "normalization_suggestion_acceptance_version" => "1",
  "run_id" => run_id,
  "generated_on" => TODAY,
  "suggestions_path" => relative_path(suggestions_path),
  "normalization_path" => relative_path(normalization_path),
  "policy" => normalization["normalization_suggestion_acceptance"]["policy"],
  "counts" => {
    "suggestions" => suggestions.length,
    "auto_accepted" => accepted.length,
    "review_needed" => review_needed.length
  },
  "auto_accepted" => accepted,
  "review_needed" => review_needed
}

markdown = []
markdown << "# Motif Normalization Auto-Accept Review"
markdown << ""
markdown << "Generated on #{TODAY} from `#{relative_path(suggestions_path)}`."
markdown << ""
markdown << "Policy: auto-accept medium-or-high-confidence `map_to_existing_group` suggestions whose target group already exists. Everything else stays reviewable."
markdown << ""
markdown << "## Summary"
markdown << ""
markdown << "- Suggestions reviewed: #{suggestions.length}"
markdown << "- Auto-accepted into main taxonomy: #{accepted.length}"
markdown << "- Staged for review: #{review_needed.length}"
markdown << ""
markdown << "## Auto-Accepted"
markdown << ""
markdown << "| Motif ID | Label | Group | Relationship | Occurrences | Traditions |"
markdown << "| --- | --- | --- | --- | ---: | --- |"
accepted.first(300).each do |row|
  markdown << "| `#{row.fetch("motif_id")}` | #{row["label"]} | `#{row["suggested_group_id"]}` #{row["suggested_group_label"]} | #{row["relationship"]} | #{row["occurrences"]} | #{Array(row["traditions"]).join(", ")} |"
end
markdown << ""
markdown << "## Staged For Review"
markdown << ""
markdown << "| Motif ID | Label | Action | Suggested Group | Confidence | Reason |"
markdown << "| --- | --- | --- | --- | --- | --- |"
review_needed.first(500).each do |row|
  markdown << "| `#{row.fetch("motif_id")}` | #{row["label"]} | #{row["suggested_action"]} | `#{row["suggested_group_id"]}` #{row["suggested_group_label"]} | #{row["confidence"]} | #{row["reason"]} |"
end
markdown << ""
markdown << "_Showing first #{[review_needed.length, 500].min} of #{review_needed.length} review rows._"

unless options[:dry_run]
  FileUtils.mkdir_p(File.dirname(normalization_path))
  File.write(normalization_path, "#{YAML.dump(normalization)}\n")
  FileUtils.mkdir_p(File.dirname(review_data_path))
  File.write(review_data_path, "#{YAML.dump(review_data)}\n")
  FileUtils.mkdir_p(File.dirname(report_path))
  File.write(report_path, markdown.join("\n") + "\n")
end

puts "suggestions=#{suggestions.length}"
puts "auto_accepted=#{accepted.length}"
puts "review_needed=#{review_needed.length}"
puts "wrote #{relative_path(normalization_path)}" unless options[:dry_run]
puts "wrote #{relative_path(review_data_path)}" unless options[:dry_run]
puts "wrote #{relative_path(report_path)}" unless options[:dry_run]
