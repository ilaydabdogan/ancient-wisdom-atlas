#!/usr/bin/env ruby
# frozen_string_literal: true
require "yaml"; require "date"; require "fileutils"
ROOT = File.expand_path("..", __dir__)
FREQUENCY_PATH = File.join(ROOT, "data/indexes/canonical-motif-frequency.yml")
OUTPUT_PATH = File.join(ROOT, "data/normalization/sub-family-bins-lament-and-mourning.yml")
FAMILY_ID = "lament_and_mourning"

SUB_FAMILY_DEFS = [
  ["lament_and_mourning_lament_for_fallen_warrior", "Lament for the Fallen Warrior",
    "Public and collective lament over a fallen hero, king, or champion: city mourns its protector, women keening over slain warriors, last survivor's lament for the heroic band."],
  ["lament_and_mourning_mourning_kin", "Mourning Kin",
    "Mother for slain son, father for fallen child, widow over dead husband, son for dead father, sibling for sibling, kin-grief in all its forms."],
  ["lament_and_mourning_cosmic_or_natural_mourning", "Cosmic and Natural Mourning",
    "Animals, landscape, sea, and heavens mourning the death of a hero or god; rain as divine weeping; banshees and supernatural female lament; nature darkening at a passing."],
  ["lament_and_mourning_tears_and_transformation", "Tears, Transformation, and Memorialization",
    "Tears turning to pearls or precious substances, mourner transformed into a weeping stone, posthumous flower of lament, place names born of death, perpetual mourning landmarks."],
  ["lament_and_mourning_death_from_grief", "Death from Grief",
    "Grieving spouse fading away, suicide after catastrophic loss, mourner refusing food, life-ending grief, prolonged mourning leading to physical collapse."],
  ["lament_and_mourning_lost_heroic_age", "Lost Heroic Age",
    "Aged hero recalling lost power, last survivor of a vanished company, decline of the heroic line, old age contrasted with youth, nostalgia for what cannot return."],
  ["lament_and_mourning_mistaken_killing_remorse", "Mistaken Killing and Remorse",
    "Father slays unrecognized child, victor laments slain friend, mistaken hunting kill, slayer's grief over the slain opponent, lament of guilt and future infamy."],
  ["lament_and_mourning_mourning_ritual", "Mourning Ritual and Funerary Practice",
    "Funeral processions, ritual keening, cremation rites, mourning fast, hypocritical mourning, female ritual specialists, ceremonial lament for a named figure."],
  ["lament_and_mourning_fate_and_mortality", "Fate and Mortality",
    "Life's transience, best-not-to-be-born, the impermanence of glory, tree as emblem of mortal fragility, the wish for death reversed by the fear of death."],
  ["lament_and_mourning_grief_imagery_and_song", "Grief Imagery and Song",
    "Grief expressed through music and poetry, swan song, songs that move nature, simile of plucked flower, lament beside water, hidden grief revealed by song."]
]

