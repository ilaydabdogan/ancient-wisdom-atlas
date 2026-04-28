#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "set"
require "yaml"

ROOT = File.expand_path("..", __dir__)
FIRST500_PATH = File.join(ROOT, "data", "collections", "first-500-corpus.yml")
SOURCE_MAP_PATH = File.join(ROOT, "data", "collections", "first-500-source-map.yml")
INGESTED_PATH = File.join(ROOT, "data", "collections", "ingested-corpus.yml")
QUEUE_PATH = File.join(ROOT, "data", "sources", "auto-ingestion-queue.yml")
INDEX_PATH = File.join(ROOT, "data", "indexes", "first-500-progress.yml")
REPORT_PATH = File.join(ROOT, "docs", "first-500-progress.md")
TODAY = Date.today.iso8601

STATE_RANK = {
  "unmapped" => 0,
  "source_candidate" => 1,
  "source_queued" => 2,
  "source_ingested_review" => 3,
  "source_ingested" => 4
}.freeze

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false)
end

def numeric_id(id)
  id.to_s.split(".").last.to_i
end

def expand_range(range)
  start_id, end_id = range.to_s.split("-", 2)
  raise "invalid first-500 range: #{range}" unless start_id && end_id

  start_number = numeric_id(start_id)
  end_number = numeric_id(end_id)
  raise "invalid first-500 range order: #{range}" if end_number < start_number

  (start_number..end_number).map { |number| "first500.%03d" % number }
end

def source_state(entry, ingested_ids, queue_by_id)
  source_id = entry.fetch("source_work_id")
  return "source_ingested" if ingested_ids.include?(source_id) &&
    entry.fetch("coverage_mode") == "complete_source_covers_planned_units" &&
    entry.fetch("coverage_confidence") == "high"

  return "source_ingested_review" if ingested_ids.include?(source_id)
  return "source_queued" if queue_by_id[source_id]&.fetch("status", nil) == "queued"
  return "source_candidate" if queue_by_id[source_id]

  "source_candidate"
end

def update_unit_state(unit_states, unit_id, state, entry)
  current = unit_states.fetch(unit_id)
  return if STATE_RANK.fetch(current.fetch("state")) > STATE_RANK.fetch(state)

  current["state"] = state
  current["source_work_id"] = entry.fetch("source_work_id")
  current["source_title"] = entry.fetch("source_title")
  current["coverage_mode"] = entry.fetch("coverage_mode")
  current["coverage_confidence"] = entry.fetch("coverage_confidence")
  current["next_action"] = entry.fetch("next_action")
end

first500 = load_yaml(FIRST500_PATH)
source_map = load_yaml(SOURCE_MAP_PATH)
ingested = load_yaml(INGESTED_PATH)
queue = load_yaml(QUEUE_PATH)

items = first500.fetch("items")
items_by_id = items.to_h { |item| [item.fetch("id"), item] }
ingested_ids = ingested.fetch("items").map { |item| item.fetch("id") }.to_set
queue_by_id = queue.fetch("items").to_h { |item| [item.fetch("id"), item] }
mapped_source_ids = source_map.fetch("sources").map { |entry| entry.fetch("source_work_id") }.to_set

unit_states = items.to_h do |item|
  [
    item.fetch("id"),
    {
      "id" => item.fetch("id"),
      "title" => item.fetch("title"),
      "culture_area" => item.fetch("culture_area"),
      "tradition_cluster" => item.fetch("tradition_cluster"),
      "priority_wave" => item.fetch("priority_wave"),
      "state" => "unmapped"
    }
  ]
end

source_rows = []
errors = []

source_map.fetch("sources").each do |entry|
  unit_ids = Array(entry["first500_units"]) + Array(entry["first500_ranges"]).flat_map { |range| expand_range(range) }
  missing = unit_ids.reject { |unit_id| items_by_id.key?(unit_id) }
  errors << "#{entry.fetch("source_work_id")}: unknown first-500 ids #{missing.join(", ")}" if missing.any?

  state = source_state(entry, ingested_ids, queue_by_id)
  unit_ids.each { |unit_id| update_unit_state(unit_states, unit_id, state, entry) if items_by_id.key?(unit_id) }

  source_rows << {
    "source_work_id" => entry.fetch("source_work_id"),
    "source_title" => entry.fetch("source_title"),
    "state" => state,
    "coverage_mode" => entry.fetch("coverage_mode"),
    "coverage_confidence" => entry.fetch("coverage_confidence"),
    "first500_unit_count" => unit_ids.count,
    "first500_units" => unit_ids,
    "next_action" => entry.fetch("next_action")
  }
