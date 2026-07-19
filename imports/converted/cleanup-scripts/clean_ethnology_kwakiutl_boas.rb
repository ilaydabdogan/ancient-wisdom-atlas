#!/usr/bin/env ruby
# frozen_string_literal: true

require "set"

# Bespoke deterministic cleanup for the two Boas/Hunt Kwakiutl volumes:
#   imports/converted/project-gutenberg/ethnologyofkwaki00boas-ethnology-kwakiutl-1-boas-hunt.md
#   imports/converted/project-gutenberg/ethnologyofkwaki02boas-ethnology-kwakiutl-2-boas-hunt.md
#
# Source: Franz Boas & George Hunt, "Ethnology of the Kwakiutl" (35th Annual
# Report, Bureau of American Ethnology, 1921), Parts 1 and 2. Layout: for every
# text the English FREE TRANSLATION is printed as its own paragraph block and
# the Kwakiutl original as the next paragraph block; the two alternate down the
# whole work, each broken across pages by running headers and marginal line
# numbers. The Kwakiutl OCR carries a heavy special-character orthography
# (glottal "!", raised "^", pound-sign "£" for the glottal stop, interior
# capitals, glued "8"). We DROP the Kwakiutl blocks and KEEP the English free
# translation. Every transform is mechanical line selection / deletion /
# joining — no text is ever rewritten, paraphrased, or invented.
#
# Transforms:
#   1. Structural trim (guarded by content assertions). Vol 1: keep the "#"
#      title and the ethnographic body from "I. INDUSTRIES" to just before the
#      tail "INDEX"; drop the decorative endpaper scan, the Bureau
#      administrative report, and both CONTENTS page-number tables. Vol 2: keep
#      the "#" title and Books VII-X (Social Divisions, Family Histories, Songs,
#      Addenda) from "VII.— ..." to just before "XI. VOCABULARY"; drop the
#      endpaper scan, the CONTENTS tables, the Kwakiutl-English VOCABULARY /
#      word-list glossary, and the XII Critical Remarks philology + tail Index.
#   2. Delete page furniture: standalone page/line numbers and running-header
#      lines ("boas] INDUSTRIES 59", "58 ETHNOLOGY OF THE KWAKIUTL ...",
#      "TABLE OF CONTENTS", printer signatures).
#   3. Delete Kwakiutl paragraph blocks via a per-word native-signature
#      classifier: a paragraph is dropped when the flagged fraction of its word
#      tokens is high. English blocks survive because they are ordinary English
#      even though they carry native proper names (MEnledzas, K'imgede,
#      Nak!wax"da^x") and roman-numeral genealogy refs ((XXI 1)) which stay well
#      below threshold.
#   4. Delete individual Kwakiutl lines run together with English inside one
#      paragraph (same per-line signature, higher bar).
#   5. Join residual end-of-line hyphenations; re-join paragraph splits opened
#      by removed blocks / furniture; squeeze double spaces; collapse blank runs.
#
# Modes:
#   (default)          rewrite the file(s) in place
#   ANALYZE=1          print per-paragraph flag-fraction histogram + borderline
#                      samples; do NOT write anything

ROOT = File.expand_path("../../..", __dir__)

FILES = {
  "ethnologyofkwaki00boas-ethnology-kwakiutl-1-boas-hunt.md" => {
    title:      /\A# Ethnology of the Kwakiutl, Part 1/,
    body_start: { pat: /\AI\.\s+INDUSTRIES\s*\z/, hint: "I.  INDUSTRIES" },
    body_end:   { pat: /\AINDEX\s*\z/, hint: "INDEX" }
  },
  "ethnologyofkwaki02boas-ethnology-kwakiutl-2-boas-hunt.md" => {
    title:      /\A# Ethnology of the Kwakiutl, Part 2/,
    # Skip the VII "Divisions and Names of Chiefs" native name-registry
    # (English category labels + native names, not free translation); begin at
    # the first narrative section, "Paintings and House Dishes ...".
    body_start: { pat: /\APaintings\s+and\s+House\s+Dishes\s+of\s+the/, hint: "Paintings and House Dishes ..." },
    body_end:   { pat: /\AXI\.\s+VOCABUL/, hint: "XI. VOCABULARY" }
  }
}.freeze

ANALYZE = ENV["ANALYZE"] == "1"

# --- native-signature detection ---------------------------------------------
# English contractions whose apostrophe must NOT count as a native marker.
CONTRACTIONS = %w[s t ll ve re d m em clock].freeze

# High-frequency Kwakiutl function words (normalised, punctuation/diacritics
# stripped). None is an English word; they blanket every native line.
KWAK_LEXICON = %w[
  wa wii lae laem laxa laxens laxes qa qas qaxs qaes qaen yix yixs gil gilmese
  gilemese hemis hefmis hemisa hemisexs lewa lewis lewa lens laena laemxae
  laemxla he hae heem heemis lasa gaxen gaxma nemokwe nemp qas
].freeze

