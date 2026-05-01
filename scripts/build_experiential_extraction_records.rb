#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Build canonical extraction records for the experiential corpus.
#
# Reads data/experiential/extraction-manifest.yml (manually-authored motif
# assignments) plus the markdown source texts under texts/experiential/, and
# emits one YAML record per passage under extractions/generated/experiential-batch/.
#
# Each output record uses the same schema as the ancient-corpus extraction
# records produced by the OpenAI Batch pipeline, so downstream tools can read
# both with the same parser. The records are flagged
# extracted_by: human_reading and live in their own subdirectory; build scripts
# for the ancient indexes and the public site MUST exclude this directory.
#
# Usage: ruby scripts/build_experiential_extraction_records.rb [--force]

require "yaml"
require "fileutils"
require "digest"

ROOT = File.expand_path("..", __dir__)
MANIFEST_PATH = File.join(ROOT, "data/experiential/extraction-manifest.yml")
OUTPUT_ROOT = File.join(ROOT, "extractions/generated/experiential-batch")
EXTRACTED_AT = "2026-05-01"
EXTRACTED_BY = "human_reading"

def slugify(name)
  name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
end

# Parse a markdown source text into a hash of section heading -> body lines.
# Headings are recorded with their 1-based line numbers so we can locate them
# in the canonical record's passage_locator.
def parse_sections(markdown_path)
  abs = File.join(ROOT, markdown_path)
  raise "missing source text: #{markdown_path}" unless File.file?(abs)

  raw = File.read(abs)
  body = raw.sub(/\A---\n.*?\n---\n/m, "")
  frontmatter_lines = raw.lines.size - body.lines.size
  body_lines = body.lines

  sections = {}
  current_heading = nil
  current_lines = []
  current_start_line = nil

  body_lines.each_with_index do |line, idx|
    file_line = frontmatter_lines + idx + 1
    is_heading = line =~ /^#{Regexp.escape("##")}#?\s+/ && !line.start_with?("####")
    if is_heading
      if current_heading
        sections[current_heading] = {
          start_line: current_start_line,
          end_line: file_line - 1,
          body: current_lines.join.strip
        }
      end
      current_heading = line.sub(/^#+\s+/, "").strip
      current_lines = []
      current_start_line = file_line
    elsif current_heading && !line.start_with?("# ")
      current_lines << line
    end
  end

  if current_heading
    sections[current_heading] = {
      start_line: current_start_line,
      end_line: frontmatter_lines + body_lines.size,
      body: current_lines.join.strip
    }
  end

  sections
end

def first_sentences(body, count: 2)
  sentences = body.gsub(/\s+/, " ").split(/(?<=[\.\?!])\s+/).reject(&:empty?)
  sentences.first(count).join(" ").strip
end

def evidence_quote(body, max_chars: 480)
  text = first_sentences(body, count: 3)
  return text if text.length <= max_chars

  trimmed = text[0, max_chars]
  cutoff = trimmed.rindex(/[\.!?]/)
  cutoff ? trimmed[0, cutoff + 1] : trimmed
end

def text_slug_from_path(source_path)
  name = File.basename(source_path, ".md")
  tradition = source_path.split("/")[-2]
  "#{tradition}-#{name}"
end

def write_record(text_entry, passage, sections)
  source_path = text_entry.fetch("source_path")
  tradition = text_entry.fetch("tradition")
  text_id = text_entry.fetch("text_id")
  text_slug = text_slug_from_path(source_path)
  output_dir = File.join(OUTPUT_ROOT, text_slug)
  FileUtils.mkdir_p(output_dir)

  passage_slug = passage.fetch("passage_slug")
  section_heading = passage.fetch("section")
  section = sections[section_heading]
  unless section
    raise "section not found in #{source_path}: #{section_heading.inspect}"
  end

  evidence_text = evidence_quote(section.fetch(:body))
  passage_locator_label = section_heading
  start_line = section.fetch(:start_line)
  end_line = section.fetch(:end_line)
  record_id = "extraction.experiential.#{text_slug.gsub(/-/, '_')}.#{passage_slug}"

  candidate_motifs = passage.fetch("motifs").each_with_index.map do |motif, idx|
    {
      "id" => "motif:#{idx + 1}",
      "label" => motif.fetch("label"),
      "taxonomy_refs" => [motif.fetch("slug")],
      "basis" => motif.fetch("basis"),
      "evidence_refs" => ["ev:1"],
      "confidence" => motif.fetch("confidence"),
      "cautions" => motif["cautions"].to_s
    }
  end

  literal_observations = [
    {
      "id" => "obs:1",
      "text" => passage.fetch("summary"),
      "category" => "summary",
      "evidence_refs" => ["ev:1"]
    }
  ]

  evidence = [
    {
      "id" => "ev:1",
      "type" => "summary",
      "locator" => "section: #{section_heading} (lines #{start_line}-#{end_line})",
      "quote_or_summary" => evidence_text,
      "source_text_path" => source_path,
      "rights_note" => "Original phenomenological summary text written for the experiential corpus; safe to quote within the project."
    }
  ]

  record = {
    "record_id" => record_id,
    "source_text_path" => source_path,
    "tradition" => tradition,
    "sub_corpus" => text_entry.fetch("sub_corpus"),
    "passage_locator" => {
      "label" => passage_locator_label,
      "start" => start_line.to_s,
      "end" => end_line.to_s,
      "translation" => "",
      "notes" => "Manual extraction from experiential corpus source text; passage demarcated by the ## heading in the source."
    },
    "canonical_text" => {
      "quote" => "",
      "summary" => passage.fetch("summary"),
      "language" => "English",
      "quote_policy" => "summarized"
    },
    "literal_observations" => literal_observations,
    "figures" => [],
    "roles" => [],
    "symbols" => [],
    "scenes" => [],
    "candidate_motifs" => candidate_motifs,
    "comparison_claims" => [],
    "evidence" => evidence,
    "confidence" => {
      "extraction" => "medium",
      "motif_candidates" => "medium",
      "comparison_claims" => "uncertain",
      "notes" => "Manual extraction from a structured phenomenological summary text. Motif slugs are experiential-only and are not normalized against the ancient corpus taxonomy."
    },
    "reviewer_status" => {
      "status" => "draft",
      "reviewer" => "",
      "reviewed_at" => "",
      "notes" => "Manually extracted on #{EXTRACTED_AT}. Pending review."
    },
    "extracted_by" => EXTRACTED_BY,
    "extracted_at" => EXTRACTED_AT,
    "notes" => "Generated from data/experiential/extraction-manifest.yml by scripts/build_experiential_extraction_records.rb. Source text id: #{text_id}."
  }

  output_path = File.join(output_dir, "#{passage_slug}.yml")
  File.write(output_path, "---\n" + record.to_yaml(line_width: -1).sub(/\A---\n/, ""))
  output_path
end

def main
  manifest = YAML.load_file(MANIFEST_PATH)
  texts = manifest.fetch("texts")
  written = []

  texts.each do |text_entry|
    sections = parse_sections(text_entry.fetch("source_path"))
    text_entry.fetch("passages").each do |passage|
      written << write_record(text_entry, passage, sections)
    end
  end

  puts "Wrote #{written.size} extraction records under #{OUTPUT_ROOT.sub(ROOT + '/', '')}"
end

main if $PROGRAM_NAME == __FILE__
