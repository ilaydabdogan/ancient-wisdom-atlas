#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TODAY = Date.today.iso8601
RUN_ID = "normalization-suggestions-2026-04-29-full-gap-priority"
TAXONOMY_PATH = File.join(ROOT, "taxonomy", "motif-normalization.yml")
LAYER3_REVIEW_PATH = File.join(ROOT, "data", "reviews", "normalization-suggestions", RUN_ID, "new-group-candidates-condensed.yml")
LAYER3_DOC_PATH = File.join(ROOT, "docs", "normalization-review-layer-3-new-groups.md")

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def write_yaml(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "#{YAML.dump(data)}\n")
end

def canonical_groups(taxonomy)
  taxonomy["canonical_motif_groups"] ||= []
end

def groups_by_id(taxonomy)
  canonical_groups(taxonomy).each_with_object({}) do |group, memo|
    memo[group.fetch("id").to_s] = group
  end
end

def uniq_append(array, values)
  values.each do |value|
    next if value.to_s.empty?

    array << value.to_s unless array.include?(value.to_s)
  end
end

def remove_values(array, values)
  values = values.map(&:to_s)
  array.delete_if { |value| values.include?(value.to_s) }
end

def ensure_group(taxonomy, id, label:, description:, children:, aliases:, related:)
  groups = groups_by_id(taxonomy)
  group = groups[id.to_s]
  unless group
    group = { "id" => id.to_s, "label" => label, "description" => description, "children" => [], "aliases" => [], "related" => [] }
    canonical_groups(taxonomy) << group
  end

  group["label"] = label
  group["description"] = description
  group["children"] ||= []
  group["aliases"] ||= []
  group["related"] ||= []
  uniq_append(group["children"], children)
  uniq_append(group["aliases"], aliases)
  uniq_append(group["related"], related)
  group["review_status"] = "human_accepted"
  group["accepted_on"] ||= TODAY
  group["accepted_from"] = "docs/normalization-review-layer-3-new-groups.md"
  group
end

def add_related(taxonomy, group_id, related_ids)
  groups = groups_by_id(taxonomy)
  group = groups[group_id.to_s]
  return unless group

  group["related"] ||= []
  uniq_append(group["related"], related_ids.select { |id| groups.key?(id.to_s) })
end

def raw_mapping(taxonomy, motif_id, group_id, relationship:, review_status:, review_action:, provisional:, notes:)
  taxonomy["raw_motif_group_index"] ||= {}
  previous = taxonomy["raw_motif_group_index"][motif_id.to_s]
  record = {
    "group_id" => group_id.to_s,
    "relationship" => relationship,
    "confidence" => "human",
    "review_status" => review_status,
    "review_action" => review_action,
    "provisional" => provisional,
    "source" => "docs/normalization-review-layer-3-new-groups.md",
    "accepted_on" => TODAY,
    "notes" => notes
  }
  record["previous_group_id"] = previous["group_id"] if previous.is_a?(Hash) && previous["group_id"]
  record["previous_review_status"] = previous["review_status"] if previous.is_a?(Hash) && previous["review_status"]
  taxonomy["raw_motif_group_index"][motif_id.to_s] = record
end