def kwak_word?(raw)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty?
  # pound-sign glottal, raised caret, glued glottal digit "8"
  return true if w.match?(/[£^]/)
  return true if w.match?(/[[:alpha:]]8|8[[:alpha:]]/)
  # interior "!" glued between letters: q!waq!wax, loq!wes, k!ease, Nak!wax
  return true if w.match?(/[[:alpha:]]!(?=[[:alpha:]])/)
  # interior capital after a lowercase letter: nEmp, EmxLa, aekMa, sElgwas
  return true if w.match?(/[[:lower:]][A-Z]/)
  # glued interior quote/double-mark: g"ox, g'ax^ma (apostrophe handled below)
  return true if w.match?(/[[:alpha:]]"[[:alpha:]]/)
  # LX/qE consonant clusters that never open an English word
  return true if w.match?(/\A[LX]{2}/) || w.match?(/[[:alpha:]]L[LX]/)
  # normalised function word
  norm = w.downcase.gsub(/[^a-z]/, "")
  return true if norm.length >= 2 && KWAK_LEXICON.include?(norm)
  # interior apostrophe whose suffix is not an English contraction
  if w.match?(/[[:alpha:]]['’`][[:alpha:]]/)
    suffix = w.split(/['’`]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

# Word tokens, dropping pure-number / roman-numeral / punctuation-only tokens
# (marginal line numbers, "(XXI", "1)", genealogy refs) so they neither count
# for nor against a block.
def word_tokens(line)
  line.split.reject do |t|
    core = t.gsub(/["'“”‘’()\[\],.!?;:—–*|]/, "")
    core.empty? || core.match?(/\A\d+\z/) || core.match?(/\A[IVXLCivxlc]+\z/)
  end
end

def flag_fraction(lines)
  words = lines.flat_map { |l| word_tokens(l) }
  return [0.0, 0, 0] if words.empty?
  flags = words.count { |w| kwak_word?(w) }
  [flags.to_f / words.size, flags, words.size]
end

# Words that appear only in Boas's English free translation, never in the
# Kwakiutl text: grammatical function words plus a few ultra-common English
# content words of this ethnography. A line carrying any of these is
# "English-bearing" and can never be scored native — this cleanly protects
# short English lines that also carry a native proper name.
ENGLISH_MARKERS = %w[
  the and of that this with for they them their when then from into which who
  whom where been have has had will would could should must are were was she
  her his him you your not but all after before because only upon there here
  name named gave give made make take takes went come came married son
  daughter chief princess tribe tribes people house water wood day man woman
  women fire dish feast four five six seven ten hundred blankets copper about
  down over into out again very good many other some
].to_set

def english_bearing?(line)
  word_tokens(line).any? { |t| ENGLISH_MARKERS.include?(t.downcase.gsub(/[^a-z]/, "")) }
end

def native_line?(line)
  toks = word_tokens(line)
  return false if toks.size < 2
  return false if english_bearing?(line)
  toks.any? { |w| kwak_word?(w) }
end

# A single-line section title (mostly capitals) that carries an English marker
# is always kept, even when OCR sprinkled interior capitals through it
# ("LoVE-SONG OF THE DeAD, HeARD ON ShELL IsLAND").
def english_heading?(lines)
  return false unless lines.length == 1
  s = lines[0].strip
  letters = s.gsub(/[^A-Za-z]/, "")
  return false if letters.length < 4
  upper = letters.count("A-Z")
  upper.to_f / letters.length >= 0.5 && english_bearing?(s)
end

# Dense-native fallback for the rare block where a stray English token slipped
# into an otherwise all-Kwakiutl block.
DROP_FRACTION = 0.45

def kwak_para?(lines)
  return false if english_heading?(lines)
  frac, flags, n = flag_fraction(lines)
  return false if n.zero?
  # every assessable token is native-flagged (numbered native word-lists,
  # song-name lists) and nothing English-bearing
  eng = lines.count { |l| english_bearing?(l) }
  return true if eng.zero? && flags == n
  return true if n <= 2 && flags == n
  # pure native block: at least one native line and NO English-bearing line
  native = lines.count { |l| native_line?(l) }
  return true if native >= 1 && eng.zero? && n >= 2
  # very dense native even if one English word slipped in
  return true if frac >= DROP_FRACTION && flags >= 3
  false
end

# Page furniture (single-line paragraphs).
PAGE_JUNK       = /\A[\dlLIioO°>()\[\].,;:*'"\s|]{1,6}\z/.freeze
RUNNING_HEADER  = /\A(boas|BOAS|eoas|lio|EOASJ)\s*[\]J]?\s+[A-Z]/.freeze
CONTENTS_HDR    = /\A(TABLE\s+OF\s+CONTENTS|CONTENTS|Page[.-]?|PAGE\.?)\b/.freeze
KWAK_TITLE_HDR  = /ETHNOLOGY\s+OF\s+THE\s+KWAKIUTL/.freeze
PRINTER_SIG     = /eth[.,]\s*ann|Ietii\.|\bann\.\s*3|LETH\.|lETH\./.freeze
# running-header banner words: the section name plus a page number and/or
# scan garble, e.g. "uuasJ INDUSTRIES 83", "SONGS j.^jl", "ADDENDA 1345".
HEADER_BANNER   = /\b(INDUSTRIES|KECIPES|RECIPES|SONGS|ADDENDA|VOCABULAR|CRITICAL|CONTENTS|DIVISIONS|HISTORIES)\b/.freeze

def furniture?(stripped)
  return false unless stripped.length == 1
  s = stripped[0]
  return true if s.match?(PAGE_JUNK)
  return true if s.match?(RUNNING_HEADER)
  return true if s.match?(CONTENTS_HDR)
  return true if s.match?(KWAK_TITLE_HDR) && s.split.size <= 9
  return true if s.match?(PRINTER_SIG) && s.split.size <= 9
  # page-header banner: a page number + a KWAKIUTL/ETHNOLOGY title (incl. OCR
  # garble like "1154 ETHXOLXKJY OF THE KWAKrCTL"), set mostly in capitals.
  letters = s.gsub(/[^A-Za-z]/, "")
  if s.match?(/\b\d{2,4}\b/) && s.match?(/KWAK|ETHN|ETH[A-Z]OL/i) &&
     s.split.size <= 10 && letters.length >= 6 &&
     letters.count("A-Z").to_f / letters.length >= 0.6
    return true
  end
  # banner header word with a page number and no lowercase prose (title-only)
  if s.match?(HEADER_BANNER) && s.split.size <= 5 && s.match?(/\d/) &&
     s.gsub(/[^a-z]/, "").length <= 3
    return true
  end
  false
end

def process(name, spec)
  path = File.join(ROOT, "imports/converted/project-gutenberg", name)
  abort "missing #{name}" unless File.file?(path)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  stats = Hash.new(0)

  # 1. structural trim (guarded)
  abort "#{name}: title guard failed: #{lines[0].inspect}" unless lines[0].to_s.match?(spec[:title])
  start_i = lines.index { |l| l.strip.match?(spec[:body_start][:pat]) }
  abort "#{name}: body_start '#{spec[:body_start][:hint]}' not found" unless start_i
  end_i = (start_i...lines.length).find { |i| lines[i].strip.match?(spec[:body_end][:pat]) }
  abort "#{name}: body_end '#{spec[:body_end][:hint]}' not found" unless end_i
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
    drop = keep = 0
    kept_lowconf = []
    dropped_hiconf = []
    paras.each do |para|
      next if furniture?(para.map(&:strip))
      frac, = flag_fraction(para)
      if kwak_para?(para)
        drop += 1
        # a dropped block that still shows English markers is worth eyeballing
        dropped_hiconf << [frac, para] if para.any? { |l| english_bearing?(l) }
      else
        keep += 1
        # a kept block with a high native fraction is worth eyeballing
        kept_lowconf << [frac, para] if frac >= 0.25
      end
    end
    puts "=== #{name} : #{paras.size} paragraphs -> keep=#{keep} drop=#{drop} ==="
    puts "--- KEPT but native-heavy (frac>=0.25) : #{kept_lowconf.size} ---"
    kept_lowconf.sort_by { |f, _| -f }.first(20).each do |frac, para|
      puts format("  [%.2f] %s", frac, para.first(2).join(" / ")[0, 150])
    end
    puts "--- DROPPED but shows English markers : #{dropped_hiconf.size} ---"
    dropped_hiconf.sort_by { |f, _| f }.first(20).each do |frac, para|
      puts format("  [%.2f] %s", frac, para.first(2).join(" / ")[0, 150])
    end
    return
  end

  # 2 + 3. drop furniture + Kwakiutl blocks; 4. inline line drops
  kept_paras = []
  paras.each do |para|
    stripped = para.map(&:strip)
    if furniture?(stripped)
      stats[:furniture] += 1
      next
    end
    if kwak_para?(para)
      stats[:kwak_paras] += 1
      next
    end
    filtered = para.reject do |l|
      toks = word_tokens(l)
      next false if toks.empty?
      flags = toks.count { |w| kwak_word?(w) }
      drop = flags >= 3 && flags.to_f / toks.size >= 0.5
      stats[:inline_kwak_lines] += 1 if drop
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

  # 5c. squeeze double spaces, collapse blank runs. Every "<"/">" in this text
  # is OCR figure-garble (English prose never uses them); neutralise to parens
  # so no HTML-like tag survives.
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

  File.write(path, final.join("\n") + "\n")
  puts "#{name}: #{before} -> #{final.length} (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end

selected = ARGV.empty? ? FILES : FILES.select { |n, _| ARGV.any? { |a| n.include?(a) } }
selected.each { |name, spec| process(name, spec) }
