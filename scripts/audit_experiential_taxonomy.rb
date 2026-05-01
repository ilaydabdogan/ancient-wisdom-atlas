#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Audit the experiential taxonomy for full coverage and consistency.
#
# Reads:
#   data/indexes/experiential-motif-occurrences.yml  (the 321 raw motifs)
#   taxonomy/experiential-motif-families.yml         (the family assignments)
#
# Reports:
#   - motifs declared in the index but missing from any family (unmapped)
#   - motifs declared in a family but absent from the index (typos)
#   - motifs assigned to more than one family (overlap)
#   - per-family child counts and sub_corpora coverage
#
# Exits non-zero on any unmapped or invalid motif.

require "yaml"
require "set"
require "date"

ROOT = File.expand_path("..", __dir__)
INDEX_PATH = File.join(ROOT, "data/indexes/experiential-motif-occurrences.yml")
TAXONOMY_PATH = File.join(ROOT, "taxonomy/experiential-motif-families.yml")

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

index = load_yaml(INDEX_PATH)
taxonomy = load_yaml(TAXONOMY_PATH)

raw_motifs = index.fetch("motifs").map { |m| m.fetch("motif_id") }.to_set

assigned = Hash.new { |h, k| h[k] = [] }
families = taxonomy.fetch("experiential_motif_families")
families.each do |family|
  family_id = family.fetch("id")
  Array(family["children"]).each do |motif|
    assigned[motif] << family_id
  end
end

unmapped = (raw_motifs - assigned.keys).sort
typos = (assigned.keys - raw_motifs.to_a).sort
overlap = assigned.select { |_, fams| fams.length > 1 }

puts "Experiential Taxonomy Audit"
puts "==========================="
puts "Raw motifs in index:     #{raw_motifs.size}"
puts "Assignments in taxonomy: #{assigned.values.flatten.length}"
puts "Distinct motifs covered: #{(assigned.keys & raw_motifs.to_a).length}"
puts "Family count:            #{families.length}"
puts ""

if unmapped.empty?
  puts "[OK] Every raw motif is assigned to at least one family."
else
  puts "[FAIL] #{unmapped.length} unmapped raw motifs:"
  unmapped.each { |m| puts "  - #{m}" }
end
puts ""

if typos.empty?
  puts "[OK] No taxonomy children reference unknown motif slugs."
else
  puts "[FAIL] #{typos.length} taxonomy children reference unknown motif slugs:"
  typos.each { |m| puts "  - #{m} (in #{assigned[m].join(', ')})" }
end
puts ""

if overlap.empty?
  puts "[OK] No motif is assigned to more than one family."
else
  puts "[FAIL] #{overlap.length} motifs assigned to multiple families:"
  overlap.each { |motif, fams| puts "  - #{motif}: #{fams.join(', ')}" }
end
puts ""

puts "Per-family child counts:"
families.sort_by { |f| -Array(f["children"]).length }.each do |family|
  puts "  %-45s %s children, sub_corpora=%s" % [
    family.fetch("id"),
    Array(family["children"]).length,
    Array(family["sub_corpora"]).join(",")
  ]
end

failures = unmapped.empty? && typos.empty? && overlap.empty?
exit(failures ? 0 : 1)
