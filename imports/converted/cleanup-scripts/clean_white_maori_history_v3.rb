#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/ancienthistoryof03whit-ancient-history-of-the-maori-v3-white.md
#
# Source: John White, "The Ancient History of the Maori, His Mythology and
# Traditions", vol. III (Horo-uta or Taki-tumu Migration), 1887. This volume is
# printed in two halves: an English translation of the traditions first, then
# the complete Maori-language source edition ("KO NGA TATAI KORERO WHAKAPAPA A
# TE MAORI ...") second. The Maori half carries no English and is dropped whole
# by a guarded structural trim. Inside the English half the narrative is
# continuous English prose that quotes Maori proper names (hyphenated: Nga-ti-
# mamoe, Ue-nuku) and occasionally sets an untranslated Maori waiata (chant) as
# its own short verse paragraph; those chant lines are dropped by a conservative
# Polynesian signature while every English line -- including those studded with
# Maori proper nouns -- is kept. Mechanical line selection/deletion/joining only.
#
# Transforms:
#   1. Guarded structural trim: keep "# ..." title; body = "PREFACE." through the
#      last line of the English half; drop the library/scan-noise front matter
#      and the entire Maori source edition + tail library card.
#   2. Delete page furniture: "ANCIENT MAORI HISTORY" running heads (OCR variants
#      MAOKI/MAOBI, HISTOKY/HISTOEY) with page numbers, "VOL. III.-1", bare page
#      numbers. All-caps tale/section headings are preserved.
#   3. Delete Maori-signature verse lines (Polynesian orthography: >= 3 words,
#      none an English function word, majority vowel-final, and >= 1 Maori
#      particle).
#   4. Join line-end hyphenations; re-join paragraph splits; squeeze; collapse.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/ancienthistoryof03whit-ancient-history-of-the-maori-v3-white.md")

lines = File.readlines(PATH, chomp: true)
stats = Hash.new(0)

# --- 1. structural trim (guarded by content assertions) ----------------------
start = 158  # "PREFACE." (1-based)
stop  = 15823 # "KO NGA" -- first line of the Maori source edition (1-based)
unless lines[start - 1].to_s.strip =~ /\APREFACE\.\z/
  abort "guard failed: line #{start} = #{lines[start - 1].inspect} (expected PREFACE.)"
end
unless lines[stop - 1].to_s.strip =~ /\AKO\s+NGA\z/
  abort "guard failed: line #{stop} = #{lines[stop - 1].inspect} (expected KO NGA)"
end
stats[:head_trim] = start - 1
stats[:tail_trim] = lines.length - (stop - 1)
# English half = PREFACE (line 158) .. last English line (line 15817).
body = [lines[0], ""] + lines[(start - 1)...(stop - 6)]

# --- 2. page furniture --------------------------------------------------------
RUNNING_HEAD = /\A[\dOoIl]{0,4}\s*ANCIENT\s+MAO[RKB]I\s+HIST[OK][RE]Y\.?\s*[\dOoIl]{0,4}\z/i.freeze
VOL_LINE = /\AVOL\.\s*[IVX]+\.?\s*[.\-—]*\s*\d*\z/i.freeze
PAGE_NUM = /\A[\dOoIlSg()\[\].,\s]{1,5}\z/.freeze

# --- 3. Maori-signature detection --------------------------------------------
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
                      you she we].freeze

# Maori grammatical particles / very common function words. A genuine English
# line effectively never consists of these alone, so requiring one guards
# against dropping an English line that merely happens to be vowel-heavy.
MAORI_PARTICLE = %w[te nga ka ki ko na he me mo ai ana ake nei ra ia tana tona
                    raua ratou hoki kia kua nau mai atu iho au wa taua enei ena
                    tera tenei tena tona aku ana whaka a e i o].freeze

def maori_line?(line)
  # All-caps lines are English tale/section headings ("UE-NUKU AND WHENA.") - keep.
  return false if line =~ /[A-Za-z]/ && line == line.upcase
  words = line.split.map { |t| t.gsub(/["'“”‘’()\[\],.!?;:—–*^\d]/, "") }.reject(&:empty?)
  return false if words.length < 3
  down = words.map(&:downcase)
  return false if down.any? { |w| ENGLISH_FUNCTION.include?(w) }
  vowel_final = words.count { |w| w =~ /[aeiou]\z/i }
  return false if vowel_final.to_f / words.length < 0.72
  down.any? { |w| MAORI_PARTICLE.include?(w) }
end

kept = []
body.each do |line|
  s = line.strip
  if s =~ RUNNING_HEAD || s =~ VOL_LINE
    stats[:running_heads] += 1
    next
  end
  if !s.empty? && s.length <= 5 && s =~ PAGE_NUM && s =~ /\d/
    stats[:page_num] += 1
    next
  end
  if maori_line?(s)
    stats[:maori_lines] += 1
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
  while line.rstrip =~ /[a-z]-\z/
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
