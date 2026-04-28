#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

DEFAULT_MODEL = ENV.fetch("OPENAI_BATCH_MODEL", "gpt-5.4-mini")

options = {
  model: DEFAULT_MODEL,
  endpoint: AtlasBatch::DEFAULT_ENDPOINT,
  prompt_path: "templates/batch-motif-extraction-prompt.md",
  max_output_tokens: 4_000,
  max_requests_per_shard: 1_000,
  max_bytes_per_shard: 180 * 1024 * 1024,
  include_ingested: false,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_prepare_motif_requests.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Existing batch run id") { |value| options[:run_id] = value }
  parser.on("--passages PATH", "Passages JSONL path") { |value| options[:passages_path] = value }
  parser.on("--model MODEL", "OpenAI model id") { |value| options[:model] = value }
  parser.on("--endpoint ENDPOINT", "Batch endpoint; default /v1/responses") { |value| options[:endpoint] = value }
  parser.on("--prompt PATH", "Prompt template path") { |value| options[:prompt_path] = value }
  parser.on("--max-output-tokens N", Integer, "Responses max_output_tokens") { |value| options[:max_output_tokens] = value }
  parser.on("--temperature N", Float, "Optional model temperature") { |value| options[:temperature] = value }
  parser.on("--reasoning-effort EFFORT", "Optional Responses reasoning effort") { |value| options[:reasoning_effort] = value }
  parser.on("--max-requests-per-shard N", Integer, "Shard request count limit") { |value| options[:max_requests_per_shard] = value }
  parser.on("--max-bytes-per-shard N", Integer, "Shard byte limit") { |value| options[:max_bytes_per_shard] = value }
  parser.on("--include-ingested", "Do not skip custom_ids already ingested for this run") { options[:include_ingested] = true }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]
AtlasBatch.die("--max-requests-per-shard must be positive", 64) unless options[:max_requests_per_shard].positive?
AtlasBatch.die("--max-bytes-per-shard must be at least 1000000", 64) if options[:max_bytes_per_shard] < 1_000_000

def simple_string_field(description)
  { "type" => "string", "description" => description }
end

def string_array_field(description)
  {
    "type" => "array",
    "description" => description,
    "items" => { "type" => "string" }
  }
end