end

raise errors.join("\n") if errors.any?

by_culture_area = unit_states.values
  .group_by { |unit| unit.fetch("culture_area") }
  .transform_values do |units|
    counts = units.group_by { |unit| unit.fetch("state") }.transform_values(&:count)
    {
      "total" => units.count,
      "source_ingested" => counts.fetch("source_ingested", 0),
      "source_ingested_review" => counts.fetch("source_ingested_review", 0),
      "source_queued" => counts.fetch("source_queued", 0),
      "source_candidate" => counts.fetch("source_candidate", 0),
      "unmapped" => counts.fetch("unmapped", 0)
    }
  end

state_counts = unit_states.values.group_by { |unit| unit.fetch("state") }.transform_values(&:count)

queue_outside_first500 = queue.fetch("items")
  .reject { |item| mapped_source_ids.include?(item.fetch("id")) }
  .map { |item| item.slice("id", "title", "status", "priority", "source_id") }

ingested_outside_first500 = ingested.fetch("items")
  .reject { |item| mapped_source_ids.include?(item.fetch("id")) }
  .map { |item| item.slice("id", "title", "tradition_cluster", "source_id") }

next_first500_queue = source_rows
  .select { |row| row.fetch("state") == "source_queued" }
  .sort_by { |row| [numeric_id(row.fetch("first500_units").first), row.fetch("source_work_id")] }
  .map { |row| row.transform_values { |value| value.is_a?(Array) ? value.dup : value } }

index = {
  "index_id" => "first_500_progress",
  "generated_on" => TODAY,
  "source_map_path" => "data/collections/first-500-source-map.yml",
  "first500_total_units" => items.count,
  "state_counts" => {
    "source_ingested" => state_counts.fetch("source_ingested", 0),
    "source_ingested_review" => state_counts.fetch("source_ingested_review", 0),
    "source_queued" => state_counts.fetch("source_queued", 0),
    "source_candidate" => state_counts.fetch("source_candidate", 0),
    "unmapped" => state_counts.fetch("unmapped", 0)
  },
  "by_culture_area" => by_culture_area,
  "mapped_sources" => source_rows,
  "next_first500_queue" => next_first500_queue,
  "queue_outside_first500" => queue_outside_first500,
  "ingested_outside_first500" => ingested_outside_first500
}

FileUtils.mkdir_p(File.dirname(INDEX_PATH))
File.write(INDEX_PATH, YAML.dump(index), mode: "w")

def table_row(values)
  "| #{values.join(" | ")} |"
end

summary = index.fetch("state_counts")
report = +"# First 500 Progress\n\n"
report << "Generated on #{TODAY}.\n\n"
report << "This is source-level coverage. Long works still need unit-level Markdown splitting before the first-500 units are truly complete.\n\n"
report << "## Summary\n\n"
report << table_row(["State", "Units"]) << "\n"
report << table_row(["---", "---:"]) << "\n"
summary.each { |state, count| report << table_row([state, count]) << "\n" }

report << "\n## By Culture Area\n\n"
report << table_row(["Culture Area", "Total", "Source Ingested", "Review", "Queued", "Candidate", "Unmapped"]) << "\n"
report << table_row(["---", "---:", "---:", "---:", "---:", "---:", "---:"]) << "\n"
by_culture_area.sort.each do |culture_area, counts|
  report << table_row([
    culture_area,
    counts.fetch("total"),
    counts.fetch("source_ingested"),
    counts.fetch("source_ingested_review"),
    counts.fetch("source_queued"),
    counts.fetch("source_candidate"),
    counts.fetch("unmapped")
  ]) << "\n"
end

report << "\n## Next First-500 Queue\n\n"
report << table_row(["Source", "Queued Units", "Action"]) << "\n"
report << table_row(["---", "---:", "---"]) << "\n"
next_first500_queue.each do |row|
  report << table_row([row.fetch("source_title"), row.fetch("first500_unit_count"), row.fetch("next_action")]) << "\n"
end

report << "\n## Queue Outside First 500\n\n"
report << table_row(["Status", "Source", "Title"]) << "\n"
report << table_row(["---", "---", "---"]) << "\n"
queue_outside_first500.each do |item|
  report << table_row([item.fetch("status"), item.fetch("id"), item.fetch("title")]) << "\n"
end

FileUtils.mkdir_p(File.dirname(REPORT_PATH))
File.write(REPORT_PATH, report, mode: "w")

puts "wrote #{INDEX_PATH.sub("#{ROOT}/", "")}"
puts "wrote #{REPORT_PATH.sub("#{ROOT}/", "")}"
