#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for
#   imports/converted/project-gutenberg/theegyptianheave01budgiala-egyptian-heaven-and-hell-v1-am-tuat.md
# Mechanical line selection only — no text is rewritten.
#
#   1. Head trim: OCR'd cover/bookplate garble + "Books on Egypt and
#      Chaldaea" publisher series advertisement (lines between the "# ..."
#      title line and the garbled series half-title "Boolf^g on igQ^pt ...",
#      inclusive). The real title page ("THE / EGYPTIAN HEAVEN AND HELL")
#      follows immediately.
#   2. Tail trim: everything after "END   OF   VOL.   I." (printer
#      colophon, UCLA library slip, OCR'd cover plates).
#   3. Running headers after the body-start heading "THE BOOK AM-TUAT":
#      caps-only lines containing "BOOK OF AM-TUAT"/"BOOK AM-TUAT"
#      (verso headers, often with OCR-mangled page numbers like "igO"),
#      and caps-only "… DIVISION — NAME  page" recto headers. Genuine
#      chapter headings ("THE FIRST DIVISION OF THE TUAT," etc.) contain
#      "DIVISION OF THE TUAT/THAT" and are preserved.
#   4. Hieroglyph-OCR junk lines: the printed hieroglyphic text OCRs to
#      symbol salad ("AAAAAA ^-^", "I I I <=^ ^"). A line is dropped when
#      its "wordish" character ratio is < 0.5 AND none of the protections
#      below apply. Wordish token = alphabetic run with at least one vowel
#      and one consonant and 2+ distinct letters (single a/i/o/A/I/O also
#      count). Protections (kept even at low ratio): 3+ wordish tokens;
#      2+ wordish tokens with one of length >= 4; numbered god-name list
#      entries ("9.  Tait, ..."); lines opening with a proper name and
#      comma/period (incl. hyphenated Egyptian names, optional "(?)");
#      quoted translation captions ('"life," -?-.'); "(see p./pp. …)"
#      cross-references; short bracketed English fragments ("it],");
#      standalone arabic/roman numerals (structural numbering).
#   5. Collapse runs of 2+ internal spaces to one; collapse 3+ blank
#      lines to 2.

PATH = File.expand_path("../project-gutenberg/theegyptianheave01budgiala-egyptian-heaven-and-hell-v1-am-tuat.md", __dir__)

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# 1. Head trim.
half_title = lines.index { |l| l.strip.start_with?("Boolf^g") }
raise "head marker not found" unless half_title && half_title < 500
lines = [lines[0]] + lines[(half_title + 1)..]
stats["head_trim"] = half_title

# 2. Tail trim.
end_vol = lines.rindex { |l| l.strip =~ /\AEND\s+OF\s+VOL\.\s+I\.\z/ }
raise "tail marker not found" unless end_vol && end_vol > lines.length - 300
stats["tail_trim"] = lines.length - end_vol - 1
lines = lines[0..end_vol]

# 3. Running headers, after the body-start heading.
errata = lines.index { |l| l.strip == "EEEATA" || l.strip == "ERRATA" }
raise "errata marker not found" unless errata
body_start = lines.each_index.find { |i| i > errata && lines[i].strip =~ /\ATHE\s+BOOK\s+AM-TUAT\z/ }
raise "body start not found" unless body_start

caps_only = ->(s) { !s.match?(/[a-z]/) }
kept = []
lines.each_with_index do |line, i|
  s = line.strip
  if i > body_start && caps_only.call(s)
    if s.match?(/BOOK\s+O[FK]\s+AM-TUAT|BOOK\s+AM-TUAT/)
      stats["verso_headers"] += 1
      next
    end
    if s.match?(/DIVISION/) && !s.match?(/DIVISION[,]?\s+O[FR]\s+.*T[UH]AT|VESTIBULE/)
      stats["recto_headers"] += 1
      next
    end
  end
  kept << line
end

# 4. Hieroglyph-OCR junk lines.
def wordish_tokens(s)
  s.scan(/[A-Za-z]+/).select do |r|
    if r.length == 1
      r.match?(/[aioAIO]/)
    else
      r.match?(/[aeiouyAEIOUY]/) && r.match?(/[^aeiouyAEIOUY\W]/) && r.chars.uniq.length > 1
    end
  end
end

def junk?(s)
  return false if s.match?(/\A(\d{1,3}|[ivxlcIVXLC]{1,6})[.,]?\z/) # structural numbering
  toks = wordish_tokens(s)
  nonspace = s.gsub(/\s/, "").length
  return false if nonspace.zero?
  return false if toks.sum(&:length).to_f / nonspace >= 0.5
  return false if toks.length >= 3
  return false if toks.length >= 2 && toks.any? { |t| t.length >= 4 }
  return false if s.match?(/\b\d{1,2}\.\s+[A-Z][a-z]/)                                  # "9.  Tait, ..."
  return false if s.match?(/\A["'“”‘’]?[A-Z][a-z]+(-[a-zA-Z]+)*\s*(\(\?\))?\s*[.,]/)    # "Sekhet (?), ..."
  return false if s.match?(/\A["'“”‘’]\s*[a-z]+/)                                       # '"life," ...'
  return false if s.match?(/\(see\s+pp?\./)                                             # cross-refs
  return false if s.match?(/\A[a-z]+\]?[,.]\z/)                                         # "it],"
  true
end

filtered = kept.reject do |line|
  s = line.strip
  next false if s.empty?
  if junk?(s)
    stats["hieroglyph_junk"] += 1
    true
  else
    false
  end
end

# 5. Space squeeze + blank collapse.
final = []
blank_run = 0
filtered.each do |line|
  if line.strip.empty?
    blank_run += 1
    final << "" if blank_run <= 2
  else
    blank_run = 0
    final << line.rstrip.gsub(/(?<=\S) {2,}(?=\S)/, " ")
  end
end

File.write(PATH, final.join("\n") + "\n")
puts "#{File.basename(PATH)}: #{before} -> #{final.length} lines (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