def extraction_response_schema
  evidence_ref_array = string_array_field("Evidence IDs used by this field.")

  {
    "type" => "object",
    "additionalProperties" => false,
    "properties" => {
      "record_id" => simple_string_field("Stable extraction record id supplied in the request."),
      "source_text_path" => simple_string_field("Repository-relative canonical source text path."),
      "passage_locator" => {
        "type" => "object",
        "additionalProperties" => false,
        "properties" => {
          "label" => simple_string_field("Human-readable passage label."),
          "start" => simple_string_field("Start locator or line number."),
          "end" => simple_string_field("End locator or line number."),
          "translation" => simple_string_field("Translation or edition used."),
          "notes" => simple_string_field("Locator notes.")
        },
        "required" => %w[label start end translation notes]
      },
      "canonical_text" => {
        "type" => "object",
        "additionalProperties" => false,
        "properties" => {
          "quote" => simple_string_field("Short exact excerpt only when useful and allowed; otherwise empty."),
          "summary" => simple_string_field("Neutral literal passage summary."),
          "language" => simple_string_field("Language of the passage text."),
          "quote_policy" => {
            "type" => "string",
            "enum" => %w[quoted summarized citation_only not_applicable]
          }
        },
        "required" => %w[quote summary language quote_policy]
      },
      "literal_observations" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "id" => simple_string_field("Observation id such as obs:1."),
            "text" => simple_string_field("Literal observation only."),
            "category" => {
              "type" => "string",
              "enum" => %w[action object setting speech attribute relationship sequence other]
            },
            "evidence_refs" => evidence_ref_array
          },
          "required" => %w[id text category evidence_refs]
        }
      },
      "figures" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "id" => simple_string_field("Figure id such as fig:1."),
            "name_or_label" => simple_string_field("Name or descriptive label."),
            "description" => simple_string_field("Literal description from the passage."),
            "role_refs" => string_array_field("Role ids assigned to this figure."),
            "evidence_refs" => evidence_ref_array
          },
          "required" => %w[id name_or_label description role_refs evidence_refs]
        }
      },
      "roles" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "id" => simple_string_field("Role id such as role:1."),
            "label" => simple_string_field("Evidence-based role label."),
            "assigned_to" => string_array_field("Figure ids assigned this role."),
            "basis" => simple_string_field("Brief basis from passage evidence."),
            "evidence_refs" => evidence_ref_array
          },
          "required" => %w[id label assigned_to basis evidence_refs]
        }
      },
      "symbols" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "id" => simple_string_field("Symbol id such as sym:1."),
            "label" => simple_string_field("Symbol label."),
            "literal_form" => simple_string_field("Literal object, place, being, number, gesture, or image."),
            "associated_figures" => string_array_field("Figure ids associated with this symbol."),
            "taxonomy_refs" => string_array_field("Known taxonomy symbol or motif refs, only if supported."),
            "evidence_refs" => evidence_ref_array
          },
          "required" => %w[id label literal_form associated_figures taxonomy_refs evidence_refs]
        }
      },
      "scenes" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "id" => simple_string_field("Scene id such as scene:1."),
            "label" => simple_string_field("Scene label."),
            "summary" => simple_string_field("Neutral account of what happens."),
            "figure_refs" => string_array_field("Figure ids in this scene."),
            "symbol_refs" => string_array_field("Symbol ids in this scene."),
            "evidence_refs" => evidence_ref_array
          },
          "required" => %w[id label summary figure_refs symbol_refs evidence_refs]
        }
      },
      "candidate_motifs" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "id" => simple_string_field("Motif id such as motif:1."),
            "label" => simple_string_field("Plain motif label."),
            "taxonomy_refs" => string_array_field("Known taxonomy motif refs, only if supported."),
            "basis" => simple_string_field("Evidence-based basis."),
            "evidence_refs" => evidence_ref_array,
            "confidence" => { "type" => "string", "enum" => %w[low medium high uncertain] },
            "cautions" => simple_string_field("Limits or reasons for uncertainty.")
          },
          "required" => %w[id label taxonomy_refs basis evidence_refs confidence cautions]
        }
      },
      "comparison_claims" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "id" => simple_string_field("Claim id such as claim:1."),
            "claim" => simple_string_field("Cautious comparison claim."),
            "claim_level" => {
              "type" => "string",
              "enum" => %w[same_motif same_function historical_contact common_inheritance independent_recurrence archetypal_reading visual_similarity linguistic_similarity]
            },
            "target" => simple_string_field("Compared motif, text, pattern, or tradition."),
            "evidence_refs" => evidence_ref_array,
            "counter_evidence_refs" => evidence_ref_array,
            "confidence" => { "type" => "string", "enum" => %w[low medium high uncertain] },
            "limitations" => simple_string_field("Limits of the comparison.")
          },
          "required" => %w[id claim claim_level target evidence_refs counter_evidence_refs confidence limitations]
        }
      },
      "evidence" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => {
            "id" => simple_string_field("Evidence id such as ev:1."),
            "type" => { "type" => "string", "enum" => %w[quote summary citation note] },
            "locator" => simple_string_field("Passage locator or line range."),
            "quote_or_summary" => simple_string_field("Short quote or neutral summary."),
            "source_text_path" => simple_string_field("Repository-relative source path."),
            "rights_note" => simple_string_field("Rights note for this evidence.")
          },
          "required" => %w[id type locator quote_or_summary source_text_path rights_note]
        }
      },
      "confidence" => {
        "type" => "object",
        "additionalProperties" => false,
        "properties" => {
          "extraction" => { "type" => "string", "enum" => %w[low medium high uncertain] },
          "motif_candidates" => { "type" => "string", "enum" => %w[low medium high uncertain] },
          "comparison_claims" => { "type" => "string", "enum" => %w[low medium high uncertain] },
          "notes" => simple_string_field("Confidence notes.")
        },
        "required" => %w[extraction motif_candidates comparison_claims notes]
      },
      "reviewer_status" => {
        "type" => "object",
        "additionalProperties" => false,
        "properties" => {
          "status" => { "type" => "string", "enum" => %w[draft needs_review reviewed revision_requested rejected] },
          "reviewer" => simple_string_field("Reviewer id, empty before human review."),
          "reviewed_at" => simple_string_field("Review date, empty before human review."),
          "notes" => simple_string_field("Review notes.")
        },
        "required" => %w[status reviewer reviewed_at notes]
      },
      "extracted_by" => simple_string_field("Extractor name."),
      "extracted_at" => simple_string_field("Extraction date."),
      "notes" => simple_string_field("General notes.")
    },
    "required" => %w[
      record_id source_text_path passage_locator canonical_text literal_observations
      figures roles symbols scenes candidate_motifs comparison_claims evidence confidence
      reviewer_status extracted_by extracted_at notes
    ]
  }
