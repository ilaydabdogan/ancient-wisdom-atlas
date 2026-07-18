#!/usr/bin/env ruby
# frozen_string_literal: true

# Deterministic removal of the internal Buddha-karita index block in
# imports/converted/project-gutenberg/buddhistmahayana0049vari-buddhist-mahayana-texts-sbe49.md
# (SBE 49). Per ocr-review-2.yml: the 'INDEX OF PROPER NAMES' block sits
# between Part I (Buddha-karita) and Part II (Sukhavati-vyuha texts) and
# should be cut through to the Part II title.
#
# Mechanical line selection only: drop lines 8921..9614 (1-indexed) —
# cover-scan garble after the Part I closing note ("...(A.D. 1796).",
# line 8920), the index itself (heading at 8943), and the corrigenda
# notes that follow it. Line 9615 ('BUDDHIST MAHAYANA TEXTS', the Part II
# half-title) is the first line kept.
#
# Guarded: verifies the expected text at the anchor lines before writing,
# so the script is a no-op (with error) if the file has shifted.

path = File.expand_path("../project-gutenberg/buddhistmahayana0049vari-buddhist-mahayana-texts-sbe49.md", __dir__)
abort "missing #{path}" unless File.file?(path)

lines = File.readlines(path, chomp: true)

DROP_FROM = 8921 # 1-indexed, inclusive
DROP_TO   = 9614 # 1-indexed, inclusive

anchor_before = lines[DROP_FROM - 2] # line 8920
anchor_index  = lines[8943 - 1]      # heading inside dropped block
anchor_after  = lines[DROP_TO]       # line 9615, first kept line

unless anchor_before&.include?("(A.D. 1796)") &&
       anchor_index&.start_with?("INDEX OF PROPER NAMES") &&
       anchor_after&.strip == "BUDDHIST MAHAYANA TEXTS"
  abort "anchor mismatch: file layout changed, refusing to cut " \
        "(8920=#{anchor_before.inspect} 8943=#{anchor_index.inspect} 9615=#{anchor_after.inspect})"
end

kept = lines[0...(DROP_FROM - 1)] + lines[DROP_TO..]
File.write(path, kept.join("\n") + "\n")
puts "removed internal index block lines #{DROP_FROM}-#{DROP_TO}: #{lines.length} -> #{kept.length} lines"