CHILDREN = {
  "lament_and_mourning_lament_for_fallen_warrior" => %w[
    beloved_hero_mourned_by_city_and_nature_warrior city_mourns_absent_ruler collective_lament_for_the_fallen_champion collective_lamentation_for_a_fallen_defender compassionate_lament_for_condemned_outcasts dead_ruler_still_looking_toward_lost_possessions doomed_aged_king_arms_himself_during_the_fall_of_the_city dying_hero_arranges_successor_relationship_for_his_bride dying_warrior_amid_lamentation fallen_royal_tree_lament farewell_lament_of_the_royal_household grief_weakening_warriors_before_battle heroic_death_followed_by_keening_lament heroic_lament_and_escorted_return_of_a_fallen_youth inconsolable_grief_after_slain_companions_or_beloveds lament_after_tragic_death lament_for_a_fallen_warrior lament_for_a_fallen_warrior_kinsman lament_for_dead_heroic_companions lament_for_fallen_companion_and_endangered_kin lament_for_slain_friend_opponent lament_for_the_fallen_hero lament_for_the_land_defending_hero lament_over_a_slain_sworn_companion lament_over_the_dead_companion lament_over_the_fallen_king lament_over_the_fallen_warrior_king mourning_after_destruction_of_homeland mourning_after_loss_of_protectors mourning_over_the_slain_royal_warrior public_lamentation_over_slain_warrior slaughtered_band_of_youthful_allies supernatural_female_lament_for_a_hero warrior_band_mourning_an_absent_lord women_s_lament_over_a_dead_ruler
  ],
  "lament_and_mourning_mourning_kin" => %w[
    bereaved_child_discovers_slain_parent bereaved_father_mourning_a_fallen_son bereaved_mother_laments_last_child_and_ruined_house consolatory_comparison_of_bereaved_parents daughter_lamenting_bad_marital_placement_by_mother dependent_blind_parents_lose_their_only_guide disciple_mourning_slain_teacher dying_mother_addresses_daughter family_reunion_after_mourning fatherly_supplication_for_mercy_from_a_killer_or_enemy grief_death_of_the_royal_father grief_for_lost_kinsman_or_comrade grieving_mother_at_the_grave grieving_mother_turns_to_vengeance_for_a_murdered_child grieving_parent_mourns_absent_son_as_dead grieving_parent_returns_to_battle_seeking_death_or_vengeance lament_for_the_dead_beloved lament_for_the_dead_hero_by_his_wife lament_over_the_fallen_warrior_by_mother_and_widow lamenting_survivor_beside_slain_beloved_and_kin lamenting_wife_offers_healing_to_doomed_warrior loss_of_heirs_extinguishing_household_continuity loyal_servant_mourns_the_absent_master maternal_lament_at_separation_from_exiled_children maternal_lament_for_absent_endangered_son maternal_lament_over_loss_of_the_cherished_son mistaken_return_or_presence_through_another_s_armor mother_s_lament_for_slain_and_unburied_son mother_son_grief_at_separation mourning_father_and_unavenged_son mourning_mother_imagines_son_in_the_realm_of_death mourning_parents_touch_the_slain_child one_death_dooms_a_dependent_family orphaned_child_deprived_by_the_father_s_death orphaned_wanderer_s_lament parental_lament_for_a_dead_hero parental_supplication_before_a_hero_s_fatal_combat parental_supplication_to_avert_heroic_death refusal_to_praise_an_enemy_because_of_remembered_kin_slaying return_of_the_fallen_son_to_the_grieving_father slain_son_mourned_and_avenged_by_father son_s_prostrate_lament_for_deceased_father unknown_fate_of_absent_husband violent_retaliation_after_overheard_lament widow_and_mother_keening_over_slain_husband_and_sons widow_s_lament_beside_the_body widow_s_lament_for_the_fallen_husband widow_s_lament_over_fallen_warrior_king widow_s_lament_over_the_dead_king wife_brings_weapons_and_performs_lament woman_on_tower_watching_battle_and_fearing_for_absent_husband
  ],
  "lament_and_mourning_cosmic_or_natural_mourning" => %w[
    animal_grief_mirrors_human_grief animal_mourning_for_human_master_or_companions animals_lamenting_a_slain_human_companion beloved_hero_mourned_by_city_and_nature cosmic_mourning_after_a_divine_death cosmic_or_atmospheric_mourning_for_a_slain_child death_as_final_sleep_watched_by_nature dying_animal_laments_the_manner_of_its_death fairy_women_lament_as_origin_of_a_named_wail grieving_animals_at_a_hero_s_death human_grief_mirrored_by_protective_animal_parent immortal_horses_mourning_a_dead_hero lamenting_or_questioning_bird_at_an_abandoned_seat_of_power mourning_animal_in_funeral_procession mourning_or_sentient_landscape natural_world_mourns_a_beloved_figure_s_departure public_grief_echoing_through_nature rain_as_divine_weeping sea_as_agent_of_death_and_lament sea_nymph_mourning_procession speaking_tree_lamenting_human_use_and_seasonal_suffering threefold_lamenting_birds
  ],
  "lament_and_mourning_tears_and_transformation" => %w[
    aetiology_of_pearls_and_bird_plumage_from_a_hero_s_tears grief_as_futile_tears_of_blood grief_overflowing_as_blood_and_water grief_tears_transformed_into_precious_substances grief_transformed_into_water metamorphosis_into_enduring_mourning_landmark mourner_as_fallen_heavenly_body mourner_transformed_into_weeping_stone perpetual_mourning_assigned_to_transformed_being place_name_origin_from_death_or_animal_sign posthumous_inscribed_flower_of_lament sorrow_figured_as_overwhelming_water tears_as_heavenly_sign_of_grief tears_of_mourning_bind_or_disturb_the_dead
  ],
  "lament_and_mourning_death_from_grief" => %w[
    appeal_to_hostile_divinity_for_death_as_relief attempted_suicide_interrupted_by_caregiver death_from_grief_and_blame_after_destruction_of_two_lands death_from_grief_and_fear_after_witnessing_a_killing death_from_grief_for_wounded_spouse death_from_shame_after_others_die_on_one_s_account death_from_shame_after_slaughter_caused_by_protection excessive_grief_leading_to_violation_of_human_and_divine_norms grief_driven_plunge_into_water grief_for_absent_kin_leading_to_decline_or_death grieving_beloved_wastes_away_and_vanishes grieving_spouse_fading_after_loss life_ending_grief mourning_beloved_refuses_joy_and_sustenance mourning_spouse_attempts_to_replace_the_dead_beloved_with_an_artificial_bride prolonged_mourning_without_relief_leading_to_physical_collapse_death royal_seclusion_overturned_by_grief separation_causing_refusal_of_food_and_care spouse_dies_of_grief_beside_the_dead_beloved suicide_after_catastrophic_loss
  ],
  "lament_and_mourning_lost_heroic_age" => %w[
    aged_hero_recalls_lost_youthful_power aging_singer_laments_loss_of_voice decline_and_end_of_a_heroic_company departed_companions_precede_the_speaker_into_death diminished_survivor_of_a_vanished_company former_heroic_strength_contrasted_with_old_age lament_for_a_lost_heroic_age lament_of_the_last_survivor_of_a_heroic_band lament_over_being_left_behind last_survivor_lamenting_a_vanished_heroic_company mortal_lament_for_vanished_heroic_company nostalgic_lament_for_vanished_heroic_companions old_age_contrasted_with_heroic_youth old_warrior_lamenting_lost_heroic_age
  ],
  "lament_and_mourning_mistaken_killing_remorse" => %w[
    hero_s_lament_for_a_slain_opponent innocent_victim_killed_and_later_regretted keening_and_memorialization_after_tragic_error killing_and_lament_of_a_cherished_hound lament_after_killing_a_friend_or_opponent lament_of_guilt_and_future_infamy lament_over_a_slain_opponent mistaken_hunting_kill_of_a_child mistaken_killing_of_beloved_during_hunt mistaken_killing_of_one_s_own_child past_guilt_returning_during_present_grief remorse_after_a_brother_s_death self_blame_for_destruction_of_kin slayer_laments_slain_opponent unrecognized_child_slain_by_father victor_laments_the_slain_friend
  ],
  "lament_and_mourning_mourning_ritual" => %w[
    battle_halted_by_the_arrival_of_a_grieving_queen_woman cessation_of_ritual_festivity_and_commerce_in_mourning comic_reversal_of_mourning communal_female_mourning death_memorial_covered_by_living_flowers false_death_report_leading_to_mistaken_mourning_rites funeral_lament_followed_by_sudden_love_for_the_widow funeral_or_mourning_rite_for_insects_or_animals grave_growth_sign_controlling_remarriage grief_at_body_ashes_tomb_and_name grieving_messenger_sent_to_tell_a_beloved_warrior_of_death heroic_grief_expressed_through_bodily_abasement honored_hero_cremation_with_precious_container_and_companion_burial hypocritical_mourner_with_false_tears leader_s_consoling_speech_after_communal_catastrophe messenger_announces_the_death_of_a_beloved_companion mourner_s_tears_released_by_contact_with_the_dead mourning_expressed_through_embracing_and_kissing_the_deceased_warrior_s_horse_and_equipment mourning_fast_before_renewed_combat mourning_interrupted_or_postponed_for_the_meal mourning_messenger_brings_news_of_royal_death nightly_death_watch_of_one_among_three_companions ominous_hearing_of_public_lament_before_recognition_of_death post_battle_funeral_lament_by_bereaved_women refusal_and_reversal_of_mourning_among_kin renowned_tragic_grave_of_heroine ritual_lament_for_a_named_figure ritual_procession_of_mourners shared_epitaph_as_marital_memorial uncertainty_of_death_place_or_burial_place
  ],
  "lament_and_mourning_fate_and_mortality" => %w[
    beautiful_youth_with_untimely_death best_not_to_be_born fate_lament grief_anticipating_early_death immortality_experienced_as_lamentation impermanence_of_glory_after_a_great_teacher_s_death life_s_transience_and_irreversible_death mortality_of_companions_and_remembrance_with_wine prayer_for_visible_death_in_daylight recognition_followed_by_reversal_of_life tragic_heroine_s_lament_at_death tree_emblem_of_mortal_fragility unresolved_heroic_quarrel_persists_after_death wealth_gained_abroad_overshadowed_by_grief_and_loss wish_for_death_reversed_by_fear_of_death wish_for_non_birth_or_infant_death_in_maiden_s_lament
  ],
  "lament_and_mourning_grief_imagery_and_song" => %w[
    destruction_in_the_furnace_of_grief dying_swan_song_as_image_for_lament echoed_lament_and_farewell empty_vehicle_as_sign_of_absent_hero fallen_youth_compared_to_a_plucked_flower foreign_sanctuary_preserves_memory_of_homeland_suffering grief_leading_to_speech grief_transformed_into_poetic_form grieving_hero_on_mountain_height hero_mourns_sacrificed_beloved_and_place_name_preserves_memory hero_threatens_landscape_in_grief hidden_suffering_revealed_by_bodily_scars lament_beside_water lament_comparing_joy_to_free_flowing_water_and_sorrow_to_frozen_or_imprisoned_water lament_for_beloved_speaking_bird lament_of_stranded_hero_recognized_and_answered lament_voiced_through_natural_material_and_instrument misinterpreted_lament_provokes_jealous_suspicion mourning_musician_whose_song_moves_nature pathos_of_slain_young_warriors_through_genealogy_and_simile personified_grief_fed_by_mourning place_of_past_suffering_revives_painful_memory prophecy_like_lament_for_ruined_survivors song_reserved_for_the_moment_before_death song_reveals_hidden_grief_of_the_hero spring_landscape_intensifies_separation_lament unaware_supplication_for_one_already_dead unseen_lament_heard_at_threshold_of_journey young_warrior_cut_down_like_a_tree youth_cut_down_like_an_uprooted_tree
  ]
}.freeze

