#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/specimensofbushm00blee-specimens-of-bushman-folklore-bleek-lloyd.md
#
# Source: Bleek & Lloyd, "Specimens of Bushman Folklore" (1911). Layout:
# |Xam (and, in the appendix, !Kun) text pages alternate page-by-page with
# the facing English translation pages; both carry running headers with page
# numbers. The click orthography is OCR-shredded (|, !, ^, +, doubled "ll",
# "j"-for-! etc.) and the native-language pages are dropped; the English
# pages (with their parenthesised manuscript-column citations, e.g.
# "(6981)") are kept. This script only SELECTS and DELETES lines
# mechanically.
#
# Transforms:
#   1. Structural trim (guarded): keep the "#" title, the PREFACE
#      (orig lines 430-843), and INTRODUCTION through the end of Bleek's
#      appendix papers (orig lines 1394-23269). Drops: cover/library plates
#      and title pages, CONTENTS + List of Illustrations (844-1393), the
#      INDEX, and the trailing publisher advertisements/press reviews
#      (23270-end).
#   2. Delete |Xam/!Kun paragraphs via a word-signature classifier: click
#      and diacritic OCR marks (| \ + ~ £ ^, leading/embedded !, "ll"/"j"+
#      consonant onsets, embedded digits, non-contraction apostrophes) and
#      a lexicon of very frequent |Xam/!Kun function words (ha, ta, Ine,
#      kui, ssa, ...). A paragraph is dropped when >=3 words are flagged
#      and >=15% of its words are flagged. All-caps lines (tale titles,
#      even those containing click characters) are preserved.
#   3. Delete running headers ("THE SON OF THE MANTIS. 17", "PREFACE. IX",
#      "TRANSLATION OF |KUN TEXTS. 405", "44d APPENDIX.") and page junk.
#   4. Delete individual native-language lines run together with English in
#      one paragraph (>=3 flags and >=40% of the line's words flagged) —
#      e.g. quoted verse inside narrator footnotes.
#   5. Re-join paragraph splits created by removed pages/furniture.
#   6. Squeeze runs of internal spaces; collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/specimensofbushm00blee-specimens-of-bushman-folklore-bleek-lloyd.md")

lines = File.readlines(PATH, chomp: true)

# --- 1. structural trim -----------------------------------------------------
guards = {
  1 => /\A# Specimens of Bushman Folklore/,
  430 => /\APREFACE\./,
  844 => /\ACONTENTS\./,
  1394 => /\AINTRODUCTION\./,
  23270 => /\AI ?NDEX/
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
body = [lines[0], ""] + lines[429..842] + [""] + lines[1393..23268]

# --- native-word detection ---------------------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em clock].freeze
BUSHMAN_LEXICON = %w[ta kue gii yehe dzhu ssin ssa tchin kui kiii tiken
                     han hin au ka ha ine ige ikua llkau llha].freeze
ENGLISH_STOPWORDS = %w[the and of to she he it is was were said that this
                       in on you they all one].freeze

def bushman_word?(raw)
  w = raw.gsub(/\A["“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:*]+\z/, "")
  return false if w.empty?
  return true if BUSHMAN_LEXICON.include?(w.downcase.delete("'’"))
  # click/diacritic OCR marks
  return true if w.match?(/[|\\+~£^]/)
  return true if w.match?(/![[:alpha:]]/) # leading/embedded click "!kh6"
  # click onsets: Ine, Ige, Ikua, jkhwa, jkiikko, llkau, llha
  return true if w.match?(/\A[Ilj][gknqx][[:alpha:]']/)
  return true if w.match?(/\All[[:alpha:]]/)
  # embedded digits for accented vowels: kh6, 6a, n|^a
  return true if w.match?(/[[:alpha:]][0-9][[:alpha:]]/) || w.match?(/\A[0-9][[:alpha:]]{1,}/)

  if w.match?(/[[:alpha:]]['’`´][[:lower:]]/)
    suffix = w.split(/['’`´]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

def word_tokens(line)
  line.split.reject { |t| t.gsub(/["'“”‘’()\[\],.!?;:*—–-]/, "").match?(/\A\d*\z/) }
end

def bushman_para?(para)
  assessable = para.reject { |l| l == l.upcase }
  words = assessable.flat_map { |l| word_tokens(l) }
  return false if words.empty?

  flags = words.count { |w| bushman_word?(w) }
  return true if flags >= 3 && flags.to_f / words.size >= 0.15

  if words.size <= 10 && flags >= 2
    return words.none? { |w| ENGLISH_STOPWORDS.include?(w.downcase.gsub(/[^a-z]/, "")) }
  end
  false
end

RUNNING_HEADER = Regexp.union(
  /\A[A-Z][A-Z\s.,;:'|()\\—–-]*[.\s]\s*[0-9]+[a-z]?\s*\z/, # "THE MANTIS. 17"
  /\A(PREFACE|INTRODUCTION|CONTENTS|APPENDIX)\.?\s+[IVXL1l0-9.]{1,8}\z/,
  /\A[IVXL1l0-9]{1,8}[a-z]?\s+(PREFACE|INTRODUCTION|CONTENTS|APPENDIX)\.?\z/
).freeze
PAGE_JUNK = /\A(PAGE\.?|[0-9IVXlivx.,\s]{1,6}|[A-Z]|2g)\z/.freeze

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

# --- 2+3+4. delete native paragraphs, headers, junk -------------------------
stats = Hash.new(0)
kept_paras = []
paras.each do |para|
  stripped = para.map(&:strip)
  if para.length == 1 && stripped[0].match?(PAGE_JUNK)
    stats[:page_junk] += 1
    next
  end
  if para.length == 1 && stripped[0].length <= 60 && stripped[0].match?(RUNNING_HEADER)
    stats[:running_headers] += 1
    next
  end
  if bushman_para?(stripped)
    stats[:native_paras] += 1
    next
  end
  filtered = para.reject do |l|
    next false if l == l.upcase

    toks = word_tokens(l)
    flags = toks.count { |w| bushman_word?(w) }
    drop = !toks.empty? && flags >= 3 && flags.to_f / toks.size >= 0.4
    stats[:inline_native_lines] += 1 if drop
    drop
  end
  kept_paras << filtered unless filtered.empty?
end

kept = kept_paras.flat_map { |para| para + [""] }

# --- 5. re-join paragraph splits --------------------------------------------
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

# --- 6. squeeze spaces, collapse blanks -------------------------------------
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
