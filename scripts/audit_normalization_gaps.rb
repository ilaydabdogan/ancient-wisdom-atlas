#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TODAY = Date.today.iso8601

INDEX_PATH = File.join(ROOT, "data", "indexes", "motif-occurrences.yml")
TAXONOMY_PATH = File.join(ROOT, "taxonomy", "motifs.yml")
NORMALIZATION_PATH = File.join(ROOT, "taxonomy", "motif-normalization.yml")
OUTPUT_YAML = File.join(ROOT, "data", "indexes", "normalization-gap-audit.yml")
OUTPUT_MARKDOWN = File.join(ROOT, "docs", "normalization-gap-audit.md")

REVIEW_BUCKETS = [
  {
    "id" => "death_descent_afterlife",
    "label" => "Death, Descent, Afterlife, And Ancestors",
    "patterns" => %w[afterlife ancestor ancestral burial corpse dead death descent dying grave ghost hades hell mortality nether resurrect return soul spirit tomb underworld]
  },
  {
    "id" => "journey_quest_homecoming",
    "label" => "Journey, Quest, Exile, And Homecoming",
    "patterns" => %w[arrival crossing departure exile homecoming journey passage pilgrimage quest road ship travel voyage wander wandering]
  },
  {
    "id" => "divine_ritual_sacrifice",
    "label" => "Divine Presence, Ritual, Sacrifice, And Purity",
    "patterns" => %w[altar blessing consecration curse divine god goddess holy offering prayer priest purity purification rite ritual sacred sacrifice sanctuary taboo temple vow worship]
  },
  {
    "id" => "wisdom_speech_dream_revelation",
    "label" => "Wisdom, Speech, Dream, Vision, And Revelation",
    "patterns" => %w[counsel dream instruction knowledge language memory name oracle prophecy revelation riddle song speech teaching truth vision wisdom word]
  },
  {
    "id" => "power_kingship_law_order",
    "label" => "Power, Kingship, Law, Judgment, And Social Order",
    "patterns" => %w[authority city covenant debt hierarchy honor judgment justice king kingship kingdom law oath order polis punishment queen ruler social sovereignty state throne]
  },
  {
    "id" => "love_family_gender_body",
    "label" => "Love, Family, Gender, Birth, And The Body",
    "patterns" => %w[beauty birth bride child daughter desire eros family father gender husband love maiden marriage mother nursing parent sexuality son wife womb]
  },
  {
    "id" => "animals_trickster_transformation",
    "label" => "Animals, Trickster, Disguise, And Transformation",
    "patterns" => %w[animal beast bird bull disguise dog dragon horse lion metamorphosis serpent shape shift snake trick trickster transformation wolf]
  },
  {
    "id" => "nature_elements_cosmos",
    "label" => "Nature, Elements, Celestial Order, And Cosmos",
    "patterns" => %w[chaos cosmos creation darkness earth element fire flood harvest light moon mountain nature rain river sea seasonal sky star storm sun tree water wind world]
  },
  {
    "id" => "conflict_violence_ordeal",
    "label" => "Conflict, Violence, Heroic Ordeal, And Victory",
    "patterns" => %w[battle combat enemy hero monster ordeal revenge spear struggle test trial triumph victory violence war warrior weapon wound]
  },
  {
    "id" => "objects_spaces_boundaries",
    "label" => "Objects, Places, Boundaries, And Thresholds",
    "patterns" => %w[ark boundary bridge cave center chamber city cup door gate garment garden house island labyrinth palace ring threshold veil vessel]
  },
  {
    "id" => "ethics_psychology_inner_life",
    "label" => "Ethics, Psychology, Discipline, And Inner Life",
    "patterns" => %w[anger ascetic discipline fear grief humility inner mind moderation pride renunciation self shame soul suffering temptation virtue vice]
  },
  {
    "id" => "needs_human_sorting",
    "label" => "Needs Human Sorting",
    "patterns" => []
  }
].freeze

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def slug_tokens(value)
  value.to_s.downcase.split(/[^a-z0-9]+/).reject(&:empty?)
end

def known_normalized_ids(taxonomy, normalization)
  motif_ids = taxonomy.fetch("motif_families", {}).keys
  alias_ids = normalization.fetch("aliases", {}).keys
  hierarchy_refs = normalization.fetch("hierarchies", {}).values.flat_map do |hierarchy|
    Array(hierarchy["parent_refs"]) + Array(hierarchy["child_refs"])
  end
  group_refs = Array(normalization["canonical_motif_groups"]).flat_map do |group|
    next [] unless group.is_a?(Hash)

    [group["id"], *Array(group["children"]), *Array(group["aliases"])]
  end
  raw_index_refs = normalization.fetch("raw_motif_group_index", {}).keys

  (motif_ids + alias_ids + hierarchy_refs + group_refs + raw_index_refs).compact.uniq