def write_layer3_doc(review)
  genuine = review.fetch("genuine_new_group_candidates", [])
  accepted = genuine.select { |item| item["recommended_action"].to_s.start_with?("accepted") }
  folded = genuine.select { |item| item["recommended_action"].to_s == "fold_into_existing_group" }
  legacy_folds = review.fetch("folded_single_tradition_candidates", [])

  lines = []
  lines << "# Normalization Review Layer 3: New Group Decisions"
  lines << ""
  lines << "Generated on #{TODAY}."
  lines << ""
  lines << "This file records the human decisions for the eight cross-tradition candidates from the full-gap normalization review."
  lines << ""
  lines << "## Summary"
  lines << ""
  review.fetch("summary", {}).each { |key, value| lines << "- #{key.tr("_", " ")}: #{value}" }
  lines << ""
  lines << "## Accepted Into Main Taxonomy"
  lines << ""
  lines << "| Candidate | Traditions | Source Motifs | Canonical Group | Decision Note |"
  lines << "| --- | ---: | ---: | --- | --- |"
  accepted.each do |item|
    lines << "| `#{item["id"]}` #{item["label"]} | #{Array(item["traditions"]).length} | #{Array(item["source_motif_ids"]).length} | `#{item["accepted_group_id"]}` | #{item["decision_note"]} |"
  end
  lines << ""
  lines << "## Folded Into Existing Families"
  lines << ""
  lines << "| Candidate | Traditions | Source Motifs | Fold Target | Decision Note |"
  lines << "| --- | ---: | ---: | --- | --- |"
  folded.each do |item|
    lines << "| `#{item["id"]}` #{item["label"]} | #{Array(item["traditions"]).length} | #{Array(item["source_motif_ids"]).length} | `#{item["fold_target_group_id"]}` | #{item["decision_note"]} |"
  end
  lines << ""
  lines << "## Earlier Single-Tradition Folds"
  lines << ""
  lines << "| Candidate | Traditions | Source Motifs | Fold Target | Basis |"
  lines << "| --- | --- | ---: | --- | --- |"
  legacy_folds.each do |item|
    lines << "| `#{item["id"]}` #{item["label"]} | #{Array(item["traditions"]).join(", ")} | #{Array(item["source_motif_ids"]).length} | `#{item["fold_target_group_id"]}` | #{item["fold_basis"]} |"
  end

  File.write(LAYER3_DOC_PATH, lines.join("\n") + "\n")
end

taxonomy = load_yaml(TAXONOMY_PATH)
review = load_yaml(LAYER3_REVIEW_PATH)
taxonomy["updated_on"] = TODAY

world_children = %w[
  decline_through_successive_metallic_ages
  declining_ages_of_humankind
  primeval_age_followed_by_degeneration
  primordial_innocence_followed_by_loss_of_effortless_abundance
  divine_peace_stead_and_golden_age
  four_age_decline_of_the_world_period
  four_ages_of_the_world
]

recognition_children = %w[
  recognition_by_scent_on_food_or_object
  recognition_of_herald_by_visible_tokens
  recognition_through_a_talisman_or_token
  recognition_through_hidden_identity_and_voice
  recognition_token_as_bodily_scar
  recognition_token_proving_an_otherwise_denied_encounter
  recognition_token_sent_by_envoy
  recognition_token_sent_through_a_messenger
  recognition_by_personal_tokens
  recognition_prevents_kin_slaying_by_poison
  recognition_token_exchanged_while_one_beloved_sleeps
  recognition_tokens_from_the_abducted_beloved
]

enchanting_music_children = %w[
  music_that_charms_nature
  music_that_charms_nature_and_restrains_violence
  enchanted_music_compels_procession
  enchanted_music_that_causes_sleep
  enchanting_music_that_attracts_living_beings
  magical_music_causing_universal_emotion_or_sleep
  magical_music_controlling_emotion_and_sleep
  magical_music_subdues_opponents
  music_that_compels_emotion_and_sleep
  music_that_induces_sleep_or_weakens_vigilance
  enchanted_music_summons_animals_birds_forest_beings_and_sky_daughters
  music_compelling_or_softening_supernatural_powers
  powerful_music_causing_beings_to_fall_or_perish
  sacred_music_draws_celestial_bodies_downward
  supernatural_music_commanding_nature
  enchanting_supernatural_music
  perilous_enchanting_music
  irresistible_fairy_music_causing_compulsory_dance_or_fatal_performance
  lethal_supernatural_music
  siren_song_draws_river_travelers_to_death
]

jealous_stepmother_children = %w[
  jealous_stepmother_demands_child_s_heart
  jealous_stepmother_endangers_children
  jealous_stepmother_falsely_accuses_innocent_stepchild
  jealous_wife_or_stepmother_harms_children
]

