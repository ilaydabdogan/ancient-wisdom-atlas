#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

ROOT = File.expand_path("..", __dir__)
RAW_ROOT = File.join(ROOT, "imports", "raw")
CONVERTED_ROOT = File.join(ROOT, "imports", "converted")

def usage
  "usage: ruby scripts/convert_plaintext_to_markdown.rb imports/raw/source.txt imports/converted/source.md"
end

def relative_path(path)
  path.sub("#{ROOT}/", "")
end

def inside_dir?(path, dir)
  expanded = File.expand_path(path)
  root = File.expand_path(dir)

  expanded == root || expanded.start_with?("#{root}/")
end

def yaml_scalar(value)
  value.to_s.inspect
end

def normalize_plaintext(raw)
  text = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "\uFFFD")
  text = text.gsub(/\r\n?/, "\n")
  text = text.lines.map { |line| line.gsub(/[ \t]+$/, "") }.join
  text = text.gsub(/\n{4,}/, "\n\n\n")
  text = text.sub(/\A\n+/, "").sub(/\n+\z/, "")
  text.empty? ? "" : "#{text}\n"
end

input_arg, output_arg = ARGV

unless input_arg && output_arg && ARGV.length == 2
  warn usage
  exit 64
end

input_path = File.expand_path(input_arg, ROOT)
output_path = File.expand_path(output_arg, ROOT)

unless inside_dir?(input_path, RAW_ROOT)
  warn "input must be under imports/raw: #{relative_path(input_path)}"
  exit 64
end

unless inside_dir?(output_path, CONVERTED_ROOT)
  warn "output must be under imports/converted: #{relative_path(output_path)}"
  exit 64
end

unless File.file?(input_path)
  warn "input file not found: #{relative_path(input_path)}"
  exit 66
end

unless File.extname(output_path).downcase == ".md"
  warn "output path should end in .md: #{relative_path(output_path)}"
  exit 64
end

source_text = normalize_plaintext(File.binread(input_path))
source_relative = relative_path(input_path)
output_relative = relative_path(output_path)
title_stub = File.basename(output_path, ".md").tr("_-", " ").split.map(&:capitalize).join(" ")

markdown = <<~MARKDOWN
  ---
  id: TODO
  title: #{yaml_scalar(title_stub.empty? ? "TODO" : title_stub)}
  text_status: draft
  source_language: TODO
  text_language: TODO
  translator: TODO
  edition: TODO
  publication_year: TODO
  source_url: TODO
  rights:
    status: TODO
    jurisdiction: TODO
    license_url: TODO
    training_use: TODO
    full_text: TODO
  transcription:
    mode: normalized
    complete: TODO
    corrections: []
    omissions: []
  conversion:
    source_path: #{yaml_scalar(source_relative)}
    output_path: #{yaml_scalar(output_relative)}
    tool: scripts/convert_plaintext_to_markdown.rb
    review_required: true
    notes:
      - "TODO: Human review required before this draft can move into texts/."
      - "TODO: Verify rights, edition, completeness, structure, and transcription accuracy."
  ---

  <!-- TODO: Human review required. This is an intermediate conversion draft, not a canonical corpus text. -->
  <!-- TODO: Verify headings, line breaks, poetry/prose structure, omissions, rights, and source metadata. -->

  # TODO: #{title_stub.empty? ? "Title" : title_stub}

MARKDOWN

markdown = "#{markdown}#{source_text}"
markdown = "#{markdown.chomp}\n"

FileUtils.mkdir_p(File.dirname(output_path))
File.write(output_path, markdown)

puts "converted #{source_relative} -> #{output_relative}"
