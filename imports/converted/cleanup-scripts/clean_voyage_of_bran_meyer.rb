#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/voyageofbransono01scuoft-voyage-of-bran-meyer.md
#
# Source: Meyer & Nutt, "The Voyage of Bran, Son of Febal" vol. I (Grimm
# Library No. 4, 1895). Layout: Meyer's English translation pages alternate
# with the Old Irish text pages ("IMRAM BRAIN" running header) whose critical
# apparatus is manuscript-sigla soup; then Meyer's NOTES, further translated
# Mongan texts (same facing-page alternation), an Irish GLOSSARY, indexes,
# and Nutt's long English essay on the Happy Otherworld (Section I).
# The Irish OCR is shredded and is dropped; all English (translation, notes,
# essay) is kept. This script only SELECTS and DELETES lines mechanically.
#
# Transforms:
#   1. Structural trim (guarded): keep the "#" title, then orig lines
#      194-4592 (introduction, Bran translation+Irish, notes, Mongan texts)
#      and 5467-13806 (Nutt's essay through "End of Section I.").
#      Drops: cover garble and title pages (2-193), GLOSSARY + indexes
#      (4593-5466), printer's colophon and back-cover garble (13807-end).
#   2. Delete Old Irish paragraphs and their critical apparatus via a
#      word-signature classifier (caret refs, digit-for-vowel OCR like
#      "sce6il"/"6robatar", internal apostrophes, interior capitals after
#      lowercase). A paragraph is Irish when >=2 words are flagged and >=20%
#      of its words are flagged, or it is a <=3-word paragraph with a flag
#      and no common English words.
#   3. Delete running headers ("IMRAM BRAIN <n>"), all-caps lines carrying a
#      page number (also covers the essay's table-of-contents page-number
#      entries), and page junk ("PAGE", stray roman numerals).
#   4. Re-join paragraph splits created by removed page furniture.
#   5. Squeeze runs of internal spaces; collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/voyageofbransono01scuoft-voyage-of-bran-meyer.md")

lines = File.readlines(PATH, chomp: true)

