#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/godsofegyptianso00budg-gods-of-the-egyptians-budge-vol1.md
#
# Source: E. A. Wallis Budge, "The Gods of the Egyptians", Vol. I (1904). The
# English narrative is clean and continuous; the pervasive noise is OCR of the
# printed hieroglyphs, which the scanner rendered as symbol-soup lines
# (backslashes, carets, "AAA/W\", "Vv\", glued glottal marks) scattered through
# the body, plus a garbled cover-scan at the head and a library DATE-DUE card at
# the tail. Interlinear hieroglyph transliteration+gloss couplets also occur;
# the glyph line of each couplet is dropped by the same signature, while the
# short English gloss fragment (real English words) is left in place — bounded,
# tolerable residue. Every transform is mechanical line selection/deletion/
# joining; no text is rewritten.
#
# Transforms:
#   1. Head trim (guarded): keep the "# ..." title, drop the cover-scan garble
#      and title pages before "PREFACE".
#   2. Tail trim (guarded): drop the library DATE-DUE card at the back.
#   3. Delete hieroglyph symbol-soup lines: any line containing a backslash, a
#      run of >=2 caret/tilde glyph marks, or that is dominated (>60%) by
#      non-letter characters (with length >= 2). English prose always carries a
#      3+ letter word and no backslash, so it survives.
#   4. Neutralize stray HTML-like OCR "<"/">" -> "("/")".
#   5. Join line-end hyphenations; squeeze double word-spacing; collapse blanks.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/godsofegyptianso00budg-gods-of-the-egyptians-budge-vol1.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. head trim -----------------------------------------------------------
head_idx = (1...lines.length).find { |i| lines[i].strip == "PREFACE" }
abort "head marker 'PREFACE' not found" unless head_idx
stats[:head_trim] = head_idx - 1
body = [lines[0], ""] + lines[head_idx..]

# --- 2. tail trim (DATE DUE card in the last 3%) ----------------------------
from = (body.length * 0.97).to_i
tail_idx = (from...body.length).find { |i| body[i].strip.match?(/\ADATE\s+DUE\z/i) }
if tail_idx
  stats[:tail_trim] = body.length - tail_idx
  body = body[0...tail_idx]
end

# --- 3. drop hieroglyph glyph-soup lines ------------------------------------
def glyph_soup?(s)
  return false if s.empty?
  return true if s.include?("\\")                       # backslash = glyph OCR
  return true if s.match?(/[\^~]{2,}/)                  # caret/tilde runs
  return true if s.match?(/[\^~]/) && !s.match?(/[A-Za-z]{3,}/)
  letters = s.count("A-Za-z")
  nonspace = s.gsub(/\s/, "").length
  return false if nonspace < 2
  # dominated by non-letter symbols and lacking any real word
  letters.to_f / nonspace < 0.40 && !s.match?(/[A-Za-z]{4,}/)
end

kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  if glyph_soup?(s)
    stats[:glyph_lines] += 1
    next true
  end
  false
end

# --- 4. neutralize <> --------------------------------------------------------
kept.map! { |l| l.tr("<>", "()") }

# --- 5. hyphen join, squeeze, collapse --------------------------------------
joined = []
i = 0
while i < kept.length
  line = kept[i]
  if line.rstrip.match?(/[a-z]-\z/)
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    if j < kept.length && kept[j].lstrip.match?(/\A[a-z]/)
      joined << line.rstrip.sub(/-\z/, "") + kept[j].lstrip
      stats[:dehyphenated] += 1
      kept.slice!(i + 1..j)
      i += 1
      next
    end
  end
  joined << line
  i += 1
end

final = []
blank_run = 0
joined.each do |line|
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
puts "#{File.basename(PATH)}: #{before} -> #{final.length} lines " \
     "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
