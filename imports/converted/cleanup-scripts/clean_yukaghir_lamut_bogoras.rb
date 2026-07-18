#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/talesofyukaghirl0000bogo-tales-of-yukaghir-lamut-bogoras.md
#
# Source: Bogoras, "Tales of Yukaghir, Lamut, and Russianized Natives of
# Eastern Siberia" (Anthropological Papers AMNH vol. XX part I, 1918).
# The OCR body is continuous English (the Russian originals mentioned in the
# introduction were not captured by this scan's OCR), interrupted by journal
# running headers. This script only SELECTS and DELETES lines mechanically;
# no text is ever rewritten.
#
# Transforms:
#   1. Keep line 1 (# title), the INTRODUCTION (orig lines 56-93), and the
#      tales body (orig lines 399-7628). Drops: library/scan front matter,
#      CONTENTS list (page-number leaders), the partially garbled phonetic
#      alphabet key, and the trailing library "Date Due" card. Boundary
#      content is asserted before trimming so a re-run on changed input aborts.
#   2. Delete running-header lines: "Anthropological Papers American Museum
#      ... [Vol. XX,", "Bogoras, Tales of Eastern Siberia.", "1918.]".
#   3. Delete standalone OCR page-number junk lines ("7(3", "14S", "x").
#   4. Join words split across lines with the OCR not-sign hyphen "word¬".
#   5. Re-join paragraph splits created by removed page furniture: if a kept
#      line ends mid-clause (lowercase letter or comma/semicolon) and the next
#      non-blank kept line starts lowercase, drop the intervening blank lines.
#   6. Squeeze runs of internal spaces to single spaces; collapse 3+ blank
#      lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/talesofyukaghirl0000bogo-tales-of-yukaghir-lamut-bogoras.md")

lines = File.readlines(PATH, chomp: true)

# --- 1. structural trim (1-indexed originals) -------------------------------
guards = {
  1 => /\A# Tales of Yukaghir/,
  56 => /\AINTRODUCTION\./,
  93 => /Bogoras,\s+..?The\s+Chukchee/,
  399 => /\AI\.\s+TALES\s+OF\s+THE\s+TUNDRA\s+YUKAGHIR/,
  7628 => /The\s+Chukchee,.\s+97/
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
body = [lines[0], ""] + lines[55..92] + [""] + lines[398..7627]

# --- 2+3. delete running headers and page-number junk -----------------------
HEADER_PATTERNS = [
  /Anthropological\s+Papers\s+American\s+Museum/,
  /Bogoras,\s+Tales\s+of\s+Eastern\s+Siberia/,
  /\A\s*1918\.\]\s*\z/
].freeze
PAGE_JUNK = /\A[0-9()\[\]xliIoOSg]{1,5}\z/ # "7(3", "14S", "i4g", stray "x"

stats = Hash.new(0)
kept = body.reject do |line|
  s = line.strip
  if HEADER_PATTERNS.any? { |p| s.match?(p) }
    stats[:running_headers] += 1
  elsif !s.empty? && s.length <= 5 && s.match?(PAGE_JUNK) && (s.match?(/\d/) || s.length == 1)
    stats[:page_junk] += 1
  else
    false
  end
end

# --- 4. join "word¬" line-break hyphenation ---------------------------------
joined = []
i = 0
while i < kept.length
  line = kept[i]
  # A joined line can itself end in "¬" (chained page-break hyphenations),
  # so keep absorbing continuation lines until it no longer does.
  while line.rstrip.end_with?("¬")
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    break unless j < kept.length

    line = line.rstrip.sub(/¬\z/, "") + kept[j].lstrip
    stats[:dehyphenated] += 1
    i = j
  end
  joined << line
  i += 1
end

# --- 5. re-join paragraph splits left by removed page furniture -------------
merged = []
joined.each do |line|
  if line.strip.empty?
    merged << line
  else
    k = merged.length - 1
    k -= 1 while k >= 0 && merged[k].strip.empty?
    if k >= 0 && k < merged.length - 1 && merged[k].match?(/[a-z,;]\z/) && line.lstrip.match?(/\A[a-z]/)
      merged.slice!(k + 1..)
      stats[:paragraphs_rejoined] += 1
    end
    merged << line
  end
end

# --- 6. squeeze spaces, collapse blanks -------------------------------------
final = []
blank_run = 0
merged.each do |line|
  out = line.rstrip.gsub(/(?<=\S) {2,}(?=\S)/, " ").sub(/\A\s+/, "")
  if out.empty?
    blank_run += 1
    final << "" if blank_run <= 2
  else
    blank_run = 0
    final << out
  end
end
final.pop while final.last == ""

File.write(PATH, final.join("\n") + "\n")
puts "#{File.basename(PATH)}: #{lines.length} -> #{final.length} lines " \
     "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
