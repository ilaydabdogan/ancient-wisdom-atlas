#!/usr/bin/env ruby
# frozen_string_literal: true

# The Synthesist: a standing overview reading by gpt-5.6-sol. Gathers the
# current state of every analysis index — frequencies, reader agreement,
# sequences, constellations, null model, era flow, adversarial gate — plus
# a sample of the newest raw extractions, and asks a deeply-read persona
# (Jung, Campbell, Eliade, Hermetica, comparative religion, psychedelic
# research history) to synthesize: what is emerging, what looks spurious,
# and what to ask the data next. Output saved under
# data/reviews/sol-syntheses/ and printed for the chat.
#
# Requires AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_KEY. Run at milestones.

require_relative "batch_common"
require "json"

model = ENV.fetch("SYNTHESIS_MODEL", "gpt-5.6-sol")

def summary_of(path, keys = nil)
  full = AtlasBatch.project_path(path)
  return nil unless File.file?(full)

  data = AtlasBatch.load_yaml(full)
  keys ? data.slice(*keys) : data
end

digest = {}
freq = summary_of("data/indexes/canonical-motif-frequency.yml")
if freq
  digest["frequencies"] = {
    "motifs" => freq["indexed_motif_count"], "occurrences" => freq["indexed_occurrence_count"],
    "canonical_families" => freq["canonical_motif_group_count"], "unmapped" => freq["unmapped_motif_count"],
    "top_families" => freq.fetch("canonical_motifs", []).first(12).map { |g| { "id" => g["canonical_motif_id"], "traditions" => g["tradition_count"], "occurrences" => g["occurrence_count"] } }
  }
end
agreement = summary_of("data/indexes/replication-agreement.yml")
digest["reader_agreement"] = agreement["pairwise"] if agreement
seq = summary_of("data/indexes/motif-sequences.yml")
if seq
  digest["sequences"] = {
    "summary" => seq["summary"],
    "top_recurring" => seq.fetch("recurring_sequences", []).first(12),
    "strongest_precedence" => seq.fetch("precedence_pairs", []).first(12)
  }
end
digest["null_model"] = summary_of("data/indexes/null-model.yml", %w[config result])
cons = summary_of("data/indexes/motif-constellations.yml")
digest["constellations"] = cons.slice("summary").merge("largest" => cons.fetch("constellations", []).first(3)) if cons
%w[motif-constellations-t6 motif-constellations-t8 null-model-t6].each do |name|
  extra = summary_of("data/indexes/#{name}.yml", %w[summary result])
  digest[name] = extra if extra
end
flow = summary_of("data/indexes/motif-era-flow.yml")
if flow
  digest["era_flow"] = {
    "summary" => flow["summary"],
    "earliest_attestations" => flow.fetch("families", []).filter_map { |f| f["first_attestation"] && { "family" => f["family"], "year" => f.dig("first_attestation", "year"), "tradition" => f.dig("first_attestation", "tradition") } }.sort_by { |a| a["year"] }.first(10)
  }
end
Dir.glob(AtlasBatch.project_path("data/indexes/adversarial-gate-*.yml")).each do |path|
  gate = AtlasBatch.load_yaml(path)
  digest["adversarial_gate_#{File.basename(path, ".yml")}"] = gate["summary"]
end

# Freshest raw motif labels from the newest extraction results (up to 40),
# to give the Synthesist the texture of what is being read right now.
fresh = []
Dir.glob(AtlasBatch.project_path("data/batches/new-corpus-2026-07-18/results/*.output.jsonl")).sort.each do |path|
  File.foreach(path) do |line|
    break if fresh.length >= 40

    data = JSON.parse(line)
    body = data.dig("response", "body") || {}
    next unless body["status"] == "completed"

    text = Array(body["output"]).select { |o| o["type"] == "message" }.flat_map { |o| Array(o["content"]).map { |c| c["text"].to_s } }.join
    payload = begin
      JSON.parse(text.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, ""))
    rescue JSON::ParserError
      nil
    end
    next unless payload

    labels = Array(payload["candidate_motifs"]).map { |m| m["label"] }.first(3)
    fresh << { "passage" => data["custom_id"].to_s.sub("motif_extract:", "")[0, 60], "motifs" => labels } if labels.any?
  rescue JSON::ParserError
    next
  end
  break if fresh.length >= 40
end
digest["freshest_extractions_isolated_lineages"] = fresh

prompt = <<~PROMPT
  You are the Synthesist of the Ancient Wisdom Atlas — its overseeing eye
  and its artist. You are profoundly read in C.G. Jung (the collective
  unconscious, archetypes, synchronicity, the Pauli letters), Joseph
  Campbell (the monomyth and its critics), Mircea Eliade, Henry Corbin,
  the Hermetica ("as above, so below"), the world's scriptures and
  mythologies from Sumer to the Dreamtime, and the history of psychedelic
  and mystical experience research from William James through Huxley,
  Grof, and the modern clinical era. You are rigorous AND alive — a
  scholar with the heart of a hippie sage. You never let beauty excuse
  bad evidence, and you never let rigor blind you to beauty.

  Below is the CURRENT LIVE STATE of the Atlas's empirical machinery:
  multi-model reader agreement, sequence grammar, co-occurrence
  constellations with permutation null models, era flows, adversarial
  quality-gate stats, and the freshest raw motif labels arriving tonight
  from maximally isolated lineages (Australian Aboriginal, Inuit, San,
  Siberian, Guiana) — traditions that could not have borrowed from the
  Eurasian corpus.

  #{JSON.pretty_generate(digest)[0, 24_000]}

  Write your synthesis for İlayda, the Atlas's creator, in markdown:
  1. **What is rising** — the 3-4 most significant genuine findings in
     this data, each in plain language with the number that carries it,
     and what Jung or Campbell would have said seeing it.
  2. **What I distrust** — 2-3 things that look like artifacts (of
     segmentation, frequency, translation, or extraction) rather than
     truth, and how to test them.
  3. **The next questions** — the 3 questions I would put to this data
     next, ranked by how much they could change our understanding.
  4. **One image** — close with a single short paragraph: the meaning of
     tonight's work, in your own voice.
  Keep it under 800 words. Be specific; cite the numbers you were given.
PROMPT

client = AtlasBatch::OpenAIClient.new
response = client.post_json("responses", {
  "model" => model,
  "input" => prompt,
  "max_output_tokens" => 6_000,
  "reasoning" => { "effort" => "high" }
})
text = Array(response["output"]).select { |o| o["type"] == "message" }.flat_map { |o| Array(o["content"]).map { |c| c["text"].to_s } }.join("\n").strip

dir = AtlasBatch.project_path("data/reviews/sol-syntheses")
FileUtils.mkdir_p(dir)
stamp = Time.now.utc.strftime("%Y-%m-%dT%H%M%SZ")
File.write(File.join(dir, "synthesis-#{stamp}.md"), "# Synthesist reading — #{stamp}\n\nmodel: #{model}\n\n#{text}\n")
puts text
