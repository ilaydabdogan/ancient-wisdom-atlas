#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/specimensofbantu00torr-specimens-bantu-folklore-torrend.md
#
# Source: Torrend, "Specimens of Bantu Folk-Lore from Northern Rhodesia"
# (1921). Parallel edition: Bantu originals (Tonga/Ila/Subiya etc.) with
# English translations; the OCR serialized the parallel columns, so
# continuous English tale translations alternate with blocks of Bantu
# original text (later tales are prefixed "(in tonga.)"). The Bantu blocks
# are dropped line-by-line via a conservative signature (>= 3 words, none
# of them common English function words, >= 65 % of words vowel-final -
# Bantu words are almost invariably vowel-final while English is
# consonant-heavy); English translation and narrative framing are kept.
# Torrend's linguistic footnotes that mix Bantu and English glosses carry
# English function words and survive; purely Bantu footnote lines fall to
# the same signature. Mechanical line selection/deletion/joining only.
#
# Transforms:
#   1. Guarded structural trim: keep "# ..." title, body from "PRELIMINARY
#      NOTES."; drop library call-number head, duplicated CONTENTS, and the
#      printer colophon tail ("Printed by Fox, Jones ...").
#   2. Delete "BANTU FOLK-LORE" running headers (with OCR'd page numbers)
#      and standalone page-number junk.
#   3. Delete "(in <language>.)" column tags and Bantu-signature lines.
#   4. Join line-end hyphenations; re-join paragraph splits left by removed
#      furniture and Bantu blocks; squeeze double word spacing; collapse
#      blank runs.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/specimensofbantu00torr-specimens-bantu-folklore-torrend.md")

lines = File.readlines(PATH, chomp: true)
stats = Hash.new(0)

# --- 1. structural trim -------------------------------------------------------
start = lines.index { |l| l.strip =~ /\APRELIMINARY\s+NOTES\.\z/ }
abort "PRELIMINARY NOTES heading not found" unless start
tail = ((lines.length * 0.95).to_i...lines.length).find { |i| lines[i].strip =~ /\APrinted\s+by\s+Fox,\s+Jones/ }
abort "printer colophon not found" unless tail
stats[:head_trim] = start - 1
stats[:tail_trim] = lines.length - tail
body = [lines[0], ""] + lines[start...tail]

# --- 2. page furniture --------------------------------------------------------
RUNNING_HEADER = /\A[\dOoIl]{0,4}\s*BANTU\s+FOLK-?LORE\s*[\dOoIl]{0,4}\z/.freeze
PAGE_NUM = /\A[\dOoIlSg()\[\]]{1,5}\z/.freeze
LANG_TAG = /\A\(in\s+[a-z]+\.?\)\z/i.freeze

# --- 3. Bantu-signature detection --------------------------------------------
STOPWORDS = %w[the and of to is was were said say says he she it they them
               their we our you your i in on with that this for not but at
               his her my me mine am are be been will shall would should
               there then when where what who how why which as by from
               have has had do does did no yes if or so all one once
               more most other another again back out up down over under
               come came go went let very much many little began].freeze

def bantu_line?(line, stopwords)
  words = line.split.map { |t| t.gsub(/["'“”‘’()\[\],.!?;:—–*^\d-]/, "") }.reject(&:empty?)
  return false if words.length < 2
  return false if words.any? { |w| stopwords.include?(w.downcase) }
  vowel_final = words.count { |w| w =~ /[aeiou]\z/i }
  if words.length == 2
    # Two-word remnants of Bantu blocks ("Bamujata bamutora."): both long
    # and vowel-final; short English exclamations never fit this shape.
    return vowel_final == 2 && words.all? { |w| w.length >= 6 } && words.any? { |w| w.length >= 8 }
  end
  vowel_final.to_f / words.length >= 0.65
end

kept = []
body.each do |line|
  s = line.strip
  if s =~ RUNNING_HEADER
    stats[:running_headers] += 1
    next
  end
  if !s.empty? && s.length <= 5 && s =~ PAGE_NUM && s =~ /\d/
    stats[:page_junk] += 1
    next
  end
  if s =~ LANG_TAG
    stats[:lang_tags] += 1
    next
  end
  if bantu_line?(s, STOPWORDS)
    stats[:bantu_lines] += 1
    next
  end
  kept << line
end

# --- 4. hyphen join, paragraph rejoin, squeeze --------------------------------
joined = []
i = 0
while i < kept.length
  line = kept[i]
  if line.rstrip =~ /[a-z]-\z/
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    if j < kept.length && kept[j].lstrip =~ /\A[a-z]/
      joined << line.rstrip.sub(/-\z/, "") + kept[j].lstrip
      stats[:dehyphenated] += 1
      i = j + 1
      next
    end
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
