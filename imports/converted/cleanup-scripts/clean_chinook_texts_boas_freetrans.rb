#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bespoke deterministic cleanup for the Boas "Chinook Texts" (BAE Bulletin 20,
# 1894) re-conversion:
#   imports/converted/project-gutenberg/chinooktexts00boas-chinook-texts-boas.md
#
# Unlike the earlier combined script (which KEPT the word-by-word English gloss
# lines), this extracts ONLY the CONTINUOUS ENGLISH: the Introduction historical
# account, and every free-translation block introduced by a standalone
# "Translation." heading, plus the ethnographic "Notes." blocks. The native
# lines AND their choppy word-gloss lines are dropped -- word-gloss is not
# continuous English. Every transform is mechanical line selection / deletion /
# joining; no text is rewritten.
#
# State machine over the body:
#   * head trimmed to the first standalone "INTRODUCTION." -> KEEP (intro prose)
#   * "ALPHABET." (phonetic table) -> DROP
#   * a standalone "Translation." / "Translation" / "Notes." heading -> KEEP
#   * inside a KEEP block, drop page/running-header furniture; exit to DROP on
#     the first native-signature line (native text resuming)
#   * tail card ("Boston Public Library ...") trimmed off

ROOT = File.expand_path("../../..", __dir__)
NAME = "chinooktexts00boas-chinook-texts-boas.md"

CONTRACTIONS = %w[s t ll ve re d m em clock].freeze

def native_word?(raw)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty?
  return true if w.match?(/[[:alpha:]]8|8[[:alpha:]]/)
  return true if w.match?(/[[:lower:]][A-Z]/)
  return true if w.match?(/[[:alpha:]][;][[:alpha:]]/)
  return true if w.match?(/\A[LXqE]{2,}/)
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
  return true if s.match?(/ethnolog/i)
  return true if s.match?(/\bBUREAU\s+OF\b/i)
  return true if s.match?(/\bBULL\.\s/i)
  caps = s.scan(/[A-Z]/).size
  low  = s.scan(/[a-z]/).size
  # running header: has a page number and is largely uppercase, short
  return true if s.match?(/\d/) && caps > low && s.split.size <= 9
  # embedded running header carrying the section banner
  return true if s.match?(/\bTRANSLATION\b/) && norm(s) != "translation"
  # standalone all-caps banner tokens (CHINOOK / BO / KATHLAMET / HISTORICAL ...)
  toks = s.split
  return true if toks.size <= 3 && toks.all? { |t| t.gsub(/[^A-Za-z]/, "") =~ /\A[A-Z]{2,}\z/ }
  false
end

def norm(s)
  s.gsub(/[^A-Za-z]/, "").downcase
end

def keep_trigger?(s)
  n = norm(s)
  n == "translation" || n == "notes"
end

def process
  path = File.join(ROOT, "imports/converted/project-gutenberg", NAME)
  abort "missing #{NAME}" unless File.file?(path)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  title = lines[0]

  intro = lines.index { |l| l.strip == "INTRODUCTION." }
  abort "INTRODUCTION. not found" unless intro

  # tail: cut from Boston Public Library card
  tail = lines.each_index.to_a.reverse.find { |i| lines[i].strip.match?(/\ABoston\s+Public\s+Library\b/i) }
  body_end = tail || lines.length

  state = :keep   # start keeping intro prose
  out = []
  stats = Hash.new(0)

  (intro...body_end).each do |i|
    s = lines[i].strip
    if s.empty?
      out << "" if state != :drop
      next
    end
    # ALPHABET table ends the intro; always drop from there until next trigger
    if norm(s) == "alphabet"
      state = :drop
      stats[:alphabet] += 1
      next
    end
    if keep_trigger?(s)
      state = :keep
      stats[:triggers] += 1
      out << ""            # separator between blocks
      next                 # drop the heading word itself
    end
    next if state == :drop
    # inside a KEEP block
    if native_line?(s)
      state = :drop
      stats[:native_exit] += 1
      next
    end
    if furniture?(s)
      stats[:furniture] += 1
      next
    end
    out << lines[i].rstrip
    stats[:kept] += 1
  end

  # hyphen joins
  joined = []
  i = 0
  while i < out.length
    line = out[i]
    if line.rstrip.match?(/[A-Za-z]-\z/)
      j = i + 1
      j += 1 while j < out.length && out[j].strip.empty?
      if j < out.length && out[j].lstrip.match?(/\A[a-z]/)
        line = line.rstrip.sub(/-\z/, "") + out[j].lstrip
        out.slice!(i + 1..j)
        joined << line
        i += 1
        next
      end
    end
    joined << line
    i += 1
  end

  # squeeze double spaces, collapse blank runs
  final = [title, ""]
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
  puts "#{NAME}: #{before} -> #{final.length} (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end

process
