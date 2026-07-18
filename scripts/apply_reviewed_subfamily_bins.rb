#!/usr/bin/env ruby
# frozen_string_literal: true

# Applies reviewer-accepted sub-family binning proposals as
# data/normalization/sub-family-bins-<family>.yml files (same format as
# the hand-made bins). accept -> draft applied; revise -> reviewer's
# corrected_draft; reject -> skipped. Existing bin files are never
# overwritten. Validates that sub_families cover the drafted children
# exactly once; files failing validation are skipped and listed.

require_relative "batch_common"

options = { bins_dir: "data/normalization" }
OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/apply_reviewed_subfamily_bins.rb --review-run RUN --draft-run RUN"
  parser.on("--review-run RUN_ID") { |value| options[:review_run] = value }
  parser.on("--draft-run RUN_ID") { |value| options[:draft_run] = value }
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
skipped = []
Dir.glob(File.join(AtlasBatch.batch_dir(options[:review_run]), "results", "*.output.jsonl")).sort.each do |path|
  AtlasBatch.read_jsonl(path).each do |line|
    body = line.dig("response", "body") || {}
    next unless body["status"] == "completed"

    review = parse_yaml_block(response_text(body))
    next unless review.is_a?(Hash)

    source_id = line["custom_id"].to_s.sub(/\Areview:/, "")
    bin = case review["verdict"].to_s
          when "accept" then drafts[source_id]
          when "revise" then parse_yaml_block(review["corrected_draft"].to_s) || drafts[source_id]
          else
            skipped << { "id" => source_id, "reason" => "rejected" }
            nil
          end
    next unless bin.is_a?(Hash) && bin["family"] && bin["sub_families"].is_a?(Array)

    family = bin["family"].to_s
    target = AtlasBatch.project_path(File.join(options[:bins_dir], "sub-family-bins-#{family}.yml"))
    if File.file?(target)
      skipped << { "id" => source_id, "reason" => "bin file exists" }
      next
    end

    children = bin["sub_families"].flat_map { |sf| Array(sf["children"]) }
    if children.length != children.uniq.length || children.empty?
      skipped << { "id" => source_id, "reason" => "duplicate or empty child assignments" }
      next
    end

    bin["provenance"] = "machine_binned: drafted gpt-5.6-luna run #{options[:draft_run]}, reviewed gpt-5.6-terra run #{options[:review_run]}"
    bin["total_motifs"] = children.length
    bin["sub_families"].each { |sf| sf["child_count"] = Array(sf["children"]).length }
    AtlasBatch.write_yaml(target, bin)
    applied << family
  end
end

puts "applied #{applied.length} bin files; skipped #{skipped.length}"
skipped.group_by { |s| s["reason"] }.each { |reason, list| puts "  #{reason}: #{list.length}" }
