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
  run_id: "normalization-suggestions-2026-04-28-unmapped",
  normalization_path: "taxonomy/motif-normalization.yml",
  output_path: "taxonomy/motif-normalization-expanded.yml",
  report_path: "docs/motif-normalization-expanded-review.md",
  suggestions_path: nil,
  include_low_confidence: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_motif_normalization_expansion_draft.rb [options]"
  parser.on("--run-id RUN_ID", "Normalization suggestion run id") { |value| options[:run_id] = value }
  parser.on("--suggestions PATH", "Suggestions JSONL path") { |value| options[:suggestions_path] = value }
  parser.on("--normalization PATH", "Base motif normalization YAML") { |value| options[:normalization_path] = value }
  parser.on("--output PATH", "Draft expanded normalization YAML") { |value| options[:output_path] = value }
  parser.on("--report PATH", "Human review Markdown report") { |value| options[:report_path] = value }
  parser.on("--include-low-confidence", "Include low-confidence map/new-group suggestions in the draft mapping") { options[:include_low_confidence] = true }
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
  end.compact
end

def safe_id(value, fallback: "motif_group")
  id = value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
  id.empty? ? fallback : id
end

def existing_group_ids(normalization)
  Array(normalization["canonical_motif_groups"]).map { |group| group["id"] if group.is_a?(Hash) }.compact.to_h { |id| [id, true] }
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

def suggested_group_id(suggestion)
  return suggestion["suggested_group_id"].to_s if suggestion["suggested_group_id"].to_s != ""

  new_group = suggestion["suggested_new_group"].is_a?(Hash) ? suggestion["suggested_new_group"] : {}
  safe_id(new_group["id"].to_s.empty? ? suggestion["suggested_group_label"] : new_group["id"])
end

def new_group_record(group_id, suggestion)
  new_group = suggestion["suggested_new_group"].is_a?(Hash) ? suggestion["suggested_new_group"] : {}
  {
    "id" => group_id,
    "label" => new_group["label"].to_s.empty? ? suggestion["suggested_group_label"].to_s : new_group["label"].to_s,
    "description" => new_group["description"].to_s,
    "children" => [],
    "aliases" => [],
    "related" => Array(new_group["related_group_ids"]).map(&:to_s).reject(&:empty?),
    "draft_status" => "new_group_candidate",
    "draft_parent_group_ids" => Array(new_group["parent_group_ids"]).map(&:to_s).reject(&:empty?),
    "draft_reason_existing_groups_insufficient" => new_group["reason_existing_groups_insufficient"].to_s
  }
end

def flag_record(suggestion, reason)
  {
    "motif_id" => suggestion.fetch("motif_id"),
    "label" => suggestion["label"].to_s,
    "occurrences" => suggestion["occurrences"].to_i,
    "traditions" => Array(suggestion["traditions"]),
    "suggested_action" => suggestion["suggested_action"].to_s,
    "suggested_group_id" => suggestion["suggested_group_id"].to_s,
    "suggested_group_label" => suggestion["suggested_group_label"].to_s,
    "relationship" => suggestion["relationship"].to_s,
    "confidence" => suggestion["confidence"].to_s,
    "reason" => reason,
    "rationale" => suggestion["rationale"].to_s,
    "cautions" => suggestion["cautions"].to_s
  }
end

run_id = options.fetch(:run_id)
suggestions_path = project_path(options[:suggestions_path] || File.join("data", "reviews", "normalization-suggestions", run_id, "suggestions.jsonl"))
normalization_path = project_path(options.fetch(:normalization_path))
output_path = project_path(options.fetch(:output_path))
report_path = project_path(options.fetch(:report_path))

unless File.file?(suggestions_path)
  warn "suggestions file not found: #{relative_path(suggestions_path)}"
  warn "Run scripts/batch_ingest_normalization_suggestion_results.rb first."
  exit 66
end

normalization = load_yaml(normalization_path)
suggestions = read_jsonl(suggestions_path)
known_groups = existing_group_ids(normalization)
known_motifs = current_mapped_ids(normalization)

draft = Marshal.load(Marshal.dump(normalization))
draft["status"] = "draft_expanded"
draft["updated_on"] = TODAY
draft["expansion_draft"] = {
  "generated_on" => TODAY,
  "source_suggestions_path" => relative_path(suggestions_path),
  "base_normalization_path" => relative_path(normalization_path),
  "purpose" => "Draft expansion generated from model normalization suggestions. Review before merging into taxonomy/motif-normalization.yml.",
  "include_low_confidence" => options[:include_low_confidence]
}
draft["canonical_motif_groups"] ||= []
draft["raw_motif_group_index"] ||= {}
draft["expansion_review_flags"] = []

draft_group_lookup = draft.fetch("canonical_motif_groups").each_with_object({}) do |group, memo|
  memo[group.fetch("id")] = group if group.is_a?(Hash) && group["id"]
end

accepted = []
new_groups = {}
already_known = []
excluded = []
needs_review = []

