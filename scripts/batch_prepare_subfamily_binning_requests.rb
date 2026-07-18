#!/usr/bin/env ruby
# frozen_string_literal: true

# Prepares sub-family binning proposals for canonical families that do not
# yet have a data/normalization/sub-family-bins-<family>.yml. The model
# receives the family's full child-motif roster (ids, labels, occurrence
# counts, tradition spreads) plus one existing hand-made bin file as a
# format exemplar, and proposes 6-12 sub-families covering every child.
# Proposals are DRAFTS for human review — bin files are only written after
# acceptance (same discipline as the 9 hand-shepherded families).

require_relative "batch_common"

options = {
  frequency_index: "data/indexes/canonical-motif-frequency.yml",
  bins_dir: "data/normalization",
  model: ENV.fetch("OPENAI_BATCH_MODEL", "gpt-5.6-sol"),
  endpoint: AtlasBatch::DEFAULT_ENDPOINT,
  max_output_tokens: 16_000,
  min_children: 20,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_subfamily_binning_requests.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Batch run id") { |value| options[:run_id] = value }
  parser.on("--model MODEL", "Model / deployment id") { |value| options[:model] = value }
  parser.on("--min-children N", Integer, "Skip families with fewer children (default 20)") { |value| options[:min_children] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]

frequency = AtlasBatch.load_yaml(AtlasBatch.project_path(options[:frequency_index]))
binned = Dir.glob(AtlasBatch.project_path(File.join(options[:bins_dir], "sub-family-bins-*.yml")))
            .map { |path| File.basename(path, ".yml").sub("sub-family-bins-", "") }
            .to_set

exemplar_path = Dir.glob(AtlasBatch.project_path(File.join(options[:bins_dir], "sub-family-bins-*.yml"))).min
exemplar = exemplar_path ? File.read(exemplar_path)[0, 3000] : ""

requests = []
request_map = []
frequency.fetch("canonical_motifs", []).each do |group|
  family = group["canonical_motif_id"]
  next if binned.include?(family)

  children = group.fetch("mapped_motifs", [])
  next if children.length < options[:min_children]

  roster = children.sort_by { |child| -child["occurrence_count"].to_i }.map do |child|
    top_traditions = child.fetch("traditions", {}).sort_by { |_, count| -count }.first(4).map(&:first).join(",")
    "- #{child["motif_id"]} | #{child["label"]} | #{child["occurrence_count"]} occ | #{top_traditions}"
  end.join("\n")

  prompt = <<~PROMPT
    You are organizing the canonical motif family "#{family}"
    (#{group["label"]}: #{group["description"]}) for the Ancient Wisdom
    Atlas taxonomy. It has #{children.length} child motifs. Propose
    sub-families that carve this family at its natural joints.

    Rules (taxonomy follows evidence, not theory):
    - 6 to 12 sub-families; every child motif assigned to exactly one.
    - Sub-families must emerge from what the child labels actually
      describe — concrete recurring images and situations — not from
      a-priori theoretical schemes.
    - Sub-family ids: #{family}_<short_snake_case>.
    - Balance matters: avoid one giant catch-all; a small "unsorted"
      residual sub-family is acceptable if honest.

    CHILD ROSTER (id | label | occurrences | top traditions):
    #{roster[0, 16_000]}

    FORMAT EXEMPLAR (a hand-made bin file for another family):
    ---
    #{exemplar}
    ---

    Output ONLY YAML matching the exemplar's schema exactly:
    family: #{family}
    total_motifs: #{children.length}
    sub_families:
    - id: ...
      label: ...
      child_count: ...
      children: [ ...motif ids... ]
    No code fences.
  PROMPT

  requests << {
    "custom_id" => "subfamily:#{family}",
    "method" => "POST",
    "url" => options[:endpoint],
    "body" => {
      "model" => options[:model],
      "input" => prompt,
      "max_output_tokens" => options[:max_output_tokens],
      "reasoning" => { "effort" => "high" }
    }
  }
  request_map << { "custom_id" => "subfamily:#{family}", "family" => family, "child_count" => children.length }
end

AtlasBatch.die("no unbinned families above threshold", 66) if requests.empty?

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

puts "prepared #{requests.length} sub-family binning request(s)"
