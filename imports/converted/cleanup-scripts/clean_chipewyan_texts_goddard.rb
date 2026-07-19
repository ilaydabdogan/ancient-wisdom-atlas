#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/textsanalysisofc0000godd-chipewyan-texts-goddard.md
#
# Source: Pliny Earle Goddard, "Chipewyan Texts" (AMNH Anthropological Papers
# X, Part I, 1912), bound together with the companion "Analysis of Cold Lake
# Dialect, Chipewyan" (Part II). Layout of Part I: an English INTRODUCTION in
# continuous prose, then the "TEXTS" -- each numbered story printed line-by-line
# as a native Chipewyan line (Goddard's syllable-spaced phonetic transcription)
# immediately followed by a continuous English free-translation line beneath it.
# Unlike the interlinear word-gloss volumes, Goddard's Chipewyan translation
# lines are genuine running English ("In the beginning young geese they took.
# Canoe they tied them to."), so here we KEEP the English lines and DROP the
# native lines. Part II (phonetics / verbal-stem analysis / stem glossaries) is
# not narrative translation and is cut off wholesale. Every transform is
# mechanical line selection/deletion/joining -- no text is rewritten.
#
# Transforms:
#   1. Structural trim (guarded): keep the "# Chipewyan Texts" title and
#      everything from the first standalone "INTRODUCTION." heading (Part I intro)
#      onward; drop the front title-pages / CONTENTS. Cut the tail from the
#      "ANTHROPOLOGICAL PAPERS ... ANALYSIS OF COLD LAKE DIALECT" banner (Part II)
#      to the end.
#   2. Delete page furniture: standalone marginal line-numbers / page-numbers and
#      the running "Anthropological Papers American Museum ..." header lines.
#   3. Delete native Chipewyan lines: a line is native when it carries a native
#      signature (interior capital after a lowercase letter, a glued digit/"0",
#      "$"/"?" glued to letters, or an internal apostrophe whose suffix is not an
#      English contraction) and contains no (>=2 letter) English function word;
#      or when it is a run of >=6 short syllable-tokens (mean alphabetic length
#      <= 2.8) with no English function word. Goddard's English translation lines
#      always carry function words and survive.
#   4. Join residual end-of-line hyphenations and collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/textsanalysisofc0000godd-chipewyan-texts-goddard.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. structural trim -----------------------------------------------------
intro = (1...lines.length).find { |i| lines[i].strip == "INTRODUCTION." }
abort "INTRODUCTION. not found" unless intro
stats[:head_trim] = intro - 1
body = [lines[0], ""] + lines[intro..]

# tail: Part II. Cut at the "ANTHROPOLOGICAL PAPERS" banner that precedes the
# "ANALYSIS OF COLD LAKE DIALECT, CHIPEWYAN." title.
adx = body.index { |l| l.strip.match?(/\AANALYSIS\s+OF\s+COLD\s+LAKE\s+DIALECT/) }
abort "ANALYSIS OF COLD LAKE DIALECT not found" unless adx
cut = adx
(adx - 1).downto(adx - 15) do |i|
  break if i < 0
  if body[i].strip.match?(/\AANTHROPOLOGICAL\s+PAPERS\z/)
    cut = i
    break
  end
end
stats[:tail_trim] = body.length - cut
body = body[0...cut]

# --- native-signature detection ---------------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em].freeze

def native_word?(raw)
  return true if raw.match?(/[[:alpha:]][0-9]|[0-9][[:alpha:]]/) # glued digit / "0"
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.?!;:*]+\z/, "")
  return false if w.empty?
  return true if w.match?(%r{[[:alpha:]][$?£#\\]|[$?£#\\][[:alpha:]]}) # gv$ ya? #e
  return true if w.match?(/[[:lower:]][A-Z]/)                    # naL, teL, ts'I
  if w.match?(/[[:alpha:]][‘’'`][[:alpha:]]/)
    suffix = w.split(/[‘’'`]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

def alpha_tokens(line)
  line.split.map { |t| t.gsub(/[^[:alpha:]]/, "") }.reject(&:empty?)
end

# A genuine English content word: >=5 letters, has a vowel, no native signature.
# Goddard's syllable-spaced Chipewyan almost never produces such a token (the
# transcription is broken into 2-4 letter syllables); his English translation
# lines almost always contain at least one. This sidesteps the fact that bare
# Chipewyan syllables ("he", "we", "to", "at", "be", "ne") collide with English
# function words and so cannot be used to tell the two apart.
def english_content?(raw)
  w = raw.gsub(/[^[:alpha:]]/, "")
  w.length >= 5 && w.match?(/[aeiouyAEIOUY]/) && !native_word?(raw)
end

def native_line?(line)
  words = line.split.reject { |t| t.gsub(/[^[:alpha:]]/, "").empty? }
  return false if words.empty?
  # Any real English content word -> this is a translation line, keep it.
  return false if words.any? { |w| english_content?(w) }
  # No English content: native if it carries a native signature, or if it is a
  # run of >=5 short syllable-tokens (mean alphabetic length <= 2.7).
  return true if words.any? { |w| native_word?(w) }
  toks = alpha_tokens(line)
  return true if toks.size >= 5 && toks.sum(&:length).to_f / toks.size <= 2.7
  false
end

PAGE_JUNK = /\A[\dlLIioO°>()\[\].,;:*^ ]{1,6}\z/.freeze
RUNNING_HDR = /\AAnthropological\s+Papers\s+American\s+Museum|American\s+Museum\s+of\s+Natural\s+History\.?\s*\[/i.freeze

# --- 2+3. drop furniture + native lines -------------------------------------
kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  if s.match?(PAGE_JUNK) || s.match?(RUNNING_HDR)
    stats[:page_junk] += 1
    next true
  end
  if native_line?(s)
    stats[:native_lines] += 1
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
