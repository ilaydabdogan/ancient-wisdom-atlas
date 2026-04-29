#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
OUTPUT_PATH = File.join(ROOT, "TEXTS.md")
TODAY = Date.today.iso8601

INGESTED_PATH = File.join(ROOT, "data", "collections", "ingested-corpus.yml")
FIRST_500_PATH = File.join(ROOT, "data", "collections", "first-500-corpus.yml")
SOURCE_MAP_PATH = File.join(ROOT, "data", "collections", "first-500-source-map.yml")

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def titleize(value)
  value.to_s
    .tr("_-", " ")
    .split
    .map { |part| part[0] ? part[0].upcase + part[1..] : part }
    .join(" ")
end

def md_link(label, path)
  return label.to_s if path.to_s.empty?

  "[#{label}](#{path})"
end

def unit_number(unit_id)
  unit_id.to_s.split(".").last.to_i
end

def expand_unit_refs(source)
  refs = Array(source["first500_units"])
  Array(source["first500_ranges"]).each do |range|
    left, right = range.to_s.split("-", 2)
    next unless left && right

    prefix = left.split(".").first
    (unit_number(left)..unit_number(right)).each do |number|
      refs << format("%s.%03d", prefix, number)
    end
  end
  refs.uniq
end

def source_note(source)
  mode = source["coverage_mode"].to_s
  action = source["next_action"].to_s
  note = case mode
         when "complete_source_covers_planned_units"
           "source Markdown included"
         when "translation_source_review_required"
           "source Markdown included; translation/source review required"
         when "candidate_source_needs_unit_match"
           "source Markdown included; unit matching required"
         else
           mode.empty? ? "source Markdown included" : mode.tr("_", " ")
         end
  action.empty? ? note : "#{note}; next: #{action.tr("_", " ")}"
end

ingested = load_yaml(INGESTED_PATH)
first_500 = load_yaml(FIRST_500_PATH)
source_map = load_yaml(SOURCE_MAP_PATH)

ingested_items = ingested.fetch("items", [])
registered_by_id = ingested_items.to_h { |item| [item.fetch("id"), item] }
registered_paths = ingested_items.map { |item| item["canonical_text_path"] }.compact
markdown_paths = Dir.glob(File.join(ROOT, "texts", "**", "*.md"))
  .map { |path| path.sub("#{ROOT}/", "") }
  .reject { |path| path == "texts/README.md" }
  .sort

orphan_paths = markdown_paths - registered_paths

source_records_by_unit = Hash.new { |hash, key| hash[key] = [] }
source_map.fetch("sources", []).each do |source|
  expand_unit_refs(source).each do |unit_id|
    source_records_by_unit[unit_id] << source
  end
end

included_source_ids = source_map.fetch("sources", []).map { |source| source["source_work_id"] }.compact.uniq
first500_items = first_500.fetch("items", [])
covered_units = 0
review_units = 0

unit_rows = first500_items.map do |item|
  unit_id = item.fetch("id")
  sources = source_records_by_unit[unit_id]
  ingested_sources = sources.map do |source|
    registered = registered_by_id[source["source_work_id"]]
    next unless registered && registered["canonical_text_path"]

    [source, registered]
  end.compact

  checked = !ingested_sources.empty?
  if checked
    covered_units += 1
    review_units += 1 if ingested_sources.any? { |source, _registered| source["coverage_mode"] != "complete_source_covers_planned_units" }
  end

  source_details = if checked
                     ingested_sources.map do |source, registered|
                       "#{md_link(registered["title"], registered["canonical_text_path"])} (#{source_note(source)})"
                     end.join("; ")
                   else
                     rights = item["candidate_rights"].to_s.tr("_", " ")
                     rights.empty? ? "planned" : "planned; rights: #{rights}"
                   end

  {
    "culture_area" => item.fetch("culture_area"),
    "line" => "- [#{checked ? "x" : " "}] `#{unit_id}` #{item.fetch("title")} — #{source_details}"
  }
end