end

def load_taxonomy_context
  motifs = AtlasBatch.load_yaml(File.join(AtlasBatch::ROOT, "taxonomy", "motifs.yml"), {})
  symbols = AtlasBatch.load_yaml(File.join(AtlasBatch::ROOT, "taxonomy", "symbols.yml"), {})

  {
    "motif_families" => (motifs["motif_families"] || {}).keys.sort,
    "symbols" => (symbols["symbols"] || {}).keys.sort
  }
end

def record_id_for(passage)
  "batch.motif.#{AtlasBatch.safe_slug(passage.fetch("passage_id"), fallback: "passage")}"
end

def custom_id_for(passage)
  "motif_extract:#{passage.fetch("passage_id")}"
end

def request_body(passage, prompt, taxonomy_context, options)
  record_id = record_id_for(passage)
  locator = passage.fetch("locator")
  source_rights = passage["rights"] || {}
  user_payload = {
    "task" => "passage_level_motif_symbol_pattern_extraction",
    "record_id" => record_id,
    "source_text_path" => passage.fetch("source_text_path"),
    "passage_locator" => {
      "label" => locator.fetch("label"),
      "start" => locator.fetch("start_line").to_s,
      "end" => locator.fetch("end_line").to_s,
      "translation" => passage["source_title"].to_s,
      "notes" => "Stable markdown line range generated from canonical text."
    },
    "source_metadata" => {
      "source_text_id" => passage["source_text_id"],
      "source_title" => passage["source_title"],
      "tradition" => passage["tradition"],
      "culture" => passage["culture"],
      "text_language" => passage["text_language"],
      "rights_status" => source_rights["status"],
      "training_use" => source_rights["training_use"],
      "full_text" => source_rights["full_text"]
    },
    "available_taxonomy_refs" => taxonomy_context,
    "passage_text" => passage.fetch("text")
  }

  body = {
    "model" => options.fetch(:model),
    "input" => [
      { "role" => "system", "content" => prompt },
      { "role" => "user", "content" => JSON.pretty_generate(user_payload) }
    ],
    "text" => {
      "format" => {
        "type" => "json_schema",
        "name" => "atlas_motif_extraction",
        "strict" => true,
        "schema" => extraction_response_schema
      }
    },
    "max_output_tokens" => options.fetch(:max_output_tokens)
  }
  body["temperature"] = options[:temperature] if options.key?(:temperature)
  body["reasoning"] = { "effort" => options[:reasoning_effort] } if options[:reasoning_effort].to_s.strip != ""
  body
end

def ingested_custom_ids(run_id)
  path = File.join(AtlasBatch.batch_dir(run_id), "ingested-results.jsonl")
  return [] unless File.file?(path)

  AtlasBatch.read_jsonl(path).map { |record| record["custom_id"] if record["status"] == "ingested" }.compact.uniq
end

def shard_requests(requests, max_requests:, max_bytes:)
  shards = []
  current = []
  current_bytes = 0

  requests.each do |request|
    line = JSON.generate(request)
    line_bytes = line.bytesize + 1
    if current.any? && (current.length >= max_requests || current_bytes + line_bytes > max_bytes)
      shards << current
      current = []
      current_bytes = 0
    end

    AtlasBatch.die("single request exceeds shard byte limit: #{request.fetch("custom_id")}", 65) if line_bytes > max_bytes

    current << request
    current_bytes += line_bytes
  end

  shards << current if current.any?
  shards
end

run_id = options.fetch(:run_id)
manifest = AtlasBatch.load_manifest(run_id)
passages_path = AtlasBatch.project_path(options[:passages_path] || manifest.dig("artifacts", "passages_path") || File.join("data/batches", run_id, "passages.jsonl"))
AtlasBatch.die("Passages file not found: #{AtlasBatch.relative_path(passages_path)}", 66) unless File.file?(passages_path)

