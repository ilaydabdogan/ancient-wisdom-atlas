#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

ROOT = File.expand_path("..", __dir__)

options = {
  queue: File.join(ROOT, "data", "sources", "auto-ingestion-queue.yml"),
  source: "project_gutenberg",
  ids: nil,
  limit: 5,
  dry_run: false,
  force: false,
  promote: true
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/corpus_run_pipeline.rb [options]"
  parser.on("--queue PATH", "Queue YAML path") { |value| options[:queue] = File.expand_path(value, ROOT) }
  parser.on("--source NAME", "Source key, default: project_gutenberg") { |value| options[:source] = value }
  parser.on("--ids CSV", "Queue ids or source ids to process") { |value| options[:ids] = value }
  parser.on("--limit N", Integer, "Maximum queued items, default: 5") { |value| options[:limit] = value }
  parser.on("--all", "Process all matching items") { options[:limit] = nil }
  parser.on("--dry-run", "Print planned pipeline steps") { options[:dry_run] = true }
  parser.on("--force", "Pass --force to each stage") { options[:force] = true }
  parser.on("--no-promote", "Fetch and convert only; leave canonical promotion for review") { options[:promote] = false }
end.parse!

def run_stage(script, args)
  command = ["ruby", File.join("scripts", script), *args]
  puts "==> #{command.join(' ')}"
  success = system(*command)
  exit 1 unless success
end

base_args = ["--queue", options[:queue], "--source", options[:source]]
base_args += ["--ids", options[:ids]] if options[:ids]
base_args += options[:limit] ? ["--limit", options[:limit].to_s] : ["--all"]
base_args << "--dry-run" if options[:dry_run]
base_args << "--force" if options[:force]

convert_status = options[:dry_run] ? "queued,fetched" : "fetched"
promote_status = options[:dry_run] ? "queued,fetched,converted" : "converted"

run_stage("corpus_fetch_queue.rb", base_args + ["--status", "queued"])
run_stage("corpus_convert_queue.rb", base_args + ["--status", convert_status])
run_stage("corpus_promote_queue.rb", base_args + ["--status", promote_status]) if options[:promote]

puts "pipeline complete"
