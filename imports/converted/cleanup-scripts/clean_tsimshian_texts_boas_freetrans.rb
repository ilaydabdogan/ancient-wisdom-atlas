#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bespoke deterministic cleanup for the Boas "Tsimshian Texts" (BAE Bulletin 27,
# 1902) re-conversion:
#   imports/converted/project-gutenberg/tsimshiantexts00boas-tsimshian-texts-boas.md
#
# Structure: the Nass-River native text is printed with a word-by-word English
# interlinear gloss (native line, then gloss line, each separated by blank
# lines), and a CONTINUOUS-ENGLISH free translation runs as a band interleaved
# page-by-page with it. The free-translation paragraphs are the ONLY continuous
# English in the body; the choppy word-gloss is not. Plus the Introduction and a
# closing "ABSTRACTS" section are continuous English.
#
# Discriminator (deterministic, structural): in this OCR the free-translation
# paragraphs are printed as RUNS OF CONSECUTIVE non-blank lines, whereas every
# interlinear native line and its gloss line is isolated by blank lines. So a
# maximal run of >=3 consecutive non-blank lines that is overwhelmingly English
# (native-signature fraction < 0.34) is free-translation prose and is KEPT;
# everything else (native lines, one/two-line gloss fragments, page furniture,
# and the decorative-endpaper garble at both ends) is dropped. No text is ever
# rewritten -- only whole lines are selected, deleted, and hyphen-joined.

ROOT = File.expand_path("../../..", __dir__)
NAME = "tsimshiantexts00boas-tsimshian-texts-boas.md"

CONTRACTIONS = %w[s t ll ve re d m em clock].freeze

def native_word?(raw)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty?
  return true if w.match?(/[[:alpha:]]8|8[[:alpha:]]/)
  return true if w.match?(/[[:lower:]][A-Z]/)
  return true if w.match?(/[[:alpha:]][;][[:alpha:]]/)
  return true if w.match?(/\A[LXqE]{2,}/)
  return true if w.match?(/[[:alpha:]]"[[:alpha:]]/)      # glued quote k'"ali
  if w.match?(/[[:alpha:]]['’`][[:alpha:]]/)
    suffix = w.split(/['’`]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

def native_line?(line)
  words = line.split.reject { |t| t.gsub(/[^[:alpha:]]/, "").empty? }
  return false if words.empty?
  flags = words.count { |w| native_word?(w) }
  return true if flags >= 2 && flags.to_f / words.size >= 0.40
  return true if words.size <= 2 && flags == words.size && flags.positive?
  false
end

PAGE_JUNK = /\A[\dlLIioO°>()\[\].,;:*'"—-]{1,6}\z/.freeze

def furniture?(s)
  return true if s.match?(PAGE_JUNK)
  return true if s.match?(/ETHNOLOG/)          # caps running header, not prose "ethnologic"
  return true if s.match?(/\[ethnolog/i)
  return true if s.match?(/\bBUREAU\s+OF\b/i)
  return true if s.match?(/TSIMSHIAN\s+TEXTS/i)          # running header
  return true if s.match?(/\[bull\./i)
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

  intro = lines.index { |l| l.strip == "INTRODUCTION" }
  abort "INTRODUCTION not found" unless intro

  abs_start = lines.index { |l| l.strip == "ABSTRACTS" }
  abort "ABSTRACTS heading not found" unless abs_start
  hard_stop = lines.length
  # cut the terminal binding-plate garble: first run of >=6 garble lines after abstracts
  garble = ->(i) { i >= lines.length || lines[i].strip.empty? || wordish(lines[i]) < 2 }
  stop = hard_stop
  run = 0
  ((abs_start + 3)...hard_stop).each do |i|
    if garble.call(i)
      run += 1
      if run >= 6
        stop = i - run + 1
        break
      end
    else
      run = 0
    end
  end

  # walk [intro, stop): keep maximal consecutive non-blank runs that are prose
  out = [title, ""]
  kept_lines = 0
  kept_runs = 0
  i = intro
  while i < stop
    if lines[i].strip.empty?
      i += 1
      next
    end
    j = i
    j += 1 while j < stop && !lines[j].strip.empty?
    block = lines[i...j]
    nat = block.count { |l| native_line?(l.strip) }
    text = block.join(" ")
    letters = text.count("A-Za-z").to_f
    nonspace = text.gsub(/\s/, "").length
    # carets / backslashes never occur in clean prose; they mark column-bleed scramble
    junky = text.count("^") >= 2 || text.count("\\") >= 2
    clean = nonspace.positive? && letters / nonspace >= 0.65 && !junky
    if block.size >= 3 && clean && nat.to_f / block.size < 0.34
      body = block.reject { |l| furniture?(l.strip) }
      if body.length >= 3
        body.each { |l| out << l.rstrip }
        out << ""
        kept_lines += body.length
        kept_runs += 1
      end
    end
    i = j
  end

  # hyphen joins
  joined = []
  i = 0
  while i < out.length
    line = out[i]
    if line.rstrip.match?(/[A-Za-z]-\z/)
      k = i + 1
      k += 1 while k < out.length && out[k].strip.empty?
      if k < out.length && out[k].lstrip.match?(/\A[a-z]/)
        line = line.rstrip.sub(/-\z/, "") + out[k].lstrip
        out.slice!(i + 1..k)
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
  puts "#{NAME}: #{before} -> #{final.length} (runs=#{kept_runs} kept_lines=#{kept_lines})"
end

process
