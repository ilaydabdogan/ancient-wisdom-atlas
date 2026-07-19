#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/centralcaribs0000fara-the-central-caribs-farabee.md
#
# Source: W. C. Farabee, "The Central Caribs" (Univ. of Pennsylvania Museum
# Anthropological Publications X, 1924). The volume opens with continuous English
# descriptive ethnography (Geographical Environment, Material Culture, Social
# Culture, Language) and closes with "The Map" narrative and a Bibliography; in
# between sits ~23,000 lines of non-prose that the review flagged: an
# English-Carib VOCABULARY, per-tribe vocabulary word-lists, NUMERALS, and a
# large anthropometric SOMATIC CHARACTERISTICS measurement number-table. This
# non-prose block is bounded between the first "VOCABULARY" heading and the
# "THE MAP" heading, so it is cut wholesale; the descriptive-ethnography narrative
# plus The Map and Bibliography are kept. The plate-caption back matter is also
# dropped. Every transform is mechanical line selection/deletion/joining — no
# text is rewritten.
#
# Transforms:
#   1. Head trim (guarded): keep the "# ..." title, drop the Internet-Archive /
#      University-Museum title boilerplate before "CONTENTS".
#   2. Cut the non-prose middle: from the first "VOCABULARY" heading up to the
#      "THE MAP" heading (vocabulary lists + per-tribe vocab + NUMERALS +
#      SOMATIC CHARACTERISTICS measurement tables).
#   3. Tail trim: drop the plate-caption block from the first
#      "ANTHR. PUB. UNIV. MUSEUM ... PLATE" banner onward.
#   4. Delete residual stray-garble / no-word lines in the kept text.
#   5. Neutralize stray HTML-like OCR "<"/">" -> "("/")".
#   6. Join line-end hyphenations; squeeze double word-spacing; collapse blanks.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/centralcaribs0000fara-the-central-caribs-farabee.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

find = lambda do |from, re|
  idx = (from...lines.length).find { |i| lines[i].strip.match?(re) }
  abort "marker #{re.inspect} not found past #{from}" unless idx
  idx
end

contents_idx = find.call(1, /\ACONTENTS\z/)
vocab_idx    = find.call(contents_idx + 1, /\AVOCABULARY\z/)
map_idx      = find.call(vocab_idx + 1, /\ATHE\s+MAP\z/)
plates_idx   = find.call(map_idx + 1, /\AANTHR\.\s+PUB/)

stats[:head_trim] = contents_idx - 1
stats[:mid_cut]   = map_idx - vocab_idx
stats[:tail_trim] = lines.length - plates_idx

body = [lines[0], ""] + lines[contents_idx...vocab_idx] + [""] + lines[map_idx...plates_idx]

# --- 4. drop residual stray-garble / no-word lines --------------------------
kept = body.reject do |line|
  s = line.strip
  next false if s.empty?
  unless s.match?(/[A-Za-z]{3,}/)
    stats[:garble_lines] += 1
    next true
  end
  false
end

# --- 5. neutralize <> --------------------------------------------------------
kept.map! { |l| l.tr("<>", "()") }

# --- 6. hyphen join, squeeze, collapse --------------------------------------
joined = []
i = 0
while i < kept.length
  line = kept[i]
  if line.rstrip.match?(/[a-z]-\z/)
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    if j < kept.length && kept[j].lstrip.match?(/\A[a-z]/)
      joined << line.rstrip.sub(/-\z/, "") + kept[j].lstrip
      stats[:dehyphenated] += 1
      kept.slice!(i + 1..j)
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
