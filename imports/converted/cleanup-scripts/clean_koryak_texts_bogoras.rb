#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/koryaktextswald05bogorich-koryak-texts-bogoras.md
#
# Source: Bogoras, "Koryak Texts" (Publications of the American Ethnological
# Society vol. V, 1917). Layout: each tale is given as English free
# translation interleaved page-by-page with interlinear Koryak (a Koryak line
# as its own paragraph, followed by a word-gloss line as its own paragraph).
# Tales 23-24 add continuous Chukchee/Koryak-dialect/Kamchadal versions after
# the English translation. The Koryak OCR is shredded (clicks/diacritics ->
# symbol soup) and is dropped; the English free translation is kept.
# This script only SELECTS and DELETES lines mechanically.
#
# Transforms:
#   1. Structural trim (guarded by content assertions): keep the "# Koryak
#      Texts" title, the INTRODUCTION prose (orig lines 193-490), and the
#      tales + Appendix I (orig lines 726-5857). Drops: title pages, editor's
#      note, CONTENTS, ERRATA, the garbled phonetic-alphabet table
#      (491-725), APPENDIX II constellation lists (Koryak name tables), and
#      the Koryak-English VOCABULARY (5858-end).
#   2. Delete interlinear material paragraph-by-paragraph:
#        - a paragraph whose lines are majority Koryak-signature is deleted;
#        - the single-line paragraph immediately following a Koryak paragraph
#          is its word-gloss -> deleted (unless it looks like a footnote);
#        - subsequent short lowercase single-line paragraphs are gloss
#          wrap-overs -> deleted.
#      Koryak signature (per word): "8/", "^", "£", slash or sandwiched digit
#      inside a word, or an internal apostrophe whose suffix is not an
#      English contraction. Proper names that Bogoras carries into the
#      English translation (Eme'mqut, Yini'a-nawgut) are whitelisted.
#      A line is Koryak when >=2 words are flagged and >=50% of its words
#      are flagged (or it is a 1-2 word line that is entirely flagged).
#   3. Delete dialect-version headings ("Chukchee.", "Koryak, Kamenskoye.",
#      "Kamchadal.1") and standalone roman-numeral/page-junk lines.
#   4. Join OCR line-break hyphenations left by the generic cleaner:
#      "Little-Bird-\n" + "Man ..." (uppercase continuation keeps the hyphen).
#   5. Re-join paragraph splits created by removed interlinear blocks: a kept
#      line ending mid-clause followed by a lowercase-starting line.
#   6. Squeeze runs of internal spaces; collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/koryaktextswald05bogorich-koryak-texts-bogoras.md")

lines = File.readlines(PATH, chomp: true)

