#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/ethnologicalstu00rothgoog-ethnological-studies-queensland-roth.md
#
# Source: W. E. Roth, "Ethnological Studies among the North-West-Central
# Queensland Aborigines" (1897), Google Books scan. The narrative ethnography is
# clean, continuous English; the noise is (a) Google Books front boilerplate and
# a library bookplate, (b) stray single-character OCR garble in the plate/figure
# regions, and (c) a garbled plate-caption block at the tail. Interspersed native
# vocabulary and anthropometric measurement word-lists remain partly (they carry
# 3+ letter native words and are not separable from the surrounding narrative by
# a mechanical signature) — bounded, tolerable residue. Every transform is
# mechanical line selection/deletion/joining; no text is rewritten.
#
# Transforms:
#   1. Head trim (guarded): keep the "# ..." title, drop the Google boilerplate,
#      library bookplate, and duplicated title pages before "PREFACE.".
#   2. Delete stray-garble / no-word lines: any non-blank line that contains no
#      3+-letter Latin word (single-char plate garble, page-furniture, isolated
#      figure numbers). Narrative prose always carries a 3+ letter word.
#   3. Neutralize stray HTML-like OCR "<"/">" -> "("/")".
#   4. Join line-end hyphenations; squeeze double word-spacing; collapse blanks.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/ethnologicalstu00rothgoog-ethnological-studies-queensland-roth.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. head trim -----------------------------------------------------------
head_idx = (1...lines.length).find { |i| lines[i].strip == "PREFACE." }
abort "head marker 'PREFACE.' not found" unless head_idx
stats[:head_trim] = head_idx - 1
body = [lines[0], ""] + lines[head_idx..]

# --- 2. drop stray-garble / no-word lines -----------------------------------
kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  unless s.match?(/[A-Za-z]{3,}/)
    stats[:garble_lines] += 1
    next true
  end
  false
end

# --- 3. neutralize <> --------------------------------------------------------
kept.map! { |l| l.tr("<>", "()") }

# --- 4. hyphen join, squeeze, collapse --------------------------------------
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
