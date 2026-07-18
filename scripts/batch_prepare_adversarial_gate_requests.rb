#!/usr/bin/env ruby
# frozen_string_literal: true

# The adversarial quality gate — smart version.
#
# Design (generator-verifier separation with grounding and calibration):
#   1. MECHANICAL FIRST: quote fidelity is verified in code by normalized
#      substring matching against the true source passage. The verifier
#      model receives the mechanical findings; it never re-litigates what
#      string matching already proves.
#   2. HONEYPOTS: ~2% of gate requests are secretly corrupted copies of
#      real drafts (a tampered quote, or a fabricated motif with no
#      textual basis). The verifier cannot distinguish them; its detection
#      rate on honeypots is the gate's measured sensitivity. A gate
#      without calibration is theater.
#   3. VERDICTS ARE ROUTED, NOT FINAL: pass/revise/reject verdicts feed
#      the review index; rejects are meant to be confirmed by a second
#      verifier (different deployment) before they count. Nothing is
#      auto-deleted.
#
# The verifier model must differ from the extractor (correlated-failure
# defense). usage:
#   ruby scripts/batch_prepare_adversarial_gate_requests.rb \
#     --run-id gate-newcorpus-sol --source-run new-corpus-2026-07-18

require_relative "batch_common"

options = {
  model: ENV.fetch("OPENAI_BATCH_MODEL", "gpt-5.6-sol"),
  endpoint: AtlasBatch::DEFAULT_ENDPOINT,
  max_output_tokens: 8_000,
  max_requests_per_shard: 1_000,
  honeypot_rate: 0.02,
  limit: nil,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_adversarial_gate_requests.rb --run-id RUN_ID --source-run RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Gate batch run id") { |value| options[:run_id] = value }
  parser.on("--source-run RUN_ID", "Extraction run whose results are gated") { |value| options[:source_run] = value }
  parser.on("--model MODEL", "Verifier model/deployment (must differ from the extractor)") { |value| options[:model] = value }
  parser.on("--honeypot-rate F", Float, "Fraction of corrupted calibration decoys (default 0.02)") { |value| options[:honeypot_rate] = value }
  parser.on("--limit N", Integer, "Limit gated records, for demos") { |value| options[:limit] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]
AtlasBatch.die("--source-run is required", 64) unless options[:source_run]

source_dir = AtlasBatch.batch_dir(options[:source_run])
passages_path = File.join(source_dir, "passages.jsonl")
unless File.file?(passages_path)
  source_index = AtlasBatch.load_yaml(File.join(source_dir, "requests", "index.yml"))
  passages_path = AtlasBatch.project_path(source_index["passages_path"].to_s)
end
AtlasBatch.die("passages file not found for #{options[:source_run]}", 66) unless File.file?(passages_path)
passages = AtlasBatch.read_jsonl(passages_path).to_h { |p| [p["passage_id"], p] }
request_map = AtlasBatch.read_jsonl(File.join(source_dir, "request-map.jsonl")).to_h { |r| [r["custom_id"], r] }

def response_text(body)
  parts = []
  Array(body["output"]).each do |item|
    next unless item.is_a?(Hash) && item["type"] == "message"

    Array(item["content"]).each { |c| parts << c["text"].to_s if c.is_a?(Hash) && c["text"] }
  end
  text = parts.join("\n").strip
  text.empty? ? body["output_text"].to_s.strip : text
end

def parse_payload(text)
  cleaned = text.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
  JSON.parse(cleaned)
rescue JSON::ParserError
  match = cleaned.match(/\{.*\}/m)
  return nil unless match

  begin
    JSON.parse(match[0])
  rescue JSON::ParserError
    nil
  end
end

def normalize_ws(text)
  text.to_s.gsub(/\s+/, " ").strip
end

# Collect every string under a key named "quote" anywhere in the payload.
def collect_quotes(node, out = [])
  case node
  when Hash
    node.each { |key, value| key == "quote" && value.is_a?(String) && !value.strip.empty? ? out << value : collect_quotes(value, out) }
  when Array
    node.each { |item| collect_quotes(item, out) }
  end
  out
end

def mechanical_quote_check(payload, passage_text)
  normalized_passage = normalize_ws(passage_text)
  quotes = collect_quotes(payload)
  failures = quotes.reject { |quote| normalized_passage.include?(normalize_ws(quote)) }
  { "quotes_total" => quotes.length, "quotes_failed" => failures.length,
    "failed_quotes" => failures.first(5).map { |quote| quote[0, 160] } }
end

# Deterministic corruptions for honeypots. The corruption type alternates.
def corrupt_payload(payload, kind)
  corrupted = JSON.parse(JSON.generate(payload))
  case kind
  when :quote_tamper
    quote = corrupted.dig("canonical_text", "quote").to_s
    words = quote.split(" ")
    if words.length >= 8
      words[3] = "silver"
      words[5] = "serpent"
      corrupted["canonical_text"]["quote"] = words.join(" ")
    else
      corrupted["canonical_text"]["quote"] = "And the silver serpent rose over the waters and spoke the hidden name. " + quote
    end
  when :fabricated_motif
    corrupted["candidate_motifs"] = Array(corrupted["candidate_motifs"]) + [{
      "id" => "motif:hp",
      "label" => "ritual dismemberment of the moon bull",
      "taxonomy_refs" => ["sacred_combat"],
      "basis" => "The passage describes the moon bull being ritually dismembered at the threshold.",
      "evidence_refs" => ["ev:1"],
      "confidence" => "high"
    }]
  end
  corrupted
end

def gate_prompt(passage, mapping, draft_text, mechanical)
  mech_summary = if mechanical["quotes_total"].zero?
    "No quotes present in the draft (that itself may be an issue)."
  elsif mechanical["quotes_failed"].zero?
    "All #{mechanical["quotes_total"]} quotes verified verbatim against the source passage by exact matching. Do NOT re-check quotes; focus on judgment calls."
  else
    "MECHANICAL CHECK FAILED: #{mechanical["quotes_failed"]} of #{mechanical["quotes_total"]} quotes do NOT appear in the source passage: #{mechanical["failed_quotes"].inspect}. Confirm severity and check whether they are paraphrases mislabeled as quotes."
  end

  <<~PROMPT
    You are the adversarial quality gate for the Ancient Wisdom Atlas.
    A different model drafted a motif-extraction record for the passage
    below. Your job is to try to REFUTE the draft. Be skeptical by
    default: when uncertain whether a claim is supported, flag it. Some
    records in this batch have been deliberately corrupted as calibration
    tests — treat every record as potentially compromised.

    MECHANICAL PRE-CHECK RESULT (ground truth, computed by code):
    #{mech_summary}

    Your judgment tasks, in order of importance:
    1. FABRICATION - does the draft assert events, figures, objects, or
       scenes that do not occur in the passage? (Outside knowledge of the
       work does not count as support.)
    2. PROJECTION - flag motif labels that read meaning INTO the passage
       rather than out of it (any water = "baptism", any tree =
       "axis mundi", any conflict = "sacred_combat" without warrant).
    3. CONFIDENCE INFLATION - flag high/medium confidence on thin
       evidence.
    4. OMISSIONS - briefly note clearly present motifs the draft missed.

    SOURCE PASSAGE (#{passage["source_title"]}, #{mapping.dig("locator", "label")}):
    ---
    #{passage["text"][0, 6000]}
    ---

    DRAFT RECORD:
    ---
    #{draft_text[0, 12_000]}
    ---

    Output ONLY a YAML object, no code fences:
    verdict: pass | revise | reject
    issues:
    - category: quote_fidelity | fabrication | projection | confidence_inflation | omission
      detail: one sentence, specific, citing the offending label or claim
    summary: one-sentence overall judgment
    Verdict rules: reject = fabrication or systematic quote failure;
    revise = real but fixable issues; pass = defensible as a draft.
  PROMPT
end

requests = []
gate_map = []
honeypot_counter = 0
record_counter = 0

Dir.glob(File.join(source_dir, "results", "*.output.jsonl")).sort.each do |path|
  AtlasBatch.read_jsonl(path).each do |line|
    break if options[:limit] && requests.length >= options[:limit]

    body = line.dig("response", "body") || {}
    next unless body["status"] == "completed"

    custom_id = line["custom_id"].to_s
    mapping = request_map[custom_id]
    next unless mapping

    passage = passages[mapping["passage_id"]]
    next unless passage

    draft_text = response_text(body)
    payload = parse_payload(draft_text)
    next if payload.nil?

    record_counter += 1
    mechanical = mechanical_quote_check(payload, passage["text"])
    requests << {
      "custom_id" => "gate:#{custom_id}",
      "method" => "POST",
      "url" => options[:endpoint],
      "body" => {
        "model" => options[:model],
        "input" => gate_prompt(passage, mapping, JSON.pretty_generate(payload), mechanical),
        "max_output_tokens" => options[:max_output_tokens],
        "reasoning" => { "effort" => mechanical["quotes_failed"].positive? ? "high" : "medium" }
      }
    }
    gate_map << {
      "custom_id" => "gate:#{custom_id}", "source_custom_id" => custom_id,
      "record_id" => mapping["record_id"], "source_text_path" => mapping["source_text_path"],
      "honeypot" => nil, "mechanical" => mechanical
    }

    # Honeypot injection: a corrupted twin of this record, unmarked in the
    # prompt, marked only in the gate map for calibration scoring.
    next unless (record_counter * options[:honeypot_rate]).floor > honeypot_counter

    honeypot_counter += 1
    kind = honeypot_counter.odd? ? :quote_tamper : :fabricated_motif
    corrupted = corrupt_payload(payload, kind)
    hp_mechanical = mechanical_quote_check(corrupted, passage["text"])
    requests << {
      "custom_id" => "gate:hp#{honeypot_counter}:#{custom_id}",
      "method" => "POST",
      "url" => options[:endpoint],
      "body" => {
        "model" => options[:model],
        "input" => gate_prompt(passage, mapping, JSON.pretty_generate(corrupted), hp_mechanical),
        "max_output_tokens" => options[:max_output_tokens],
        "reasoning" => { "effort" => "medium" }
      }
    }
    gate_map << {
      "custom_id" => "gate:hp#{honeypot_counter}:#{custom_id}", "source_custom_id" => custom_id,
      "record_id" => mapping["record_id"], "source_text_path" => mapping["source_text_path"],
      "honeypot" => kind.to_s, "mechanical" => hp_mechanical
    }
  end
end

AtlasBatch.die("no completed results to gate in #{options[:source_run]}", 66) if requests.empty?

run_id = options[:run_id]
requests_dir = File.join(AtlasBatch.batch_dir(run_id), "requests")
FileUtils.mkdir_p(requests_dir)
shard_entries = []
requests.each_slice(options[:max_requests_per_shard]).with_index do |slice, index|
  shard_id = "shard-%04d" % (index + 1)
  path = File.join(requests_dir, "#{shard_id}.jsonl")
  AtlasBatch.write_jsonl(path, slice, force: options[:force])
  shard_entries << {
    "shard_id" => shard_id,
    "path" => AtlasBatch.relative_path(path),
    "request_count" => slice.length,
    "bytes" => File.size(path),
    "sha256" => AtlasBatch.sha256_file(path),
    "endpoint" => options[:endpoint],
    "model" => options[:model],
    "status" => "prepared"
  }
end
AtlasBatch.write_jsonl(File.join(AtlasBatch.batch_dir(run_id), "request-map.jsonl"), gate_map, force: options[:force])

index_path = File.join(requests_dir, "index.yml")
AtlasBatch.write_yaml(index_path, {
  "batch_request_index_version" => "1",
  "run_id" => run_id,
  "source_run" => options[:source_run],
  "created_at" => AtlasBatch.utc_now,
  "updated_at" => AtlasBatch.utc_now,
  "endpoint" => options[:endpoint],
  "model" => options[:model],
  "honeypot_count" => honeypot_counter,
  "shards" => shard_entries
})

manifest = AtlasBatch.load_manifest(run_id)
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["status"] = "requests_prepared"
AtlasBatch.save_manifest(manifest)

puts "prepared #{requests.length} gate request(s) (#{honeypot_counter} honeypots) in #{shard_entries.length} shard(s)"
