#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/internet-archive/fourbooksconfuci00leggiala-four-books-confucian-legge.md
#
# Source: James Legge, "The Four Books" (Confucian Analects, Great Learning,
# Doctrine of the Mean, Works of Mencius), Chinese text with English translation
# and notes. The English translation and Legge's English notes are clean and
# continuous; the noise is the OCR of the printed Chinese source characters,
# which the scanner rendered as short gibberish lines (one or a few glyphs per
# line: "3E", "Jl", "ja.", "iTri") scattered between the English, plus title-page
# duplications at the head and a University-of-California library card at the
# tail. Legge's notes carry inline Chinese glued to English words; those lines
# retain real English words and are kept. Every transform is mechanical line
# selection/deletion/joining — no text is rewritten.
#
# Transforms:
#   1. Head trim (guarded): keep the "# ..." title, drop the repeated title
#      pages before the first "CONFUCIAN ANALECTS" section banner.
#   2. Tail trim (guarded): drop the library card from "University of California"
#      onward.
#   3. Delete Chinese-glyph OCR lines: any non-blank line that contains no
#      3+-letter Latin word (these are the one/few-glyph Chinese fragments and
#      stray page-furniture). English prose and notes always carry a 3+ letter
#      word and survive; a note line with inline Chinese also survives.
#   4. Neutralize stray HTML-like OCR "<"/">" -> "("/")".
#   5. Join line-end hyphenations; squeeze double word-spacing; collapse blanks.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/internet-archive/fourbooksconfuci00leggiala-four-books-confucian-legge.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. head trim -----------------------------------------------------------
head_idx = (40...lines.length).find { |i| lines[i].strip.match?(/\ACONFUCIAN\s+ANALECTS\z/) }
abort "head marker 'CONFUCIAN ANALECTS' not found" unless head_idx
stats[:head_trim] = head_idx - 1
body = [lines[0], ""] + lines[head_idx..]

# --- 2. tail trim (UC library card) -----------------------------------------
from = (body.length * 0.98).to_i
tail_idx = (from...body.length).find { |i| body[i].strip.match?(/\AUniversity\s+of\s+California\z/) }
if tail_idx
  stats[:tail_trim] = body.length - tail_idx
  body = body[0...tail_idx]
end

# --- 3. drop Chinese-glyph / no-word lines ----------------------------------
kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  unless s.match?(/[A-Za-z]{3,}/)
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
