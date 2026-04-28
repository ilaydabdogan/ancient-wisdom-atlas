#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "corpus_queue_common"

options = {
  queue: CorpusQueue::DEFAULT_QUEUE_PATH,
  statuses: ["fetched"],
  source: "project_gutenberg",
  ids: [],
  limit: 5,
  dry_run: false,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/corpus_convert_queue.rb [options]"
  parser.on("--queue PATH", "Queue YAML path") { |value| options[:queue] = CorpusQueue.project_path(value) }
  parser.on("--status CSV", "Statuses to convert, default: fetched") { |value| options[:statuses] = value.split(",") }
  parser.on("--source NAME", "Source key, default: project_gutenberg") { |value| options[:source] = value }
  parser.on("--ids CSV", "Queue ids or source ids to convert") { |value| options[:ids] = value.split(",") }
  parser.on("--limit N", Integer, "Maximum items, default: 5") { |value| options[:limit] = value }
  parser.on("--all", "Process all matching items") { options[:limit] = nil }
  parser.on("--force", "Rewrite converted Markdown if it exists") { options[:force] = true }
  parser.on("--dry-run", "Print planned conversions without writing") { options[:dry_run] = true }
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

items.each do |item|
  raw_relative = CorpusQueue.raw_path(item)
  raw_path = CorpusQueue.project_path(raw_relative)
  converted_relative = CorpusQueue.converted_path(item)
  converted_path = CorpusQueue.project_path(converted_relative)

  if options[:dry_run]
    puts "would convert #{raw_relative} -> #{converted_relative}"
    next
  end

  raise "missing raw file for #{item.fetch('id')}: #{raw_relative}" unless File.file?(raw_path)

  if File.file?(converted_path) && !options[:force]
    puts "converted exists #{converted_relative}"
  else
    body = CorpusQueue.clean_raw_text(File.binread(raw_path))
    FileUtils.mkdir_p(File.dirname(converted_path))
    File.write(converted_path, "# #{item.fetch('title')}\n\n#{body}", mode: "w")
  end

  item["converted_path"] = converted_relative
  item["pipeline"] ||= {}
  item["pipeline"]["converted_on"] = CorpusQueue::TODAY
  item["status"] = "converted" unless item["status"] == "ingested"
  puts "converted #{item.fetch('id')} -> #{converted_relative}"
end

CorpusQueue.save_queue(queue, options[:queue]) unless options[:dry_run]
