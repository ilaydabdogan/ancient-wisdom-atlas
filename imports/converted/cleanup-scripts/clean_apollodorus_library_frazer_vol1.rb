#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/librarywithengli01apoluoft-apollodorus-library-frazer-vol1.md
#
# Source: Apollodorus, "The Library" vol. I, Loeb Classical Library, with an
# English translation by Sir James George Frazer (1921). Greek and English on
# facing pages, interleaved throughout by the OCR. The Greek survived OCR as
# Latin-lookalike glyph soup (interior capitals, accented vowels, stray '@')
# and is dropped along with the Greek apparatus criticus; the clean English
# translation and the English/Latin footnotes are kept. This script only
# SELECTS and DELETES lines mechanically (via loeb_greek_lib.rb); it never
# writes or invents text.
#
# Transforms (see loeb_greek_lib.rb for the classifier details):
#   1. Structural trim (guarded by content assertions): keep the "# The Library"
#      title and the INTRODUCTION-through-last-footnote body (orig lines
#      141-23330). Drops: IA/Loeb title-page scan cruft + CONTENTS (2-140) and
#      the Toronto library card (23331-end).
#   2. Delete Greek paragraphs, Greek apparatus, page headers/numbers, printer
#      signatures, and OCR garble via the shared no-English-stopword +
#      Greek-signature classifier.
#   3. Re-join paragraph splits left by removed furniture.
#   4. Neutralize stray angle brackets; squeeze double spaces; collapse blanks.
#
# Set DRYRUN=1 to print stats + sample windows without modifying the file.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/librarywithengli01apoluoft-apollodorus-library-frazer-vol1.md")

lines = File.readlines(PATH, chomp: true)

guards = {
  1 => /\A# The Library/,
  141 => /\AINTRODUCTION\b/,
  23330 => /\A144\)/
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
body = [lines[0], ""] + lines[140..23329]

require_relative "loeb_greek_lib"
final, stats = LoebGreek.clean(body)

if ENV["DRYRUN"]
  puts "#{File.basename(PATH)}: #{lines.length} -> #{final.length} lines " \
       "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
  LoebGreek.sample(final)
else
  File.write(PATH, final.join("\n") + "\n")
  puts "#{File.basename(PATH)}: #{lines.length} -> #{final.length} lines " \
       "(#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end
