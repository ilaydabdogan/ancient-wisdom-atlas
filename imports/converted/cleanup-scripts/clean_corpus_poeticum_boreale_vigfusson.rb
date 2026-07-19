#!/usr/bin/env ruby
# frozen_string_literal: true

require "set"

# Bespoke deterministic cleanup for:
#   imports/converted/internet-archive/corpuspoeticumbo01guuoft-corpus-poeticum-boreale-v1-vigfusson-powell.md
#
# Source: Gudbrand Vigfusson & F. York Powell, "Corpus Poeticum Boreale," Vol. I
# (Eddic Poetry), Oxford 1883. Layout: the Old Norse verse is printed as its own
# numbered stanza blocks and the English PROSE translation follows as its own
# numbered blocks; the two alternate down the whole work. The Norse OCR is badly
# garbled (thorn/eth rendered as p/d, accents rendered as stray digits, ligature
# soup) as is the Norse philological apparatus; the English prose is readable. We
# DROP the Norse verse/philology blocks and KEEP the English prose translation
# and the English scholarly prose (Introduction, Book prefaces, Excursus).
# Every transform is mechanical line selection / deletion / joining — no text is
# ever rewritten, paraphrased, or invented.
#
# Transforms:
#   1. Structural trim (guarded): keep the "#" title and the body from the first
#      "INTRODUCTION." heading (line 1176) to just before the tail "NOTES:"
#      section. Drops: the garbled title page, the CONTENTS page-number tables,
#      and the tail philological NOTES apparatus (which degrades into pure scan
#      garble at the very end).
#   2. Delete page furniture: standalone page/line numbers, running-header
#      fragments ("$1] THE GUEST'S WISDOM. 3", "4 OLD ETHIC POEMS. [BK. I.]",
#      "vi CONTENTS.", "B 2"), and short scan-garble scraps.
#   3. Delete Old Norse blocks via a per-word signature classifier
#      (thorn/eth/ae/o-slash + accented vowels, OCR digit-for-accent inside a
#      word, and a lexicon of high-frequency Norse function words) combined with
#      an English-marker veto: a block with a Norse line and NO English-bearing
#      line is dropped; English prose (dense with grammatical words) survives.
#   4. Delete individual Norse lines run together with English in one paragraph.
#   5. Join residual hyphenations; re-join paragraph splits; neutralise stray
#      "<"/">" scan-garble to parens; squeeze spaces; collapse blank runs.
#
# Modes: ANALYZE=1 prints keep/drop counts + borderline samples, writes nothing.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT,
  "imports/converted/internet-archive/corpuspoeticumbo01guuoft-corpus-poeticum-boreale-v1-vigfusson-powell.md")

ANALYZE = ENV["ANALYZE"] == "1"

# --- Old Norse signature -----------------------------------------------------
NORSE_SPECIAL = /[þðæœøåÞÐÆŒØÅ]/.freeze
NORSE_ACCENT  = /[áéíóúýàèìòùâêîôûäëïöüÿãõñ]/i.freeze

# High-frequency Norse function words; OCR renders þ->p and ð->d, so both spell-
# ings are listed. None of these is an English word (English function words that
# might collide — at, is, he, in, on, of, to, as, it, er — are deliberately kept
# OUT of this list and out of the English-marker set).
NORSE_LEXICON = %w[
  es ok sa vid vidr vithr med um enn eda edr edu pat that peim peims theim madr
  mannr madir se ser til ef ero erosk hann hon ek pu thu pik thik par thar pott
  thott pviat thviat pegi thegi pegir thegir munu mon skal skyli skolo skulu
  vito vera vesa gestr gest pess thess verdr verthr sialfr miak hverr hverjo
  vitz inn einn eldz vatz byrdi byrdir naudr snotrom brandom gumna gumnar aldar
].to_set

def norse_word?(raw)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty?
  return true if w.match?(NORSE_SPECIAL)
  return true if w.match?(NORSE_ACCENT)
  # OCR renders a dropped accent as a stray digit glued inside a word
  # (g6ds, oréz, r46, é6kunnom, pidd-168, sié): a digit adjacent to a letter
  # inside a token that is mostly letters.
  if w.gsub(/[^[:alpha:]]/, "").length >= 2 && w.match?(/[[:alpha:]]\d|\d[[:alpha:]]/)
    return true
  end
  norm = w.downcase.gsub(/[^a-zþð]/, "").tr("þð", "pd")
  return true if norm.length >= 2 && NORSE_LEXICON.include?(norm)
  false
end

# Unambiguously-English grammar words, none of which occurs in the Norse verse.
# Content words are deliberately EXCLUDED because many collide with Norse
# (her=hér, man=man "remembers", men=menn, thing, water, fire, good ...); the
# grammatical function words below appear in essentially every English prose
# line yet never in the Norse.
ENGLISH_MARKERS = %w[
  the and that this with which when then from into where who whom been have has
  had will would should could they them theirs their she his him you your yours
  are were was not but because before after though while does doth unto upon
  every only very most than thus there here itself myself himself herself
  themselves yourself ourselves what whose whence whither shall
].to_set