def load_yaml(path); YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}; end
def main
  freq = load_yaml(FREQUENCY_PATH)
  family = freq.fetch("canonical_motifs").find { |g| g["canonical_motif_id"] == FAMILY_ID }
  motifs = family.fetch("mapped_motifs").map { |m| m["motif_id"] }
  m2s = {}; CHILDREN.each { |k, v| v.each { |m| m2s[m] = k } }
  bins = Hash.new { |h, k| h[k] = [] }
  unbinned = []
  motifs.each { |m| (b = m2s[m]) ? bins[b] << m : unbinned << m }
  output = {
    "generated_on" => Date.today.iso8601, "family" => FAMILY_ID,
    "method" => "manual binning by reading slugs",
    "total_motifs" => motifs.length, "binned" => motifs.length - unbinned.length, "unbinned" => unbinned.length,
    "sub_families" => SUB_FAMILY_DEFS.map { |id, label, desc|
      { "id" => id, "label" => label, "description" => desc, "child_count" => bins[id].length, "children" => bins[id].sort }
    },
    "unbinned_children" => unbinned.sort
  }
  FileUtils.mkdir_p(File.dirname(OUTPUT_PATH))
  File.write(OUTPUT_PATH, "---\n" + output.to_yaml(line_width: -1).sub(/\A---\n/, ""))
  puts "#{FAMILY_ID}: #{motifs.length} total / #{motifs.length - unbinned.length} binned / #{unbinned.length} unbinned"
  SUB_FAMILY_DEFS.each { |id, _, _| puts "  %-60s %4d" % [id, bins[id].length] }
  unbinned.each { |m| puts "  UNBINNED: #{m}" } if unbinned.any?
end
main if $PROGRAM_NAME == __FILE__
