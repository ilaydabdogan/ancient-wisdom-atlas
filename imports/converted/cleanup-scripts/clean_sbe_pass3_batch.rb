#!/usr/bin/env ruby
# frozen_string_literal: true

# Pass-3 deterministic cleanup for eight prose Sacred-Books-of-the-East
# volumes (Legge's Shu/Shih King and Li Ki, Rhys Davids' Questions of King
# Milinda, and the three Vinaya Texts volumes), driven by a per-file spec
# table. This mirrors the engine of clean_sbe_and_folklore_batch.rb exactly
# — mechanical line selection/deletion/joining only. NO text is ever
# rewritten, paraphrased, or edited; every operation is a guarded structural
# cut or a whole-line drop that raises if its marker is not found.
#
# Operations (in order, all optional per file):
#   head_cut_to:    delete lines between the "# ..." title line and the
#                   first line matching this regex (marker line kept).
#                   Used to drop the CONTENTS / TRANSLITERATION front-matter
#                   tables and title-page scan garble that precede the real
#                   Preface / Introduction / first book heading.
#   tail_cut_from:  delete from the first line matching this regex in the
#                   tail region (past `tail_frac` of the file) through EOF.
#   tail_cut_after: same, but the marker line itself is kept.
#   drop:           delete any line matching one of these regexes
#                   (file-specific running headers verified against the
#                   file, e.g. OCR-garbled Milinda verso headers whose
#                   mangled page prefixes "^6"/"xlii"/"t6" dodge the generic
#                   digit-anchored verso pass).
#   verso_caps_headers: delete "<page num>  <ALL-CAPS short title>" verso
#                   running headers (>=70% uppercase, <=50 chars). SBE
#                   headers whose OCR-mangled page numbers made them unique,
#                   so the generic repeat-based detector missed them.
#   recto_caps_headers: symmetric to verso — delete "<ALL-CAPS short title>
#                   <page num>" recto running headers (title >=70%
#                   uppercase, <=50 chars, line ends in a page number).
#                   Catches "CHAP. 2. THE CANON OF YAO. 33",
#                   "SECT. I. YU 3Ao. 3", "THE PAVARAJVA CEREMONY. 355".
#                   Prose sentences carry lowercase words (ratio < 0.7) and
#                   footnote citations end in a period, so both survive.
#   dehyphen:       join "word-" EOL with the next non-blank line when it
#                   starts lowercase, consuming intervening blank lines
#                   (these scans are double-spaced).
#   squeeze:        collapse runs of 2+ internal spaces to one.
# Blank lines are always collapsed to at most 2 at the end.

DIR = File.expand_path("../project-gutenberg", __dir__)

SPECS = {
  # Front matter: title-page + CONTENTS table before the real "PREFACE."
  # No transliteration/index/catalog back matter present (ends in text).
  "sacredbooksofch03conf-shu-king-shih-king-legge.md" => {
    head_cut_to: /\APREFACE\.\z/,
    verso_caps_headers: true, recto_caps_headers: true,
    dehyphen: true, squeeze: true
  },
  # CONTENTS + transliteration table before the preface. The preface's own
  # "PREFACE." heading was OCR-destroyed to garble ("gh GH DM aid Cd 3."),
  # and the only clean "PREFACE" tokens in the front matter are the page-xi..
  # page-xiv verso/recto RUNNING headers *inside* the preface — so anchoring
  # on "PREFACE" would cut the preface's first two pages. Anchor instead on
  # the verified first line of preface prose (Legge, "I MAY be permitted..").
  "sacredbooksofchi0027unse-li-ki-part1-legge.md" => {
    head_cut_to: /\AI MAY be permitted to express/,
    verso_caps_headers: true, recto_caps_headers: true,
    dehyphen: true, squeeze: true
  },
  # Head already clean: title line then "BOOK XI. YU 3A0" content. No cut.
  "mlbd.sacredbooksofeas0000fmax.vol.28-li-ki-part2-legge.md" => {
    verso_caps_headers: true, recto_caps_headers: true,
    dehyphen: true, squeeze: true
  },
  # Head already clean: title then real "INTRODUCTION." text. Garbled verso
  # headers ("^6 THE QUESTIONS OF KING MILTNDA.", "xlii TOE QUESTIONS OF
  # KING MILINDA.", "t6 the questions of king MILINDA.") dropped by regex;
  # the mixed-case title line is safe (not all-caps, not all-lowercase).
  "questionsofkingm01davi-questions-of-king-milinda-part1.md" => {
    drop: [/QUESTIONS OF KING/, /the questions of king/],
    verso_caps_headers: true, recto_caps_headers: true,
    dehyphen: true, squeeze: true
  },
  # Part II's recto running header is "OF MILINDA THE KING <page>", which OCR
  # frequently lower-cased ("of milinda the king. 5") so the caps-ratio recto
  # pass misses it. The drop matches the header form only — "KING" must sit at
  # the line end (optionally followed by page-number garble), so real prose
  # like "Now Milinda the king went up to the place" is kept.
  "questionsofkingm02davi-questions-of-king-milinda-part2.md" => {
    drop: [/QUESTIONS OF KING/, /the questions of king/,
           /MILINDA T[A-Z]+ KING[.,]?[\dilI ]*\z/i],
    verso_caps_headers: true, recto_caps_headers: true,
    dehyphen: true, squeeze: true
  },
  # CONTENTS + transliteration-listing before the standalone "INTRODUCTION"
  # heading of the real text.
  "sacredbookseast13mulluoft-vinaya-texts-part1.md" => {
    head_cut_to: /\AINTRODUCTION\z/,
    verso_caps_headers: true, recto_caps_headers: true,
    dehyphen: true, squeeze: true
  },
  # CONTENTS before the "MAHAVAGGA." book heading (no separate introduction
  # in this volume).
  "vinayatexts02davi-vinaya-texts-part2.md" => {
    head_cut_to: /\AMAHAVAGGA\.\z/,
    verso_caps_headers: true, recto_caps_headers: true,
    dehyphen: true, squeeze: true
  },
  # CONTENTS (incl. index + transliteration listing) before "ATULLAVAGGA."
  "in.ernet.dli.2015.189082-vinaya-texts-part3.md" => {
    head_cut_to: /\AATULLAVAGGA\.\z/,
    verso_caps_headers: true, recto_caps_headers: true,
    dehyphen: true, squeeze: true
  }
}.freeze

