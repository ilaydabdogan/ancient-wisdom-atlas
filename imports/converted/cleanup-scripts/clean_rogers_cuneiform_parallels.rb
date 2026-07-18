#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for
#   imports/converted/project-gutenberg/cuneiformparalle00rogeuoft-cuneiform-parallels-rogers.md
# Mechanical line selection only — no text is rewritten.
#
#   1. Head trim: Toronto library plate + Internet Archive scan boilerplate
#      (everything between the "# ..." title line and the title page, i.e.
#      up to and including the "Microsoft  Corporation" line).
#   2. Tail trim: the ILLUSTRATIONS plate section (plate captions mixed with
#      OCR'd photograph garble and the Acme library card pocket), i.e.
#      everything from the standalone garbled "¥11" line that follows the
#      end of the INDEX through EOF.
#   3. Recto running headers: ALL-CAPS section-title lines ending in a
#      space-separated page number >= 40 (verified by exhaustive listing:
#      all 156 such lines after the front-matter TOC are per-page headers
#      like "ISHTAR'S  DESCENT  TO  HADES  121"). Applied only after the
#      "LIST  OF  ILLUSTRATIONS" TOC block so contents entries survive.
#      Structural headings like "TABLET  NO.  3" carry numbers < 40 and
#      are kept.
#   4. Dehyphenation across blank lines: "word-" at EOL joined with the
#      next non-blank line when it starts lowercase (the scan is
#      double-spaced, so the generic cleaner's adjacent-line join missed
#      these). Intervening blank lines are consumed.
#   5. Collapse runs of 2+ internal spaces to one (double-spaced OCR).
#   6. Collapse 3+ blank lines to 2.

PATH = File.expand_path("../project-gutenberg/cuneiformparalle00rogeuoft-cuneiform-parallels-rogers.md", __dir__)

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# 1. Head trim: title line stays, drop up to "Microsoft  Corporation".
ms = lines.index { |l| l.strip == "Microsoft  Corporation" }
raise "head marker not found" unless ms && ms < 60
lines = [lines[0]] + lines[(ms + 1)..]
stats["head_trim"] = ms

# 2. Tail trim: from garbled "¥11" (immediately before "ILLUSTRATIONS"
# plates section, after the INDEX) through EOF.
tail = lines.rindex { |l| l.strip == "¥11" }
raise "tail marker not found" unless tail && tail > lines.length - 2000
illus = lines[tail..].find { |l| l.strip == "ILLUSTRATIONS" }
raise "ILLUSTRATIONS not adjacent to tail marker" unless illus
stats["tail_trim"] = lines.length - tail
lines = lines[0...tail]

# 3. Recto running headers, only after the front-matter TOC.
toc_end = lines.index { |l| l.strip =~ /\Ax?\s*LIST\s+OF\s+ILLUSTRATIONS\z/ } || 0
header_re = /\A[A-Z][A-Z .,'&\-]*\s(\d{2,3})\z/
kept = []
lines.each_with_index do |line, i|
  s = line.strip
  if i > toc_end + 40 && (m = s.match(header_re)) && m[1].to_i >= 40
    stats["running_headers"] += 1
    next
  end
  kept << line
end

# 4. Dehyphenation across the double-spaced layout.
joined = []
i = 0
while i < kept.length
  line = kept[i]
  if line =~ /[a-z]-\z/
    j = i + 1
    j += 1 while j < kept.length && kept[j].strip.empty?
    if j < kept.length && kept[j].lstrip =~ /\A[a-z]/
      joined << line.sub(/-\z/, "") + kept[j].lstrip
      stats["dehyphenated"] += 1
      i = j + 1
      next
    end
  end
  joined << line
  i += 1
end

# 5 + 6. Space squeeze and blank-line collapse.
final = []
blank_run = 0
joined.each do |line|
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
