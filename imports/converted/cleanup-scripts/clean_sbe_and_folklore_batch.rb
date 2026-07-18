#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for the remaining `converted`-status queue
# files (SBE volumes and single-language folklore/scholarly editions),
# driven by a per-file spec table. Mechanical line selection only — no text
# is rewritten.
#
# Operations (in order, all optional per file):
#   head_cut_to:    delete lines between the "# ..." title line and the
#                   first line matching this regex (marker line kept).
#                   Removes cover-scan garble, library bookplates, Google/
#                   Internet Archive boilerplate, and reprint-publisher
#                   catalogs (MLBD series lists, Trubner ads).
#   tail_cut_from:  delete from the first line matching this regex in the
#                   tail region (past `tail_frac` of the file) through EOF.
#                   Removes publisher ad catalogs, OCR-shredded
#                   transliteration tables, library card pockets, covers.
#   tail_cut_after: same, but the marker line itself is kept (e.g.
#                   "THE END.").
#   drop:           delete any line matching one of these regexes
#                   (file-specific running headers and marginalia,
#                   verified against the file).
#   verso_caps_headers: delete lines of the form "<page num>  <ALL-CAPS
#                   short title>" (>=70% uppercase letters, <=50 chars) —
#                   SBE verso running headers whose OCR-mangled page
#                   numbers made them unique so the generic repeat-based
#                   pass missed them. Footnotes ("3  Doubtful.") and
#                   numbered verse lines are lowercase-dominant and are
#                   kept.
#   dehyphen:       join "word-" EOL with the next non-blank line when it
#                   starts lowercase, consuming intervening blank lines
#                   (these scans are double-spaced, so the generic
#                   adjacent-line join missed them).
#   squeeze:        collapse runs of 2+ internal spaces to one
#                   (double-word-spaced OCR only).
# Blank lines are always collapsed to at most 2 at the end.

DIR = File.expand_path("../project-gutenberg", __dir__)

TRANSLIT = /\ATRANSLITERATION\s+OF\s+ORI(ENTAL)?[A-Z\s]*ALPHABETS?[.,]?\z|\ATRANSLITERATION OF ORIE/