prompt_path = AtlasBatch.project_path(options[:prompt_path])
AtlasBatch.die("Prompt template not found: #{AtlasBatch.relative_path(prompt_path)}", 66) unless File.file?(prompt_path)

passages = AtlasBatch.read_jsonl(passages_path)
done = options[:include_ingested] ? [] : ingested_custom_ids(run_id)
done_lookup = done.to_h { |custom_id| [custom_id, true] }
prompt = File.read(prompt_path)
taxonomy_context = load_taxonomy_context

request_records = []
request_map = []
passages.each do |passage|
  custom_id = custom_id_for(passage)
  next if done_lookup[custom_id]

  request_records << {
    "custom_id" => custom_id,
    "method" => "POST",
    "url" => options.fetch(:endpoint),
    "body" => request_body(passage, prompt, taxonomy_context, options)
  }
  request_map << {
    "custom_id" => custom_id,
    "record_id" => record_id_for(passage),
    "passage_id" => passage.fetch("passage_id"),
    "source_text_path" => passage.fetch("source_text_path"),
    "locator" => passage.fetch("locator"),
    "passage_sha256" => passage.fetch("sha256")
  }
end

shards = shard_requests(
  request_records,
  max_requests: options[:max_requests_per_shard],
  max_bytes: options[:max_bytes_per_shard]
)

requests_dir = File.join(AtlasBatch.batch_dir(run_id), "requests")
FileUtils.mkdir_p(requests_dir)
shard_entries = []
shards.each_with_index do |records, index|
  shard_id = "shard-%04d" % (index + 1)
  path = File.join(requests_dir, "#{shard_id}.jsonl")
  AtlasBatch.write_jsonl(path, records, force: options[:force])
  shard_entries << {
    "shard_id" => shard_id,
    "path" => AtlasBatch.relative_path(path),
    "request_count" => records.length,
    "bytes" => File.size(path),
    "sha256" => AtlasBatch.sha256_file(path),
    "endpoint" => options.fetch(:endpoint),
    "model" => options.fetch(:model),
    "status" => "prepared"
  }
end

request_map_path = File.join(AtlasBatch.batch_dir(run_id), "request-map.jsonl")
AtlasBatch.write_jsonl(request_map_path, request_map, force: options[:force])

index_path = File.join(requests_dir, "index.yml")
request_index = {
  "batch_request_index_version" => "1",
  "run_id" => run_id,
  "created_at" => AtlasBatch.utc_now,
  "updated_at" => AtlasBatch.utc_now,
  "endpoint" => options.fetch(:endpoint),
  "model" => options.fetch(:model),
  "prompt_path" => AtlasBatch.relative_path(prompt_path),
  "passages_path" => AtlasBatch.relative_path(passages_path),
  "request_map_path" => AtlasBatch.relative_path(request_map_path),
  "skipped_ingested_count" => done.length,
  "shards" => shard_entries
}
AtlasBatch.write_yaml(index_path, request_index)

manifest["pipeline"] = "motif_extraction"
manifest["status"] = "requests_prepared"
manifest["config"] ||= {}
manifest["config"]["motif_request_generation"] = {
  "model" => options.fetch(:model),
  "endpoint" => options.fetch(:endpoint),
  "prompt_path" => AtlasBatch.relative_path(prompt_path),
  "max_output_tokens" => options.fetch(:max_output_tokens),
  "temperature" => options[:temperature],
  "reasoning_effort" => options[:reasoning_effort],
  "max_requests_per_shard" => options[:max_requests_per_shard],
  "max_bytes_per_shard" => options[:max_bytes_per_shard]
}
manifest["artifacts"]["requests_index_path"] = AtlasBatch.relative_path(index_path)
manifest["artifacts"]["request_map_path"] = AtlasBatch.relative_path(request_map_path)
manifest["counts"] ||= {}
manifest["counts"]["requests_prepared"] = request_records.length
manifest["counts"]["request_shards"] = shard_entries.length
manifest["counts"]["skipped_ingested_requests"] = done.length
AtlasBatch.save_manifest(manifest)

puts "prepared #{request_records.length} request(s) in #{shard_entries.length} shard(s)"
puts "wrote #{AtlasBatch.relative_path(index_path)}"
