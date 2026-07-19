#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/rosettaproject_ojc_book-1-ojibwa-texts-jones.md
#
# Source: William Jones, "Ojibwa Texts" (Publications of the American
# Ethnological Society vol. VII, 1917). Layout: each tale is printed as a block
# of Ojibwa text (Jones's phonetic orthography, with marginal line-numbers
# 5/10/15/20/25 set as their own lines, bracketed page markers, and footnotes)
# facing a block of continuous English free translation on every page. Ojibwa
# and English blocks alternate throughout the body. The Ojibwa OCR is a soup of
# glued glottal apostrophes, superscript carets/digits, and interior capitals;
# it is dropped and the English free translation is kept. This script only
# SELECTS and DELETES lines mechanically -- no text is rewritten or invented.
#
# Transforms:
#   1. Structural trim (guarded): keep the "# Ojibwa Texts" title and everything
#      from the standalone "PREFACE." heading onward; drop the front title-pages,
#      the duplicated AES publications list, and the CONTENTS table.
#   2. Delete page furniture: standalone marginal line-numbers / page-numbers and
#      bracketed page markers ("5", "lo", "[3]").
#   3. Delete Ojibwa-language lines by per-word signature (an internal apostrophe
#      whose suffix is not an English contraction, a glued superscript caret/
#      digit/asterisk, an interior capital after a lowercase letter, or a glued
#      glottal "8"). A line is Ojibwa when >=2 words are flagged and >=34% of its
#      words are flagged, when it is a 1-2 word line entirely flagged, or when it
#      carries a signature and not a single (>=2 letter) English function word.
#   4. Join residual end-of-line hyphenations and collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/rosettaproject_ojc_book-1-ojibwa-texts-jones.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. structural trim -----------------------------------------------------
pref = lines.index { |l| l.strip == "PREFACE." }
abort "PREFACE. not found" unless pref
stats[:head_trim] = pref - 1
body = [lines[0], ""] + lines[pref..]

# --- Ojibwa-signature detection ---------------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em].freeze

def ojibwa_word?(raw)
  # superscript reference marks glued to the word: caret / digit / asterisk
  return true if raw.match?(/[[:alpha:]][\^0-9*]|[\^0-9*][[:alpha:]]/)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:*^]+\z/, "")
  return false if w.empty?
  return true if w.match?(/[[:alpha:]]8|8[[:alpha:]]/)         # glued glottal 8
  return true if w.match?(/[[:lower:]][A-Z]/)                  # interior capital
  # internal apostrophe glued between letters whose suffix is not a contraction
  # (ka'i'ciwaniwisit, saga'a'mugubanan, a'pidci)
  if w.match?(/[[:alpha:]][‘’'`][[:alpha:]]/)
    suffix = w.split(/[‘’'`]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

# English function words used to tell an English translation line from an
# Ojibwa one. One-letter tokens are omitted (too ambiguous with Ojibwa).
ENGLISH_STOPWORDS = %w[the an and of to in he she it they we you is are was
                       were said say that this his her him not for with all then
                       when there had have who out one your my me].freeze

def ojibwa_line?(line)
  words = line.split.reject { |t| t.gsub(/[^[:alpha:]]/, "").empty? }
  return false if words.empty?
  flags = words.count { |w| ojibwa_word?(w) }
  return true if flags >= 2 && flags.to_f / words.size >= 0.34
  return true if words.size <= 2 && flags == words.size && flags.positive?
  stopwords = words.count do |w|
    ww = w.downcase.gsub(/[^a-z]/, "")
    ww.length >= 2 && ENGLISH_STOPWORDS.include?(ww)
  end
  return true if flags >= 1 && stopwords.zero? && words.size >= 2
  false
end

# standalone marginal line / page numbers, incl. OCR variants ("lo", "[3]")
PAGE_JUNK = /\A[\dlLIioO°>()\[\].,;:*^ ]{1,6}\z/.freeze

# --- 2+3. drop furniture + Ojibwa lines -------------------------------------
kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  if s.match?(PAGE_JUNK)
    stats[:page_junk] += 1
    next true
  end
  if ojibwa_line?(s)
    stats[:ojibwa_lines] += 1
    next true
  end
  false
end

# --- 4. join residual end-of-line hyphenations ------------------------------
joined = []
i = 0
while i < kept.length
  line = kept[i]
  if line.rstrip.match?(/[A-Za-z]-\z/)
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    if j < kept.length && kept[j].lstrip.match?(/\A[a-z]/)
      line = line.rstrip.sub(/-\z/, "") + kept[j].lstrip
      stats[:hyphen_joined] += 1
      kept.slice!(i + 1..j)
      joined << line
      i += 1
      next
    end
  end
  joined << line
  i += 1
end

# --- 5. squeeze double spaces, neutralize stray <>, collapse blank runs ------
final = []
blank_run = 0
joined.each do |line|
  out = line.rstrip.gsub(/(?<=\S) {2,}(?=\S)/, " ").sub(/\A\s+/, "").tr("<>", "()")
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
puts "#{File.basename(PATH)}: #{before} -> #{final.length} " \
     "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
