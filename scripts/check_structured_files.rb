#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)

yaml_globs = [
  ".github/**/*.yml",
  ".github/**/*.yaml",
  "data/**/*.yml",
  "data/**/*.yaml",
  "extractions/**/*.yml",
  "extractions/**/*.yaml",
  "manifests/**/*.yml",
  "manifests/**/*.yaml",
  "taxonomy/**/*.yml",
  "taxonomy/**/*.yaml",
  "templates/**/*.yml",
  "templates/**/*.yaml"
]

json_globs = [
  "schemas/**/*.json"
]

errors = []

yaml_globs.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.sort.uniq.each do |path|
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false)
rescue Psych::Exception => e
  errors << "#{path.sub("#{ROOT}/", "")}: invalid YAML: #{e.message}"
end

json_globs.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.sort.uniq.each do |path|
  JSON.parse(File.read(path))
rescue JSON::ParserError => e
  errors << "#{path.sub("#{ROOT}/", "")}: invalid JSON: #{e.message}"
end

if errors.empty?
  puts "structured files ok"
else
  warn errors.join("\n")
  exit 1
end
