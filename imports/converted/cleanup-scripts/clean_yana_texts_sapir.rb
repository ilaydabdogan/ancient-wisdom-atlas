#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic extraction for:
#   imports/converted/project-gutenberg/yanatexts00sapirich-yana-texts-sapir.md
#
# Source: Edward Sapir, "Yana Texts" (University of California Publications in
# American Archaeology and Ethnology vol. 9, no. 1, 1910), together with Yana
# Myths collected by Roland B. Dixon. Layout is mixed:
#   * The main Sapir myths (I-XXIV) are printed as INTERLINEAR WORD-GLOSS: a
#     Yana line (apostrophe/asterisk/caret-laden phonetic transcription) followed
#     by a word-by-word English gloss line whose columns are separated by "|".
#     A word-gloss is NOT continuous prose and is dropped.
#   * A handful of myths additionally carry a CONTINUOUS English free-translation
#     ("The Rolling Skull", nos. IX and XXIII), which is continuous prose.
#   * The Dixon "Supplementary Yana Myths" (collected in English) at the tail are
#     entirely CONTINUOUS English prose.
#   * INTRODUCTORY REMARKS and the numbered footnotes are continuous English.
# So the promotable continuous English is a MINORITY of the volume (intro +
# footnotes + the few free-translations + the Dixon section); the bulk is
# word-gloss. This script deterministically drops the Yana transcription lines
# and the "|" word-gloss lines and the front/back UC publication catalogs,
# keeping whatever continuous English remains. It only SELECTS/DELETES lines --
# no text is rewritten. VERDICT: partial (see report); run and inspect output.
#
# Transforms:
#   1. Structural trim (guarded): keep the "# Yana Texts" title and everything
#      from "INTRODUCTORY REMARKS." onward; drop the front UC publications
#      catalog + CONTENTS, and drop the tail "UNIVERSITY OF CALIFORNIA
#      PUBLICATIONS -(CONTINUED)" catalog.
#   2. Delete word-gloss lines (any line containing a "|" column separator).
#   3. Delete Yana transcription lines by signature, guarded so that a continuous
#      English line carrying one or two Yana proper names is never dropped.
#   4. Delete page furniture (marginal numbers, UC running heads/feet).
#   5. Join residual end-of-line hyphenations and collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/yanatexts00sapirich-yana-texts-sapir.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. structural trim -----------------------------------------------------
intro = (1...lines.length).find { |i| lines[i].strip.match?(/\AINTRODUCTORY\s+REMARKS/) }
abort "INTRODUCTORY REMARKS not found" unless intro
stats[:head_trim] = intro - 1
body = [lines[0], ""] + lines[intro..]

from = (body.length * 0.9).to_i
tail = (from...body.length).find { |i| body[i].strip.match?(/PUBLICATIONS\s*-?\s*\(CONTINUED\)/) }
abort "tail catalog marker not found" unless tail
stats[:tail_trim] = body.length - tail
body = body[0...tail]

# --- Yana-signature detection -----------------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em].freeze

def yana_word?(raw)
  return true if raw.match?(/[[:alpha:]][0-9]|[0-9][[:alpha:]]/)   # glued digit
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.?;:]+\z/, "")
  return false if w.empty?
  return true if w.match?(/[[:alpha:]][*^«»!£][[:alpha:]]?|[*^«»!£][[:alpha:]]/) # t'm*t' k!a'ina t'u«et'
  return true if w.match?(/[[:lower:]][A-Z]/)
  if w.match?(/[[:alpha:]][‘’'`][[:alpha:]]/)
    suffix = w.split(/[‘’'`]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

# A genuine English content word: >=5 letters, a vowel, no Yana signature.
def english_content?(raw)
  w = raw.gsub(/[^[:alpha:]]/, "")
  w.length >= 5 && w.match?(/[aeiouyAEIOUY]/) && !yana_word?(raw)
end

def yana_line?(line)
  words = line.split.reject { |t| t.gsub(/[^[:alpha:]]/, "").empty? }
  return false if words.empty?
  flags = words.count { |w| yana_word?(w) }
  return false if flags.zero?                         # clean English -> keep
  content = words.count { |w| english_content?(w) }
  # signatured line with no real English content word -> Yana transcription
  return true if content.zero?
  # heavily signatured line (even if OCR left an English-looking token) -> Yana
  return true if flags >= 2 && flags.to_f / words.size >= 0.5
  false
end

PAGE_JUNK = /\A[\dlLIioO°>()\[\].,;:*^ ]{1,6}\z/.freeze
# UC running head ("224  University of California Publications ... [Vol. 9") and
# running foot ("1910]  Sapir:  Yana Texts.  235").
RUNNING = /University\s+of\s+California\s+Publications|Sapir:\s+[TY]ana\s+Texts/i.freeze

# --- 2+3+4. drop gloss, Yana lines, furniture -------------------------------
kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  if s.include?("|")
    stats[:gloss_lines] += 1
    next true
  end
  if s.match?(PAGE_JUNK) || s.match?(RUNNING)
    stats[:furniture] += 1
    next true
  end
  if yana_line?(s)
    stats[:yana_lines] += 1
    next true
  end
  false
end

# --- 5. join residual end-of-line hyphenations ------------------------------
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

# --- 6. squeeze double spaces, neutralize stray <>, collapse blank runs ------
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
