#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "corpus_queue_common"

options = {
  queue: CorpusQueue::DEFAULT_QUEUE_PATH,
  statuses: ["converted"],
  source: "project_gutenberg",
  ids: [],
  limit: 5,
  dry_run: false,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/corpus_promote_queue.rb [options]"
  parser.on("--queue PATH", "Queue YAML path") { |value| options[:queue] = CorpusQueue.project_path(value) }
  parser.on("--status CSV", "Statuses to promote, default: converted") { |value| options[:statuses] = value.split(",") }
  parser.on("--source NAME", "Source key, default: project_gutenberg") { |value| options[:source] = value }
  parser.on("--ids CSV", "Queue ids or source ids to promote") { |value| options[:ids] = value.split(",") }
  parser.on("--limit N", Integer, "Maximum items, default: 5") { |value| options[:limit] = value }
  parser.on("--all", "Process all matching items") { options[:limit] = nil }
  parser.on("--force", "Rewrite canonical text and manifest if they exist") { options[:force] = true }
  parser.on("--dry-run", "Print planned promotions without writing") { options[:dry_run] = true }
end.parse!

queue = CorpusQueue.load_queue(options[:queue])
items = CorpusQueue.selected_items(
  queue,
  ids: options[:ids],
  statuses: options[:ids].any? ? [] : options[:statuses],
  source: options[:source],
  limit: options[:limit]
)

if items.empty?
  puts "no queue items matched"
  exit 0
end

promoted = []

items.each do |item|
  unless CorpusQueue.allowed_for_auto_promote?(item)
    warn "skipping #{item.fetch('id')}: rights fields do not allow automatic full-text promotion"
    next
  end

  raw_relative = CorpusQueue.raw_path(item)
  raw_path = CorpusQueue.project_path(raw_relative)
  converted_path = CorpusQueue.project_path(CorpusQueue.converted_path(item))
  canonical_relative = CorpusQueue.canonical_path(item)
  canonical_path = CorpusQueue.project_path(canonical_relative)

  if options[:dry_run]
    puts "would promote #{item.fetch('id')} -> #{canonical_relative}"
    next
  end

  raise "missing raw file for #{item.fetch('id')}: #{raw_relative}" unless File.file?(raw_path)
  raise "missing converted file for #{item.fetch('id')}: #{CorpusQueue.converted_path(item)}" unless File.file?(converted_path)

  if File.file?(canonical_path) && !options[:force]
    raise "canonical file already exists for #{item.fetch('id')}: #{canonical_relative} (use --force to rewrite)"
  end

  body = CorpusQueue.canonical_body_from_converted(File.binread(converted_path))
  FileUtils.mkdir_p(File.dirname(canonical_path))
  File.write(canonical_path, CorpusQueue.canonical_markdown(item, body), mode: "w")
  FileUtils.mkdir_p(CorpusQueue.project_path(CorpusQueue.extraction_dir(item)))

  item["canonical_path"] = canonical_relative
  item["manifest_path"] = CorpusQueue.manifest_path(item)
  item["extraction_dir"] = CorpusQueue.extraction_dir(item)
  item["pipeline"] ||= {}
  item["pipeline"]["promoted_on"] = CorpusQueue::TODAY
  item["status"] = "ingested"

  CorpusQueue.write_manifest(item)
  promoted << item
  puts "promoted #{item.fetch('id')} -> #{canonical_relative}"
end

unless options[:dry_run]
  CorpusQueue.update_registry(promoted) if promoted.any?
  CorpusQueue.save_queue(queue, options[:queue])
end