included_by_cluster = ingested_items.group_by { |item| item["tradition_cluster"].to_s }
unit_rows_by_culture = unit_rows.group_by { |row| row.fetch("culture_area") }
out_of_plan = ingested_items.reject { |item| included_source_ids.include?(item.fetch("id")) }

markdown = []
markdown << "# Texts Checklist"
markdown << ""
markdown << "Generated on #{TODAY} from `data/collections/ingested-corpus.yml`, `data/collections/first-500-corpus.yml`, and `data/collections/first-500-source-map.yml`."
markdown << ""
markdown << "This page tracks complete source Markdown files currently present in the repo and the planned first-500 corpus units still to be filled or split. A checked first-500 unit means a complete source Markdown file exists that covers it; long works may still need unit-level splitting before the unit is final."
markdown << ""
markdown << "## Summary"
markdown << ""
markdown << "| Track | Count |"
markdown << "| --- | ---: |"
markdown << "| Included Markdown source texts | #{ingested_items.length} |"
markdown << "| Markdown files under `texts/` | #{markdown_paths.length} |"
markdown << "| First-500 planned units | #{first500_items.length} |"
markdown << "| First-500 units with source Markdown | #{covered_units} |"
markdown << "| First-500 units needing translation/source review or unit matching | #{review_units} |"
markdown << "| First-500 units still unchecked | #{first500_items.length - covered_units} |"
markdown << "| Included source texts outside first-500 source map | #{out_of_plan.length} |"
markdown << ""

markdown << "## Included Markdown Source Texts"
markdown << ""
included_by_cluster.sort_by { |cluster, _items| titleize(cluster) }.each do |cluster, items|
  markdown << "### #{titleize(cluster)}"
  markdown << ""
  items.sort_by { |item| item["title"].to_s.downcase }.each do |item|
    path = item["canonical_text_path"]
    path_note = path && File.exist?(File.join(ROOT, path)) ? md_link(path, path) : "`missing path`"
    markdown << "- [x] #{item.fetch("title")} — `#{item.fetch("id")}` — #{path_note}"
  end
  markdown << ""
end

unless orphan_paths.empty?
  markdown << "## Unregistered Markdown Files"
  markdown << ""
  markdown << "These files exist under `texts/` but are not yet present in `data/collections/ingested-corpus.yml`."
  markdown << ""
  orphan_paths.each do |path|
    markdown << "- [x] #{md_link(path, path)}"
  end
  markdown << ""
end

markdown << "## First-500 Planned Units"
markdown << ""
markdown << "Checked units have a complete source Markdown file in the repo. Unchecked units are still planned targets."
markdown << ""
unit_rows_by_culture.sort_by { |culture, _rows| culture }.each do |culture, rows|
  markdown << "### #{culture}"
  markdown << ""
  rows.sort_by { |row| unit_number(row.fetch("line")[/`(first500\.\d+)`/, 1]) }.each do |row|
    markdown << row.fetch("line")
  end
  markdown << ""
end

markdown << "## Included Texts Outside The First-500 Source Map"
markdown << ""
markdown << "These are already in Markdown and remain valuable, but they are not currently mapped as first-500 source coverage."
markdown << ""
out_of_plan.group_by { |item| item["tradition_cluster"].to_s }.sort_by { |cluster, _items| titleize(cluster) }.each do |cluster, items|
  markdown << "### #{titleize(cluster)}"
  markdown << ""
  items.sort_by { |item| item["title"].to_s.downcase }.each do |item|
    markdown << "- [x] #{item.fetch("title")} — `#{item.fetch("id")}` — #{md_link(item["canonical_text_path"], item["canonical_text_path"])}"
  end
  markdown << ""
end

File.write(OUTPUT_PATH, markdown.join("\n").rstrip + "\n")

puts "wrote #{OUTPUT_PATH.sub("#{ROOT}/", "")}"
puts "included_texts=#{ingested_items.length} first500_covered=#{covered_units} first500_unchecked=#{first500_items.length - covered_units}"
