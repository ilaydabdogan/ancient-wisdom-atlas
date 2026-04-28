#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "time"
require_relative "corpus_queue_common"

options = {
  queue: CorpusQueue::DEFAULT_QUEUE_PATH,
  source: "project_gutenberg",
  ids: [],
  duration_hours: 10.0,
  interval_seconds: 1_800,
  limit_per_cycle: 1,
  max_cycles: nil,
  dry_run: false,
  force: false,
  promote: true,
  check_command: ["ruby", "scripts/check_clean_markdown.rb"],
  stop_when_empty: true
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/corpus_trickle_run.rb [options]"
  parser.on("--queue PATH", "Queue YAML path") { |value| options[:queue] = CorpusQueue.project_path(value) }
  parser.on("--source NAME", "Source key, default: project_gutenberg") { |value| options[:source] = value }
  parser.on("--ids CSV", "Queue ids or source ids to process") { |value| options[:ids] = value.split(",") }
  parser.on("--duration-hours N", Float, "Run window, default: 10") { |value| options[:duration_hours] = value }
  parser.on("--interval-seconds N", Integer, "Delay between cycles, default: 1800") { |value| options[:interval_seconds] = value }
  parser.on("--limit-per-cycle N", Integer, "Items per cycle, default: 1") { |value| options[:limit_per_cycle] = value }
  parser.on("--max-cycles N", Integer, "Stop after N cycles even if time remains") { |value| options[:max_cycles] = value }
  parser.on("--dry-run", "Preview one cycle without downloading or sleeping") { options[:dry_run] = true }
  parser.on("--force", "Pass --force to the queue pipeline") { options[:force] = true }
  parser.on("--no-promote", "Fetch and convert only") { options[:promote] = false }
  parser.on("--no-check", "Skip post-cycle Markdown validation") { options[:check_command] = nil }
  parser.on("--check-all", "Run the full repo check after each cycle") { options[:check_command] = ["ruby", "scripts/check_all.rb"] }
  parser.on("--keep-waiting-when-empty", "Sleep and re-check until the run window ends") { options[:stop_when_empty] = false }
end.parse!

options[:interval_seconds] = 0 if options[:dry_run]

def log(message)
  puts "[#{Time.now.iso8601}] #{message}"
end

def queued_items(options)
  queue = CorpusQueue.load_queue(options[:queue])
  CorpusQueue.selected_items(
    queue,
    ids: options[:ids],
    statuses: options[:ids].any? ? [] : ["queued"],
    source: options[:source],
    limit: options[:limit_per_cycle]
  )
end

def run_command(command)
  log "==> #{command.join(' ')}"
  success = system(*command)
  raise "command failed: #{command.join(' ')}" unless success
end

def pipeline_command(options)
  command = [
    "ruby",
    "scripts/corpus_run_pipeline.rb",
    "--queue",
    options[:queue],
    "--source",
    options[:source],
    "--limit",
    options[:limit_per_cycle].to_s
  ]
  command += ["--ids", options[:ids].join(",")] if options[:ids].any?
  command << "--dry-run" if options[:dry_run]
  command << "--force" if options[:force]
  command << "--no-promote" unless options[:promote]
  command
end

def sleep_until_next_cycle(seconds, deadline)
  return if seconds <= 0

  remaining = [seconds, (deadline - Time.now).ceil].min
  return if remaining <= 0

  log "sleeping #{remaining} seconds before next cycle"
  sleep remaining
end

$stdout.sync = true
$stderr.sync = true

started_at = Time.now
deadline = started_at + (options[:duration_hours] * 3600)
cycle = 0

log "trickle run started; deadline=#{deadline.iso8601}; limit_per_cycle=#{options[:limit_per_cycle]}"

loop do
  break if Time.now >= deadline
  break if options[:max_cycles] && cycle >= options[:max_cycles]

  pending = queued_items(options)
  if pending.empty?
    log "no queued items matched source=#{options[:source]}"
    break if options[:stop_when_empty] || options[:dry_run]

    sleep_until_next_cycle(options[:interval_seconds], deadline)
    next
  end

  cycle += 1
  log "cycle #{cycle}: processing #{pending.map { |item| item.fetch('id') }.join(', ')}"
  run_command(pipeline_command(options))

  if options[:check_command] && !options[:dry_run]
    run_command(options[:check_command])
  end

  break if options[:dry_run]

  sleep_until_next_cycle(options[:interval_seconds], deadline)
end

log "trickle run complete; cycles=#{cycle}; elapsed_seconds=#{(Time.now - started_at).round}"
