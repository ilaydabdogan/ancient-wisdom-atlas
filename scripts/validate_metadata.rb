#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "date"

ROOT = File.expand_path("..", __dir__)
REQUIRED_FRONT_MATTER_DIRS = %w[patterns texts].freeze

errors = []

REQUIRED_FRONT_MATTER_DIRS.each do |dir|
  Dir.glob(File.join(ROOT, dir, "**/*.md")).sort.each do |path|
    raw = File.read(path)
    relative = path.sub("#{ROOT}/", "")
    next if relative == "texts/README.md"

    unless raw.start_with?("---\n")
      errors << "#{relative}: missing YAML front matter"
      next
    end

    parts = raw.split(/^---\s*$/, 3)
    metadata = YAML.safe_load(parts[1] || "", permitted_classes: [Date], aliases: false) || {}
    errors << "#{relative}: missing id" if metadata["id"].to_s.strip.empty?
    errors << "#{relative}: missing title" if metadata["title"].to_s.strip.empty?
  rescue Psych::SyntaxError => e
    errors << "#{relative}: invalid YAML front matter: #{e.message}"
  end
end

if errors.empty?
  puts "metadata ok"
else
  warn errors.join("\n")
  exit 1
end
