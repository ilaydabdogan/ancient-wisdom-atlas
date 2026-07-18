#!/usr/bin/env ruby
# frozen_string_literal: true

# Proposes within-family synonym merges from motif-label embeddings:
# pairs of child motifs in the SAME canonical family whose label vectors
# exceed a cosine threshold become merge candidates, ranked by similarity.
# Proposals go to the review queue — nothing merges automatically.

require_relative "batch_common"

options = {
  run_id: "label-embeddings-2026-07-18",
  threshold: 0.90,
  output: "data/reviews/synonym-merge-proposals.yml"
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/build_synonym_merge_proposals.rb [options]"
  parser.on("--run-id RUN_ID", "Label embedding run id") { |value| options[:run_id] = value }
  parser.on("--threshold F", Float, "Cosine threshold (default 0.90)") { |value| options[:threshold] = value }
  parser.on("--output PATH", "Output path") { |value| options[:output] = value }
end.parse!

run_dir = AtlasBatch.batch_dir(options[:run_id])
meta = AtlasBatch.read_jsonl(File.join(run_dir, "request-map.jsonl")).to_h { |r| [r["custom_id"], r] }

vectors = {}
Dir.glob(File.join(run_dir, "results", "*.output.jsonl")).sort.each do |path|
  AtlasBatch.read_jsonl(path).each do |line|
    embedding = line.dig("response", "body", "data", 0, "embedding")
    next unless embedding.is_a?(Array)

    info = meta[line["custom_id"].to_s]
    next unless info

    norm = Math.sqrt(embedding.sum { |x| x * x })
    vectors[info["motif_id"]] = { "family" => info["family"], "occ" => info["occurrences"].to_i,
                                  "v" => embedding.map { |x| x / norm } }
  end
end
AtlasBatch.die("no vectors loaded", 66) if vectors.empty?

by_family = vectors.group_by { |_, data| data["family"] }
proposals = []
by_family.each do |family, members|
  list = members.to_a
  list.combination(2).each do |(id_a, a), (id_b, b)|
    dot = 0.0
    va = a["v"]
    vb = b["v"]
    va.each_index { |i| dot += va[i] * vb[i] }
    next if dot < options[:threshold]

    keep, merge = a["occ"] >= b["occ"] ? [id_a, id_b] : [id_b, id_a]
    proposals << { "family" => family, "keep" => keep, "merge" => merge,
                   "similarity" => dot.round(4),
                   "keep_occurrences" => [a["occ"], b["occ"]].max,
                   "merge_occurrences" => [a["occ"], b["occ"]].min }
  end
end
proposals.sort_by! { |p| -p["similarity"] }

AtlasBatch.write_yaml(AtlasBatch.project_path(options[:output]), {
  "synonym_merge_proposals_version" => "1",
  "generated_at" => AtlasBatch.utc_now,
  "run_id" => options[:run_id],
  "threshold" => options[:threshold],
  "note" => "Merge candidates for review; the lower-occurrence motif merges into the higher. Nothing applies automatically.",
  "count" => proposals.length,
  "proposals" => proposals.first(2000)
})
puts "vectors: #{vectors.length}; families: #{by_family.length}; proposals >= #{options[:threshold]}: #{proposals.length}"
proposals.first(6).each { |p| puts "  #{p["similarity"]}: #{p["merge"]} -> #{p["keep"]} (#{p["family"]})" }
