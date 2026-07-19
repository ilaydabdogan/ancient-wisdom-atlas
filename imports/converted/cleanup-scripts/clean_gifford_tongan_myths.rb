#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/tonganmythstales0000giff-tongan-myths-and-tales-gifford.md
#
# Source: E. W. Gifford, "Tongan Myths and Tales" (Bernice P. Bishop Museum
# Bulletin 8, 1924; here the 1971 Kraus reprint scan). Many tales are printed
# with the Tongan-language text parallel to Miss Baker's English translation, so
# the OCR serialised blocks of Tongan paragraphs alternating with blocks of the
# English translation. The Tongan blocks are dropped by a conservative
# Polynesian per-line signature (>= 3 words, none an English function word,
# majority vowel-final, and >= 1 Tongan particle); the English translation and
# the surrounding English introduction/notes are kept, including English lines
# carrying embedded Tongan names/glosses. The Kraus reprint scattered a soft
# hyphen ("¬") through the English at line-ends; those and ordinary line-end
# hyphens are re-joined. Mechanical line selection/deletion/joining only.
#
# Transforms:
#   1. Guarded structural trim: keep "# Tongan Myths and Tales" title; body from
#      "CONTENTS" through the last footnote; drop the Trent-University library
#      front cruft and the tail "Date Due" library card (walked back past its
#      scan-garble lines).
#   2. Delete page furniture: "Gifford — Tongan Myths and Tales" and "Bernice P.
#      Bishop Museum — Bulletin" running heads, bare page numbers.
#   3. Delete Tongan-signature lines.
#   4. Join "¬"/"-" line-end hyphenations; re-join paragraph splits; squeeze;
#      collapse blank runs; neutralise stray "<>" scan garble.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/tonganmythstales0000giff-tongan-myths-and-tales-gifford.md")

lines = File.readlines(PATH, chomp: true)
stats = Hash.new(0)

# --- 1. structural trim -------------------------------------------------------
start = lines.index { |l| l.strip =~ /\ACONTENTS\z/ }
abort "CONTENTS heading not found" unless start
dd = lines.rindex { |l| l.strip =~ /\ADate\s+Due\z/i }
abort "Date Due library card not found" unless dd
# Walk back from the library card past its blank/scan-garble lines to the last
# line of real text (a line with at least two 3+ letter words).
tail = dd
tail -= 1 while tail > start && lines[tail - 1].to_s.scan(/[A-Za-z]{3,}/).length < 2
stats[:head_trim] = start
stats[:tail_trim] = lines.length - tail
body = [lines[0], ""] + lines[start...tail]

# --- 2. page furniture --------------------------------------------------------
RUNNING_HEAD = %r{\A(Gifford\s*[—\-]\s*Tongan\s+Myths|Bernice\s+P\.\s+Bishop\s+Museum)}i.freeze
PAGE_NUM = /\A[\dOoIl][\dOoIl\s]{0,4}\z/.freeze

# --- 3. Tongan-signature detection -------------------------------------------
ENGLISH_FUNCTION = %w[the and of was were with that this they their them from
                      which said but not his her when what will would could
                      should been then there are have has had who your out than
                      these those him its our other some made went came before
                      after because while where about over under again upon into
                      within without between against must being does did such
                      only more most very much many here near down back away
                      still until though also thus even ever never always both
                      each every another whom whose shall may might can cannot
                      well in on at by for as an it if or up all is us you she
                      we].freeze

# Tongan grammatical particles / very common function words.
TONGAN_PARTICLE = %w[koe mo kia ae ki he mei pea kae naa ke oku ko ne ia kihe
                     aki oe ka nau leva koia aia hono ihe ai na moe foki kuo nae
                     ho hoku ene mei ha ma o a e i pe kae ki moou mou ange].freeze

def tongan_line?(line)
  # All-caps lines are English section/tale headings - keep.
  return false if line =~ /[A-Za-z]/ && line == line.upcase
  words = line.split.map { |t| t.gsub(/["'“”‘’()\[\],.!?;:—–*^\d]/, "") }.reject(&:empty?)
  return false if words.length < 3
  down = words.map(&:downcase)
  return false if down.any? { |w| ENGLISH_FUNCTION.include?(w) }
  vf = words.count { |w| w =~ /[aeiou]\z/i }.to_f / words.length
  return false if vf < 0.70
  return true if down.any? { |w| TONGAN_PARTICLE.include?(w) }
  # Untranslated Tongan verse (numeral chants, waiata) whose words are not in
  # the particle list still betrays itself by pure Tongan orthography: every
  # word built only from Tongan-alphabet letters (aeiou + f h k l m n p s t v g
  # + glottal). The English translation anglicises names with b/d/g/r/w/y, so a
  # 4+ word, vowel-final, function-word-free, all-Tongan-letter line is Tongan.
  words.length >= 4 && vf >= 0.80 && words.all? { |w| w =~ /\A[aeioufhklmnpstvg'‘’ʻ]+\z/i }
end

kept = []
body.each do |line|
  s = line.strip
  if s =~ RUNNING_HEAD
    stats[:running_heads] += 1
    next
  end
  if !s.empty? && s.length <= 5 && s =~ PAGE_NUM && s =~ /\d/
    stats[:page_num] += 1
    next
  end
  if tongan_line?(s)
    stats[:tongan_lines] += 1
    next
  end
  kept << line.tr("<>", "()")
end

# --- 4. hyphen join (soft "¬" and ordinary "-"), rejoin, squeeze -------------
joined = []
i = 0
while i < kept.length
  line = kept[i]
  # Loop so consecutive hyphenated lines ("run¬" then a continuation that
  # itself ends "strik¬") all collapse into one word/paragraph.
  loop do
    m = line.rstrip.match(/(¬|[A-Za-z]-)\z/)
    break unless m

    soft = m[1] == "¬"
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    # Soft hyphen always marks a broken word; ordinary hyphen only joins when
    # the continuation begins lower-case (keeps real hyphenated compounds).
    break unless j < kept.length && (soft || kept[j].lstrip =~ /\A[a-z]/)

    line = line.rstrip.sub(/(¬|-)\z/, "") + kept[j].lstrip
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
