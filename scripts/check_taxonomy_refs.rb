#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "date"

ROOT = File.expand_path("..", __dir__)

motifs = YAML.load_file(File.join(ROOT, "taxonomy/motifs.yml")).fetch("motif_families").keys
traditions = YAML.load_file(File.join(ROOT, "taxonomy/traditions.yml")).fetch("traditions").keys

errors = []

Dir.glob(File.join(ROOT, "patterns/**/*.md")).sort.each do |path|
  raw = File.read(path)
  relative = path.sub("#{ROOT}/", "")
  unless raw.start_with?("---\n")
    errors << "#{relative}: missing YAML front matter"
    next
  end

  metadata = YAML.safe_load(raw.split(/^---\s*$/, 3)[1] || "", permitted_classes: [Date], aliases: false) || {}

  Array(metadata["motifs"]).each do |motif|
    errors << "#{relative}: unknown motif #{motif}" unless motifs.include?(motif)
  end

  Array(metadata["traditions"]).each do |tradition|
    errors << "#{relative}: unknown tradition #{tradition}" unless traditions.include?(tradition)
  end
end

if errors.empty?
  puts "taxonomy refs ok"
else
  warn errors.join("\n")
  exit 1
end

