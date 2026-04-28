#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)

MARKDOWN_PATHS = [
  File.join(ROOT, "README.md"),
  *Dir.glob(File.join(ROOT, "{comparisons,docs,patterns,texts}", "**/*.md"))
].select { |path| File.file?(path) }.sort.freeze

RAW_TEXT_EXTENSIONS = %w[
  .asc .epub .htm .html .json .log .mht .mhtml .pdf .rtf .tei .text .txt
  .xhtml .xml .zip
].freeze

HTML_ENTITY_PATTERN = /&(?:amp|apos|copy|gt|ldquo|lsquo|mdash|nbsp|ndash|quot|rdquo|rsquo);|&#(?:\d+|x[0-9a-fA-F]+);/
HTML_TAG_PATTERN = %r{</?[A-Za-z][A-Za-z0-9:-]*(?:\s+[^<>]*)?/?>}
SCRIPT_STYLE_PATTERN = %r{</?(?:script|style)\b[^>]*>}i
GUTENBERG_PATTERNS = [
  /project gutenberg/i,
  /gutenberg (?:ebook|e-text)/i,
  /\*\*\*\s*start of (?:the )?(?:project gutenberg )?(?:ebook|e-text)/i,
  /\*\*\*\s*end of (?:the )?(?:project gutenberg )?(?:ebook|e-text)/i,
  /this eBook is for the use of anyone anywhere/i,
  /project gutenberg literary archive foundation/i
].freeze

ALLOWED_CONTROL_CHARS = [9, 10, 13].freeze

def relative_path(path)
  path.sub("#{ROOT}/", "")
end

def front_matter_line_range(lines)
  return nil unless lines.first&.match?(/\A---\s*\z/)

  closing_index = lines[1..]&.index { |line| line.match?(/\A---\s*\z/) }
  return nil unless closing_index

  1..(closing_index + 2)
end

def raw_download_path?(path)
  relative = relative_path(path)
  return false if File.directory?(path)
  return false if File.basename(path).start_with?(".")

  RAW_TEXT_EXTENSIONS.include?(File.extname(relative).downcase)
end

def without_inline_code(line)
  line.gsub(/`[^`\n]*`/, "")
end

errors = []

MARKDOWN_PATHS.each do |path|
  relative = relative_path(path)
  raw = File.binread(path)
  text = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "\uFFFD")
  lines = text.lines(chomp: false)
  front_matter_lines = front_matter_line_range(lines)
  blank_run_start = nil
  blank_run_count = 0
  in_fence = false

  errors << "#{relative}:#{[lines.length, 1].max}: missing final newline" unless text.end_with?("\n")

  lines.each_with_index do |line, index|
    line_number = index + 1
    in_front_matter = front_matter_lines&.cover?(line_number)

    if line.match?(/\A[ \t]*(```|~~~)/)
      in_fence = !in_fence unless in_front_matter
    end

    if line.match?(/[ \t]+(?:\r?\n|\z)/)
      errors << "#{relative}:#{line_number}: trailing whitespace"
    end

    if (match = line.match(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/))
      codepoint = match[0].ord
      unless ALLOWED_CONTROL_CHARS.include?(codepoint)
        errors << "#{relative}:#{line_number}: control character U+#{codepoint.to_s(16).upcase.rjust(4, "0")}"
      end
    end

    if line.strip.empty?
      blank_run_start ||= line_number
      blank_run_count += 1
      if blank_run_count == 3
        errors << "#{relative}:#{blank_run_start}: excessive blank lines"
      end
    else
      blank_run_start = nil
      blank_run_count = 0
    end

    next if in_front_matter || in_fence

    content = without_inline_code(line)

    if content.match?(SCRIPT_STYLE_PATTERN)
      errors << "#{relative}:#{line_number}: script/style HTML tag"
    elsif content.match?(HTML_TAG_PATTERN) && !content.match?(/\A\s*<!--.*-->\s*\z/)
      errors << "#{relative}:#{line_number}: raw HTML tag"
    end

    if content.match?(HTML_ENTITY_PATTERN)
      errors << "#{relative}:#{line_number}: undecoded HTML entity"
    end

    next unless relative.start_with?("texts/")

    GUTENBERG_PATTERNS.each do |pattern|
      next unless line.match?(pattern)

      errors << "#{relative}:#{line_number}: Project Gutenberg boilerplate"
      break
    end
  end
end

Dir.glob(File.join(ROOT, "texts", "**", "*")).sort.each do |path|
  next unless raw_download_path?(path)

  errors << "#{relative_path(path)}:1: raw download file under texts/"
end

if errors.empty?
  puts "clean markdown ok"
else
  warn errors.join("\n")
  exit 1
end
