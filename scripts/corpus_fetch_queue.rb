#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "corpus_queue_common"

options = {
  queue: CorpusQueue::DEFAULT_QUEUE_PATH,
  statuses: ["queued"],
  source: "project_gutenberg",
  ids: [],
  limit: 5,
  dry_run: false,
  force: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/corpus_fetch_queue.rb [options]"
  parser.on("--queue PATH", "Queue YAML path") { |value| options[:queue] = CorpusQueue.project_path(value) }
  parser.on("--status CSV", "Statuses to fetch, default: queued") { |value| options[:statuses] = value.split(",") }
  parser.on("--source NAME", "Source key, default: project_gutenberg") { |value| options[:source] = value }
  parser.on("--ids CSV", "Queue ids or source ids to fetch") { |value| options[:ids] = value.split(",") }
  parser.on("--limit N", Integer, "Maximum items, default: 5") { |value| options[:limit] = value }
  parser.on("--all", "Process all matching items") { options[:limit] = nil }
  parser.on("--force", "Re-download even if raw file exists") { options[:force] = true }
  parser.on("--dry-run", "Print planned fetches without downloading") { options[:dry_run] = true }
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
  url = CorpusQueue.download_url(item)
  raw_relative = CorpusQueue.raw_path(item)
  raw_path = CorpusQueue.project_path(raw_relative)

  if options[:dry_run]
    puts "would fetch #{item.fetch('id')} from #{url} -> #{raw_relative}"
    next
  end

  if File.file?(raw_path) && !options[:force]
    puts "raw exists #{raw_relative}"
  else
    FileUtils.mkdir_p(File.dirname(raw_path))
    success = system("curl", "-L", url, "-o", raw_path)
    raise "curl failed for #{item.fetch('id')}" unless success
  end

  item["raw_path"] = raw_relative
  item["download_url"] ||= url
  item["source_url"] ||= CorpusQueue.landing_url(item)
  item["pipeline"] ||= {}
  item["pipeline"]["raw_fetched_on"] = CorpusQueue::TODAY
  item["status"] = "fetched" unless item["status"] == "ingested"
  puts "fetched #{item.fetch('id')} -> #{raw_relative}"
end

CorpusQueue.save_queue(queue, options[:queue]) unless options[:dry_run]
