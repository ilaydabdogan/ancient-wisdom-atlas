#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "batch_common"

options = {
  glob: "texts/public-domain/**/*.md",
  max_chars: 6_000,
  min_chars: 500,
  text_paths: [],
  coverage_statuses: [],
  coverage_priorities: [],
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/batch_segment_passages.rb --run-id RUN_ID [options]"
  parser.on("--run-id RUN_ID", "Stable batch run id, e.g. demo-motif-extraction-001") { |value| options[:run_id] = value }
  parser.on("--glob GLOB", "Text glob relative to repo root") { |value| options[:glob] = value }
  parser.on("--text PATH", "Canonical markdown text path; may be repeated") { |value| options[:text_paths] << value }
  parser.on("--coverage PATH", "Use data/indexes/extraction-coverage.yml to select texts needing extraction") { |value| options[:coverage_path] = value }
  parser.on("--coverage-status STATUS", "Only select this coverage status; may be repeated") { |value| options[:coverage_statuses] << value }
  parser.on("--coverage-priority PRIORITY", "Only select this coverage priority; may be repeated") { |value| options[:coverage_priorities] << value }
  parser.on("--max-source-texts N", Integer, "Limit number of source texts selected before passage segmentation") { |value| options[:max_source_texts] = value }
  parser.on("--limit N", Integer, "Limit total passages written, useful for demos") { |value| options[:limit] = value }
  parser.on("--max-passages-per-text N", Integer, "Limit passages selected from each text") { |value| options[:max_passages_per_text] = value }
  parser.on("--max-chars N", Integer, "Approximate maximum characters per passage") { |value| options[:max_chars] = value }
  parser.on("--min-chars N", Integer, "Soft minimum characters before flushing at headings") { |value| options[:min_chars] = value }
  parser.on("--output PATH", "Output passages JSONL path") { |value| options[:output] = value }
  parser.on("--force", "Replace changed generated files") { options[:force] = true }
end.parse!

AtlasBatch.die("--run-id is required", 64) unless options[:run_id]
AtlasBatch.die("--max-chars must be at least 1000", 64) if options[:max_chars] < 1_000
AtlasBatch.die("--min-chars cannot exceed --max-chars", 64) if options[:min_chars] > options[:max_chars]

def coverage_text_paths(options)
  coverage_path = AtlasBatch.project_path(options.fetch(:coverage_path))
  AtlasBatch.die("Coverage index not found: #{AtlasBatch.relative_path(coverage_path)}", 66) unless File.file?(coverage_path)

  coverage = AtlasBatch.load_yaml(coverage_path, {})
  rows = coverage.fetch("texts", [])
  statuses = options.fetch(:coverage_statuses)
  priorities = options.fetch(:coverage_priorities)

  rows.select do |row|
    default_target = statuses.empty? && priorities.empty? ? row["needs_full_extraction"] : true
    status_match = statuses.empty? || statuses.include?(row["status"].to_s)
    priority_match = priorities.empty? || priorities.include?(row["priority"].to_s)
    default_target && status_match && priority_match
  end.map { |row| row.fetch("source_text_path") }.uniq
end

def selected_text_paths(options)
  paths = if options[:text_paths].any?
            options[:text_paths]
          elsif options[:coverage_path]
            coverage_text_paths(options)
          else
            Dir.glob(File.join(AtlasBatch::ROOT, options[:glob])).map { |path| AtlasBatch.relative_path(path) }
          end

  selected = paths.map { |path| AtlasBatch.project_path(path) }
                  .select { |path| File.file?(path) }
  selected = selected.sort unless options[:coverage_path]
  selected = selected.first(options[:max_source_texts]) if options[:max_source_texts]
  selected
end

def split_oversized_paragraph(paragraph, max_chars)
  lines = paragraph.fetch("text").lines(chomp: true)
  chunks = []
  current = []
  start_line = paragraph.fetch("start_line")
  current_start = start_line

  lines.each_with_index do |line, index|
    candidate = (current + [line]).join("\n")
    if current.any? && candidate.length > max_chars
      chunks << {
        "start_line" => current_start,
        "end_line" => start_line + index - 1,
        "text" => current.join("\n")
      }
      current = [line]
      current_start = start_line + index
    else
      current << line
    end
  end

  if current.any?
    chunks << {
      "start_line" => current_start,
      "end_line" => paragraph.fetch("end_line"),
      "text" => current.join("\n")
    }
  end

  chunks
end

def passage_from(paragraphs, source, heading_path)
  text = paragraphs.map { |paragraph| paragraph.fetch("text") }.join("\n\n").strip
  start_line = paragraphs.first.fetch("start_line")
  end_line = paragraphs.last.fetch("end_line")
  source_slug = AtlasBatch.safe_slug(source.fetch("source_text_id"), fallback: AtlasBatch.safe_slug(source.fetch("path")))
  passage_id = "#{source_slug}__l#{start_line}-l#{end_line}"
  label_base = heading_path.any? ? heading_path.join(" / ") : source.fetch("title")

  {
    "passage_id" => passage_id,
    "source_text_path" => source.fetch("path"),
    "source_text_id" => source.fetch("source_text_id"),
    "source_title" => source.fetch("title"),
    "tradition" => source["tradition"],
    "culture" => source["culture"],
    "text_language" => source["text_language"],
    "rights" => source["rights"],
    "locator" => {
      "label" => "#{label_base}; lines #{start_line}-#{end_line}",
      "start_line" => start_line,
      "end_line" => end_line,
      "heading_path" => heading_path
    },
    "char_count" => text.length,
    "word_count" => text.scan(/\S+/).length,
    "sha256" => AtlasBatch.sha256_text(text),
    "text" => text
  }
end

def build_passages_for_text(path, max_chars:, min_chars:)
  relative = AtlasBatch.relative_path(path)
  parsed = AtlasBatch.read_markdown(path)
  metadata = parsed.fetch("metadata")
  paragraphs = AtlasBatch.paragraphs_from_entries(parsed.fetch("body_entries"))
  source = {
    "path" => relative,
    "source_text_id" => metadata["id"].to_s.empty? ? AtlasBatch.safe_slug(relative) : metadata["id"].to_s,
    "title" => metadata["title"].to_s.empty? ? File.basename(path, ".md") : metadata["title"].to_s,
    "tradition" => metadata["tradition"],
    "culture" => metadata["culture"],
    "text_language" => metadata["text_language"],
    "rights" => metadata["rights"] || {},
    "sha256" => AtlasBatch.sha256_file(path)
  }

  passages = []
  current = []
  current_chars = 0
  heading_path = []

  flush = lambda do
    if current.any?
      passages << passage_from(current, source, heading_path)
      current = []
      current_chars = 0
    end
  end

  paragraphs.each do |paragraph|
    label = AtlasBatch.heading_label(paragraph.fetch("text"))
    if label
      flush.call if current_chars >= min_chars
      heading_path = (heading_path + [label]).last(4)
    end

    units = paragraph.fetch("text").length > max_chars ? split_oversized_paragraph(paragraph, max_chars) : [paragraph]
    units.each do |unit|
      unit_size = unit.fetch("text").length
      if current.any? && current_chars + unit_size + 2 > max_chars
        flush.call
      end

      current << unit
      current_chars += unit_size + 2
    end
  end

  flush.call

  [source.merge("passage_count" => passages.length), passages]
end

paths = selected_text_paths(options)
AtlasBatch.die("No canonical markdown texts matched the selection", 66) if paths.empty?

source_summaries = []
passages = []
paths.each do |path|
  source, source_passages = build_passages_for_text(
    path,
    max_chars: options[:max_chars],
    min_chars: options[:min_chars]
  )
  source_passages = source_passages.first(options[:max_passages_per_text]) if options[:max_passages_per_text]
  source["passage_count"] = source_passages.length
  source_summaries << source
  passages.concat(source_passages)
  break if options[:limit] && passages.length >= options[:limit]
end
passages = passages.first(options[:limit]) if options[:limit]

run_id = options[:run_id]
output_path = AtlasBatch.project_path(options[:output] || File.join("data/batches", run_id, "passages.jsonl"))
result = AtlasBatch.write_jsonl(output_path, passages, force: options[:force])

manifest = AtlasBatch.load_manifest(run_id)
manifest["pipeline"] ||= "motif_extraction"
manifest["status"] = "passages_prepared"
manifest["config"] ||= {}
manifest["config"]["segmentation"] = {
  "glob" => options[:text_paths].any? ? nil : options[:glob],
  "text_paths" => options[:text_paths],
  "coverage_path" => options[:coverage_path],
  "coverage_statuses" => options[:coverage_statuses],
  "coverage_priorities" => options[:coverage_priorities],
  "max_source_texts" => options[:max_source_texts],
  "max_chars" => options[:max_chars],
  "min_chars" => options[:min_chars],
  "limit" => options[:limit]
}
manifest["artifacts"]["passages_path"] = AtlasBatch.relative_path(output_path)
manifest["counts"] ||= {}
manifest["counts"]["source_texts_segmented"] = source_summaries.length
manifest["counts"]["passages"] = passages.length
manifest["source_texts"] = source_summaries
AtlasBatch.save_manifest(manifest)

puts "#{result == :unchanged ? "unchanged" : "wrote"} #{AtlasBatch.relative_path(output_path)}"
puts "segmented #{source_summaries.length} text(s) into #{passages.length} passage(s)"
