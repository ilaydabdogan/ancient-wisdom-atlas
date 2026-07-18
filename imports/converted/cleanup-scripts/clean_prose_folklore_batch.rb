#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for the prose ethnography / folklore volumes
# in the `converted` queue (single-language continuous English editions),
# driven by a per-file spec table. Mechanical line selection only — no text
# is ever rewritten, paraphrased, or edited. Same engine and guarantees as
# clean_sbe_and_folklore_batch.rb; guarded so it aborts if a marker is not
# found rather than making a bad cut.
#
# Operations (in order, all optional per file except the always-on passes):
#   head_cut_to:    delete lines between the "# ..." title line and the first
#                   line matching this regex (marker line kept). Removes
#                   title-page scan garble, library plates, and the CONTENTS /
#                   LIST OF ILLUSTRATIONS block that precedes the real
#                   Preface/Introduction. The leading "# Title" line is always
#                   kept.
#   tail_cut_from:  delete from the first line matching this regex in the tail
#                   region (past `tail_frac` of the file, default 0.5) through
#                   EOF (marker line dropped). Removes index, publisher ads,
#                   and appendices that are clearly tabular / native-language
#                   apparatus (vocabularies, weight-and-measurement tables,
#                   interlinear song texts, glossaries).
#   tail_cut_after: same, but the marker line itself is kept.
#   tail_frac:      fraction of the file after which the tail marker is sought.
#   drop:           delete any line matching one of these regexes (file-specific
#                   running headers / marginalia, verified against the file).
#
# Always-on passes (these OCR archive scans all need them):
#   boilerplate       — scanner artifacts ("Hosted by Google", "Digitized by").
#   page_numbers      — standalone integer / bracketed-integer lines.
#   caps_headers      — running headers of the form "<page num>  ALLCAPS TITLE"
#                       (verso) or "ALLCAPS TITLE  <page num>" (recto): the
#                       title part must be <=50 chars and >=70% uppercase
#                       letters (>=4 letters). Footnotes ("3  Doubtful.") and
#                       numbered verse lines are lowercase-dominant and kept;
#                       roman-numeral chapter headings ("CHAPTER V") carry no
#                       arabic page number and are kept.
#   dehyphen          — join "word-" EOL with the next non-blank line when it
#                       starts lowercase, consuming intervening blank lines
#                       (these scans are double-spaced).
#   squeeze           — collapse runs of 2+ internal spaces to one.
# Blank lines are always collapsed to at most 2 at the end.

DIR = File.expand_path("../project-gutenberg", __dir__)