SPECS = {
  "upanishads01ml-upanishads-part-1-muller.md" => {
    head_cut_to: /\ATHE\z/,
    tail_cut_from: /\AJune,  1879\.\z/,
    drop: [/\A\d[\d ]{0,5}\s+\S+UPANISHAD.{0,4}\z/],
    verso_caps_headers: true, dehyphen: true, squeeze: true
  },
  "p2upanishads00mluoft-upanishads-part-2-muller.md" => {
    tail_cut_from: /\AJanuary,  1888\.\z/,
    drop: [/\A\d[\d ]{0,5}\s+\S+UPANISHAD.{0,4}\z/],
    verso_caps_headers: true, dehyphen: true, squeeze: true
  },
  "mlbd.dhammapadasuttni0000fmax-sutta-nipata-fausboll.md" => {
    head_cut_to: /\ASON te NTS\.\z/,
    tail_cut_from: TRANSLIT,
    dehyphen: true
  },
  "mlbd.sacredbooksofeas0000fmax.vol.16-i-ching-legge.md" => {
    head_cut_to: /\ACONBEN TS\z/,
    tail_cut_from: TRANSLIT,
    dehyphen: true
  },
  "buddhistmahayana0049vari-buddhist-mahayana-texts-sbe49.md" => {
    head_cut_to: /\ACONTENTS OF THE TWO PARTS\.\z/,
    tail_cut_from: TRANSLIT,
    dehyphen: true
  },
  "saddharmapundar00cambuoft-saddharma-pundarika-kern.md" => {
    tail_cut_from: TRANSLIT,
    dehyphen: true, squeeze: true
  },
  "jainasutrasparti029233mbp-jaina-sutras-part-1-jacobi.md" => {
    head_cut_to: /\ATHE\z/,
    tail_cut_from: TRANSLIT,
    dehyphen: true
  },
  "zendavesta01darm-zend-avesta-part-1-vendidad.md" => {
    head_cut_to: /\ATHE\z/,
    tail_cut_from: TRANSLIT,
    verso_caps_headers: true, dehyphen: true, squeeze: true
  },
  "zendavesta02darm-zend-avesta-part-2-yasts.md" => {
    head_cut_to: /\ATHE\z/,
    tail_cut_from: TRANSLIT,
    verso_caps_headers: true, dehyphen: true, squeeze: true
  },
  "zendavesta03darm-zend-avesta-part-3-yasna-gathas.md" => {
    head_cut_to: /\ATHE\z/,
    tail_cut_from: TRANSLIT,
    verso_caps_headers: true, dehyphen: true, squeeze: true
  },
  "pahlavitexts01west-pahlavi-texts-part-1-bundahis.md" => {
    head_cut_to: /\ATHE\z/,
    tail_cut_from: TRANSLIT,
    verso_caps_headers: true, dehyphen: true, squeeze: true
  },
  "nihongi1asto-nihongi-volume-1-aston.md" => {
    head_cut_to: /\ATRANSACTIONS AND PROCEEDINGS\z/,
    tail_cut_after: /\ABND OF VOly 1\.\z/,
    dehyphen: true
  },
  "nihongi2asto-nihongi-volume-2-aston.md" => {
    head_cut_to: /\ATRANSACTIONS AND PROCEEDINGS\z/,
    tail_cut_after: /\AYiriaku Tenno, I\. 333-372\.\z/,
    dehyphen: true
  },
  "thricegreatesth02meadgoog-thrice-greatest-hermes-vol2-mead.md" => {
    head_cut_to: /\AThrice-Greatest Hermes\z/,
    dehyphen: true
  },
  "cu31924060029984-book-of-jubilees-charles.md" => {
    head_cut_to: /\ATHE\z/,
    tail_cut_after: /\AEND\z/,
    drop: [
      /\A[xvilXVIL0-9]{1,6}\s+THE BOOK OF JUBILEES\z/,
      /\ATHE BOOK OF JUBILEES\s+\S{1,6}\z/,
      /\ATHE BOOK OF JUBILEES\z/
    ],
    dehyphen: true
  },
  "in.ernet.dli.2015.65659-masnavi-whinfield.md" => {
    drop: [
      /\A.{0,6}MASNA\s?V.{0,12}\z/,           # "THE  MASNA VI." header variants
      /\A\[?book\s+[ivxlIVXL]{1,6}[.\]]{0,2}\z/i, # "[book vi." folio markers
      /\A\d{1,3}[°*']\z/                       # page numbers OCR'd with degree signs
    ],
    dehyphen: true, squeeze: true
  },
  "11542006bsb-sankhya-karika-davies.md" => {
    head_cut_to: /\ATHE SANKHYA KARIKA OF\z/,
    tail_cut_from: /\ABet ie MDZ/,
    drop: [/\A.{0,2}HINDU PHILOSOPHY[.,]?\s+\S{1,4}\z/],
    dehyphen: true
  },
  "polynesianmythol00greyuoft-polynesian-mythology-grey.md" => {
    # Cut after the last readable line of the music appendix: the plates
    # that follow OCR to pure shred, then John Murray ads + card pocket.
    tail_cut_after: /Eastern  Music\."\z/,
    dehyphen: true, squeeze: true
  },
  "cu31924028465320-journey-in-southern-siberia-curtin.md" => {
    head_cut_to: /\AA  JOURNEY\z/,
    dehyphen: true, squeeze: true
  },
  "b21936171-the-melanesians-codrington.md" => {
    tail_cut_after: /\ATHE  END\.\z/,
    drop: [/\A\[CH\.\z/, /\A[IVXL]{1,6}\.\]\z/], # marginal chapter tags
    dehyphen: true, squeeze: true
  },
  "cu31924104074665-animism-folklore-guiana-indians-roth.md" => {
    head_cut_to: /\AAN  INQUIRY  INTO  THE\z/,
    tail_cut_from: /\ANOTE\z/, tail_frac: 0.7,   # BAE index + list of publications
    drop: [/\A[A-Zl]{3,6}\]\s/],                 # "ROTH]/BOTH] ..." running headers
    dehyphen: true, squeeze: true
  },
  "narrativesofrite00markiala-rites-and-laws-of-the-yncas-markham.md" => {
    head_cut_to: /\AWORKS\s+ISSUED\s+BY\z/,
    # The volume contains several narratives; an internal document also
    # ends with "THE END." (line ~7081), so cut at the LAST occurrence
    # (line ~9900, after the index), not the first.
    tail_cut_after: /\ATHE\s+END\.\z/, tail_last: true,
    dehyphen: true, squeeze: true
  },
  "epicsongsofrussi00hapguoft-epic-songs-of-russia-hapgood.md" => {
    head_cut_to: /\ATHE\z/,
    tail_cut_after: /\Ahundred\s+years\.\s+\/\z/,
    drop: [/\AEPI\S{0,2}\s+SONGS\s+OF\s+RUSSIA\b.{0,8}\z/],
    dehyphen: true, squeeze: true
  },
  "cu31924029909086-more-australian-legendary-tales-parker.md" => {
    tail_cut_after: /\AWahn,  crow\.\z/          # glossary end; David Nutt ads follow
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

# Optional ARGV filter: run only for files whose name contains any argument
# substring (used for reruns after restoring a file from git — the passes
# are not idempotent against already-cleaned files).
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
