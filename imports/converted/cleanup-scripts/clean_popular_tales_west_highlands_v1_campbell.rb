#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/internet-archive/populartalesofwe01campuoft-popular-tales-west-highlands-v1-campbell.md
#
# Source: J. F. Campbell, "Popular Tales of the West Highlands" vol. I
# (new edition, 1890). Layout: a scholarly English INTRODUCTION, then each
# tale is given first as a clean continuous ENGLISH translation (with an
# English collector's pedigree note), immediately followed by the full
# GAELIC original (and occasionally Gaelic notes). English and Gaelic
# alternate throughout. The Gaelic is kept clean by the printer but is a
# different language; it is dropped. The English translation + English notes
# are kept. This script only SELECTS and DELETES lines mechanically; it never
# writes, paraphrases, or invents text.
#
# Transforms:
#   1. Structural trim (guarded by content assertions): keep the "# Popular
#      Tales..." title and the INTRODUCTION-through-last-tale body
#      (orig lines 944-22628, i.e. up to and including "END OF VOL. I.").
#      Drops: IA/library title-page scan cruft and the CONTENTS table
#      (lines 2-943), and the Toronto library due-date card (22629-end).
#   2. Delete Gaelic paragraphs via an orthographic signature classifier.
#      Gaelic per-word signatures: the digraphs bh/mh/dh/fh (which are
#      pervasive in Gaelic and near-absent in this book's English), grave
#      accents, Gaelic elision apostrophes ('s, 'n, dh', a', b', gu'n),
#      the endings -idh/-adh/-aidh/-eadh, and a small lexicon of very common
#      Gaelic function words (agus, bha, cha, thu, robh, chaidh, ...).
#      A paragraph is Gaelic when >=3 words are flagged and >=18% of its
#      assessable words are flagged (or a short line is entirely flagged with
#      no English stopword). English paragraphs quoting a stray Gaelic name
#      survive because their Gaelic fraction stays tiny.
#   3. Delete page furniture: running headers ("WEST HIGHLAND TALES"),
#      bare page numbers / roman numerals, all-caps GAELIC tale headings
#      (all-caps line with a Gaelic-signature word and no English stopword),
#      and OCR garble lines (no real English word, mostly non-alphabetic).
#   4. Re-join paragraph splits created by removed furniture (a kept English
#      line ending mid-clause followed by a lowercase-starting line).
#   5. Squeeze the pervasive double-space-between-words OCR artifact; collapse
#      3+ blank lines to 2.
#
# Set DRYRUN=1 to print stats + sample windows without modifying the file.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/internet-archive/populartalesofwe01campuoft-popular-tales-west-highlands-v1-campbell.md")

lines = File.readlines(PATH, chomp: true)

# --- 1. structural trim -----------------------------------------------------
guards = {
  1 => /\A# Popular Tales of the West Highlands/,
  944 => /\AINTRODUCTION\./,
  22628 => /\AEND\s+OF\s+VOL\.\s+I\./
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
body = [lines[0], ""] + lines[943..22627]

require_relative "west_highlands_gaelic_lib"
final, stats = WestHighlandsGaelic.clean(body)

if ENV["DRYRUN"]
  puts "#{File.basename(PATH)}: #{lines.length} -> #{final.length} lines " \
       "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
  WestHighlandsGaelic.sample(final)
else
  File.write(PATH, final.join("\n") + "\n")
  puts "#{File.basename(PATH)}: #{lines.length} -> #{final.length} lines " \
       "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end
