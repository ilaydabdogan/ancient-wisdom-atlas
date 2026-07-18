#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for
#   imports/converted/project-gutenberg/thompson-1928-gilgamesh-epic-of-gilgamish-thompson.md
# after the generic scripts/clean_ocr_conversion.rb pass. Mechanical line
# deletion only — no text is rewritten.
#
#   1. Google Books reproduction boilerplate at head (exact-line matches).
#   2. Residual per-page running headers "THE EPIC OF GILGAMISH." that the
#      generic pass missed because OCR junk/page numbers made each unique.
#      The closing line "THE END OF THE EPIC OF GILGAMISH." is preserved.
#   3. Printer colophon + Google watermark after the end of the poem.
#   4. A curated exact-match list of standalone OCR symbol-salad lines
#      (each verified in context to carry no words of the translation).
#   5. Collapse 3+ blank lines to 2.

PATH = File.expand_path("../project-gutenberg/thompson-1928-gilgamesh-epic-of-gilgamish-thompson.md", __dir__)

HEAD_BOILERPLATE = [
  "This is a reproduction of a library book that was digitized",
  "by Google as part of an ongoing effort to preserve the",
  "information in books and make it universally accessible.",
  "Google books",
  "https://books.google.com"
].freeze

TAIL_BOILERPLATE = [
  "SHARP AND SONS, BATR", # printer colophon (OCR-mangled)
  "dee Google"            # Google watermark
].freeze

# Standalone OCR junk lines, each verified in context (blank-delimited,
# not a continuation of a hyphen/OCR-split verse line).
JUNK_EXACT = [
  "ve sda za",
  "CoA",
  "e o . ©. e. e. o  @ e. ©. ©. o.  @ e. OGF Ò% © ©  @",
  "» 99",
  "P>",
  "— z",
  "— LL",
  "— a oe —",
  "= na",
  "w",
  "+P"
].freeze

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

kept = lines.reject do |line|
  s = line.strip
  if HEAD_BOILERPLATE.include?(s)
    stats["head_boilerplate"] += 1
  elsif TAIL_BOILERPLATE.include?(s)
    stats["tail_boilerplate"] += 1
  elsif s.match?(/\A[^a-zA-Z]*T[HR]E EPIC OF GILGAMISH\b/) && !s.include?("END OF")
    stats["running_headers"] += 1
  elsif JUNK_EXACT.include?(s)
    stats["junk_lines"] += 1
  else
    next false
  end
  true
end

final = []
blank_run = 0
kept.each do |line|
  if line.strip.empty?
    blank_run += 1
    final << "" if blank_run <= 2
  else
    blank_run = 0
    final << line
  end
end

File.write(PATH, final.join("\n") + "\n")
puts "#{File.basename(PATH)}: #{before} -> #{final.length} lines (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
