#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/b24853665-fox-texts-jones.md
#
# Source: William Jones, "Fox Texts" (Publications of the American Ethnological
# Society vol. I, 1907). Layout: each tale is printed as a block of Fox-language
# text (Jones's phonetic orthography, with marginal line-numbers 5/10/15/20 set
# as their own lines and page numbers between blocks), immediately followed by a
# block of continuous English free translation. Fox and English blocks alternate
# page by page throughout the body. The Fox OCR is a soup of interior capitals,
# glued superscript digits/asterisks, and glottal apostrophes; it is dropped and
# the English free translation is kept. This script only SELECTS and DELETES
# lines mechanically -- no text is rewritten, paraphrased, or invented.
#
# Transforms:
#   1. Structural trim (guarded): keep the "# Fox Texts" title and everything
#      from the standalone "INTRODUCTION." heading onward; drop the front
#      title-pages / duplicated AES publications list / CONTENTS table, and drop
#      the "Wellcome Library ..." scanner cruft at the very back.
#   2. Delete page furniture: standalone marginal line-numbers / page-numbers and
#      their OCR variants ("5", "10", "13", "I 2").
#   3. Delete Fox-language lines by per-word signature (interior capital after a
#      lowercase letter, a glued glottal apostrophe whose suffix is not an
#      English contraction, a digit/asterisk glued to a letter, or a run of
#      Fox-only letters). A line is Fox when >=2 words are flagged and >=40% of
#      its words are flagged, or it is a 1-2 word line entirely flagged. English
#      prose that merely carries a native proper name stays below threshold.
#   4. Join residual end-of-line hyphenations and collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/b24853665-fox-texts-jones.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. structural trim -----------------------------------------------------
intro = lines.index { |l| l.strip == "INTRODUCTION." }
abort "INTRODUCTION. not found" unless intro
stats[:head_trim] = intro - 1
body = [lines[0], ""] + lines[intro..]

# tail: "Wellcome Library" bookplate cruft
from = (body.length * 0.9).to_i
tail = (from...body.length).find { |i| body[i].strip.match?(/\AWellcome\s+Library\z/) }
if tail
  stats[:tail_trim] = body.length - tail
  body = body[0...tail]
end

# --- Fox-signature detection ------------------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em].freeze

def fox_word?(raw)
  # Superscript reference marks (digit / asterisk) are glued directly to the
  # Fox word; test the RAW token before punctuation stripping would eat them
  # ("ahinatc*", "saneniwAg1", "hawigo**").
  return true if raw.match?(/[[:alpha:]][0-9*]|[0-9*][[:alpha:]]/)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:*]+\z/, "")
  return false if w.empty?
  # glottal "8" glued to letters
  return true if w.match?(/[[:alpha:]]8|8[[:alpha:]]/)
  # interior capital after a lowercase letter (saneniwAg, NegutwaiyAg, ahAneminam)
  return true if w.match?(/[[:lower:]][A-Z]/)
  # left/right single-quote glottal glued inside a word (a‘kwi, ka'i'ciwaniwisit)
  if w.match?(/[[:alpha:]][‘’'`][[:alpha:]]/)
    suffix = w.split(/[‘’'`]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

# Common English words used to tell an English translation line from a Fox one.
# Deliberately excludes "on"/"a"/"i": Jones renders the very common Fox
# connective as "On" and Fox has bare "a'"/"i" tokens, so they are not reliable
# English glue.
ENGLISH_STOPWORDS = %w[the an and of to in he she it they we you is are
                       was were said say that this his her him not for with all
                       then when there had have who].freeze

def fox_line?(line)
  words = line.split.reject { |t| t.gsub(/[^[:alpha:]]/, "").empty? }
  return false if words.empty?
  flags = words.count { |w| fox_word?(w) }
  return true if flags >= 2 && flags.to_f / words.size >= 0.34
  return true if words.size <= 2 && flags == words.size && flags.positive?
  # A multi-word line carrying at least one Fox signature and NOT a single
  # English function word is Fox: Jones's English translation lines always
  # contain function words, his Fox lines never do. A lone one-letter token
  # ("a", "i") is too ambiguous with Fox ("a'", "i") to count as English glue.
  stopwords = words.count do |w|
    ww = w.downcase.gsub(/[^a-z]/, "")
    ww.length >= 2 && ENGLISH_STOPWORDS.include?(ww)
  end
  return true if flags >= 1 && stopwords.zero? && words.size >= 2
  false
end

# standalone marginal line / page numbers, incl. OCR variants ("I 2", "3^3")
PAGE_JUNK = /\A[\dlLIioO°>()\[\].,;:*^ ]{1,6}\z/.freeze

# --- 2+3. drop furniture + Fox lines ----------------------------------------
kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  if s.match?(PAGE_JUNK)
    stats[:page_junk] += 1
    next true
  end
  if fox_line?(s)
    stats[:fox_lines] += 1
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

# --- 5. squeeze double spaces, collapse blank runs --------------------------
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