def word_tokens(line)
  line.split.reject do |t|
    core = t.gsub(/["'“”‘’()\[\],.!?;:—–*|§]/, "")
    core.empty? || core.match?(/\A\d+\z/) || core.match?(/\A[IVXLCivxlc]+\z/)
  end
end

def english_bearing?(line)
  word_tokens(line).any? { |t| ENGLISH_MARKERS.include?(t.downcase.gsub(/[^a-z]/, "")) }
end

def norse_line?(line)
  toks = word_tokens(line)
  return false if toks.size < 2
  return false if english_bearing?(line)
  toks.any? { |w| norse_word?(w) }
end

def flag_fraction(lines)
  words = lines.flat_map { |l| word_tokens(l) }
  return [0.0, 0, 0] if words.empty?
  flags = words.count { |w| norse_word?(w) }
  [flags.to_f / words.size, flags, words.size]
end

def english_heading?(lines)
  return false unless lines.length == 1
  s = lines[0].strip
  letters = s.gsub(/[^A-Za-z]/, "")
  return false if letters.length < 4
  letters.count("A-Z").to_f / letters.length >= 0.5 && english_bearing?(s)
end

DROP_FRACTION = 0.45

def norse_para?(lines)
  return false if english_heading?(lines)
  frac, flags, n = flag_fraction(lines)
  return false if n.zero?
  eng = lines.count { |l| english_bearing?(l) }
  return true if eng.zero? && flags == n            # wholly Norse-flagged tokens
  return true if n <= 2 && flags == n
  native = lines.count { |l| norse_line?(l) }
  return true if native >= 1 && eng.zero? && n >= 2 # pure Norse block
  return true if frac >= DROP_FRACTION && flags >= 3
  false
end

# --- page furniture (single-line paragraphs) --------------------------------
PAGE_JUNK      = /\A[\dlLIioO°>()\[\].,;:*'"\s|§]{1,6}\z/.freeze
RUNNING_HEADER = /\[?\s*BK\.\s|CONTENTS\.?|CORPVS\s+POETICVM|OXFORD|CLARENDON/.freeze
SIGNATURE      = /\A[A-Z]\s?\d{1,2}\z/.freeze # printer signature "B 2", "b 3"

def furniture?(stripped)
  return false unless stripped.length == 1
  s = stripped[0]
  return true if s.match?(PAGE_JUNK)
  return true if s.match?(SIGNATURE)
  return true if s.match?(RUNNING_HEADER) && s.split.size <= 8
  false
end

# --- run ---------------------------------------------------------------------
lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# 1. structural trim (guarded)
abort "title guard failed: #{lines[0].inspect}" unless lines[0].to_s.match?(/\A# Corpus Poeticum Boreale/)
start_i = lines.index { |l| l.strip.match?(/\AINTRODUCTION\.\s*\z/) }
abort "INTRODUCTION. not found" unless start_i
end_i = lines.index { |l| l.strip.match?(/\ANOTES:\s*\z/) }
abort "NOTES: not found" unless end_i && end_i > start_i
stats[:head_trim] = start_i - 1
stats[:tail_trim] = lines.length - end_i
body = [lines[0], ""] + lines[start_i...end_i]

# split into paragraphs
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

if ANALYZE
  keep = drop = 0
  kept_lowconf = []
  dropped_hiconf = []
  paras.each do |para|
    next if furniture?(para.map(&:strip))
    frac, = flag_fraction(para)
    if norse_para?(para)
      drop += 1
      dropped_hiconf << [frac, para] if para.any? { |l| english_bearing?(l) }
    else
      keep += 1
      kept_lowconf << [frac, para] if frac >= 0.25
    end
  end
  puts "=== #{paras.size} paragraphs -> keep=#{keep} drop=#{drop} ==="
  puts "--- KEPT but Norse-heavy (frac>=0.25) : #{kept_lowconf.size} ---"
  kept_lowconf.sort_by { |f, _| -f }.first(24).each do |frac, para|
    puts format("  [%.2f] %s", frac, para.first(2).join(" / ")[0, 150])
  end
  puts "--- DROPPED but shows English markers : #{dropped_hiconf.size} ---"
  dropped_hiconf.sort_by { |f, _| f }.first(24).each do |frac, para|
    puts format("  [%.2f] %s", frac, para.first(2).join(" / ")[0, 150])
  end
  exit
end

# 2 + 3. drop furniture + Norse blocks; 4. inline Norse line drops
kept_paras = []
paras.each do |para|
  stripped = para.map(&:strip)
  if furniture?(stripped)
    stats[:furniture] += 1
    next
  end
  if norse_para?(para)
    stats[:norse_paras] += 1
    next
  end
  filtered = para.reject do |l|
    drop = norse_line?(l)
    stats[:inline_norse_lines] += 1 if drop
    drop
  end
  kept_paras << filtered unless filtered.empty?
end

kept = kept_paras.flat_map { |para| para + [""] }

# 5a. join residual end-of-line hyphenations
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

# 5b. re-join paragraph splits opened by removed blocks / furniture
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

# 5c. neutralise stray angle-bracket scan garble; squeeze spaces; collapse blanks
final = []
blank_run = 0
merged.each do |line|
  out = line.rstrip.tr("<>", "()").gsub(/(?<=\S) {2,}(?=\S)/, " ").sub(/\A\s+/, "")
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
puts "#{File.basename(PATH)}: #{before} -> #{final.length} (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
