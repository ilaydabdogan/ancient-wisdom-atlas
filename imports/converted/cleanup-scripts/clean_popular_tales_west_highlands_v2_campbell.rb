#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/internet-archive/populartalesofw02campuoft-popular-tales-west-highlands-v2-campbell.md
#
# Source: J. F. Campbell, "Popular Tales of the West Highlands" vol. II
# (new edition, 1890). Same layout as vol. I: each tale is a clean continuous
# ENGLISH translation (plus an English collector's note) immediately followed
# by the full GAELIC original. English and Gaelic alternate throughout. The
# Gaelic is dropped; the English translation + English notes are kept. This
# script only SELECTS and DELETES lines mechanically; it never writes or
# invents text. The Gaelic/English classifier + furniture rules are shared
# with vol. I (west_highlands_gaelic_lib.rb).
#
# Transforms (see west_highlands_gaelic_lib.rb for the classifier details):
#   1. Structural trim (guarded by content assertions): keep the "# Popular
#      Tales..." title and the body from tale XVIII ("THE CHEST") through the
#      closing "FINIS." (orig lines 947-22991). Drops: IA/library title-page
#      scan cruft and the multi-page CONTENTS table (lines 2-946), and the
#      library shelf card (22992-end).
#   2. Delete Gaelic paragraphs, page furniture, Gaelic all-caps headings, and
#      OCR garble lines via the shared orthographic classifier.
#   3. Re-join paragraph splits left by removed furniture.
#   4. Squeeze the pervasive double-space OCR artifact; neutralize stray
#      angle brackets; collapse 3+ blank lines to 2.
#
# Set DRYRUN=1 to print stats + sample windows without modifying the file.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/internet-archive/populartalesofw02campuoft-popular-tales-west-highlands-v2-campbell.md")

lines = File.readlines(PATH, chomp: true)

# --- 1. structural trim -----------------------------------------------------
guards = {
  1 => /\A# Popular Tales of the West Highlands/,
  947 => /\AXVIII\./,
  22991 => /\AFINIS\./
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
body = [lines[0], ""] + lines[946..22990]

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