def verso_caps_header?(line)
  m = line.match(/\A\d[\d ]{0,5}\s+(\S.*)\z/)
  return false unless m
  rest = m[1]
  return false if rest.length > 50
  letters = rest.scan(/[A-Za-z]/)
  return false if letters.length < 4
  letters.count { |c| c =~ /[A-Z]/ }.to_f / letters.length >= 0.7
end

def recto_caps_header?(line)
  m = line.match(/\A(\S.*?)\s+\d[\d ]{0,5}\z/)
  return false unless m
  rest = m[1]
  return false if rest.length > 50
  letters = rest.scan(/[A-Za-z]/)
  return false if letters.length < 4
  letters.count { |c| c =~ /[A-Z]/ }.to_f / letters.length >= 0.7
end

# Optional ARGV filter: run only for files whose name contains any argument
# substring (passes are not idempotent, so reruns must restore from git first).
selected = ARGV.empty? ? SPECS : SPECS.select { |n, _| ARGV.any? { |a| n.include?(a) } }

selected.each do |name, spec|
  path = File.join(DIR, name)
  abort "missing #{name}" unless File.file?(path)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  stats = Hash.new(0)

  if spec[:head_cut_to]
    idx = (1...[lines.length, 1200].min).find { |i| lines[i].strip =~ spec[:head_cut_to] }
    raise "#{name}: head marker not found" unless idx
    stats["head_trim"] = idx - 1
    lines = [lines[0]] + lines[idx..]
  end

  if spec[:tail_cut_from] || spec[:tail_cut_after]
    re = spec[:tail_cut_from] || spec[:tail_cut_after]
    from = (lines.length * (spec[:tail_frac] || 0.5)).to_i
    range = (from...lines.length)
    idx = spec[:tail_last] ? range.to_a.reverse.find { |i| lines[i].strip =~ re } : range.find { |i| lines[i].strip =~ re }
    raise "#{name}: tail marker not found" unless idx
    keep_to = spec[:tail_cut_after] ? idx : idx - 1
    stats["tail_trim"] = lines.length - keep_to - 1
    lines = lines[0..keep_to]
  end

  drops = spec[:drop] || []
  lines = lines.reject do |line|
    s = line.strip
    if drops.any? { |re| s =~ re }
      stats["dropped"] += 1
      true
    elsif spec[:verso_caps_headers] && verso_caps_header?(s)
      stats["verso_headers"] += 1
      true
    elsif spec[:recto_caps_headers] && recto_caps_header?(s)
      stats["recto_headers"] += 1
      true
    else
      false
    end
  end

  if spec[:dehyphen]
    joined = []
    i = 0
    while i < lines.length
      line = lines[i]
      if line =~ /[a-z]-\z/
        j = i + 1
        j += 1 while j < lines.length && lines[j].strip.empty?
        if j < lines.length && lines[j].lstrip =~ /\A[a-z]/
          joined << line.sub(/-\z/, "") + lines[j].lstrip
          stats["dehyphenated"] += 1
          i = j + 1
          next
        end
      end
      joined << line
      i += 1
    end
    lines = joined
  end

  final = []
  blank_run = 0
  lines.each do |line|
    if line.strip.empty?
      blank_run += 1
      final << "" if blank_run <= 2
    else
      blank_run = 0
      line = line.rstrip
      line = line.gsub(/(?<=\S) {2,}(?=\S)/, " ") if spec[:squeeze]
      final << line
    end
  end

  File.write(path, final.join("\n") + "\n")
  puts "#{name}: #{before} -> #{final.length} (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end