folds = {
  "marriage_choice_bride_winning" => {
    target: "sacred_love",
    children: %w[bride_choice_assembly bride_s_own_answer_required bride_winning_martial_contest],
    note: "Bride contests and marriage choice are a subset of sacred love, union, and kinship patterns."
  },
  "deceptive_war_stratagem" => {
    target: "trickster",
    children: %w[deceptive_gift_containing_hidden_warriors deceptive_promise_of_treasure_used_to_lure_an_enemy],
    note: "Military deception is boundary-crossing trickery applied to warfare."
  },
  "celestial_guides_witnesses" => {
    target: "dream_and_vision",
    children: %w[moon_as_guide_and_comforter moon_as_witness_to_future_absence],
    note: "Celestial guidance and witness motifs function here as perception, omen, and altered-awareness patterns."
  },
  "solar_power" => {
    target: "sacred_fire",
    children: %w[sun_as_source_of_illumination_and_growth sun_confined_and_released_from_a_tower sunlight_petrifies_beings_of_darkness_or_fog],
    note: "Solar deity imagery, life-giving light, and cosmic sustenance are covered by sacred fire and divine light."
  }
}

ensure_group(
  taxonomy,
  "world_ages_cosmic_decline",
  label: "World Ages and Cosmic Decline",
  description: "The recurring schema of successive world ages, yugas, golden ages, metallic ages, and cosmic decline, where a primordial or divine order decays across time.",
  children: world_children,
  aliases: %w[world_ages_decline ages_of_decline golden_age_primordial_peace four_ages yugas metallic_ages],
  related: %w[sacred_time cosmic_origin duality divine_judgment flood_and_renewal]
)

ensure_group(
  taxonomy,
  "recognition_tokens_hidden_identity",
  label: "Recognition Tokens and Identity Proofs",
  description: "Tokens, scars, scent, voice, talismans, and messenger-borne objects prove identity, kinship, authority, or a denied encounter across traditions.",
  children: recognition_children,
  aliases: %w[recognition_tokens recognition_tokens_hidden_identity identity_tokens proof_tokens hidden_identity_proof recognition_by_scar],
  related: %w[hero_journey sacred_treasures royal_legitimacy sacred_love miraculous_child divine_judgment storytelling_as_power]
)

ensure_group(
  taxonomy,
  "enchanting_music",
  label: "Enchanting Music and Sound Power",
  description: "Music, song, instrument sound, or voice acts as supernatural force: charming nature, compelling sleep or procession, subduing opponents, summoning powers, or luring hearers across a threshold.",
  children: enchanting_music_children,
  aliases: %w[enchanted_music magical_music supernatural_music sound_compulsion orphic_music siren_song music_as_power],
  related: %w[storytelling_as_power sacred_knowledge threshold_guardian sacred_love sacred_combat]
)

ensure_group(
  taxonomy,
  "jealous_stepmother_persecuted_child",
  label: "Jealous Stepmother and Persecuted Child",
  description: "A jealous stepmother, wife, or rival caretaker endangers, falsely accuses, or demands violence against an innocent child; the focus is persecution within the household rather than the child's sacred destiny.",
  children: jealous_stepmother_children,
  aliases: %w[persecuted_child jealous_stepmother wicked_stepmother false_accusation_of_stepchild],
  related: %w[miraculous_child sacred_love divine_judgment]
)

groups = groups_by_id(taxonomy)

if groups["storytelling_as_power"]
  groups["storytelling_as_power"]["children"] ||= []
  groups["storytelling_as_power"]["aliases"] ||= []
  remove_values(groups["storytelling_as_power"]["children"], enchanting_music_children)
  remove_values(groups["storytelling_as_power"]["aliases"], %w[enchanted_music enchanted_music_sound_power enchanting_music magical_music supernatural_music])
  uniq_append(groups["storytelling_as_power"]["related"], ["enchanting_music"])
end

folds.each_value do |decision|
  target = groups[decision.fetch(:target)]
  next unless target

  target["children"] ||= []
  target["aliases"] ||= []
  uniq_append(target["children"], decision.fetch(:children))
end

add_related(taxonomy, "sacred_time", ["world_ages_cosmic_decline"])
add_related(taxonomy, "cosmic_origin", ["world_ages_cosmic_decline", "sacred_fire"])
add_related(taxonomy, "sacred_fire", ["world_ages_cosmic_decline", "enchanting_music"])
add_related(taxonomy, "storytelling_as_power", ["enchanting_music", "recognition_tokens_hidden_identity"])
add_related(taxonomy, "threshold_guardian", ["enchanting_music"])
add_related(taxonomy, "miraculous_child", ["jealous_stepmother_persecuted_child", "recognition_tokens_hidden_identity"])
add_related(taxonomy, "divine_judgment", ["world_ages_cosmic_decline", "jealous_stepmother_persecuted_child"])
add_related(taxonomy, "sacred_love", ["jealous_stepmother_persecuted_child", "recognition_tokens_hidden_identity"])
add_related(taxonomy, "sacred_treasures", ["recognition_tokens_hidden_identity"])
add_related(taxonomy, "dream_and_vision", ["celestial_guides_witnesses"])
add_related(taxonomy, "trickster", ["deceptive_war_stratagem"])

