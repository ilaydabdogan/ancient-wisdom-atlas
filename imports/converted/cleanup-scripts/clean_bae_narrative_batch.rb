#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for seven Bureau-of-American-Ethnology /
# AMNH narrative & song volumes (English myth free-translations and
# descriptive ethnography), driven by a per-file spec table. Mechanical
# line selection only — no text is ever rewritten or paraphrased. Song-text
# lines (native words + English gloss) and musical-notation artifacts in the
# Densmore volumes are intentionally left inline; only page furniture and
# front/back matter are touched.
#
# Operations (in order, all optional per file):
#   head_cut_to:    delete lines between the "# ..." title line and the first
#                   line matching this regex (marker line kept). Removes cover
#                   scan garble, Google/Internet-Archive boilerplate, the
#                   Bureau administrative annual report, and the volume's
#                   contents / list-of-songs / illustrations front matter.
#   tail_cut_from:  delete from the first line matching this regex in the tail
#                   region (past `tail_frac` of the file) through EOF. Removes
#                   the index, bibliography, and library card-pocket furniture.
#   tail_cut_after: same, but the marker line itself is kept.
#   drop:           delete any line matching one of these regexes (file-
#                   specific running headers, verified against the file — e.g.
#                   the OCR-garbled BAE verso "<pg> SENECA FICTION ... MYTHS"
#                   and recto "<author>] FICTION <pg>" running heads).
#   repeat_headers: delete short lines whose digit/punct-stripped normalized
#                   form repeats >= N times AND that carry a digit or are all
#                   upper-case (the generic clean_ocr_conversion.rb heuristic;
#                   catches consistent per-page running headers). Mixed-case
#                   prose and refrains survive.
#   strip_pages:    delete standalone integer / bracketed-integer page-number
#                   lines (default true).
#   boilerplate:    delete "Hosted by Google" / "Digitized by ..." /
#                   "archive.org" scanner lines (default true).
#   dehyphen:       join "word-" EOL with the next non-blank line when it
#                   starts lowercase, consuming intervening blank lines (these
#                   scans are double-spaced).
#   squeeze:        collapse runs of 2+ internal spaces to one (double-word-
#                   spaced Google OCR only; NOT applied to the Densmore volumes
#                   so song-text / notation column spacing is preserved).
# Blank lines are always collapsed to at most 2 at the end.
#
# Guarded: raises if a declared head/tail marker is not found, so a silent
# mis-cut can never ship.

DIR = File.expand_path("../project-gutenberg", __dir__)

# BAE verso running header: "<page>  SENECA FICTION, LEGENDS, AND MYTHS [..]"
# The page number and bracketed reference garble per page, but the run up to
# the reliably-OCR'd word MYTHS is entirely non-lowercase.
SENECA_VERSO = /\A\d{1,3}[^a-z]{3,}MYTHS/
# BAE recto running header: "<garbled author>]  FICTION/LEGENDS  <page>".
# Starts with a short token closing a bracket, ends on the page number.
SENECA_RECTO = /\A.{0,12}\]\s+\S.*\d[^a-z0-9]{0,4}\z/

