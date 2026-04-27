#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "yaml"
require "date"

ROOT = File.expand_path("..", __dir__)
EXPORT_DIR = File.join(ROOT, "exports")

COLLECTIONS = {
  "texts" => ["texts/**/*.md"],
  "patterns" => ["patterns/**/*.md"]
}.freeze

STRUCTURED_COLLECTIONS = {
  "extractions" => ["extractions/**/*.yml", "extractions/**/*.yaml"],
  "manifests" => ["manifests/**/*.yml", "manifests/**/*.yaml"],
  "collections" => ["data/collections/**/*.yml", "data/collections/**/*.yaml"]
}.freeze

def read_markdown(path)
  raw = File.read(path)
  if raw.start_with?("---\n")
    parts = raw.split(/^---\s*$/, 3)
    front_matter = parts[1] ? YAML.safe_load(parts[1], permitted_classes: [Date], aliases: false) : {}
    body = parts[2] || raw
  else
    front_matter = {}
    body = raw
  end

  {
    "path" => path.sub("#{ROOT}/", ""),
    "metadata" => front_matter || {},
    "body" => body.strip
  }
end

def write_jsonl(collection, records)
  FileUtils.mkdir_p(EXPORT_DIR)
  output_path = File.join(EXPORT_DIR, "#{collection}.jsonl")
  File.open(output_path, "w") do |file|
    records.each { |record| file.puts(JSON.generate(record)) }
  end
  output_path
end

def read_structured(path)
  {
    "path" => path.sub("#{ROOT}/", ""),
    "data" => YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false)
  }
end

written = []

COLLECTIONS.each do |collection, globs|
  files = globs.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.sort
  records = files.map do |path|
    read_markdown(path).merge("collection" => collection)
  end
  written << write_jsonl(collection, records)
end

STRUCTURED_COLLECTIONS.each do |collection, globs|
  files = globs.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.sort
  records = files.map do |path|
    read_structured(path).merge("collection" => collection)
  end
  written << write_jsonl(collection, records)
end

atlas_records = (COLLECTIONS.keys + STRUCTURED_COLLECTIONS.keys).flat_map do |collection|
  File.readlines(File.join(EXPORT_DIR, "#{collection}.jsonl"), chomp: true).map { |line| JSON.parse(line) }
end
written << write_jsonl("atlas", atlas_records)

written.each do |path|
  puts "wrote #{path.sub("#{ROOT}/", "")}"
end
