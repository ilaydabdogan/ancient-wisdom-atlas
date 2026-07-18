#!/usr/bin/env ruby
# frozen_string_literal: true

# Prepares comparison-draft requests for the strongest conserved
# co-occurrence edges (from build_motif_constellations.rb). For each edge,
# the model receives both canonical families' evidence profiles and drafts
# a structured comparison record: shared function, tradition spread,
# similarity type per docs/methodology.md's claim ladder, and explicit
# disconfirming considerations. Drafts land in the run's results and feed
# the human review queue — they are never auto-published.

require_relative "batch_common"

options = {
  constellation_index: "data/indexes/motif-constellations.yml",
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  model: ENV.fetch("OPENAI_BATCH_MODEL", "gpt-5.6-sol"),
  endpoint: AtlasBatch::DEFAULT_ENDPOINT,
  max_output_tokens: 16_000,
  limit: 100,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_edge_comparison_requests.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--model MODEL", "Model / deployment id") { |value| options[:model] = value }
  parser.on("--limit N", Integer, "Top-N conserved edges (default 100)") { |value| options[:limit] = value }
  parser.on("--max-output-tokens N", Integer, "Responses max_output_tokens") { |value| options[:max_output_tokens] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

constellations = AtlasBatch.load_yaml(AtlasBatch.project_path(options[:constellation_index]))
frequency = AtlasBatch.load_yaml(AtlasBatch.project_path(options[:frequency_index]))
AtlasBatch.die("constellation index missing; run build_motif_constellations.rb", 66) if constellations.empty?

families = frequency.fetch("canonical_motifs", []).to_h { |group| [group["canonical_motif_id"], group] }

def family_profile(group)
  return "unknown family" unless group

  mapped = group.fetch("mapped_motifs", []).sort_by { |motif| -motif["occurrence_count"].to_i }
  traditions = group.fetch("traditions", {}).sort_by { |_, count| -count }
  <<~PROFILE
    id: #{group["canonical_motif_id"]}
    label: #{group["label"]}
    description: #{group["description"]}
    occurrences: #{group["occurrence_count"]} across #{group["tradition_count"]} traditions
    tradition distribution: #{traditions.first(15).map { |name, count| "#{name}(#{count})" }.join(", ")}
    strongest child motifs: #{mapped.first(12).map { |motif| "#{motif["motif_id"]} (#{motif["occurrence_count"]})" }.join(", ")}
  PROFILE
end

edges = constellations.fetch("conserved_edges", []).first(options[:limit])
AtlasBatch.die("no conserved edges available", 66) if edges.empty?

requests = []
request_map = []
edges.each do |edge|
  a, b = edge["pair"]
  custom_id = "edge_comparison:#{a}__#{b}"
  prompt = <<~PROMPT
    You are drafting a scholarly comparison record for the Ancient Wisdom
    Atlas, a source-grounded comparative-mythology project. Two canonical
    motif families co-occur within passages significantly more often than
    chance in #{edge["tradition_count"]} independent traditions
    (#{edge["traditions"].join(", ")}), with #{edge["total_cooccurrences"]}
    total co-occurrences. The within-tradition permutation null model
    confirms this family-pair structure exceeds base-rate expectation.

    FAMILY A:
    #{family_profile(families[a])}
    FAMILY B:
    #{family_profile(families[b])}

    Draft a comparison record as YAML with exactly these keys:
    title: short scholarly title for the pairing
    families: [#{a}, #{b}]
    shared_function_hypothesis: 2-4 sentences on WHY these families may
      travel together (narrative function, ritual logic, psychological
      structure). Ground claims in the tradition distribution shown; do
      not invent passages.
    claim_level: one of same_motif | same_function | historical_contact |
      common_inheritance | independent_recurrence (choose the strongest
      DEFENSIBLE level given the tradition spread; justify in one sentence)
    strongest_traditions: the 3-5 traditions where this pairing is best
      attested, from the data above
    disconfirming_considerations: 2-3 honest alternative explanations
      (translation artifact, extraction correlation, genre convention,
      segmentation effects) and what evidence would distinguish them
    suggested_passage_checks: 3-5 concrete text+family combinations a
      human reviewer should spot-check (title-level; you do not have
      passage IDs)
    confidence: low | medium (never high; this is a machine draft)
    reviewer_status: needs_review

    Output ONLY the YAML record, no code fences.
  PROMPT
  requests << {
    "custom_id" => custom_id,
    "method" => "POST",
    "url" => options[:endpoint],
    "body" => {
      "model" => options[:model],
      "input" => prompt,
      "max_output_tokens" => options[:max_output_tokens],
      "reasoning" => { "effort" => "high" }
    }
  }
  request_map << {
    "custom_id" => custom_id,
    "families" => [a, b],
    "tradition_count" => edge["tradition_count"]
  }
end

run_id = options[:run_id]
requests_dir = File.join(AtlasBatch.batch_dir(run_id), "requests")
FileUtils.mkdir_p(requests_dir)
shard_path = File.join(requests_dir, "shard-0001.jsonl")
AtlasBatch.write_jsonl(shard_path, requests, force: options[:force])
AtlasBatch.write_jsonl(File.join(AtlasBatch.batch_dir(run_id), "request-map.jsonl"), request_map, force: options[:force])

index_path = File.join(requests_dir, "index.yml")
AtlasBatch.write_yaml(index_path, {
  "batch_request_index_version" => "1",
  "run_id" => run_id,
  "created_at" => AtlasBatch.utc_now,
  "updated_at" => AtlasBatch.utc_now,
  "endpoint" => options[:endpoint],
  "model" => options[:model],
  "shards" => [{
    "shard_id" => "shard-0001",
    "path" => AtlasBatch.relative_path(shard_path),
    "request_count" => requests.length,
    "bytes" => File.size(shard_path),
    "sha256" => AtlasBatch.sha256_file(shard_path),
    "endpoint" => options[:endpoint],
    "model" => options[:model],
    "status" => "prepared"
  }]
})

manifest = AtlasBatch.load_manifest(run_id)
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["status"] = "requests_prepared"
AtlasBatch.save_manifest(manifest)

puts "prepared #{requests.length} edge-comparison request(s)"
puts "wrote #{AtlasBatch.relative_path(index_path)}"