SPECS = {
  "senecafictionle00hewigoog-seneca-fiction-legends-myths-curtin-hewitt.md" => {
    head_cut_to: /\ASENECA  FICTION,  LEGENDS,  AND  MYTHS\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    drop: [SENECA_VERSO, SENECA_RECTO],
    repeat_headers: 15, dehyphen: true, squeeze: true
  },
  "thezueniindians00stevrich-zuni-indians-stevenson.md" => {
    head_cut_to: /\ATHE  ZUNI  INDIANS:  THEIR  MYTHOLOGY,  ESOTERIC\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.8,
    drop: [SENECA_RECTO],
    repeat_headers: 15, dehyphen: true, squeeze: true
  },
  "sia00stevgoog-the-sia-stevenson.md" => {
    head_cut_to: /\ABy  Matilda  Coxe  Stevenson\.\*\z/,
    # Volume is the complete 11th Annual Report (Sia + Turner Ungava + Dorsey
    # Siouan Cults papers, all English ethnography — kept), then the combined
    # index whose heading OCR'd as "INIDEX." (a later running header reads
    # "INDEX.").
    tail_cut_from: /\AINI?DEX\.?\z/, tail_frac: 0.9,
    drop: [SENECA_RECTO],
    repeat_headers: 15, dehyphen: true, squeeze: true
  },
  "mythstraditionso0025lowi-myths-traditions-crow-lowie.md" => {
    head_cut_to: /\AMYTHS  AND  TRADITIONS  OF  THE  CROW  INDIANS\.\z/,
    tail_cut_from: /\ADATE  DUE\z/, tail_frac: 0.95,
    repeat_headers: 15, dehyphen: true, squeeze: true
  },
  "chippewamusic01dens-chippewa-music-1-densmore.md" => {
    head_cut_to: /\AANALYSIS  OF  CHIPPEWA  MUSIC\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    repeat_headers: 15, dehyphen: true
  },
  "chippewamusic02dens-chippewa-music-2-densmore.md" => {
    head_cut_to: /\AANALYSIS  OF  CHIPPEWA  MUSIC\z/,
    tail_cut_from: /\AAUTHORITIES   CITED\z/, tail_frac: 0.9,
    repeat_headers: 15, dehyphen: true
  },
  "tetonsiouxmusic00densgoog-teton-sioux-music-densmore.md" => {
    head_cut_to: /\ABy  FRANCES  DENSMORE\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    repeat_headers: 15, dehyphen: true
  }
}.freeze

BOILERPLATE = [
  /\AHosted by Google\z/i,
  /\ADigiti[sz]ed by (the )?(Google|Internet Archive|Microsoft)/i,
  /\Ahttps?:\/\/(www\.)?archive\.org/i
].freeze

def normalized_header(line)
  line.gsub(/[\d\[\]().:;,'"*—–-]+/, " ").squeeze(" ").strip.downcase
end

# Optional ARGV filter: run only for files whose name contains any argument.
selected = ARGV.empty? ? SPECS : SPECS.select { |n, _| ARGV.any? { |a| n.include?(a) } }

selected.each do |name, spec|
  path = File.join(DIR, name)
  abort "missing #{name}" unless File.file?(path)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  stats = Hash.new(0)

  if spec[:head_cut_to]
    idx = (1...lines.length).find { |i| lines[i].strip =~ spec[:head_cut_to] }
    raise "#{name}: head marker not found" unless idx
    stats["head_trim"] = idx - 1
    lines = [lines[0]] + lines[idx..]
  end

  if spec[:tail_cut_from] || spec[:tail_cut_after]
    re = spec[:tail_cut_from] || spec[:tail_cut_after]
    from = (lines.length * (spec[:tail_frac] || 0.5)).to_i
    idx = (from...lines.length).find { |i| lines[i].strip =~ re }
    raise "#{name}: tail marker not found" unless idx
    keep_to = spec[:tail_cut_after] ? idx : idx - 1
    stats["tail_trim"] = lines.length - keep_to - 1
    lines = lines[0..keep_to]
  end

  # Repeat-based running-header detection over the post-cut body.
  running_headers = {}
  if spec[:repeat_headers]
    counts = Hash.new(0)
    lines.each do |line|
      s = line.strip
      next if s.empty? || s.length > 60
      form = normalized_header(s)
      next if form.empty? || form.length < 4
      counts[form] += 1 if s.match?(/\d/) || s == s.upcase
    end
    running_headers = counts.select { |_, c| c >= spec[:repeat_headers] }
    running_headers = running_headers.keys.to_h { |k| [k, true] }
  end

  drops = spec[:drop] || []
  strip_pages = spec.fetch(:strip_pages, true)
  boilerplate = spec.fetch(:boilerplate, true)

  lines = lines.reject do |line|
    s = line.strip
    if boilerplate && BOILERPLATE.any? { |re| s.match?(re) }
      stats["boilerplate"] += 1
      true
    elsif strip_pages && s.match?(/\A\[?\d{1,4}\]?\z/)
      stats["page_numbers"] += 1
      true
    elsif drops.any? { |re| s =~ re }
      stats["dropped"] += 1
      true
    elsif !s.empty? && s.length <= 60 && running_headers[normalized_header(s)] &&
          (s.match?(/\d/) || s == s.upcase)
      stats["running_headers"] += 1
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