suggestions.sort_by { |suggestion| [suggestion["motif_id"].to_s] }.each do |suggestion|
  motif_id = suggestion.fetch("motif_id")
  confidence = suggestion["confidence"].to_s
  action = suggestion["suggested_action"].to_s

  if known_motifs[motif_id]
    already_known << flag_record(suggestion, "already present in base normalization")
    next
  end

  if confidence == "low" && !options[:include_low_confidence]
    needs_review << flag_record(suggestion, "low confidence")
    next
  end

  case action
  when "map_to_existing_group"
    group_id = suggestion["suggested_group_id"].to_s
    unless known_groups[group_id] || draft_group_lookup[group_id]
      needs_review << flag_record(suggestion, "suggested existing group is not present")
      next
    end

    draft.fetch("raw_motif_group_index")[motif_id] = {
      "group_id" => group_id,
      "relationship" => suggestion["relationship"].to_s,
      "confidence" => confidence,
      "review_status" => "model_suggested",
      "source" => relative_path(suggestions_path),
      "notes" => [suggestion["rationale"].to_s, suggestion["cautions"].to_s].reject(&:empty?).join(" Caution: ")
    }
    accepted << flag_record(suggestion, "mapped to existing group")
  when "new_group_candidate"
    group_id = suggested_group_id(suggestion)
    if group_id.empty?
      needs_review << flag_record(suggestion, "new group candidate missing group id")
      next
    end

    unless draft_group_lookup[group_id]
      record = new_group_record(group_id, suggestion)
      draft.fetch("canonical_motif_groups") << record
      draft_group_lookup[group_id] = record
      new_groups[group_id] = record
    end

    draft_group_lookup.fetch(group_id)["children"] = (Array(draft_group_lookup.fetch(group_id)["children"]) + [motif_id]).uniq.sort
    draft.fetch("raw_motif_group_index")[motif_id] = {
      "group_id" => group_id,
      "relationship" => suggestion["relationship"].to_s.empty? ? "child" : suggestion["relationship"].to_s,
      "confidence" => confidence,
      "review_status" => "new_group_candidate",
      "source" => relative_path(suggestions_path),
      "notes" => [suggestion["rationale"].to_s, suggestion["cautions"].to_s].reject(&:empty?).join(" Caution: ")
    }
    accepted << flag_record(suggestion, "mapped to new group candidate")
  when "exclude_from_pattern_queries"
    excluded << flag_record(suggestion, "model suggested exclusion from pattern queries")
  else
    needs_review << flag_record(suggestion, "model requested human review")
  end
end

draft["expansion_draft"]["suggestion_count"] = suggestions.length
draft["expansion_draft"]["accepted_mapping_count"] = accepted.length
draft["expansion_draft"]["new_group_candidate_count"] = new_groups.length
draft["expansion_draft"]["excluded_count"] = excluded.length
draft["expansion_draft"]["needs_review_count"] = needs_review.length
draft["expansion_draft"]["already_known_count"] = already_known.length
draft["expansion_review_flags"] = {
  "low_confidence_or_needs_human_review" => needs_review,
  "new_group_candidates" => new_groups.values,
  "excluded_from_pattern_queries" => excluded,
  "already_known_in_base_normalization" => already_known
}

FileUtils.mkdir_p(File.dirname(output_path))
File.write(output_path, "#{YAML.dump(draft)}\n")

markdown = []
markdown << "# Motif Normalization Expansion Draft"
markdown << ""
markdown << "Generated on #{TODAY} from `#{relative_path(suggestions_path)}`."
markdown << ""
markdown << "This is a review artifact. It does not modify `taxonomy/motif-normalization.yml`."
markdown << ""
markdown << "## Summary"
markdown << ""
markdown << "- Suggestions reviewed: #{suggestions.length}"
markdown << "- Accepted draft mappings: #{accepted.length}"
markdown << "- New canonical group candidates: #{new_groups.length}"
markdown << "- Low-confidence / needs human review: #{needs_review.length}"
markdown << "- Suggested exclusions: #{excluded.length}"
markdown << "- Already known in base normalization: #{already_known.length}"
markdown << ""
markdown << "## New Group Candidates"
markdown << ""
if new_groups.empty?
  markdown << "No new group candidates were accepted into the draft."
else
  markdown << "| Group ID | Label | Children Added | Review Note |"
  markdown << "| --- | --- | ---: | --- |"
  new_groups.values.sort_by { |group| group.fetch("id") }.each do |group|
    markdown << "| `#{group.fetch("id")}` | #{group["label"]} | #{Array(group["children"]).length} | #{group["draft_reason_existing_groups_insufficient"]} |"
  end
end

markdown << ""
markdown << "## Low Confidence Or Human Review"
markdown << ""
markdown << "| Motif ID | Label | Suggested Action | Suggested Group | Confidence | Reason |"
markdown << "| --- | --- | --- | --- | --- | --- |"
needs_review.first(500).each do |record|
  markdown << "| `#{record.fetch("motif_id")}` | #{record["label"]} | #{record["suggested_action"]} | `#{record["suggested_group_id"]}` #{record["suggested_group_label"]} | #{record["confidence"]} | #{record["reason"]} |"
end
markdown << ""
markdown << "_Showing first #{[needs_review.length, 500].min} of #{needs_review.length} review rows._"

markdown << ""
markdown << "## Suggested Exclusions"
markdown << ""
markdown << "| Motif ID | Label | Confidence | Rationale |"
markdown << "| --- | --- | --- | --- |"
excluded.first(300).each do |record|
  markdown << "| `#{record.fetch("motif_id")}` | #{record["label"]} | #{record["confidence"]} | #{record["rationale"]} |"
end
markdown << ""
markdown << "_Showing first #{[excluded.length, 300].min} of #{excluded.length} exclusion rows._"

FileUtils.mkdir_p(File.dirname(report_path))
File.write(report_path, markdown.join("\n") + "\n")

puts "wrote #{relative_path(output_path)}"
puts "wrote #{relative_path(report_path)}"
puts "accepted=#{accepted.length} new_groups=#{new_groups.length} needs_review=#{needs_review.length} excluded=#{excluded.length}"
