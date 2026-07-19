#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bespoke deterministic cleanup for the Boas "Kathlamet Texts" (BAE Bulletin 26,
# 1901) re-conversion:
#   imports/converted/project-gutenberg/kathlamettexts00boas-kathlamet-texts-boas.md
#
# This volume is a pure Boas interlinear: every native line is followed by its
# choppy word-by-word English gloss line, and -- unlike Chinook -- there is NO
# per-myth free-translation section. The gloss is not continuous English, so the
# myth bodies cannot be promoted as continuous English. The ONLY continuous
# English in the file is (a) the Introduction historical account and (b) the two
# "ABSTRACTS OF MYTHS" / "ABSTRACTS OF TALKS" sections (prose summaries of every
# myth and tale). This script isolates exactly those two contiguous continuous-
# English regions by explicit start/stop markers, strips page furniture, and
# joins hyphenation. Every transform is mechanical line selection; no text is
# rewritten. The catastrophic library-plate garble at head and tail is dropped.

ROOT = File.expand_path("../../..", __dir__)
NAME = "kathlamettexts00boas-kathlamet-texts-boas.md"

PAGE_JUNK = /\A[\dlLIioO°>()\[\].,;:*'"—-]{1,6}\z/.freeze

def furniture?(s)
  return true if s.match?(PAGE_JUNK)
  return true if s.match?(/\bBUREAU\s+OF\b/i)
  return true if s.match?(/KATHLAMET\s+TEXTS/i)      # running header "boas] KATHLAMET TEXTS 253"
  return true if s.match?(/\[bo?ll?\./i)             # "[boll. 26"
  caps = s.scan(/[A-Z]/).size
  low  = s.scan(/[a-z]/).size
  return true if s.match?(/\d/) && caps > low && s.split.size <= 9
  false
end

def wordish(s)
  s.scan(/[A-Za-z]{3,}/).size
end

def process
  path = File.join(ROOT, "imports/converted/project-gutenberg", NAME)
  abort "missing #{NAME}" unless File.file?(path)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  title = lines[0]

  intro_start = lines.index { |l| l.strip == "INTRODUCTION" }
  abort "INTRODUCTION not found" unless intro_start
  intro_end = (intro_start...lines.length).find { |i| lines[i].strip.match?(/\AAlpha/i) }
  abort "Alphabet marker not found" unless intro_end

  abs_start = lines.index { |l| l.strip.match?(/\AABSTRACTS\s+OF\s+MYTHS/) }
  abort "ABSTRACTS OF MYTHS not found" unless abs_start
  tail = lines.index { |l| l.strip.match?(/LIBRARY\s+OF\s+CONGRESS/i) }
  hard_stop = tail || lines.length
  # The library binding-plate garble begins abruptly after the last abstract;
  # cut at the first run of 3 consecutive garble lines (blank / <2 real words).
  # A page break yields only ~3 garble lines (blank/pagenum/blank); the binding
  # plate is dozens. Require a run of >=6 consecutive garble lines to cut.
  garble = ->(i) { i >= lines.length || lines[i].strip.empty? || wordish(lines[i]) < 2 }
  abs_stop = hard_stop
  run = 0
  ((abs_start + 3)...hard_stop).each do |i|
    if garble.call(i)
      run += 1
      if run >= 6
        abs_stop = i - run + 1
        break
      end
    else
      run = 0
    end
  end

  ranges = [[intro_start, intro_end], [abs_start, abs_stop]]

  kept = [title, ""]
  ranges.each do |a, b|
    block = []
    (a...b).each do |i|
      s = lines[i].strip
      if s.empty?
        block << ""
        next
      end
      next if furniture?(s)
      block << lines[i].rstrip
    end
    # drop trailing garble lines (fewer than 2 real words)
    block.pop while !block.empty? && (block.last.strip.empty? || wordish(block.last) < 2)
    kept.concat(block)
    kept << ""
  end

  # hyphen joins
  joined = []
  i = 0
  while i < kept.length
    line = kept[i]
    if line.rstrip.match?(/[A-Za-z]-\z/)
      j = i + 1
      j += 1 while j < kept.length && kept[j].strip.empty?
      if j < kept.length && kept[j].lstrip.match?(/\A[a-z]/)
        line = line.rstrip.sub(/-\z/, "") + kept[j].lstrip
        kept.slice!(i + 1..j)
        joined << line
        i += 1
        next
      end
    end
    joined << line
    i += 1
  end

  # squeeze double spaces, collapse blank runs, neutralize stray angle brackets
  final = []
  blank_run = 0
  joined.each do |line|
    o = line.rstrip.gsub(/(?<=\S) {2,}(?=\S)/, " ").sub(/\A\s+/, "").tr("<>", "()")
    if o.empty?
      blank_run += 1
      final << "" if blank_run <= 1
    else
      blank_run = 0
      final << o
    end
  end
  final.pop while final.last == ""

  File.write(path, final.join("\n") + "\n")
  puts "#{NAME}: #{before} -> #{final.length}"
end

process
