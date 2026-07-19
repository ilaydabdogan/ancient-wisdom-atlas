#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/wishramtexts00sapirich-wishram-texts-sapir.md
#
# Source: Edward Sapir, "Wishram Texts" (Publications of the American
# Ethnological Society vol. II, 1909), with an Appendix of supplementary Upper
# Chinookan texts and a section of Wasco Tales and Myths collected by Jeremiah
# Curtin. Layout: through the "Texts" body, each numbered myth is printed as a
# block of Wishram text (Sapir's phonetic orthography, with inline marginal
# line-numbers 5/10/15/20/25) followed by a block of continuous English free
# translation; a native and an English rendering of each title alternate too.
# The appended Wasco/Curtin tales are English-only. The Wishram OCR is a soup of
# glottal apostrophes and glued "!"/"8"/"^"/"£"/"/" marks and interior capitals;
# it is dropped and the English block-translations + English-only appendix are
# kept. This script only SELECTS and DELETES lines mechanically.
#
# Transforms:
#   1. Structural trim (guarded): keep the "# Wishram Texts" title and everything
#      from the standalone "INTRODUCTION." heading onward; drop the front
#      title-pages and CONTENTS table, and drop the tail "THE AMERICAN
#      ETHNOLOGICAL SOCIETY." officers/members/publications catalog and the
#      library date-stamp cruft after it.
#   2. Delete page furniture: standalone marginal line-numbers / page-numbers.
#   3. Delete Wishram-language lines by per-word signature (an internal glottal
#      "!"/"8"/"^"/"£"/"/" glued to letters, an interior capital after a
#      lowercase letter, a glued digit/asterisk, or an internal apostrophe whose
#      suffix is not an English contraction). A line is Wishram when >=2 words
#      are flagged and >=34% are flagged, when it is a 1-2 word line entirely
#      flagged, or when it carries a signature and not a single (>=2 letter)
#      English function word. English translation lines keep their function words.
#   4. Join residual end-of-line hyphenations and collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/wishramtexts00sapirich-wishram-texts-sapir.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. structural trim -----------------------------------------------------
intro = (1...lines.length).find { |i| lines[i].strip == "INTRODUCTION." }
abort "INTRODUCTION. not found" unless intro
stats[:head_trim] = intro - 1
body = [lines[0], ""] + lines[intro..]

# tail: the AES officers/members/publications catalog. Cut at the "THE AMERICAN
# ETHNOLOGICAL SOCIETY." banner that immediately precedes "OFFICERS FOR 1908."
from = (body.length * 0.9).to_i
off = (from...body.length).find { |i| body[i].strip.match?(/\AOFFICERS\s+FOR\s+1908/) }
abort "tail marker OFFICERS FOR 1908 not found" unless off
cut = off
(off - 1).downto(off - 6) do |i|
  break if i < 0
  if body[i].strip.match?(/\ATHE\s+AMERICAN\s+ETHNOLOGICAL\s+SOCIETY/)
    cut = i
    break
  end
end
stats[:tail_trim] = body.length - cut
body = body[0...cut]

# --- Wishram-signature detection --------------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em].freeze

def wishram_word?(raw)
  # glued digit / asterisk superscript marks, tested on the raw token
  return true if raw.match?(/[[:alpha:]][0-9*]|[0-9*][[:alpha:]]/)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.?;:*]+\z/, "")
  return false if w.empty?
  # glottalized-stop / accent marks OCR'd as these glued to letters:
  #   tk!a'munak, ik!a'munak, iLa8, ya/xiba, taya^iikm, ca'xalix£
  return true if w.match?(%r{[[:alpha:]][!£^8/]|[!£^8/][[:alpha:]]})
  return true if w.match?(/[[:lower:]][A-Z]/)          # interior capital
  if w.match?(/[[:alpha:]][‘’'`][[:alpha:]]/)
    suffix = w.split(/[‘’'`]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

# English function words used to tell an English translation line from a
# Wishram one. One-letter tokens omitted (too ambiguous).
ENGLISH_STOPWORDS = %w[the an and of to in on he she it they we you is are was
                       were said say that this his her him not for with all then
                       when there had have who out one your my me but so as at
                       up down into them their].freeze

def wishram_line?(line)
  words = line.split.reject { |t| t.gsub(/[^[:alpha:]]/, "").empty? }
  return false if words.empty?
  flags = words.count { |w| wishram_word?(w) }
  return true if flags >= 2 && flags.to_f / words.size >= 0.34
  return true if words.size <= 2 && flags == words.size && flags.positive?
  stopwords = words.count do |w|
    ww = w.downcase.gsub(/[^a-z]/, "")
    ww.length >= 2 && ENGLISH_STOPWORDS.include?(ww)
  end
  return true if flags >= 1 && stopwords.zero? && words.size >= 2
  false
end

# standalone marginal line / page numbers (incl. OCR variants) and the printer's
# signature line ("I — PUBL. AMER. ETHN. SOC. VOL. II.").
PAGE_JUNK = /\A[\dlLIioO°>()\[\].,;:*^ ]{1,6}\z/.freeze
PRINTER_SIG = /AMER\.\s+ETH[NX]\.\s+SOC/.freeze

# --- 2+3. drop furniture + Wishram lines ------------------------------------
kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  if s.match?(PAGE_JUNK) || s.match?(PRINTER_SIG)
    stats[:page_junk] += 1
    next true
  end
  if wishram_line?(s)
    stats[:wishram_lines] += 1
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
