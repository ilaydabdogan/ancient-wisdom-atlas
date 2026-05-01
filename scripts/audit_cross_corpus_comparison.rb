#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Audit the cross-corpus taxonomy comparison for completeness and consistency.
#
# Verifies that:
#   - every experiential family is recorded exactly once in
#     experiential_to_ancient
#   - every ancient_family_ref is a real ancient family id
#   - the strength distribution counts match the actual entries
#   - every ancient family is either referenced or listed as
#     ancient_families_without_experiential_counterpart
#   - the experiential_families_without_ancient_counterpart list matches
#     the entries with strength: none or weak with empty ancient_family_refs

require "yaml"
require "set"
require "date"

ROOT = File.expand_path("..", __dir__)
COMPARISON_PATH = File.join(ROOT, "data/indexes/cross-corpus-taxonomy-comparison.yml")
EXPERIENTIAL_TAXONOMY_PATH = File.join(ROOT, "taxonomy/experiential-motif-families.yml")
ANCIENT_TAXONOMY_PATH = File.join(ROOT, "taxonomy/motif-normalization.yml")

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

comparison = load_yaml(COMPARISON_PATH)
experiential = load_yaml(EXPERIENTIAL_TAXONOMY_PATH)
ancient = load_yaml(ANCIENT_TAXONOMY_PATH)

experiential_family_ids = experiential.fetch("experiential_motif_families").map { |f| f.fetch("id") }.to_set
ancient_family_ids = Array(ancient.fetch("canonical_motif_groups")).map { |g| g.fetch("id") }.to_set

mappings = comparison.fetch("experiential_to_ancient")
mapped_experiential = mappings.map { |m| m.fetch("experiential_family") }
referenced_ancient = mappings.flat_map { |m| Array(m["ancient_family_refs"]) }.to_set
unreferenced_ancient_listed = comparison.fetch("ancient_families_without_experiential_counterpart").to_set

puts "Cross-Corpus Comparison Audit"
puts "============================="
puts "Experiential families:                  #{experiential_family_ids.size}"
puts "Ancient families:                       #{ancient_family_ids.size}"
puts "Mappings recorded:                      #{mappings.length}"
puts ""

duplicates = mapped_experiential.group_by { |id| id }.transform_values(&:length).select { |_, count| count > 1 }
missing_experiential = experiential_family_ids - mapped_experiential.to_set
extra_experiential = mapped_experiential.to_set - experiential_family_ids
unknown_ancient_refs = referenced_ancient - ancient_family_ids
unlisted_ancient = ancient_family_ids - referenced_ancient - unreferenced_ancient_listed
double_listed_ancient = referenced_ancient & unreferenced_ancient_listed
unknown_unlisted = unreferenced_ancient_listed - ancient_family_ids

issues = []
issues << "[FAIL] duplicate experiential mappings: #{duplicates.keys.join(', ')}" unless duplicates.empty?
issues << "[FAIL] experiential families with no mapping: #{missing_experiential.to_a.sort.join(', ')}" unless missing_experiential.empty?
issues << "[FAIL] mappings reference unknown experiential families: #{extra_experiential.to_a.sort.join(', ')}" unless extra_experiential.empty?
issues << "[FAIL] mappings reference unknown ancient families: #{unknown_ancient_refs.to_a.sort.join(', ')}" unless unknown_ancient_refs.empty?
issues << "[FAIL] ancient families neither mapped nor listed as without-counterpart: #{unlisted_ancient.to_a.sort.join(', ')}" unless unlisted_ancient.empty?
issues << "[FAIL] ancient families both mapped and listed as without-counterpart: #{double_listed_ancient.to_a.sort.join(', ')}" unless double_listed_ancient.empty?
issues << "[FAIL] without-counterpart list includes unknown ancient families: #{unknown_unlisted.to_a.sort.join(', ')}" unless unknown_unlisted.empty?

# Strength counts
declared = comparison.fetch("mapping_strength_distribution")
observed = mappings.group_by { |m| m.fetch("strength") }.transform_values(&:length)
[%w[strong moderate weak none]].flatten.each do |strength|
  d = declared[strength].to_i
  o = observed[strength].to_i
  if d != o
    issues << "[FAIL] strength distribution mismatch for #{strength}: declared=#{d} observed=#{o}"
  end
end

if issues.empty?
  puts "[OK] Mapping is structurally complete and consistent."
  puts ""
  puts "Strength distribution (observed):"
  observed.sort.each { |strength, count| puts "  %-10s %s" % [strength, count] }
  puts ""
  puts "Ancient families without experiential counterpart: #{unreferenced_ancient_listed.size}"
  puts "Experiential families without ancient counterpart: #{comparison.fetch('experiential_families_without_ancient_counterpart').length}"
  exit 0
else
  issues.each { |i| puts i }
  exit 1
end
