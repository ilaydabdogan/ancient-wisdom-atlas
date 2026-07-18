#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for the two Cultee/Boas interlinear volumes:
#   imports/converted/project-gutenberg/chinooktexts00boas-chinook-texts-boas.md
#   imports/converted/project-gutenberg/kathlamettexts00boas-kathlamet-texts-boas.md
#
# Source: Franz Boas, "Chinook Texts" (BAE Bulletin 20, 1894) and "Kathlamet
# Texts" (BAE Bulletin 26, 1901), both dictated by Charles Cultee. Layout: the
# native-language text is printed line-by-line with an English word-by-word
# gloss line directly beneath each native line; the Introduction and several
# closing "Beliefs, Customs, and Tales" sections are continuous English prose /
# free translation. Unlike Bogoras's Koryak/Chukchee volumes there is NO
# separate free translation for the myths, so here we KEEP the English gloss
# lines (they are the only English rendering) and DROP the native lines. Every
# transform is mechanical line selection/deletion/joining — no text is ever
# rewritten.
#
# Transforms:
#   1. Structural trim (guarded): keep the "# ..." title line and everything
#      from the standalone "INTRODUCTION." heading onward; drop the library
#      bookplate / cover-scan garble and the OCR'd CONTENTS table at the front,
#      and drop the library card-pocket notice at the very back.
#   2. Delete page furniture: standalone marginal line-numbers / page-numbers,
#      bracketed page markers, and the split running-header fragments
#      ("[BUREAU OF", "ETHNOLOGY", "BOAS", "CHINOOK"/"KATHLAMET" + "MYTH."/
#      "TEXTS." caps banners).
#   3. Delete native-language lines by per-word signature (interior capital
#      after a lowercase letter, a glottal "8" glued to letters, an internal
#      apostrophe whose suffix is not an English contraction, or glued interior
#      punctuation). A line is native when >=2 words are flagged and >=40% of
#      its words are flagged, or it is a 1-2 word line entirely flagged. English
#      prose lines that merely contain one native proper name (Q;Elte',
#      Quila'pax, Katlamat) stay below the threshold and survive.
#   4. Join end-of-line hyphenations and collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)

FILES = {
  "chinooktexts00boas-chinook-texts-boas.md" => {
    tail_cut_from: /\ABoston\s+Public\s+Library\z/
  },
  "kathlamettexts00boas-kathlamet-texts-boas.md" => {
    tail_cut_from: nil # set per-file below if a card-pocket tail is present
  }
}.freeze

HEADER_PATTERNS = [
  /\A\[?\s*BUREAU\s+OF\b/i,
  /\A[L\[]?ETHNOLOGY\b/i,
  /\ABOAS\b/i,
  /\ACHINO[OI][KI]['.]?\b/i,          # CHINOOK / CHINOOI' banner
  /\AKATHLAMET\b/i,
  /MYTH\.?\s*\d*\z/,                    # "CIK^A THEIR MYTH. 13"
  /\ATEXTS\.\z/i,
  /\[ethnology\]?\s*\z/i,
  /\bBULL\.\s/i
].freeze

# standalone page / marginal line numbers, incl. OCR variants (9>, 1L, 113)
PAGE_JUNK = /\A[\dlLIioO°>()\[\].,;:*]{1,5}\z/.freeze

CONTRACTIONS = %w[s t ll ve re d m em clock].freeze

def native_word?(raw)
  w = raw.gsub(/\A["'“”‘’(\[]+/, "").gsub(/["'“”‘’)\],.!?;:]+\z/, "")
  return false if w.empty?
  return true if w.match?(/[[:alpha:]]8|8[[:alpha:]]/)
  return true if w.match?(/[[:lower:]][A-Z]/)          # aLgomEl, na'k, iEmEli
  return true if w.match?(/[[:alpha:]][;][[:alpha:]]/) # glued semicolon Q;Elte'
  return true if w.match?(/\A[LXqE]{2,}/)              # LeXat, LkaL
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

def process(name, spec)
  path = File.join(ROOT, "imports/converted/project-gutenberg", name)
  abort "missing #{name}" unless File.file?(path)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  stats = Hash.new(0)

  # 1. structural trim
  intro = lines.index { |l| l.strip == "INTRODUCTION." }
  abort "#{name}: INTRODUCTION. not found" unless intro
  stats[:head_trim] = intro - 1
  body = [lines[0], ""] + lines[intro..]

  if spec[:tail_cut_from]
    from = (body.length * 0.85).to_i
    cut = (from...body.length).find { |i| body[i].strip.match?(spec[:tail_cut_from]) }
    if cut
      stats[:tail_trim] = body.length - cut
      body = body[0...cut]
    end
  end

  # 2 + 3. furniture + native lines
  kept = body.reject do |line|
    s = line.strip
    next false if s.empty?
    if s.match?(PAGE_JUNK)
      stats[:page_junk] += 1
      next true
    end
    if HEADER_PATTERNS.any? { |p| s.match?(p) } && s.split.size <= 6
      stats[:headers] += 1
      next true
    end
    if native_line?(s)
      stats[:native_lines] += 1
      next true
    end
    false
  end

  # 4. hyphen joins
  joined = []
  i = 0
  while i < kept.length
    line = kept[i]
    if line.rstrip.match?(/[A-Za-z]-\z/)
      j = i + 1
      j += 1 while j < kept.length && kept[j].strip.empty?
      if j < kept.length && kept[j].lstrip.match?(/\A[a-z]/)
        line = line.rstrip.sub(/-\z/, "") + kept[j].lstrip
        stats[:hyphen_joined] += 1
        kept.slice!(i + 1..j)
        joined << line
        i += 1
        next
      end
    end
    joined << line
    i += 1
  end

  # 5. squeeze double spaces, collapse blanks
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

  File.write(path, final.join("\n") + "\n")
  puts "#{name}: #{before} -> #{final.length} (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end

selected = ARGV.empty? ? FILES : FILES.select { |n, _| ARGV.any? { |a| n.include?(a) } }
selected.each { |name, spec| process(name, spec) }
