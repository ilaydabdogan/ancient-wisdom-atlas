#!/usr/bin/env ruby
# frozen_string_literal: true

# Applies reviewer-accepted timeline datings to the cultural timeline.
# Joins the review run's verdicts with the drafting run's entries:
# accept -> original draft applied; revise -> reviewer's corrected_draft
# applied; reject -> skipped and listed. Every applied entry is marked
# with drafter/reviewer provenance. Idempotent by entry id.

require_relative "batch_common"

options = { timeline_index: "data/indexes/cultural-timeline.yml" }
OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/apply_reviewed_timeline_entries.rb --review-run RUN --draft-run RUN"
  parser.on("--review-run RUN_ID", "Review run id") { |value| options[:review_run] = value }
  parser.on("--draft-run RUN_ID", "Drafting run id") { |value| options[:draft_run] = value }
end.parse!
AtlasBatch.die("--review-run and --draft-run required", 64) unless options[:review_run] && options[:draft_run]

def response_text(body)
  parts = []
  Array(body["output"]).each do |item|
    next unless item.is_a?(Hash) && item["type"] == "message"

    Array(item["content"]).each { |c| parts << c["text"].to_s if c.is_a?(Hash) && c["text"] }
  end
  text = parts.join("\n").strip
  text.empty? ? body["output_text"].to_s.strip : text
end

def parse_yaml_block(text)
  YAML.safe_load(text.sub(/\A```(?:yaml)?\s*/i, "").sub(/\s*```\z/, ""), permitted_classes: [Date, Time], aliases: false)
rescue Psych::SyntaxError
  nil
end

drafts = {}
Dir.glob(File.join(AtlasBatch.batch_dir(options[:draft_run]), "results", "*.output.jsonl")).sort.each do |path|
  AtlasBatch.read_jsonl(path).each do |line|
    body = line.dig("response", "body") || {}
    next unless body["status"] == "completed"

    drafts[line["custom_id"].to_s] = parse_yaml_block(response_text(body))
  end
end

applied = []
rejected = []
timeline_path = AtlasBatch.project_path(options[:timeline_index])
timeline = AtlasBatch.load_yaml(timeline_path)
existing_ids = timeline.fetch("entries", []).map { |e| e["id"] }.to_set
existing_paths = timeline.fetch("entries", []).flat_map { |e| Array(e["current_text_paths"]) }.to_set

Dir.glob(File.join(AtlasBatch.batch_dir(options[:review_run]), "results", "*.output.jsonl")).sort.each do |path|
  AtlasBatch.read_jsonl(path).each do |line|
    body = line.dig("response", "body") || {}
    next unless body["status"] == "completed"

    review = parse_yaml_block(response_text(body))
    next unless review.is_a?(Hash)

    source_id = line["custom_id"].to_s.sub(/\Areview:/, "")
    entry = case review["verdict"].to_s
            when "accept" then drafts[source_id]
            when "revise" then parse_yaml_block(review["corrected_draft"].to_s) || drafts[source_id]
            else
              rejected << { "id" => source_id, "issues" => review["issues"] }
              nil
            end
    next unless entry.is_a?(Hash) && entry["id"] && entry["approximate_date_range"].is_a?(Hash)
    next if existing_ids.include?(entry["id"])
    next if Array(entry["current_text_paths"]).any? { |p| existing_paths.include?(p) }

    entry["provenance"] = "machine_dated: drafted by gpt-5.6-sol, reviewed by gpt-5.6-luna (#{options[:review_run]}); verify before scholarly citation"
    timeline["entries"] << entry
    existing_ids << entry["id"]
    Array(entry["current_text_paths"]).each { |p| existing_paths << p }
    applied << entry["id"]
  end
end

AtlasBatch.write_yaml(timeline_path, timeline)
puts "applied #{applied.length} timeline entries; rejected #{rejected.length}"
rejected.first(5).each { |r| puts "  rejected: #{r["id"]}" }
