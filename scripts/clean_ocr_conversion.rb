#!/usr/bin/env ruby
# frozen_string_literal: true

# Deterministic OCR-noise cleanup for converted archive.org texts, applied
# to imports/converted/ files BEFORE canonical promotion. Only mechanical,
# reviewable transforms — no model ever rewrites canonical text:
#
#   1. boilerplate  — scanner artifacts ("Hosted by Google", "Digitized by").
#   2. page numbers — standalone integer / bracketed-integer lines.
#   3. running headers — short lines whose digit-and-punctuation-stripped
#      normalized form repeats >= --header-threshold times (per-page titles
#      like "TALES AND TRADITIONS. 348"). Conservative: normalized form must
#      be <= 60 chars and either contain a digit or be fully uppercase, so
#      poetic refrains in mixed case survive.
#   4. dehyphenation — join "word-\ncontinuation" when the continuation
#      starts lowercase.
#   5. blank-line collapse — 3+ consecutive blank lines to 2.
#
# Optional --trim-before/--trim-after cut front/back matter by line number
# (1-indexed, inclusive body range) before the passes run.

require_relative "batch_common"

options = {
  files: [],
  header_threshold: 15,
  trim_before: nil,
  trim_after: nil,
  dry_run: false
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/clean_ocr_conversion.rb --file PATH [options]"
  parser.on("--file PATH", "Converted markdown file; may be repeated") { |value| options[:files] << value }
  parser.on("--header-threshold N", Integer, "Repeats before a normalized line counts as a running header (default 15)") { |value| options[:header_threshold] = value }
  parser.on("--trim-before N", Integer, "Drop lines before this 1-indexed line (front matter)") { |value| options[:trim_before] = value }
  parser.on("--trim-after N", Integer, "Drop lines after this 1-indexed line (back matter)") { |value| options[:trim_after] = value }
  parser.on("--dry-run", "Report what would change without writing") { options[:dry_run] = true }
end.parse!

AtlasBatch.die("--file is required", 64) if options[:files].empty?

BOILERPLATE = [
  /\AHosted by Google\z/i,
  /\ADigiti[sz]ed by (the )?(Google|Internet Archive|Microsoft)/i,
  /\Ahttps?:\/\/(www\.)?archive\.org/i
].freeze

def normalized_header(line)
  line.gsub(/[\d\[\]().:;,'"*—–-]+/, " ").squeeze(" ").strip.downcase
end

options[:files].each do |path|
  full = AtlasBatch.project_path(path)
  AtlasBatch.die("missing #{path}", 66) unless File.file?(full)

  lines = File.readlines(full, chomp: true)
  stats = Hash.new(0)
  original_count = lines.length

  if options[:trim_before] || options[:trim_after]
    from = (options[:trim_before] || 1) - 1
    to = (options[:trim_after] || lines.length) - 1
    front = lines.first.to_s.start_with?("---") ? [] : nil
    # Preserve YAML front matter if present: find its end before trimming.
    if lines.first.to_s.match?(/\A---\s*\z/)
      close = (1...lines.length).find { |i| lines[i].match?(/\A---\s*\z/) }
      if close
        front = lines[0..close]
        from = [from, close + 1].max
      end
    end
    body = lines[from..to] || []
    stats["trimmed"] = original_count - body.length - (front ? front.length : 0)
    lines = (front || []) + body
  end

  header_counts = Hash.new(0)
  lines.each do |line|
    stripped = line.strip
    next if stripped.empty? || stripped.length > 60

    form = normalized_header(stripped)
    next if form.empty? || form.length < 4

    header_counts[form] += 1 if stripped.match?(/\d/) || stripped == stripped.upcase
  end
  running_headers = header_counts.select { |_, count| count >= options[:header_threshold] }.keys.to_set

  kept = []
  lines.each do |line|
    stripped = line.strip
    if BOILERPLATE.any? { |pattern| stripped.match?(pattern) }
      stats["boilerplate"] += 1
      next
    end
    if stripped.match?(/\A\[?\d{1,4}\]?\z/)
      stats["page_numbers"] += 1
      next
    end
    if !stripped.empty? && stripped.length <= 60
      form = normalized_header(stripped)
      if running_headers.include?(form) && (stripped.match?(/\d/) || stripped == stripped.upcase)
        stats["running_headers"] += 1
        next
      end
    end
    kept << line
  end

  joined = []
  index = 0
  while index < kept.length
    line = kept[index]
    if line.match?(/[a-z]-\z/) && index + 1 < kept.length && kept[index + 1].lstrip.match?(/\A[a-z]/)
      next_line = kept[index + 1].lstrip
      joined << line.sub(/-\z/, "") + next_line
      stats["dehyphenated"] += 1
      index += 2
    else
      joined << line
      index += 1
    end
  end

  final = []
  blank_run = 0
  joined.each do |line|
    if line.strip.empty?
      blank_run += 1
      next if blank_run > 2

      final << ""
    else
      blank_run = 0
      final << line
    end
  end

  summary = stats.map { |key, value| "#{key}=#{value}" }.join(" ")
  if options[:dry_run]
    puts "DRY #{path}: #{original_count} -> #{final.length} lines (#{summary})"
  else
    File.write(full, final.join("\n") + "\n")
    puts "cleaned #{path}: #{original_count} -> #{final.length} lines (#{summary})"
  end
end
