#!/usr/bin/env ruby
# frozen_string_literal: true
# Trickster comparison experiment: ask several models the same trickster
# questions with NO Atlas access (ungrounded / training-only), plus one
# Atlas-GROUNDED answer per question. Objective, honest: identical prompts,
# same phrasing, answers stored verbatim for side-by-side comparison on the
# /trickster/ page. Writes data/reviews/trickster-model-comparison.yml.
require_relative "batch_common"
require "json"

A0 = { ep: ENV.fetch("ATLAS_AZURE_0_ENDPOINT"), key: ENV.fetch("ATLAS_AZURE_0_KEY") }
A1 = { ep: ENV.fetch("ATLAS_AZURE_1_ENDPOINT"), key: ENV.fetch("ATLAS_AZURE_1_KEY") }
# model -> which resource hosts its realtime deployment
MODELS = {
  "gpt-5.5" => A0, "gpt-5.6-terra" => A0, "gpt-5.6-luna" => A0,
  "gpt-5.4-std" => A1, "gpt-5.1-std" => A1
}
GROUNDER = "gpt-5.6-terra"

QUESTIONS = [
  { id: "function", q: "In comparative mythology, what is the trickster figure fundamentally trying to do? What is its function?" },
  { id: "companions", q: "Across the world's mythologies, which other mythic figures or recurring patterns does the trickster most often appear together with?" },
  { id: "universal", q: "Is the trickster essentially the SAME figure across all cultures, or fundamentally different in different places? And why does such a figure recur across unconnected peoples?" },
  { id: "dwelling", q: "Where does the trickster 'live' — what is its natural domain, setting, or place in the world of myth?" },
  { id: "knowledge", q: "What is the trickster's relationship to knowledge, fire, and theft?" },
  { id: "today", q: "If the trickster took a form in today's world, what would it be, where would it appear, and how would it speak?" }
]

EVIDENCE = <<~EV
  EVIDENCE from the Ancient Wisdom Atlas (a corpus of 68 traditions, every
  claim traced to quoted passages). Answer using ONLY what this evidence
  supports; cite the numbers; do not add outside lore beyond what the
  evidence shows:
  - The trickster family appears in 68 traditions across 3,278 tagged
    occurrences.
  - Its single dominant motif is "Trickster At The Boundary" (2,319
    occurrences across 65 traditions) — liminality/boundaries is
    empirically the core of the figure, not a footnote.
  - Its strongest conserved co-occurrence bonds (patterns it reliably
    travels with, across many unrelated traditions) are: sacred_knowledge
    (25 traditions), shapeshifter (21), death_and_transformation (16),
    sacred_exchange (14), sacred_love (13), miraculous_child (12),
    hero_journey (10), culture_hero (10).
  - CROWN FINDING: in a preregistered test where the isolated peoples'
    taxonomy and the connected Old World's taxonomy were each built blind
    and their webs compared, the trickster appeared in only 1 of the 24
    strongest cross-world matched bonds. So: the trickster is nearly
    UNIVERSAL IN PRESENCE (68 traditions) yet SINGULAR IN STRUCTURE — the
    least cross-culturally convergent of the major figures. It is
    everywhere, but it bonds differently everywhere; the boundary-crosser
    resists the net even mathematically.
EV

def ask(cfg, model, prompt)
  uri = URI.join("#{cfg[:ep].chomp('/')}/openai/v1/", "responses")
  http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true; http.read_timeout = 240
  req = Net::HTTP::Post.new(uri)
  req["api-key"] = cfg[:key]; req["Content-Type"] = "application/json"
  req.body = JSON.generate({ "model" => model, "input" => prompt, "max_output_tokens" => 3000 })
  res = http.request(req)
  return "[error #{res.code}]" unless res.code.to_i.between?(200, 299)
  b = JSON.parse(res.body)
  txt = Array(b["output"]).select { |o| o["type"] == "message" }
                          .flat_map { |o| Array(o["content"]).map { |c| c["text"].to_s } }.join("\n").strip
  txt.empty? ? "[empty]" : txt
rescue StandardError => e
  "[exception #{e.message[0, 80]}]"
end

UNGROUNDED_SUFFIX = "\n\nAnswer as an expert in comparative mythology, in about 120 words. Be specific and concrete; name figures and cultures where relevant."

out = { "trickster_model_comparison_version" => "1", "generated_at" => AtlasBatch.utc_now,
        "note" => "Same questions to each model with NO Atlas access (ungrounded, training-only), plus one Atlas-grounded answer. Verbatim, for honest side-by-side comparison.",
        "models_ungrounded" => MODELS.keys, "grounder" => GROUNDER, "questions" => [] }

QUESTIONS.each do |qq|
  warn "Q: #{qq[:id]}"
  entry = { "id" => qq[:id], "question" => qq[:q], "ungrounded" => {}, "atlas_grounded" => nil }
  threads = MODELS.map do |model, cfg|
    Thread.new { [model, ask(cfg, model, qq[:q] + UNGROUNDED_SUFFIX)] }
  end
  threads.each { |t| m, a = t.value; entry["ungrounded"][m] = a }
  entry["atlas_grounded"] = ask(A0, GROUNDER, "#{EVIDENCE}\n\nQUESTION: #{qq[:q]}\n\nAnswer in about 120 words, grounded strictly in the evidence above, citing the specific numbers/findings.")
  out["questions"] << entry
  warn "  done (#{entry["ungrounded"].keys.length} ungrounded + grounded)"
end

AtlasBatch.write_yaml(AtlasBatch.project_path("data/reviews/trickster-model-comparison.yml"), out)
puts "wrote data/reviews/trickster-model-comparison.yml (#{QUESTIONS.length} questions x #{MODELS.length} ungrounded models + grounded)"
