#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/chukcheemytholog00wgbo-chukchee-mythology-bogoras.md
#
# Source: Bogoras, "Chukchee Mythology" (Jesup North Pacific Expedition
# vol. VIII part I, 1910). Layout is the same as Bogoras's Koryak Texts:
# each tale's English free translation is interleaved page-by-page with the
# romanized Chukchee original, the Chukchee given line-by-line with an
# English word-by-word gloss line (plus wrap-over fragments) under each.
# The word-gloss lines scramble English word order ("take his wife Oh, to
# the (open) they took him") and are dropped together with the Chukchee;
# the continuous-English free translation is kept. Modeled on
# clean_koryak_texts_bogoras.rb. Mechanical line selection/deletion/joining
# only - no text is rewritten.
#
# Transforms:
#   1. Structural trim (guarded): keep the "# ..." title and everything from
#      "I. - INTRODUCTION." to the tale body end; drop the series title
#      pages/plan-of-publication front matter and the AMNH/Brill publisher
#      catalog tail (from "PUBLICATIONS"). The garbled phonetic-alphabet
#      table inside the introduction is cut ("The following alphabet ..."
#      up to the resuming prose "The terminal sound is often modified ...").
#   2. Delete running headers ("BOGORAS, CHUKCHEE TEXTS/TALES.", "Jesup
#      North Pacific Exped..."), bracketed page markers ("[7]"), and
#      standalone page-number junk.
#   3. Paragraph state machine: a Chukchee-signature paragraph is deleted;
#      the single-line paragraph that follows it is its word-gloss ->
#      deleted (unless it is a numbered sentence or footnote); subsequent
#      short lowercase/parenthesis-opening single-line paragraphs are gloss
#      wrap-overs -> deleted. Chukchee signature per word: glottal-stop "8"
#      glued to letters, ^/pound-sign/slash artifacts, digits inside words,
#      interior capital after lowercase, or an internal apostrophe whose
#      suffix is not an English contraction (covers e'nmen, yara'ni, ...).
#   4. Join end-of-line hyphenations (lowercase and uppercase-name
#      continuations) and re-join paragraph splits left by removed pages.
#   5. Collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/chukcheemytholog00wgbo-chukchee-mythology-bogoras.md")

lines = File.readlines(PATH, chomp: true)
stats = Hash.new(0)

# --- 1. structural trims ------------------------------------------------------
intro = lines.index { |l| l.strip =~ /\AI\.\s*—\s*INTRODUCTION\.\z/ }
abort "intro heading not found" unless intro
alpha_s = (intro...lines.length).find { |i| lines[i].strip =~ /\AThe following alphabet has been used/ }
alpha_e = alpha_s && (alpha_s...lines.length).find { |i| lines[i].strip =~ /\AThe terminal sound is often modified/ }
abort "alphabet-table bounds not found" unless alpha_e
pubs = ((lines.length * 0.9).to_i...lines.length).find { |i| lines[i].strip =~ /\APUBLICATIONS\z/ }
abort "publisher catalog start not found" unless pubs

body = [lines[0], ""] + lines[intro...alpha_s] + lines[alpha_e...pubs]
stats[:head_trim] = intro - 1
stats[:alphabet_cut] = alpha_e - alpha_s
stats[:tail_trim] = lines.length - pubs

# --- 2. page furniture --------------------------------------------------------
HEADER_PATTERNS = [
  /BOGORAS,\s+CHUKCHEE\s+(TEXTS|TALES)/i,
  /Jesup\s+North\s+Pacific\s+Exped/i,
  /\A\[\d{1,3}\]\z/,
  /\AVOL\.\s*VIII\.?\z/i
].freeze
PAGE_JUNK = /\A[0-9()\[\]lIoOSg]{1,5}\z/.freeze

body = body.reject do |line|
  s = line.strip
  if HEADER_PATTERNS.any? { |p| s.match?(p) }
    stats[:running_headers] += 1
  elsif !s.empty? && s.length <= 5 && s.match?(PAGE_JUNK) && s.match?(/\d/)
    stats[:page_junk] += 1
  else
    false
  end
end

# --- 3. Chukchee-signature detection -----------------------------------------
CONTRACTIONS = %w[s t ll ve re d m em clock].freeze

