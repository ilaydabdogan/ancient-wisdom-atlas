#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

ROOT = File.expand_path("..", __dir__)
PATH = File.join(ROOT, "data/collections/first-500-corpus.yml")

data = YAML.load_file(PATH)
items = data.fetch("items")
ids = items.map { |item| item.fetch("id") }

errors = []
errors << "expected 500 items, got #{items.length}" unless items.length == 500
errors << "duplicate ids found" unless ids.uniq.length == ids.length

items.each do |item|
  %w[id title culture_area tradition_cluster era source_type ingestion_unit priority_wave candidate_rights status].each do |key|
    errors << "#{item.fetch("id", "unknown")}: missing #{key}" if item[key].to_s.strip.empty?
  end
end

group_total = data.fetch("groups").sum { |group| group.fetch("count") }
errors << "group counts total #{group_total}, expected 500" unless group_total == 500

if errors.empty?
  puts "first 500 corpus ok"
else
  warn errors.join("\n")
  exit 1
end

