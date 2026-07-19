#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/notesoneasternc01skingoog-eastern-cree-northern-saulteaux-skinner.md
#
# Source: Alanson Skinner, "Notes on the Eastern Cree and Northern Saulteaux"
# (AMNH Anthropological Papers IX, 1911), Google Books scan. The body is clean
# continuous English ethnography; the only pervasive noise is the Google scan
# furniture injected at every page break: the two-line "Digitized by" / "Google"
# footer (printed as two separate lines with blank lines between), the front
# Google Books license boilerplate, the Harvard/Peabody library bookplate, and
# a garbled library DATE-DUE card at the very back. Every transform is
# mechanical line selection/deletion/joining — no text is rewritten.
#
# Transforms:
#   1. Structural head trim (guarded): keep the "# ..." title line, drop the
#      Google license boilerplate + library bookplate + digitized footers up to
#      the real title page ("ANTHROPOLOGICAL PAPERS").
#   2. Structural tail trim (guarded): drop the garbled DATE-DUE library card
#      (begins at the "DAH DUE" mis-OCR of "DATE DUE") + barcode + footers.
#   3. Delete the standalone Google scan footers anywhere: lines that are exactly
#      "Digitized by" or "Google" (case-insensitive), and the
#      "at |http : //books . google . com/" watermark line.
#   4. Neutralize stray HTML-like OCR "<"/">" -> "("/")".
#   5. Squeeze double word-spacing; collapse 3+ blank lines to 2.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/notesoneasternc01skingoog-eastern-cree-northern-saulteaux-skinner.md")

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# --- 1. head trim -----------------------------------------------------------
head_idx = (1...lines.length).find { |i| lines[i].strip == "ANTHROPOLOGICAL PAPERS" }
abort "head marker 'ANTHROPOLOGICAL PAPERS' not found" unless head_idx
stats[:head_trim] = head_idx - 1
body = [lines[0], ""] + lines[head_idx..]

# --- 2. tail trim (garbled DATE-DUE card in the last 3%) --------------------
from = (body.length * 0.97).to_i
tail_idx = (from...body.length).find { |i| body[i].strip.match?(/\bD[AU][HT]?\s*DUE\b/i) || body[i].strip.match?(/\ADEMCO\b/i) }
if tail_idx
  stats[:tail_trim] = body.length - tail_idx
  body = body[0...tail_idx]
end

# --- 3. drop standalone Google footers --------------------------------------
FOOTER = /\A(digiti[sz]ed by|google)\z/i.freeze
GOOGLE_URL = %r{books\s*\.?\s*google\s*\.?\s*com}i.freeze
kept = body.reject do |line|
  s = line.strip
  if s.match?(FOOTER)
    stats[:footers] += 1
    next true
  end
  if s.match?(GOOGLE_URL) && s.length <= 60
    stats[:google_url] += 1
    next true
  end
  false
end

# --- 4 + 5. neutralize <>, squeeze spaces, collapse blanks ------------------
final = []
blank_run = 0
kept.each do |line|
  out = line.tr("<>", "()").rstrip.gsub(/(?<=\S) {2,}(?=\S)/, " ").sub(/\A\s+/, "")
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