# --- 1. structural trim -----------------------------------------------------
guards = {
  1 => /\A# The Voyage of Bran/,
  194 => /\AINTRODUCTION\z/,
  4593 => /\AGLOSSARY\z/,
  5467 => /\ATHE\s+HAPPY\s+OTHERWORLD\s+IN\s+THE\s+MYTHICO-\z/,
  13806 => /\AEnd\s+of\s+Section\s+I\./
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
body = [lines[0], ""] + lines[193..4591] + [""] + lines[5466..13805]

# --- Irish-signature detection ----------------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em clock].freeze
# Common English words that never occur in the Old Irish text. ("a", "an",
# "for", "co" etc. are Irish words, so they are deliberately absent.)
ENGLISH_STOPWORDS = %w[the and of to she he it is was were said that this
                       in on i you they all one].freeze
# Critical-apparatus vocabulary: manuscript sigla and editorial abbreviations.
# (Roman numerals excluded: they are ordinary English section references.)
SIGLA_EXCLUDE = %w[I A O MS MSS OK II III IV V VI VII VIII IX X XI XII
                   XIII XIV XV XVI XVII XVIII XIX XX].freeze
APPARATUS_TOKEN = /\A(sic|om\.|cet\.|add\.|\.i\.)\z/.freeze

# High-frequency Old Irish function words never used in English prose.
IRISH_LEXICON = %w[ocus asbert boi dolluid iarum didiu conid amin
                   cotici cachain arrobo dobert].freeze

def irish_word?(raw)
  return true if raw.match?(APPARATUS_TOKEN)

  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty?
  return true if IRISH_LEXICON.include?(w.downcase)
  # eclipsis/nasalisation prefix: i n-Dubthair, co m-bad, a n-usciu
  return true if w.match?(/\A[nm][-*][[:alpha:]]/)
  if w.match?(/[[:alpha:]]/)
    return true if w.match?(/[\^£]/)
    # manuscript sigla: short all-caps groups (H, RE, HB, REBL)
    return true if w.match?(/\A[A-Z]{1,4}\z/) && !SIGLA_EXCLUDE.include?(w)
  else
    # a lone "^" is an English footnote reference; multi-character caret
    # clusters (^^, ^-, ^*^) are OCR'd Irish superscript numbers
    return w.include?("^") && w.length >= 2
  end
  # OCR turns accented vowels into digits: sce6il, 6robatar, d6ib, 7naic
  return true if w.match?(/[[:alpha:]][0-9][[:alpha:]]/)
  return true if w.match?(/\A[0-9][[:alpha:]]{2,}/)
  # interior capital after a lowercase letter: CoUbrain, hEmain
  return true if w.match?(/[[:lower:]][A-Z]/)

  if w.match?(/[[:alpha:]]['’`´][[:lower:]]/)
    suffix = w.split(/['’`´]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

def word_tokens(line)
  line.split.reject { |t| t.gsub(/["'“”‘’()\[\],.!?;:*—–-]/, "").match?(/\A\d*\z/) }
end

def irish_para?(para)
  # All-caps lines are English headings ("BY ALFRED NUTT"); the sigla flag
  # must never judge them.
  assessable = para.reject { |l| l == l.upcase }
  words = assessable.flat_map { |l| word_tokens(l) }
  return false if words.empty?

  flags = words.count { |w| irish_word?(w) }
  return true if flags >= 2 && flags.to_f / words.size >= 0.15

  if words.size <= 10 && flags >= 1
    return words.none? { |w| ENGLISH_STOPWORDS.include?(w.downcase.gsub(/[^a-z]/, "")) }
  end
  false
end

RUNNING_HEADER = /\AIMRAM\s+BRAIN(\s+\d+)?\z/.freeze
# all-caps line carrying a page number (running headers, TOC entries)
CAPS_WITH_PAGE = /\A(\d+\s+)?[A-Z][A-Z\s.,:;'^()-]*\d+\s*\z/.freeze
PAGE_JUNK = /\A(PAGE|[0-9IVXlivx.,\s]{1,6}|FINIT)\z/.freeze

# --- split into paragraphs ---------------------------------------------------
paras = []
current = []
body.each do |line|
  if line.strip.empty?
    paras << current unless current.empty?
    current = []
  else
    current << line
  end
end
paras << current unless current.empty?

# --- 2+3. delete Irish paragraphs, headers, junk ----------------------------
stats = Hash.new(0)
kept_paras = []
paras.each do |para|
  stripped = para.map(&:strip)
  if para.length == 1 && stripped[0].match?(RUNNING_HEADER)
    stats[:running_headers] += 1
    next
  end
  if para.length == 1 && stripped[0].match?(PAGE_JUNK)
    stats[:page_junk] += 1
    next
  end
  if para.length == 1 && stripped[0].length <= 60 && stripped[0].match?(CAPS_WITH_PAGE)
    stats[:caps_page_lines] += 1
    next
  end
  if irish_para?(stripped)
    stats[:irish_paras] += 1
    next
  end
  # Mixed paragraph: drop Irish lines run together with English ones.
  filtered = para.reject do |l|
    next false if l == l.upcase

    toks = word_tokens(l)
    flags = toks.count { |w| irish_word?(w) }
    drop = !toks.empty? && flags >= 3 && flags.to_f / toks.size >= 0.4
    stats[:inline_irish_lines] += 1 if drop
    drop
  end
  kept_paras << filtered unless filtered.empty?
end

kept = kept_paras.flat_map { |para| para + [""] }

# --- 4. re-join paragraph splits --------------------------------------------
merged = []
kept.each do |line|
  if line.strip.empty?
    merged << line
  else
    k = merged.length - 1
    k -= 1 while k >= 0 && merged[k].strip.empty?
    if k >= 0 && k < merged.length - 1 && merged[k].match?(/[a-z,;]\z/) && line.lstrip.match?(/\A[a-z]/)
      merged.slice!(k + 1..)
      stats[:paragraphs_rejoined] += 1
    end
    merged << line
  end
end

# --- 5. squeeze spaces, collapse blanks -------------------------------------
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
