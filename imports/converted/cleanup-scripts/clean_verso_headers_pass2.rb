#!/usr/bin/env ruby
# frozen_string_literal: true

# Second pass over the volumes that clean_sbe_and_folklore_batch.rb
# processed without the verso-caps-header rule: previewing showed their
# "<page num>  <ALL-CAPS running title>" verso headers (e.g.
# "4 DHAMMAPADA. CHAP. I.", "26 AJTARANGA", "140 NTHONGI.") match the same
# mechanical rule with no meaningful false positives (the handful of
# non-header matches are short all-caps footnote cross-reference fragments,
# whose removal is sanctioned). Rule: leading page number, remainder
# <= 50 chars with >= 4 letters and >= 70% uppercase.

DIR = File.expand_path("../project-gutenberg", __dir__)

FILES = %w[
  saddharmapundar00cambuoft-saddharma-pundarika-kern.md
  mlbd.sacredbooksofeas0000fmax.vol.16-i-ching-legge.md
  mlbd.dhammapadasuttni0000fmax-sutta-nipata-fausboll.md
  buddhistmahayana0049vari-buddhist-mahayana-texts-sbe49.md
  jainasutrasparti029233mbp-jaina-sutras-part-1-jacobi.md
  nihongi1asto-nihongi-volume-1-aston.md
  nihongi2asto-nihongi-volume-2-aston.md
].freeze

def verso_caps_header?(line)
  m = line.match(/\A\d[\d ]{0,5}\s+(\S.*)\z/)
  return false unless m
  rest = m[1]
  return false if rest.length > 50
  letters = rest.scan(/[A-Za-z]/)
  return false if letters.length < 4
  letters.count { |c| c =~ /[A-Z]/ }.to_f / letters.length >= 0.7
end

FILES.each do |name|
  path = File.join(DIR, name)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  removed = 0
  kept = lines.reject do |line|
    if verso_caps_header?(line.strip)
      removed += 1
      true
    else
      false
    end
  end
  final = []
  blank_run = 0
  kept.each do |line|
    if line.strip.empty?
      blank_run += 1
      final << "" if blank_run <= 2
    else
      blank_run = 0
      final << line
    end
  end
  File.write(path, final.join("\n") + "\n")
  puts "#{name}: #{before} -> #{final.length} (verso_headers=#{removed})"
end
