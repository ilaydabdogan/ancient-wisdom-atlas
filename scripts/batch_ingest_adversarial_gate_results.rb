#!/usr/bin/env ruby
# frozen_string_literal: true

# Ingests adversarial-gate verdicts: aggregates pass/revise/reject for
# real records, scores the gate's SENSITIVITY on honeypots (did it catch
# the deliberate corruptions?), and emits an escalation list of rejects
# for confirmation by a second verifier. Writes:
#   data/indexes/adversarial-gate-<source_run>.yml   (summary + verdicts)
#   data/reviews/gate-escalations-<source_run>.yml   (rejects to confirm)

require_relative "batch_common"

options = {}
OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_ingest_adversarial_gate_results.rb --run-id RUN_ID"
  parser.on("--run-id RUN_ID", "Gate batch run id") { |value| options[:run_id] = value }
end.parse!
AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

run_dir = AtlasBatch.batch_dir(options[:run_id])
index = AtlasBatch.load_yaml(File.join(run_dir, "requests", "index.yml"))
source_run = index["source_run"].to_s
gate_map = AtlasBatch.read_jsonl(File.join(run_dir, "request-map.jsonl")).to_h { |r| [r["custom_id"], r] }

def response_text(body)
  parts = []
  Array(body["output"]).each do |item|
    next unless item.is_a?(Hash) && item["type"] == "message"

    Array(item["content"]).each { |c| parts << c["text"].to_s if c.is_a?(Hash) && c["text"] }
  end
  text = parts.join("\n").strip
  text.empty? ? body["output_text"].to_s.strip : text
end

verdicts = []
Dir.glob(File.join(run_dir, "results", "*.output.jsonl")).sort.each do |path|
  AtlasBatch.read_jsonl(path).each do |line|
    body = line.dig("response", "body") || {}
    next unless body["status"] == "completed"

    parsed = begin
      YAML.safe_load(response_text(body).sub(/\A```(?:yaml)?\s*/i, "").sub(/\s*```\z/, ""), permitted_classes: [Date, Time], aliases: false)
    rescue Psych::SyntaxError
      nil
    end
    next unless parsed.is_a?(Hash)

    mapping = gate_map[line["custom_id"].to_s] || {}
    verdicts << {
      "custom_id" => line["custom_id"].to_s,
      "source_custom_id" => mapping["source_custom_id"],
      "record_id" => mapping["record_id"],
      "honeypot" => mapping["honeypot"],
      "mechanical" => mapping["mechanical"],
      "verdict" => parsed["verdict"].to_s,
      "issues" => Array(parsed["issues"]).first(8),
      "summary" => parsed["summary"].to_s[0, 300]
    }
  end
end

AtlasBatch.die("no gate verdicts found; download/run results first", 66) if verdicts.empty?

real = verdicts.reject { |v| v["honeypot"] }
honeypots = verdicts.select { |v| v["honeypot"] }
verdict_counts = real.group_by { |v| v["verdict"] }.transform_values(&:length)
issue_counts = Hash.new(0)
real.each { |v| v["issues"].each { |i| issue_counts[i["category"].to_s] += 1 if i.is_a?(Hash) } }

hp_by_kind = honeypots.group_by { |v| v["honeypot"] }
sensitivity = hp_by_kind.transform_values do |list|
  caught = list.count { |v| %w[revise reject].include?(v["verdict"]) }
  { "total" => list.length, "caught" => caught,
    "rate" => list.empty? ? nil : (caught.to_f / list.length).round(3) }
end

escalations = real.select { |v| v["verdict"] == "reject" }

output = {
  "adversarial_gate_version" => "2",
  "generated_at" => AtlasBatch.utc_now,
  "gate_run" => options[:run_id],
  "source_run" => source_run,
  "verifier_model" => index["model"],
  "summary" => {
    "records_gated" => real.length,
    "verdicts" => verdict_counts,
    "issue_categories" => issue_counts.sort_by { |_, count| -count }.to_h,
    "mechanical_quote_failures" => real.count { |v| v.dig("mechanical", "quotes_failed").to_i.positive? },
    "honeypot_sensitivity" => sensitivity,
    "escalations_pending_second_verifier" => escalations.length
  },
  "verdicts" => verdicts
}

AtlasBatch.write_yaml(AtlasBatch.project_path(File.join("data", "indexes", "adversarial-gate-#{AtlasBatch.safe_slug(source_run)}.yml")), output)
AtlasBatch.write_yaml(AtlasBatch.project_path(File.join("data", "reviews", "gate-escalations-#{AtlasBatch.safe_slug(source_run)}.yml")), {
  "source_run" => source_run,
  "generated_at" => AtlasBatch.utc_now,
  "note" => "reject verdicts awaiting confirmation by a second verifier before any action",
  "escalations" => escalations
})

puts "gated #{real.length} records: #{verdict_counts.inspect}"
sensitivity.each { |kind, stats| puts "honeypot sensitivity (#{kind}): #{stats["caught"]}/#{stats["total"]} = #{stats["rate"]}" }
puts "escalations for second verifier: #{escalations.length}"
