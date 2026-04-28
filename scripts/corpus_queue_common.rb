#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "yaml"

module CorpusQueue
  ROOT = File.expand_path("..", __dir__)
  DEFAULT_QUEUE_PATH = File.join(ROOT, "data", "sources", "auto-ingestion-queue.yml")
  TODAY = Date.today.iso8601

  module_function

  def relative(path)
    File.expand_path(path).sub("#{ROOT}/", "")
  end

  def project_path(path)
    File.expand_path(path, ROOT)
  end

  def load_queue(path = DEFAULT_QUEUE_PATH)
    YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false)
  end

  def save_queue(queue, path = DEFAULT_QUEUE_PATH)
    queue["updated_on"] = TODAY
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, YAML.dump(queue), mode: "w")
  end

  def slugify(value, fallback: "work")
    slug = value.to_s.downcase
      .gsub(/['`’]/, "")
      .gsub(/[^a-z0-9]+/, "-")
      .gsub(/\A-|-+\z/, "")
      .gsub(/-{2,}/, "-")
    slug = fallback if slug.empty?
    slug[0, 90].gsub(/-\z/, "")
  end

  def tradition_path(item)
    item.fetch("tradition").tr("_", "-")
  end

  def source_id(item)
    item.fetch("source_id").to_s
  end

  def source_key(item)
    source = item.fetch("source")
    id = source_id(item)
    source == "project_gutenberg" ? "source.project_gutenberg.#{id}" : "source.#{source}.#{id}"
  end

  def download_url(item)
    return item.fetch("download_url") if item["download_url"].to_s.strip != ""

    case item.fetch("source")
    when "project_gutenberg"
      "https://www.gutenberg.org/ebooks/#{source_id(item)}.txt.utf-8"
    else
      raise "unsupported source for automatic download: #{item.fetch('source')}"
    end
  end

  def landing_url(item)
    return item.fetch("source_url") if item["source_url"].to_s.strip != ""

    case item.fetch("source")
    when "project_gutenberg"
      "https://www.gutenberg.org/ebooks/#{source_id(item)}"
    else
      item["download_url"].to_s
    end
  end

  def item_slug(item)
    slugify(item["slug"] || item.fetch("title"), fallback: source_id(item))
  end

  def raw_path(item)
    item["raw_path"] || "imports/raw/project-gutenberg/#{source_id(item)}-#{item_slug(item)}.txt"
  end

  def converted_path(item)
    item["converted_path"] || "imports/converted/project-gutenberg/#{source_id(item)}-#{item_slug(item)}.md"
  end

  def canonical_path(item)
    item["canonical_path"] ||
      "texts/public-domain/#{tradition_path(item)}/project-gutenberg/#{item_slug(item)}.md"
  end

  def manifest_path(item)
    item["manifest_path"] ||
      "manifests/project-gutenberg/#{source_id(item)}-#{item_slug(item)}.yml"
  end

  def extraction_dir(item)
    item["extraction_dir"] ||
      "extractions/#{tradition_path(item)}/project-gutenberg/#{item_slug(item)}"
  end

  def selected_items(queue, ids: [], statuses: [], source: nil, limit: nil)
    normalized_ids = Array(ids).map(&:to_s).reject(&:empty?)
    normalized_statuses = Array(statuses).map(&:to_s).reject(&:empty?)

    items = queue.fetch("items").select do |item|
      next false if source && item.fetch("source") != source

      if normalized_ids.any?
        normalized_ids.include?(item.fetch("id").to_s) || normalized_ids.include?(source_id(item))
      elsif normalized_statuses.any?
        normalized_statuses.include?(item.fetch("status").to_s)
      else
        true
      end
    end

    limit ? items.first(limit) : items
  end

  def checksum(path)
    Digest::SHA256.file(path).hexdigest
  end

  def decode_text(raw)
    utf8 = raw.dup.force_encoding("UTF-8")
    return utf8.encode("UTF-8") if utf8.valid_encoding?

    raw.dup.force_encoding("Windows-1252").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
  end

  def clean_raw_text(raw)
    text = decode_text(raw)
    text = text.delete_prefix("\uFEFF").gsub("\r\n", "\n").gsub("\r", "\n")

    lines = text.lines(chomp: true)
    start_index = lines.index { |line| line.match?(/\*\*\* START OF (?:THE |THIS )?PROJECT GUTENBERG EBOOK/i) }
    end_index = [
      lines.index { |line| line.match?(/\*\*\* END OF (?:THE |THIS )?PROJECT GUTENBERG EBOOK/i) },
      lines.index { |line| line.match?(/\A\s*End of Project Gutenberg/i) }
    ].compact.min

    if start_index && end_index && end_index > start_index
      lines = lines[(start_index + 1)...end_index]
    elsif start_index
      lines = lines[(start_index + 1)..]
    elsif end_index
      lines = lines[0...end_index]
    end

    lines = remove_transcriber_or_producer_blocks(lines)
    lines = remove_illustration_placeholders(lines)
    lines = lines.reject do |line|
      line.match?(/\A\s*(Produced by|This eBook was produced by)\b/i) ||
        line.match?(/\A\s*\[Illustration(?::[^\]]*)?\]\s*\z/i)
    end
    lines = lines.map(&:rstrip)

    lines.shift while lines.first&.strip&.empty?
    lines.pop while lines.last&.strip&.empty?

    collapse_blank_lines(lines).join("\n") + "\n"
  end

  def remove_transcriber_or_producer_blocks(lines)
    output = []
    skipping = false
    blank_count = 0

    lines.each do |line|
      if line.match?(/\A\s*(Transcriber's Notes?|Transcriber’s Notes?|A note from the digitizer|Produced by|Distributed Proofreading Team)\b/i)
        skipping = true
        blank_count = 0
        next
      end

      if skipping
        if line.strip.empty?
          blank_count += 1
          skipping = false if blank_count >= 2
        else
          blank_count = 0
        end
        next
      end

      output << line
    end

    output
  end

  def remove_illustration_placeholders(lines)
    output = []
    skipping = false

    lines.each do |line|
      if line.match?(/\A\s*\[Illustration\b/i)
        skipping = !line.include?("]")
        next
      end

      if skipping
        skipping = false if line.include?("]")
        next
      end

      output << line
    end

    output
  end

  def collapse_blank_lines(lines)
    output = []
    blank_count = 0

    lines.each do |line|
      if line.strip.empty?
        blank_count += 1
        output << "" if blank_count <= 2
      else
        blank_count = 0
        output << line
      end
    end

    output
  end

  def rights_for(item)
    item.fetch("rights")
  end

  def allowed_for_auto_promote?(item)
    rights = rights_for(item)
    rights.fetch("status") == "public_domain" &&
      rights.fetch("jurisdiction") == "US" &&
      rights.fetch("full_text") == "allowed" &&
      rights.fetch("training_use") == "allowed"
  end

  def canonical_markdown(item, body)
    rights = rights_for(item)
    metadata = {
      "id" => item.fetch("id"),
      "title" => item.fetch("title"),
      "alternate_titles" => Array(item["alternate_titles"]),
      "text_status" => item.fetch("text_status"),
      "tradition" => item.fetch("tradition"),
      "culture" => item.fetch("culture"),
      "region" => item.fetch("region"),
      "source_language" => item.fetch("source_language"),
      "text_language" => item.fetch("text_language"),
      "date_range" => item.fetch("date_range"),
      "source_type" => item.fetch("source_type", "text"),
      "provenance" => {
        "source_id" => source_key(item),
        "edition" => item.fetch("edition"),
        "translator" => item.fetch("translator", ""),
        "editor" => item.fetch("editor", ""),
        "publication_year" => item.fetch("publication_year"),
        "publisher" => item.fetch("publisher", "Project Gutenberg"),
        "source_url" => landing_url(item),
        "access_date" => TODAY
      },
      "rights" => {
        "status" => rights.fetch("status"),
        "jurisdiction" => rights.fetch("jurisdiction"),
        "license_url" => rights.fetch("license_url"),
        "training_use" => rights.fetch("training_use"),
        "full_text" => rights.fetch("full_text"),
        "notes" => rights.fetch("notes", "")
      },
      "trademark" => {
        "status" => "present",
        "marks" => ["Project Gutenberg"],
        "use_rules" => "Use only as factual source attribution; do not use the mark as repository branding."
      },
      "transcription" => {
        "mode" => "normalized",
        "complete" => item.fetch("text_status") == "complete",
        "corrections" => [],
        "omissions" => [
          "Distributor header, license footer, start/end markers, and production boilerplate were removed.",
          "Raw source capture is preserved under imports/raw for auditability."
        ]
      },
      "tags" => Array(item["tags"]),
      "motifs" => Array(item["motifs"]),
      "figures" => Array(item["figures"])
    }

    front_matter = YAML.dump(metadata).sub(/\A---\s*\n/, "")
    <<~MARKDOWN
      ---
      #{front_matter}---

      # #{item.fetch("title")}

      #{body}
    MARKDOWN
  end

  def write_manifest(item)
    raw = project_path(raw_path(item))
    converted = project_path(converted_path(item))
    canonical = project_path(canonical_path(item))
    rights = rights_for(item)

    manifest = {
      "manifest_version" => "1",
      "batch_id" => "auto-ingestion-queue",
      "created_date" => TODAY,
      "updated_date" => TODAY,
      "artifacts" => [
        {
          "id" => "artifact.gutenberg_#{source_id(item)}",
          "work_id" => item.fetch("id"),
          "title" => item.fetch("title"),
          "source_url" => landing_url(item),
          "fetch_date" => item.dig("pipeline", "raw_fetched_on") || TODAY,
          "raw" => {
            "path" => relative(raw),
            "checksum" => { "algorithm" => "sha256", "value" => checksum(raw) },
            "media_type" => "text/plain",
            "notes" => "Raw plain-text source capture."
          },
          "converted" => {
            "path" => relative(converted),
            "checksum" => { "algorithm" => "sha256", "value" => checksum(converted) },
            "media_type" => "text/markdown",
            "notes" => "Intermediate Markdown draft after removing distributor packaging."
          },
          "canonical" => {
            "path" => relative(canonical),
            "checksum" => { "algorithm" => "sha256", "value" => checksum(canonical) },
            "media_type" => "text/markdown",
            "notes" => "Canonical reviewed Markdown corpus text."
          },
          "converter" => {
            "name" => "scripts/corpus_promote_queue.rb",
            "version" => "1",
            "command" => "ruby scripts/corpus_promote_queue.rb --ids #{item.fetch('id')}",
            "settings" => ["strip_distributor_header_footer", "preserve_plain_text_structure"],
            "notes" => "Queue-based plain-text converter for rights-cleared Project Gutenberg source captures."
          },
          "cleanup_notes" => [
            "Removed distributor packaging and license text from canonical corpus file.",
            "Preserved source line and paragraph structure without interpretive rewriting."
          ],
          "rights" => {
            "status" => rights.fetch("status"),
            "jurisdiction" => rights.fetch("jurisdiction"),
            "license_url" => rights.fetch("license_url"),
            "full_text" => rights.fetch("full_text"),
            "training_use" => rights.fetch("training_use"),
            "notes" => rights.fetch("notes", "")
          },
          "trademark" => {
            "status" => "present",
            "marks" => ["Project Gutenberg"],
            "use_rules" => "Use as factual source attribution only.",
            "notes" => "The repository does not use the mark as branding."
          },
          "review" => {
            "status" => "auto_promoted_from_rights_cleared_queue",
            "reviewer" => "Codex",
            "review_date" => TODAY,
            "notes" => "Auto-promoted from a queue item whose rights fields explicitly allowed full-text and training use. Human spot review is still recommended."
          },
          "extraction" => {
            "readiness" => "ready",
            "blocking_issues" => [],
            "notes" => "Ready for motif extraction."
          }
        }
      ]
    }

    path = project_path(manifest_path(item))
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, YAML.dump(manifest), mode: "w")
  end

  def update_registry(items)
    path = project_path("data/collections/ingested-corpus.yml")
    registry = YAML.safe_load(File.read(path), permitted_classes: [Date], aliases: false)
    existing = registry.fetch("items").reject { |record| items.any? { |item| item.fetch("id") == record.fetch("id") } }

    additions = items.map do |item|
      {
        "id" => item.fetch("id"),
        "title" => item.fetch("title"),
        "tradition_cluster" => item.fetch("tradition_cluster"),
        "source_id" => source_key(item),
        "canonical_text_path" => canonical_path(item),
        "manifest_path" => manifest_path(item),
        "extraction_dir" => extraction_dir(item),
        "rights" => {
          "status" => "public_domain",
          "full_text" => "allowed",
          "training_use" => "allowed"
        },
        "ingestion_status" => "canonical_text_added",
        "extraction_status" => "pending_seed_records"
      }
    end

    registry["updated_on"] = TODAY
    registry["items"] = (existing + additions).sort_by { |record| record.fetch("id") }
    File.write(path, YAML.dump(registry), mode: "w")
  end
end