def chukchee_word?(raw)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty?
  return true if w.match?(%r{8/|[\^£]|/})
  return true if w.match?(/[[:alpha:]][0-9][[:alpha:]]/)
  return true if w.match?(/[[:alpha:]]8|8[[:alpha:]]/)
  return true if w.match?(/[[:lower:]][A-Z]/)
  return true if w.match?(/[&#*]/) && w.match?(/[[:alpha:]]/)
  if w.match?(/[[:alpha:]]['’`´][[:alpha:]]/)
    suffix = w.split(/['’`´]/).last.to_s.downcase.gsub(/[^a-z]/, "")
    return true unless CONTRACTIONS.include?(suffix)
  end
  false
end

ENGLISH_STOPWORDS = %w[the a an and of to in on he she it they we you i is
                       was were said say that this all one there then].freeze

def chukchee_line?(line)
  words = line.split.reject { |t| t.gsub(/["'“”‘’()\[\],.!?;:—–-]/, "").match?(/\A\d*\z/) }
  return false if words.empty?
  flags = words.count { |w| chukchee_word?(w) }
  return true if flags >= 4
  return true if flags >= 2 && flags.to_f / words.size >= 1.0 / 3
  return true if words.size <= 2 && flags == words.size && flags.positive?
  if words.size <= 3 && flags >= 1
    return true if words.none? { |w| ENGLISH_STOPWORDS.include?(w.downcase.gsub(/[^a-z]/, "")) }
  end
  false
end

def chukchee_para?(para)
  flagged = para.count { |l| chukchee_line?(l) }
  flagged >= 1 && flagged >= (para.length / 2.0).ceil
end

# Numbered sentences ("1. I raced down from a hill-top ...") and footnotes
# must never be eaten as glosses; Chukchee numbered lines are caught by the
# signature test instead.
NUMBERED_OR_FOOTNOTE = /\A\d{1,3}[.\s]\s*\S/.freeze
CAPS_HEADING = /\A[A-Z][A-Z\s.,'()——:-]{3,}\z/.freeze
TALE_HEADING = /\A[i\d]{1,3}\.\s*\(?[A-Z]/.freeze

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

kept_paras = []
chain = 0 # 2 = expect gloss para, 1 = expect gloss wrap-overs
paras.each do |para|
  stripped = para.map(&:strip)
  if para.length == 1 && stripped[0].match?(CAPS_HEADING)
    chain = 0
    kept_paras << para
    next
  end
  if chukchee_para?(stripped)
    stats[:chukchee_paras] += 1
    chain = 2
    next
  end
  if chain.positive? && !stripped[0].match?(NUMBERED_OR_FOOTNOTE)
    if chain == 2 && para.length <= 2
      stats[:glosses] += 1
      chain = 1
      next
    elsif chain == 1 && para.length == 1 && stripped[0].length <= 50 &&
          stripped[0].match?(/\A[a-z("'“‘\[]/)
      stats[:gloss_wraps] += 1
      next
    end
  end
  # Mixed paragraph: drop Chukchee lines run together with English ones,
  # plus the gloss line directly under each.
  filtered = []
  last_dropped = false
  skip_gloss = 0
  para.each do |line|
    s = line.strip
    if chukchee_line?(s)
      stats[:inline_chukchee_lines] += 1
      skip_gloss = 1
      last_dropped = true
      next
    end
    if skip_gloss.positive? && !s.match?(NUMBERED_OR_FOOTNOTE)
      stats[:inline_glosses] += 1
      skip_gloss -= 1
      last_dropped = true
      next
    end
    skip_gloss = 0
    filtered << line
    last_dropped = false
  end
  chain = last_dropped ? 2 : 0
  kept_paras << filtered unless filtered.empty?
end

kept = kept_paras.flat_map { |para| para + [""] }

# --- 4. hyphen joins + paragraph rejoin --------------------------------------
joined = []
i = 0
while i < kept.length
  line = kept[i]
  while line.rstrip.match?(/[A-Za-z]-\z/)
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    break unless j < kept.length && kept[j].lstrip.match?(/\A[[:alpha:]]/)
    cont = kept[j].lstrip
    break unless cont.match?(/\A[a-z]/) || line.rstrip.match?(/[A-Z][a-z]*-\z/)
    line = line.rstrip.sub(/-\z/, cont.match?(/\A[a-z]/) ? "" : "-") + cont
    stats[:hyphen_joined] += 1
    kept.slice!(i + 1..j)
  end
  joined << line
  i += 1
end

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

# --- 5. squeeze/collapse ------------------------------------------------------
final = []
blank_run = 0
merged.each do |line|
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
puts "#{File.basename(PATH)}: #{lines.length} -> #{final.length} lines " \
     "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