# --- 1. structural trim -----------------------------------------------------
guards = {
  1 => /\A# Koryak Texts/,
  193 => /\AINTRODUCTION\./,
  491 => /\AThe\s+following\s+alphabet\s+has\s+been\s+used/,
  726 => /\Ai\.\s+Little-Bird-Man\s+and\s+Raven-Man/,
  5858 => /\AAPPENDIX\s+II\./
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
body = [lines[0], ""] + lines[192..489] + [""] + lines[725..5856]

# --- Koryak-signature detection ---------------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em clock].freeze
ENGLISH_CARRIED_NAMES = /\A(Eme['’]mqut|Yini['’]a-.awgut)/i.freeze

def koryak_word?(raw)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty? || w.match?(ENGLISH_CARRIED_NAMES)
  return true if w.match?(%r{8/|[\^£]|/})
  return true if w.match?(/[[:alpha:]][0-9][[:alpha:]]/)
  # OCR renders the glottal-stop sign as "8" glued to letters (iLa8, Qiyme8en)
  return true if w.match?(/[[:alpha:]]8|8[[:alpha:]]/)
  # OCR renders raised/special letters as capitals inside a word after a
  # lowercase letter (gawannVLen, taya^iikm -> yaqalhenVtifi); English words
  # in this text never contain an interior capital after a lowercase letter.
  return true if w.match?(/[[:lower:]][A-Z]/)
  # OCR renders the accent apostrophe as "x" in some passages (Gumnaxn,
  # gayoxlenat). Vowel-x-consonant never occurs in this text's English
  # ("ex-", "six-", "mix-", "fix-" words are excluded).
  if w.match?(/[aiou]x[b-df-hj-np-tv-z]/) && !w.downcase.match?(/\A(six|mix|fix)/) && !w.downcase.include?("ex")
    return true
  end

  if w.match?(/[[:alpha:]]['’`´][[:alpha:]]/)
    suffix = w.split(/['’`´]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

# Very common English words: a short Koryak line never contains one, while a
# short English/gloss line essentially always does.
ENGLISH_STOPWORDS = %w[the a an and of to in on he she it they we you i is
                       was were said say that this all one end there].freeze

def koryak_line?(line)
  words = line.split.reject { |t| t.gsub(/["'“”‘’()\[\],.!?;:—–-]/, "").match?(/\A\d*\z/) }
  return false if words.empty?

  flags = words.count { |w| koryak_word?(w) }
  return true if flags >= 4
  return true if flags >= 2 && flags.to_f / words.size >= 1.0 / 3
  return true if words.size <= 2 && flags == words.size

  if words.size <= 3 && flags >= 1
    no_stopwords = words.none? { |w| ENGLISH_STOPWORDS.include?(w.downcase.gsub(/[^a-z]/, "")) }
    return true if no_stopwords
  end
  false
end

def koryak_para?(para)
  koryak = para.count { |l| koryak_line?(l) }
  koryak >= 1 && koryak >= (para.length / 2.0).ceil
end

DIALECT_HEADING = /\A(Chukchee|Kamchadal|Koryak,\s+\S+)\s*\.?\s*[0-9l]*\z/.freeze
# printer's signature lines: "I— FUEL. AMER. ETHN. SOC. VOL. V."
# (OCR also renders ETHN as ETHX)
PRINTER_SIGNATURE = /AMER\.\s+ETH[NX]\.\s+SOC/.freeze
PAGE_JUNK = /\A[0-9IVXlivxoO°()\[\].,\s]{1,6}\z/.freeze
FOOTNOTE_START = /\A\d+\s+[A-Z(]/.freeze
# All-caps section headings (APPENDIX I., SONGS., CONSTELLATIONS.) must
# survive even when they directly follow an interlinear block.
CAPS_HEADING = /\A[A-Z][A-Z\s.,'()-]{3,}\z/.freeze

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

# --- 2+3. paragraph state machine -------------------------------------------
stats = Hash.new(0)
kept_paras = []
chain = 0 # 2 = expect gloss para, 1 = expect gloss wrap-overs
paras.each do |para|
  stripped = para.map(&:strip)
  if para.length == 1 && stripped[0].match?(DIALECT_HEADING)
    stats[:dialect_headings] += 1
    chain = 0
    next
  end
  if para.length == 1 && (stripped[0].match?(PAGE_JUNK) || stripped[0].match?(PRINTER_SIGNATURE))
    stats[:page_junk] += 1
    next # page furniture: does not affect gloss chain
  end
  if koryak_para?(stripped)
    stats[:koryak_paras] += 1
    chain = 2
    next
  end
  # Shredded Koryak lines the OCR broke into 1-3 char fragments
  # ("Q oy qmn • aqoy ikaixtin , qin ay alaxgitca").
  if para.length == 1
    toks = stripped[0].split
    if toks.length >= 6 && toks.sum(&:length).to_f / toks.length <= 3.2 &&
       toks.count { |t| koryak_word?(t) } >= 2
      stats[:shredded_koryak] += 1
      chain = 2
      next
    end
  end
  if para.length == 1 && stripped[0].match?(CAPS_HEADING)
    chain = 0
    kept_paras << para
    next
  end
  if chain.positive? && !stripped[0].match?(FOOTNOTE_START)
    # A word-gloss para is normally a single line; when the OCR ran the
    # wrapped gloss together it is 2 lines, each with wide column gaps.
    gloss_shape = para.length == 1 ||
                  (para.length == 2 && para.all? { |l| l.match?(/\S {3,}\S/) })
    if chain == 2 && gloss_shape
      stats[:glosses] += 1
      chain = 1
      next
    elsif chain == 1 && para.length == 1 &&
          stripped[0].length <= 45 && stripped[0].match?(/\A[a-z(]/)
      stats[:gloss_wraps] += 1
      next
    end
  end
  # Mixed paragraph (OCR ran English and interlinear lines together without
  # a blank line): drop the Koryak lines inside it, plus a directly following
  # wide-gap gloss line. If the paragraph ends on a dropped Koryak line, its
  # gloss is the next paragraph, so arm the gloss chain.
  filtered = []
  last_dropped = false
  skip_next_gloss = false
  para.each do |line|
    s = line.strip
    if skip_next_gloss && line.match?(/\S {3,}\S/)
      stats[:inline_glosses] += 1
      skip_next_gloss = false
      last_dropped = true
      next
    end
    skip_next_gloss = false
    if koryak_line?(s)
      stats[:inline_koryak_lines] += 1
      skip_next_gloss = true
      last_dropped = true
    else
      filtered << line
      last_dropped = false
    end
  end
  chain = last_dropped ? 2 : 0
  kept_paras << filtered unless filtered.empty?
end

kept = kept_paras.flat_map { |para| para + [""] }

# --- 4. join residual end-of-line hyphenations (uppercase continuations) ----
joined = []
i = 0
while i < kept.length
  line = kept[i]
  while line.rstrip.match?(/[A-Za-z]-\z/)
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    break unless j < kept.length && kept[j].lstrip.match?(/\A[A-Z]/)

    line = line.rstrip + kept[j].lstrip
    stats[:hyphen_joined] += 1
    kept.slice!(i + 1..j)
  end
  joined << line
  i += 1
end

# --- 5. re-join paragraph splits --------------------------------------------
merged = []
joined.each do |line|
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