end

def bucket_for(motif_id, label)
  haystack = "#{motif_id} #{label}".downcase
  tokens = slug_tokens(haystack)

  REVIEW_BUCKETS.each do |bucket|
    next if bucket["id"] == "needs_human_sorting"

    return bucket if bucket.fetch("patterns").any? { |pattern| tokens.include?(pattern) || haystack.include?(pattern) }
  end

  REVIEW_BUCKETS.last
end

index = load_yaml(INDEX_PATH)
taxonomy = load_yaml(TAXONOMY_PATH)
normalization = load_yaml(NORMALIZATION_PATH)
known_ids = known_normalized_ids(taxonomy, normalization)

unmapped = index.fetch("motifs", []).reject { |motif| known_ids.include?(motif.fetch("motif_id")) }
bucket_records = REVIEW_BUCKETS.to_h do |bucket|
  [bucket["id"], bucket.merge("motifs" => [])]
end

unmapped.each do |motif|
  bucket = bucket_for(motif.fetch("motif_id"), motif["label"])
  bucket_records.fetch(bucket.fetch("id")).fetch("motifs") << {
    "motif_id" => motif.fetch("motif_id"),
    "label" => motif["label"],
    "occurrences" => Array(motif["occurrences"]).length,
    "traditions" => motif.fetch("traditions", {}).keys.sort
  }
end

bucket_records.each_value do |bucket|
  bucket["motifs"].sort_by! { |motif| [-motif.fetch("occurrences"), motif.fetch("motif_id")] }
end

audit = {
  "generated_on" => TODAY,
  "source" => "data/indexes/motif-occurrences.yml",
  "normalization_sources" => [
    "taxonomy/motifs.yml",
    "taxonomy/motif-normalization.yml"
  ],
  "method" => "Heuristic gap audit: motifs are considered mapped if they appear in the canonical taxonomy, normalization aliases, hierarchy refs, canonical motif groups, group children/aliases, or raw motif group index. Review buckets are semantic triage only, not canonical assignments.",
  "motif_count" => index.fetch("motif_count"),
  "mapped_count" => index.fetch("motifs", []).length - unmapped.length,
  "unmapped_count" => unmapped.length,
  "buckets" => bucket_records.values.map do |bucket|
    bucket.reject { |key, _value| key == "patterns" }.merge("count" => bucket.fetch("motifs").length)
  end
}

FileUtils.mkdir_p(File.dirname(OUTPUT_YAML))
File.write(OUTPUT_YAML, YAML.dump(audit))

markdown = []
markdown << "# Normalization Gap Audit"
markdown << ""
markdown << "Generated on #{TODAY} from `data/indexes/motif-occurrences.yml`."
markdown << ""
markdown << "This report lists motif IDs that are present in the motif occurrence index but not yet mapped in the canonical taxonomy or normalization file. The review buckets below are only rough semantic triage for human review; they are not automatic taxonomy assignments."
markdown << ""
markdown << "## Summary"
markdown << ""
markdown << "- Indexed motif IDs: #{audit.fetch("motif_count")}"
markdown << "- Already mapped: #{audit.fetch("mapped_count")}"
markdown << "- Unmapped: #{audit.fetch("unmapped_count")}"
markdown << ""
markdown << "| Review Bucket | Unmapped Motifs |"
markdown << "| --- | ---: |"
audit.fetch("buckets").each do |bucket|
  markdown << "| #{bucket.fetch("label")} | #{bucket.fetch("count")} |"
end

audit.fetch("buckets").each do |bucket|
  next if bucket.fetch("motifs").empty?

  markdown << ""
  markdown << "## #{bucket.fetch("label")}"
  markdown << ""
  markdown << "| Motif ID | Label | Occurrences | Traditions |"
  markdown << "| --- | --- | ---: | --- |"
  bucket.fetch("motifs").each do |motif|
    traditions = motif.fetch("traditions").join(", ")
    markdown << "| `#{motif.fetch("motif_id")}` | #{motif.fetch("label")} | #{motif.fetch("occurrences")} | #{traditions} |"
  end
end

FileUtils.mkdir_p(File.dirname(OUTPUT_MARKDOWN))
File.write(OUTPUT_MARKDOWN, markdown.join("\n") + "\n")

puts "wrote #{OUTPUT_YAML.sub("#{ROOT}/", "")}"
puts "wrote #{OUTPUT_MARKDOWN.sub("#{ROOT}/", "")}"
puts "mapped=#{audit.fetch("mapped_count")} unmapped=#{audit.fetch("unmapped_count")}"
