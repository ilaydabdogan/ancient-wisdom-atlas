#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/nurserytalestrad00call_0-nursery-tales-traditions-histories-zulus-callaway.md
#
# Source: Callaway, "Nursery Tales, Traditions, and Histories of the Zulus"
# vol. I (1868). Layout: parallel columns (Zulu left, English right) which
# the OCR serialised as alternating paragraph blocks: [English section
# heading] [Zulu block] [English block] [English footnotes]. The Zulu OCR is
# shredded (clicks/aspirated-hl OCR'd as carets, slashes, and interior
# capitals) and is dropped; English headings, translations, prefaces, and
# footnotes are kept. This script only SELECTS and DELETES lines mechanically.
#
# Transforms:
#   1. Structural trim (guarded): keep the "#" title and orig lines 77-34150
#      (Preface through end of tales). Drops: Princeton bookplate/title
#      pages (2-76), CONTENTS (page numbers), OPINIONS OF THE PRESS
#      publisher ads, and the library due-date card (34151-end).
#   2. Delete Zulu paragraphs via a word-signature classifier:
#      strong flags = caret or slash inside a word, interior capital after a
#      lowercase letter (endAlini, laAla), leading-apostrophe elision
#      ('kuzinguma, 'mAlola); weak flags = very frequent Zulu function words
#      (wa, ti, ke, ba, ku, ngi, ...) that never occur standalone in English.
#      A paragraph is Zulu when >=3 words are flagged and >=15% of its words
#      are flagged. All-caps lines (English/Zulu tale titles) are preserved.
#   3. Delete individual Zulu lines run together with English in one
#      paragraph (>=3 flags and >=40% of the line's words flagged).
#   4. Re-join paragraph splits created by removed Zulu blocks and page
#      furniture (English column text continues mid-sentence).
#   5. Squeeze runs of internal spaces; collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/nurserytalestrad00call_0-nursery-tales-traditions-histories-zulus-callaway.md")

lines = File.readlines(PATH, chomp: true)

# --- 1. structural trim -----------------------------------------------------
guards = {
  1 => /\A# Nursery Tales, Traditions, and Histories of the Zulus/,
  77 => /\APREFACE\s+TO\s+THE\s+FIRST\s+VOLUME\./,
  33838 => /\AERRATA\./,
  34152 => /\ACONTENTS\s+OF\s+THE\s+FIRST\s+VOLUME\./
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
# End the body before the ERRATA list (its page/line references are
# meaningless once the Zulu column is removed).
body = [lines[0], ""] + lines[76..33835]

# --- Zulu-signature detection -----------------------------------------------
# Very frequent Zulu function words; none occurs standalone in English prose.
ZULU_LEXICON = %w[wa ti ke ba ku ngi ya ni nga kwa ngokuba ukuba uku
                  unina uyise umntwana abantu bonke yena kanti kepa
                  wati bati ngoba futi njalo lapa kodwa].freeze
ENGLISH_STOPWORDS = %w[the and of to she he it is was were said that this
                       in on you they all one].freeze

def zulu_word?(raw)
  # elision apostrophe prefix must be tested before quote stripping:
  # 'kuzinguma, 'mAlola, 'muntu, ’kupela
  return true if raw.match?(/\A['’][[:lower:]]/)

  w = raw.gsub(/\A["“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty?
  return true if ZULU_LEXICON.include?(w.downcase.delete("'’"))
  # click/aspirate OCR damage: k^ale, n^uma, /Jala, pand/de
  return true if w.match?(%r{[\^]|[[:alpha:]]/[[:alpha:]]})
  # interior capital after lowercase: endAlini, ibandAla, ngasenAla
  return true if w.match?(/[[:lower:]][A-Z]/)
  # elision apostrophe prefix: 'kuzinguma, 'mAlola, 'muntu
  return true if w.match?(/\A['’][[:lower:]]/)

  false
end

def word_tokens(line)
  line.split.reject { |t| t.gsub(/["'“”‘’()\[\],.!?;:*—–-]/, "").match?(/\A\d*\z/) }
end

def zulu_para?(para)
  assessable = para.reject { |l| l == l.upcase }
  words = assessable.flat_map { |l| word_tokens(l) }
  return false if words.empty?

  flags = words.count { |w| zulu_word?(w) }
  return true if flags >= 3 && flags.to_f / words.size >= 0.15

  if words.size <= 10 && flags >= 2
    return words.none? { |w| ENGLISH_STOPWORDS.include?(w.downcase.gsub(/[^a-z]/, "")) }
  end
  false
end

PAGE_JUNK = /\A(PAGE\.?|[0-9IVXlivx.,\s]{1,6}|[A-Z])\z/.freeze

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

# --- 2+3. delete Zulu paragraphs and junk -----------------------------------
stats = Hash.new(0)
kept_paras = []
paras.each do |para|
  stripped = para.map(&:strip)
  if para.length == 1 && stripped[0].match?(PAGE_JUNK)
    stats[:page_junk] += 1
    next
  end
  if zulu_para?(stripped)
    stats[:zulu_paras] += 1
    next
  end
  filtered = para.reject do |l|
    next false if l == l.upcase

    toks = word_tokens(l)
    flags = toks.count { |w| zulu_word?(w) }
    drop = !toks.empty? && flags >= 3 && flags.to_f / toks.size >= 0.4
    stats[:inline_zulu_lines] += 1 if drop
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