world_children.each do |motif_id|
  raw_mapping(taxonomy, motif_id, "world_ages_cosmic_decline", relationship: "child_motif", review_status: "human_accepted_layer3_new_group", review_action: "accepted_new_group", provisional: false, notes: "Human decision: accept World Ages and Cosmic Decline as a distinct cross-cultural family.")
end

recognition_children.each do |motif_id|
  raw_mapping(taxonomy, motif_id, "recognition_tokens_hidden_identity", relationship: "child_motif", review_status: "human_accepted_layer3_new_group", review_action: "accepted_new_group", provisional: false, notes: "Human decision: accept Recognition Tokens as a distinct identity-proof family; existing canonical group retained.")
end

enchanting_music_children.each do |motif_id|
  raw_mapping(taxonomy, motif_id, "enchanting_music", relationship: "child_motif", review_status: "human_accepted_layer3_new_group", review_action: "accepted_new_group", provisional: false, notes: "Human decision: accept Enchanting Music as sound-power distinct from storytelling-as-narrative.")
end

jealous_stepmother_children.each do |motif_id|
  raw_mapping(taxonomy, motif_id, "jealous_stepmother_persecuted_child", relationship: "child_motif", review_status: "human_accepted_layer3_new_group", review_action: "accepted_new_group", provisional: false, notes: "Human decision: accept household persecution of the child as distinct from miraculous-child destiny.")
end

folds.each do |candidate_id, decision|
  decision.fetch(:children).each do |motif_id|
    raw_mapping(taxonomy, motif_id, decision.fetch(:target), relationship: "folded_child_motif", review_status: "human_reviewed_layer3_fold", review_action: "folded_into_existing_group", provisional: true, notes: "Human decision: #{decision.fetch(:note)}")
  end
  target = groups[decision.fetch(:target)]
  uniq_append(target["aliases"], [candidate_id]) if target
end

review["summary"] ||= {}
review["summary"]["human_decisions_applied_on"] = TODAY
review["summary"]["accepted_from_genuine_candidates"] = 4
review["summary"]["folded_from_genuine_candidates"] = 4
review["summary"]["pending_genuine_candidates_after_human_review"] = 0

accepted_notes = {
  "world_ages_cosmic_decline" => ["world_ages_cosmic_decline", "Accepted as a distinct cross-cultural world-age and cosmic-decline family."],
  "enchanting_music" => ["enchanting_music", "Accepted as sound itself operating as supernatural force, distinct from narrative power."],
  "recognition_tokens" => ["recognition_tokens_hidden_identity", "Confirmed through the existing accepted Recognition Tokens and Identity Proofs family."],
  "jealous_stepmother_persecuted_child" => ["jealous_stepmother_persecuted_child", "Accepted as household persecution of the child, distinct from miraculous-child destiny."]
}

review.fetch("genuine_new_group_candidates", []).each do |item|
  id = item.fetch("id").to_s
  if accepted_notes.key?(id)
    group_id, note = accepted_notes.fetch(id)
    item["recommended_action"] = "accepted_into_main_taxonomy"
    item["accepted_group_id"] = group_id
    item["decision_note"] = note
    item["decided_on"] = TODAY
  elsif folds.key?(id)
    item["recommended_action"] = "fold_into_existing_group"
    item["fold_target_group_id"] = folds.fetch(id).fetch(:target)
    item["decision_note"] = folds.fetch(id).fetch(:note)
    item["decided_on"] = TODAY
  end
end

write_yaml(TAXONOMY_PATH, taxonomy)
write_yaml(LAYER3_REVIEW_PATH, review)
write_layer3_doc(review)

puts "applied layer 3 human decisions"
puts "accepted_new_groups=4"
puts "folded_candidates=4"
