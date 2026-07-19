#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/sancarlosapachet0003godd-san-carlos-apache-texts-goddard.md
#
# Source: Pliny Earle Goddard, "San Carlos Apache Texts" (AMNH Anthropological
# Papers XXIV pt.3). Layout: each text is printed as a block of the Apache
# original followed by its English free translation (the translation carries "|"
# column-position markers and the characteristic "they say"/"he thought"
# narrative). The two alternate as blank-line-separated paragraphs down the whole
# paper. We DROP the Apache blocks and KEEP the English introduction + free
# translations. Discriminator: an English free-translation paragraph is dense
# with English function words, whereas an Apache paragraph contains none. Every
# transform is mechanical line selection/deletion/joining — no text is rewritten.
#
# Transforms:
#   1. Head trim (guarded): keep the "# ..." title, drop the cover-scan garble
#      before "INTRODUCTION.".
#   2. Tail trim (guarded): drop the library "Date Due" card + catalog garble.
#   3. Drop Apache paragraphs: a blank-line-separated paragraph with >= 3 word
#      tokens and ZERO English function words (and not an ALL-CAPS heading).
#   4. Drop residual garble lines (backslash, or no 3+ letter word); strip "|"
#      column markers; neutralize stray "<"/">" -> "("/")".
#   5. Join line-end hyphenations; squeeze double spacing; collapse blank runs.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/sancarlosapachet0003godd-san-carlos-apache-texts-goddard.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. head trim -----------------------------------------------------------
head_idx = (1...lines.length).find { |i| lines[i].strip.match?(/\AINTRODUCTION\b/) }
abort "head marker 'INTRODUCTION' not found" unless head_idx
stats[:head_trim] = head_idx - 1
body = [lines[0], ""] + lines[head_idx..]

# --- 2. tail trim (library Date-Due card) -----------------------------------
from = (body.length * 0.90).to_i
tail_idx = (from...body.length).find { |i| body[i].strip.match?(/\ADate\s+Due\z/i) || body[i].strip.match?(/PRINTED\s+IN\s+U\.?\s?S\.?\s?A/i) }
if tail_idx
  stats[:tail_trim] = body.length - tail_idx
  body = body[0...tail_idx]
end

# --- 3. drop Apache lines (block + inline) ----------------------------------
# An English free-translation line always carries English function words (even
# in Apache word order it keeps he/it/they/again/the...); an Apache line carries
# none. Classify per LINE so Apache lines run together with English inside one
# paragraph are also removed. The "# ..." markdown title (lines[0]) and ALL-CAPS
# section headings are always kept.
# Only unambiguous 3+ letter English function/common words (short words like
# "do", "a", "no", "it", "on" collide with Apache tokens, so they are excluded).
STOP = %w[the and they them then there their was were said say this that with
          you not but for when have has had who what she her his him are from
          again here where those will would could should been into over down
          out all one came went now about because him they'll].to_set

def word_tokens(line)
  line.split.map { |t| t.gsub(/[^A-Za-z']/, "") }.reject(&:empty?)
end

TITLE = body[0]
cleaned = body.reject do |line|
  next false if line.equal?(TITLE)
  s = line.strip
  next false if s.empty?
  if s.include?("\\") || !s.match?(/[A-Za-z]{3,}/)
    stats[:garble] += 1
    next true
  end
  next false if s == s.upcase && s.match?(/[A-Z]/) # keep ALL-CAPS headings
  toks = word_tokens(s)
  if toks.length >= 3 && toks.none? { |w| STOP.include?(w.downcase) }
    stats[:apache_lines] += 1
    next true
  end
  false
end
cleaned.map! { |l| l.tr("<>", "()").gsub("|", " ") }

# --- 5. hyphen join, squeeze, collapse --------------------------------------
joined = []
i = 0
while i < cleaned.length
  line = cleaned[i]
  if line.rstrip.match?(/[a-z]-\z/)
    j = i + 1
    j += 1 while j < cleaned.length && cleaned[j].strip.empty?
    if j < cleaned.length && cleaned[j].lstrip.match?(/\A[a-z]/)
      joined << line.rstrip.sub(/-\z/, "") + cleaned[j].lstrip
      stats[:dehyphenated] += 1
      cleaned.slice!(i + 1..j)
      i += 1
      next
    end
  end
  joined << line
  i += 1
end

final = []
blank_run = 0
joined.each do |line|
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
puts "#{File.basename(PATH)}: #{before} -> #{final.length} lines " \
     "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
