#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for:
#   imports/converted/project-gutenberg/pausaniasgreece01pausuoft-pausanias-description-of-greece-frazer-vol1.md
#
# Source: Pausanias, "Description of Greece" vol. I (Books I-II), Loeb Classical
# Library, with an English translation by W. H. S. Jones (1918). Greek and
# English on facing pages, interleaved throughout by the OCR. Here the Greek
# survived OCR as real polytonic Greek Unicode (non-ASCII); it is dropped along
# with page furniture, while the clean English translation + English/Latin
# footnotes are kept. This script only SELECTS and DELETES lines mechanically
# (via loeb_greek_lib.rb); it never writes or invents text.
#
# Transforms (see loeb_greek_lib.rb for the classifier details):
#   1. Structural trim (guarded by content assertions): keep the "# Pausanias..."
#      title and the PREFACE-through-last-translation body (orig lines
#      53-22247, ending "...into the Gulf of Thyrea."). Drops: IA/Loeb
#      title-page scan cruft (2-52); and the tail after the text -- a page of
#      plate scan-bleed garble, the "VOLUMES ALREADY PUBLISHED" Loeb catalogue
#      advertisements, and the library card (22248-end).
#   2. Delete Greek paragraphs, page headers/numbers, B.C. date margins, and OCR
#      scan-bleed garble via the shared no-English-stopword + Greek-signature
#      classifier.
#   3. Re-join paragraph splits left by removed furniture.
#   4. Neutralize stray angle brackets; squeeze double spaces; collapse blanks.
#
# Set DRYRUN=1 to print stats + sample windows without modifying the file.

ROOT = File.expand_path("../../..", __dir__)
PATH = File.join(ROOT, "imports/converted/project-gutenberg/pausaniasgreece01pausuoft-pausanias-description-of-greece-frazer-vol1.md")

lines = File.readlines(PATH, chomp: true)

guards = {
  1 => /\A# Pausanias/,
  53 => /\APREFACE\b/,
  22247 => /Gulf\s+of\s+Thyrea/
}
guards.each do |num, pattern|
  unless lines[num - 1].to_s.match?(pattern)
    abort "guard failed at line #{num}: #{lines[num - 1].inspect} !~ #{pattern.inspect}"
  end
end
body = [lines[0], ""] + lines[52..22246]

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
