#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/folktalesofangol00chat-folk-tales-of-angola-chatelain.md
#
# Source: Chatelain, "Folk-Tales of Angola" (Memoirs of the American Folk-Lore
# Society vol. I, 1894). Parallel edition: each tale is printed as a Ki-mbundu
# original line immediately followed by its literal English translation line
# (blank-line separated), so the OCR serialised the two columns as strictly
# ALTERNATING single-line paragraphs -- one Ki-mbundu line, one English gloss
# line -- throughout the tale sections. The English Preface, Introduction and
# Notes are ordinary multi-line English prose. The Ki-mbundu lines are dropped
# by a conservative per-line signature (>= 3 words, none an English function
# word, majority vowel-final -- Ki-mbundu words are almost invariably
# vowel-final and never carry English function words); the literal English
# translation is kept, INCLUDING English gloss lines that carry embedded native
# names/plant terms (those lines still contain English function words and so
# survive the signature). Mechanical line selection/deletion/joining only.
#
# Transforms:
#   1. Guarded structural trim: keep "# ..." title; body from "PREFACE." to just
#      before the alphabetical "INDEX" (its page references are meaningless once
#      the Ki-mbundu column is removed). Drops the Princeton library front cruft
#      and the back-matter index.
#   2. Delete page furniture: running heads/footers ("Introduction .",
#      "Notes .", "FOLK-TALES OF ANGOLA", "Preface .") and standalone page nums.
#   3. Delete Ki-mbundu-signature lines.
#   4. Join line-end hyphenations; re-join paragraph splits left by removed
#      furniture and Ki-mbundu lines; squeeze double spacing; collapse blanks.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/folktalesofangol00chat-folk-tales-of-angola-chatelain.md")

lines = File.readlines(PATH, chomp: true)
stats = Hash.new(0)

# --- 1. structural trim -------------------------------------------------------
start = lines.index { |l| l.strip =~ /\APREFACE\.\z/ }
abort "PREFACE. heading not found" unless start
# Cut at the APPENDIX (garbled music-notation OCR) so the body ends on the
# English bibliography; this also removes the back-matter alphabetical index.
tail = lines.index { |l| l.strip =~ /\AAPPENDIX\z/ }
abort "APPENDIX heading not found" unless tail
abort "APPENDIX found too early (#{tail})" unless tail > start + 1000
stats[:head_trim] = start
stats[:tail_trim] = lines.length - tail
body = [lines[0], ""] + lines[start...tail]

# --- 2. page furniture --------------------------------------------------------
# Repeated running heads/footers the OCR emitted as their own single lines.
RUNNING_HEAD = /\A(FOLK\s*-?\s*TALES\s+OF\s+ANGOLA|Introduction|Notes|Preface|Appendix|Contents)\s*[.\-—]*\s*[0-9ivxlcIVXLC]*\.?\z/i.freeze
PAGE_NUM = /\A[\dOoIlSregpavii.,()\[\]\s-]{1,6}\z/.freeze

# --- 3. Ki-mbundu-signature detection ----------------------------------------
# Common English function words. None is vowel-final-ambiguous with Ki-mbundu
# short words (ku, mu, dia, na, ha, o, a, u, i, e, ni, ki, ka), so their
# presence on a line is a reliable "this is the English gloss" signal.
ENGLISH_FUNCTION = %w[the and of was were with that this they their them from
                      which said but not his her when what will would could
                      should been then there are have has had who your out than
                      these those him its our other some made went came before
                      after because while where about over under again upon into
                      within without between against must being does did such
                      only more most very much many here near down back away
                      still until though also thus even ever never always both
                      each every another whom whose shall may might can cannot
                      well in on at by for as an it if or up all is us
                      you she he we my me].freeze

def native_line?(line)
  # All-caps lines are English/tale headings ("NGANA FENDA MARIA.") - keep.
  return false if line =~ /[A-Za-z]/ && line == line.upcase
  words = line.split.map { |t| t.gsub(/["'“”‘’()\[\],.!?;:—–*^\d\/]/, "") }.reject(&:empty?)
  return false if words.length < 2
  return false if words.any? { |w| ENGLISH_FUNCTION.include?(w.downcase) }
  vowel_final = words.count { |w| w =~ /[aeiou]\z/i }
  if words.length == 2
    # Two-word Ki-mbundu remnants ("uauaba kakuinii"): both long and
    # vowel-final; two-word English gloss fragments never fit this shape.
    return vowel_final == 2 && words.all? { |w| w.length >= 6 } && words.any? { |w| w.length >= 8 }
  end
  vowel_final.to_f / words.length >= 0.66
end

kept = []
body.each do |line|
  s = line.strip
  if s =~ RUNNING_HEAD
    stats[:running_heads] += 1
    next
  end
  if !s.empty? && s.length <= 6 && s =~ PAGE_NUM && s =~ /\d/
    stats[:page_num] += 1
    next
  end
  if native_line?(s)
    stats[:kimbundu_lines] += 1
    next
  end
  kept << line.tr("<>", "()")
end

# --- 4. hyphen join, paragraph rejoin, squeeze --------------------------------
joined = []
i = 0
while i < kept.length
  line = kept[i]
  # Loop so consecutive hyphenated lines all collapse (a continuation that is
  # itself hyphenated is re-checked).
  while line.rstrip =~ /[A-Za-z]-\z/
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    break unless j < kept.length && kept[j].lstrip =~ /\A[a-z]/

    line = line.rstrip.sub(/-\z/, "") + kept[j].lstrip
    stats[:dehyphenated] += 1
    kept.slice!(i + 1..j)
  end
  joined << line
  i += 1
end

merged = []
joined.each do |line|
  if line.strip.empty?
    merged << line
  else
    k = merged.length - 1
    k -= 1 while k >= 0 && merged[k].strip.empty?
    if k >= 0 && k < merged.length - 1 && merged[k] =~ /[a-z,;]\z/ && line.lstrip =~ /\A[a-z]/
      merged.slice!(k + 1..)
      stats[:paragraphs_rejoined] += 1
    end
    merged << line
  end
end

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
