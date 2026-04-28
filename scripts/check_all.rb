#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)
ruby_scripts = Dir.glob(File.join(__dir__, "*.rb")).map { |path| path.sub("#{ROOT}/", "") }.sort

ruby_scripts.each do |script|
  puts "==> ruby -c #{script}"
  success = system("ruby", "-c", script)
  exit 1 unless success
end

checks = [
  "scripts/validate_metadata.rb",
  "scripts/check_taxonomy_refs.rb",
  "scripts/check_first_500_corpus.rb",
  "scripts/build_similarity_index.rb",
  "scripts/check_structured_files.rb",
  "scripts/check_clean_markdown.rb",
  "scripts/export_jsonl.rb",
  "scripts/build_pages_site.rb"
]

checks.each do |script|
  puts "==> ruby #{script}"
  success = system("ruby", script)
  exit 1 unless success
end

puts "all checks ok"
