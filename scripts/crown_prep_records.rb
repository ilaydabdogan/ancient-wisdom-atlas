#!/usr/bin/env ruby
# frozen_string_literal: true
# Emits per-passage raw-label sets, tagged isolated/connected, for the crown
# experiment. Blind: uses free-text labels only, never taxonomy_refs/families.
require_relative "batch_common"
require "json"
ISOLATED = %w[australian-aboriginal indigenous-australian inuit
  khoisan-south-african san zulu siberian guiana-amerindian amazonian
  andamanese maya mesoamerican nahua nahua-maya-inca navajo zuni hopi
  hawaiian tsimshian native-american-great-lakes native-american-northwest-coast
  native-american-plains native-american-southeast native-american-southwest
  native-american-northeast-woodlands].to_set
out = File.open(File.join(AtlasBatch::ROOT, "data/batches/crown-label-embed-2026-07-18/crown-records.jsonl"), "w")
n = 0
Dir.glob(File.join(AtlasBatch::ROOT, "extractions/**/*.{yml,yaml}")).each do |path|
  rec = AtlasBatch.load_yaml(path); next unless rec.is_a?(Hash)
  src = rec["source_text_path"].to_s; next if src.empty?
  trad = src.split("/")[2].to_s; next if trad == "comparative"
  labels = Array(rec["candidate_motifs"]).map { |m| m["label"].to_s.strip.downcase }.reject { |l| l.length < 4 }.uniq
  next if labels.length < 2
  out.puts JSON.generate({"pile" => (ISOLATED.include?(trad) ? "iso" : "con"), "trad" => trad, "labels" => labels})
  n += 1
end
out.close
puts "wrote #{n} crown records"
