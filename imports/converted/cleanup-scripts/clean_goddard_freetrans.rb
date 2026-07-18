#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic structural extraction for two Goddard Apache volumes:
#   imports/converted/project-gutenberg/mythstalesfromsa00godd-myths-tales-san-carlos-apache-goddard.md
#   imports/converted/project-gutenberg/jicarillaapachet0008godd-jicarilla-apache-texts-goddard.md
#
# Source: Pliny Earle Goddard, "Myths and Tales from the San Carlos Apache"
# (AMNH Anthropological Papers XXIV, 1918) and "Jicarilla Apache Texts" (AMNH
# VIII, 1911). Both give the English free translation as a self-contained run:
#   - Myths and Tales is entirely Goddard's English translations (no native
#     text at all); we keep the title + narrative and drop the front/back AMNH
#     publisher catalogs.
#   - Jicarilla prints the interlinear native texts first (pp.12-192) and then a
#     grouped English "TRANSLATIONS." section (pp.193-218); we keep the title +
#     that TRANSLATIONS section and drop everything before it (the interlinear
#     native texts) and the subject INDEX after it.
# Every transform is mechanical line selection/deletion/joining, guarded by
# content assertions — no text is rewritten. Page-furniture stripping and
# dehyphenation are then applied by scripts/clean_ocr_conversion.rb.

ROOT = File.expand_path("../../..", __dir__)
DIR = File.join(ROOT, "imports/converted/project-gutenberg")

SPECS = {
  "mythstalesfromsa00godd-myths-tales-san-carlos-apache-goddard.md" => {
    head_cut_to: /\AMYTHS\s+AND\s+TALES\s+FROM\s+THE\s+SAN\s+CARLOS\s+APACHE\.\z/,
    tail_cut_from: /\A\(\s*Continued\s+from\s+2d\s+p\.\s+of\s+cover\.\s*\)\z/,
    tail_frac: 0.9
  },
  "jicarillaapachet0008godd-jicarilla-apache-texts-goddard.md" => {
    head_cut_to: /\ATRANSLATIONS\.\z/,
    tail_cut_from: /\AINDEX\.\z/,
    tail_frac: 0.5
  }
}.freeze

selected = ARGV.empty? ? SPECS : SPECS.select { |n, _| ARGV.any? { |a| n.include?(a) } }
selected.each do |name, spec|
  path = File.join(DIR, name)
  abort "missing #{name}" unless File.file?(path)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  stats = Hash.new(0)

  idx = (1...lines.length).find { |i| lines[i].strip =~ spec[:head_cut_to] }
  abort "#{name}: head marker #{spec[:head_cut_to].inspect} not found" unless idx
  stats["head_trim"] = idx - 1
  lines = [lines[0], ""] + lines[idx..]

  from = (lines.length * (spec[:tail_frac] || 0.5)).to_i
  tidx = (from...lines.length).find { |i| lines[i].strip =~ spec[:tail_cut_from] }
  abort "#{name}: tail marker #{spec[:tail_cut_from].inspect} not found past #{from}" unless tidx
  stats["tail_trim"] = lines.length - tidx
  lines = lines[0...tidx]

  # collapse blank runs to 2
  final = []
  blank = 0
  lines.each do |l|
    if l.strip.empty?
      blank += 1
      final << "" if blank <= 2
    else
      blank = 0
      final << l.rstrip
    end
  end
  final.pop while final.last == ""

  File.write(path, final.join("\n") + "\n")
  puts "#{name}: #{before} -> #{final.length} (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end
