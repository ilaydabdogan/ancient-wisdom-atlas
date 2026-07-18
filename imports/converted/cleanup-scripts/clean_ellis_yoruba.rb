#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup for
#   imports/converted/project-gutenberg/yorubaspeakingp01elligoog-yoruba-speaking-peoples-ellis.md
# Mechanical line selection only — no text is rewritten.
#
#   1. Head trim: Google Books usage-guidelines block and Harvard bookplate
#      (lines between the "# ..." title line and the half-title
#      "THE YORUBA-SPEAKINa PEOPLES").
#   2. Tail trim: the OCR-shredded grammar/vocabulary appendix ("Appendix
#      Containing a Comparison of the Tshi, Ga, Ewe, and Yoruba
#      Languages") plus the Harvard overdue slip. The prose body ends with
#      Chapter XV (Conclusions) at "number of persons, until it finally
#      became individual." — everything after that line is cut. Verified:
#      no prose (only column shred) exists between that line and EOF.
#   3. Running headers, applied after the body start ("CHAPTER L", OCR of
#      "CHAPTER I.", so the table of contents keeps its page numbers):
#        - verso: "<page> THE YORUBA-SPEAKING PEOPLES." with heavy OCR
#          variance (YOnUBA'SPEAKIXG, Y0RUBA-8PEAKIN0, ...) — matched by
#          leading page number + literal "PEOPLES";
#        - recto: all-caps chapter-title lines ending in a token that
#          contains a digit ("SYSTEM OF GOVERNMENT. 173", "PROVERBS. 285");
#        - printer signature marks ("T 2", "Q 2").
#   4. Collapse 3+ blank lines to 2.

PATH = File.expand_path("../project-gutenberg/yorubaspeakingp01elligoog-yoruba-speaking-peoples-ellis.md", __dir__)

lines = File.readlines(PATH, chomp: true)
before = lines.length
stats = Hash.new(0)

# 1. Head trim.
half_title = lines.index { |l| l.strip =~ /\ATHE YORUBA-SPEAKIN/ }
raise "head marker not found" unless half_title && half_title < 200
lines = [lines[0]] + lines[half_title..]
stats["head_trim"] = half_title - 1

# 2. Tail trim (shredded appendix).
body_end = lines.index { |l| l.strip == "number of persons, until it finally became individual." }
raise "tail marker not found" unless body_end
stats["tail_trim"] = lines.length - body_end - 1
lines = lines[0..body_end]

# 3. Running headers after body start.
body_start = lines.index { |l| l.strip =~ /\ACHAPTER L\.?\z/ }
raise "body start (CHAPTER L) not found" unless body_start

kept = []
lines.each_with_index do |line, i|
  s = line.strip
  if i > body_start
    if s.match?(/\A\d{1,3}\s+\S.*PEOPLES\b.{0,3}\z/)
      stats["verso_headers"] += 1
      next
    end
    if !s.match?(/[a-z]/) && s.match?(/\A[A-Z][A-Z ,.'\-]{5,}\s\S*\d\S*\z/)
      stats["recto_headers"] += 1
      next
    end
    if s.match?(/\A[A-Z] \d\z/)
      stats["signature_marks"] += 1
      next
    end
  end
  kept << line
end

# 4. Blank collapse.
final = []
blank_run = 0
kept.each do |line|
  if line.strip.empty?
    blank_run += 1
    final << "" if blank_run <= 2
  else
    blank_run = 0
    final << line.rstrip
  end
end

File.write(PATH, final.join("\n") + "\n")
puts "#{File.basename(PATH)}: #{before} -> #{final.length} lines (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
