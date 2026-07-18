#!/usr/bin/env ruby
# frozen_string_literal: true

# Follow-up polish after clean_sbe_and_folklore_batch.rb:
#   - p2upanishads (SBE 15): the OCR-garbled transliteration-table apparatus
#     begins at the "TRANSLITERATION OF ORIENTAL ALPHABETS" heading before
#     the ads-date marker used in the batch pass; cut from that heading so
#     the file ends with the last Upanishad translation, consistent with
#     the other SBE volumes.
#   - sutta-nipata (SBE 10): four stray fragments of the transliteration
#     section's first page ("ALPHABETS. 209", "NTAL", "=", quote mark)
#     survived just before the batch cut point; cut from "ALPHABETS. 209".

DIR = File.expand_path("../project-gutenberg", __dir__)

CUTS = {
  # Optional trailing period: the true first heading of the apparatus
  # (line ~16670, directly after the Maitrayana translation ends) reads
  # "TRANSLITERATION OF ORIENTAL ALPHABETS." with a period.
  "p2upanishads00mluoft-upanishads-part-2-muller.md" => /\ATRANSLITERATION OF ORIENTAL ALPHABETS\.?\z/,
  "mlbd.dhammapadasuttni0000fmax-sutta-nipata-fausboll.md" => /\AALPHABETS\. 209\z/
}.freeze

CUTS.each do |name, re|
  path = File.join(DIR, name)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  from = (lines.length * 0.8).to_i
  idx = (from...lines.length).find { |i| lines[i].strip =~ re }
  unless idx
    puts "#{name}: marker not found (already polished?) — skipped"
    next
  end
  lines = lines[0...idx]
  lines.pop while lines.any? && lines.last.strip.empty?
  File.write(path, lines.join("\n") + "\n")
  puts "#{name}: #{before} -> #{lines.length}"
end