SPECS = {
  # Ends with the folk-lore tales (parrot story); no index/ads follow.
  "shansathomewitht00milnrich-shans-at-home-milne.md" => {
    head_cut_to: /\AINTRODUCTION\z/
  },
  # Preface -> chapters end at the Horatian maxim before "APPENDIX A."; the
  # appendix block A-M is overwhelmingly tabular apparatus (alphabet, object
  # lists, weight/measurement tables, age-term lists, plant + shell lists,
  # earnings statement). Cutting at APPENDIX A. also removes the one narrative
  # appendix (D, a quoted Tasmanian comparative-ethnology extract).
  "b24764413-aboriginal-inhabitants-andaman-man.md" => {
    head_cut_to: /\APREFACE\.\z/,
    tail_cut_from: /\AAPPENDIX A\.\z/
  },
  # CONTENTS + illustration list precede the Author's Preface; ends with a
  # magician narrative, no back matter.
  "peopleofpolarnor00rasmuoft-people-of-polar-north-rasmussen.md" => {
    head_cut_to: /\AAUTHOR'S PREFACE\z/
  },
  # Essentially no front matter (title, then INTRODUCTION); ends with narrative.
  "acrossarcticamer006641mbp-across-arctic-america-rasmussen.md" => {
    head_cut_to: /\AINTRODUCTION\z/
  },
  # Preface start is clean; narrative runs to the end (no index in the scan).
  "amongindiansgui00thurgoog-among-indians-guiana-im-thurn.md" => {
    head_cut_to: /\APREFACE\.\z/
  },
  # Title, then the myths begin immediately; all prose (myths + description),
  # ends with a myth narrative.
  "tsimshianmytholo00boas-tsimshian-mythology-boas-tate.md" => {
    head_cut_to: /\AI\. TSIMSHIAN MYTHS\z/
  },
  # Ethnography narrative ends before the "LINGUISTICS" section, which is the
  # language apparatus: vocabularies, grammar tables, and interlinear
  # native-language creation-myth / song texts (heavily OCR-shredded).
  "pimaindians01russgoog-pima-indians-russell.md" => {
    head_cut_to: /\AINTRODUCTION\z/,
    tail_cut_from: /\ALINGUISTICS\z/
  },
  # Preface start clean; appendices (I, III, IV) are narrative prose essays and
  # a testimonial letter — kept. No index follows.
  "unknownpeopleinu00grub-unknown-people-unknown-land-grubb.md" => {
    head_cut_to: /\APREFACE\z/
  },
  # Preface start clean; the "APPENDIX. BETSILEO PLACE-NAMES" at ~6075 is an
  # internal chapter appendix (narrative continues after it to the geology
  # chapter that ends the book), so no tail cut.
  "cu31924028622284-madagascar-before-conquest-sibree.md" => {
    head_cut_to: /\APREFACE\.\z/
  },
  # CONTENTS block precedes the real Preface; back matter starts at the
  # "APPENDIX" of Ponapean clan-name lists and shell-adze measurement tables.
  "carolineislands00chri-caroline-islands-christian.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\AAPPENDIX\z/
  },
  # CONTENTS precedes CHAPTER I; the "UAP GRAMMAR" section (grammar, vocabulary,
  # interlinear phrasebook) is native-language apparatus back matter.
  "cu31924023500543-island-of-stone-money-furness.md" => {
    head_cut_to: /\ACHAPTER I\z/,
    tail_cut_from: /\AUAP GRAMMAR\z/, tail_frac: 0.4
  },
  # Preface start clean; appendices I & II are narrative prose (kept); the
  # "GLOSSARY OF NATIVE WORDS" + index that follow are reference back matter.
  "melanesiansofbri00seli-melanesians-british-new-guinea-seligman.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\AGLOSSARY OF NATIVE WORDS\z/
  },
  # Front is title-page + plate scan garble + a clan/section CONTENTS list; the
  # narrative begins at the "observant traveler in Arizona" paragraph and the
  # numbered conclusion ends at "...but from the south."; terminal plates are
  # pure OCR shred. (Body retains some interspersed clan tables / plate
  # captions — ethnographic content, not furniture.)
  "cu31924104075415-tusayan-migration-traditions-fewkes.md" => {
    head_cut_to: /\AThe\s+observant\s+traveler\s+in\s+Arizona\b/,
    tail_cut_after: /\Aare\s+found\s+not\s+to\s+have\s+come\s+from\s+the\s+north,\s+but\s+from\s+the\s+south\.\z/
  }
}.freeze

BOILERPLATE = [
  /\AHosted by Google\z/i,
  /\ADigiti[sz]ed by (the )?(Google|Internet Archive|Microsoft)/i,
  /\Ahttps?:\/\/(www\.)?archive\.org/i
].freeze

def caps_dominant?(rest)
  return false if rest.length > 50
  letters = rest.scan(/[A-Za-z]/)
  return false if letters.length < 4
  letters.count { |c| c =~ /[A-Z]/ }.to_f / letters.length >= 0.7
end

# Running header with a page number at one end and an ALL-CAPS short title at
# the other. Verso: "<num> TITLE". Recto: "TITLE <num>".
def caps_running_header?(line)
  if (m = line.match(/\A\d[\d ]{0,5}\s+(\S.*)\z/))       # verso
    return true if caps_dominant?(m[1])
  end
  if (m = line.match(/\A(.*\S)\s+\d{1,4}\z/))            # recto
    return true if caps_dominant?(m[1])
  end
  false
end

# Optional ARGV filter: run only for files whose name contains any argument
# substring (the passes are not idempotent against already-cleaned files).
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
    idx = (from...lines.length).find { |i| lines[i].strip =~ re }
    raise "#{name}: tail marker not found" unless idx
    keep_to = spec[:tail_cut_after] ? idx : idx - 1
    stats["tail_trim"] = lines.length - keep_to - 1
    lines = lines[0..keep_to]
  end

  drops = spec[:drop] || []
  lines = lines.reject do |line|
    s = line.strip
    if BOILERPLATE.any? { |re| s =~ re }
      stats["boilerplate"] += 1
      true
    elsif s =~ /\A\[?\d{1,4}\]?\z/
      stats["page_numbers"] += 1
      true
    elsif drops.any? { |re| s =~ re }
      stats["dropped"] += 1
      true
    elsif caps_running_header?(s)
      stats["caps_headers"] += 1
      true
    else
      false
    end
  end

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

  final = []
  blank_run = 0
  lines.each do |line|
    if line.strip.empty?
      blank_run += 1
      final << "" if blank_run <= 2
    else
      blank_run = 0
      final << line.rstrip.gsub(/(?<=\S) {2,}(?=\S)/, " ")
    end
  end

  File.write(path, final.join("\n") + "\n")
  puts "#{name}: #{before} -> #{final.length} (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end
