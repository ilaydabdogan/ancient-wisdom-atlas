#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bin the 548 divine_intervention child motifs into 8 sub-families.

require "yaml"
require "date"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
FREQUENCY_PATH = File.join(ROOT, "data/indexes/canonical-motif-frequency.yml")
OUTPUT_PATH = File.join(ROOT, "data/normalization/sub-family-bins-divine-intervention.yml")
FAMILY_ID = "divine_intervention"

SUB_FAMILIES = [
  {
    id: "divine_intervention_messengers_prophets",
    label: "Messengers and Prophets",
    description: "Angels, divine messengers, prophets, and prophetic commissioning. The figure who carries the divine word into the human world.",
    rules: [
      /\bangel/, /angelic/, /\barchangel/,
      /messenger/, /messengers/,
      /\bprophet/, /prophetic/, /prophesy/,
      /commission/, /commissioning/,
      /vision_authorizing/, /\bsummon/,
      /preacher/, /\bwarner/, /admonisher/,
      /heavenly_decree/, /angelic_decree/, /divine_decree/,
      /celestial_praise_and_ranked_angels/, /heavenly_order/,
      /chosen.*deput/, /chosen.*assistant/,
      /reluctant_messenger/, /reluctant_prophet/,
      /refused_homage/, /idol_breaking/
    ]
  },
  {
    id: "divine_intervention_battle_aid",
    label: "Divine Aid in Battle",
    description: "The god intervenes in war: defending heroes, granting victory, disrupting enemy weapons, riding into battle, restoring courage to flagging warriors.",
    rules: [
      /heavenly_aid_in_battle/, /aid.*\bbattle/, /aid.*\bwar/,
      /divine_intervention_in_a_pursuit/, /divine_intervention_in.*battle/,
      /divine_management_of_mortal_single_combat/,
      /divine_messenger_prompts_battle/,
      /divine_deliverance_in_communal_battle/,
      /divine_aid_to_a_hero_at_sea/,
      /divinely_aided_victory/, /divinely_granted_victory/, /divinely_aided_survival/,
      /divine_patron_strengthens_a_wounded_warrior/,
      /divine_restoration_of_battle_steeds/,
      /divine_incitement_of_opposing_armies/,
      /divine_intervention_prevents_a_successful_human_strike/,
      /divine_intervention_to_renew_human_courage/,
      /weapon_failure_as_divine_sign/,
      /warrior_as_divine_weapon/,
      /single_combat_delayed_by_divine/,
      /spared_survivor_through_divine_intervention/,
      /defeat_followed_by_divinely_aided_victory/,
      /divine_council.*nonintervention/,
      /divine_concealment_rescues_a_vulnerable_hero/,  # battle context
      /chosen_assistants_of_god_strengthened_to_victory/,
      /angelic_promise_of_success_before_conflict/,
      /persecuted_righteous_community_receives_divine.*aid/,
      /communal_unification.*divine_deliverance/,
      /supernatural_army_hidden_by_magic_mist/,
      /supernatural_helper_summoned_by_a_ruler/,
      /mist_or_cloud_covering_a_rout/,
      /army_summoned_from_the_earth/,
      /heavenly_order_defending_against_devils/,
      /armed_guardian_goddess_of_a_city/,
      /city_guardian_war_goddess_protects_people/,
      /protective_wall_or_fortress_requested_from_a_deity/,
      /parental_prayer_for_a_child_s_safety_before_war/,
      /fallen_charioteer_after_divine_disruption/,
      /aerial_divine_errand_in_a_dragon_drawn_chariot/,
      /aerial_transport_of_royal_heroes/,
      /public_protective_deities_as_paired_mounted_warriors/
    ]
  },
  {
    id: "divine_intervention_healing_provision",
    label: "Healing and Provision",
    description: "Healing miracles, curing of disease and pestilence, provision in the wilderness, drought-breaking rain, fertility, manna, water from rock, food multiplication.",
    rules: [
      /heal/, /\bcure\b/, /miraculous_cure/, /miraculous_or_unusual_cure/,
      /pestilence/, /\bplague\b/, /disease/,
      /rain_miracle/, /intercessory_rain/, /rainmaking/, /miraculous_rain/,
      /\bdrought/, /breaking.*drought/,
      /water_from_rock/, /miraculous_water/,
      /provision_in_the_wilderness/, /provisioning_in_wilderness/,
      /magical_provisioning/, /\bmanna\b/,
      /\bfertility\b/,
      /vegetation/, /providence/, /provid/,
      /supplies_the_devotee/,
      /healing_helpers_counter_destructive_enemies/,
      /food_multiplied/, /food_multiplication/,
      /restoration_to_health/,
      /pestilence_relieved/,
      /miraculous_creation_and_healing/,
      /healing_by_touch/, /healing_by_breath/, /healing_by_command/,
      /ritual_healing/,
      /divine_unity_and_providence/,
      /enemy_healers_compelled/,
      /benevolent_goddess_grants_gifts/,
      /benevolent_aerial_nature_spirits_tending/
    ]
  },
  {
    id: "divine_intervention_rescue_protection",
    label: "Rescue and Protection",
    description: "Divine rescue from peril, concealment from enemies, refuge for fugitives, protective deities of cities and households, sanctuary, deliverance from fire and water and bonds.",
    rules: [
      /\brescue/, /divine_rescue/,
      /\brefuge/, /sanctuary/, /\bshelter/,
      /\bprotect/, /protective/, /protection/,
      /deliverance/, /delivered/,
      /tutelary/, /civic_or_communal_tutelary/,
      /\bguard\b/, /guardian/, /guardianship/,
      /concealing_cloud/, /concealing_mist/,
      /divine_concealment/, /divine_signs_overcome_enchantment/,
      /seeking_divine_refuge/,
      /preserved_from_temptation/, /preservation.*temptation/,
      /protected_friends_or_believers_of_god/,
      /protective_divine_sleep/,
      /saved_by_divine/, /saved.*god/,
      /divine_aid_in_refuge/,
      /authority_restores_separated_companions/,
      /spared.*divine/, /spared_through_divine/,
      /divine_protection_from_an_adversarial_satan/,
      /reversal_through_divine_care_guidance_and_enrichment/,
      /unexpected_helper_joins_fugitives/,
      /angelic_guardianship/,
      /saving_cord_of_god/,
      /compassionate_religious_savior_as_refuge/,
      /afflicted_righteous_supplicant_appeals_to_divine_mercy/,
      /afflicted_bride.*supernatural_warning_voice/,
      /weak_remnant.*refuge/, /refuge_for_a_weak_remnant/,
      /imperiled_hero/, /endangered.*hero/,
      /deliverance_from_fiery_peril/,
      /appeal_to_divine_and_elder_protectors_during_crisis/,
      /escape_through_supernatural_aid/, /supernatural_escape/,
      /prayer_for_death_or_supernatural_removal_to_avoid/,
      /body_carried_by_unseen_forces/,
      /burden_removed_and_heart_opened/,
      /angelic_messenger_and_guardian_functions/,
      /angelic.*guardian/,
      /guardian_as_saviour_or_destroyer_of_the_city/,
      /captive_liberated/, /holy_captive_liberated/
    ]
  },
  {
    id: "divine_intervention_animal_nature_helpers",
    label: "Animal and Nature Helpers",
    description: "Animal allies in service of the divine: birds bearing news, beasts revealing trails, marine helpers, nature spirits, sacred landscapes, talking animals, animal-led discoveries.",
    rules: [
      /\banimal/, /\banimals/,
      /\bbird\b/, /\bbirds\b/,
      /marine_helper/, /\bmarine\b/,
      /forest_being/, /\bforest/,
      /nature_spirit/, /natural_phenomenon_personified/,
      /minor_nature_divinities/,
      /\bbeast\b/, /\bbeasts/, /creature_helper/,
      /sacred_or_animate_landscape/,
      /landscape_mobilized/,  # could overlap; landscape as ally
      /landscape_altered/,
      /hero_depends_on_nonhuman_ally_as_guide/,
      /benevolent_aerial_nature_spirits/,
      /magical_creation_of_animal_helpers/,
      /benevolent_animal/, /animal_devotee/,
      /\bcave\b.*\bbird\b/, /\brefuge\b.*\bbird\b/,
      /cave_refuge_with_bird_sign/, /cave_refuge_with_possible_heavenly_protection/
    ]
  },
  {
    id: "divine_intervention_saintly_miracle",
    label: "Saintly Miracle and Holy Power",
    description: "Miracles validating sanctity: signs around saints, posthumous miracles, blessings from holy figures, conversion through divine sign, miracles that mark a chosen one.",
    rules: [
      /\bsaint/, /sanctity/, /sanctified/,
      /miracle_validates/, /miracle.*sanctity/,
      /holy_man/, /holy_woman/, /holy_figure/,
      /invulnerable_saint/, /reversed_weapons.*saint/,
      /posthumous/, /posthumous_fragrance/, /posthumous_miracle/,
      /miraculous_animal_sign_from_stone/,
      /saintly_miracles/, /saintly_power/,
      /blessing_and_anger_as_channels_of_saintly_power/,
      /miraculous_creation_and_healing_by_divine_leave/,
      /miracle_validates_sanctity_and_produces_discipleship/,
      /sign_validating_authority/,
      /transfer_of_cult_through_divine_consent/,
      /cult_honor_for_divine_intervention/,
      /conversion_through_public_sign/,
      /contest_between_divine_sign_and_human_enchantment/,
      /contest_between_prophetic_truth_and_magic/,
      /challenge_contest_proving_divine_mission/,
      /prophetic_sign_rejected/,
      /\bcult\b/, /cult_honor/,
      /divine_incarnation_identification_of_a_hero/,
      /miraculous_or_unusual_birth/  # often saintly context
    ]
  },
  {
    id: "divine_intervention_possession_inspiration",
    label: "Divine Possession and Inspiration",
    description: "The deity enters or moves through a human: divine possession, prophetic ecstasy, inciting warriors, granting courage, disguised divinity prompting action.",
    rules: [
      /possession/,
      /possessed/, /possessing_god/,
      /disguised_deity/, /disguised_god/, /disguised_divinity/,
      /\bincit/, /\bincite/, /incites_a_warrior/,
      /renew_human_courage/, /grants_courage/, /strengthens.*hero/,
      /divine_breath/, /breath_of_god/,
      /spiritual_intoxication/, /divine_inspiration/,
      /divinely_inspired/, /inspired_speech/,
      /possessed_speech/, /\boracle\b/, /oracular/,
      /prophetic_ecstasy/, /ecstatic_inspiration/,
      /divine_inflowing/, /infusion/,
      /ineffective_ordinary_rowing_overcome_by_a_magical_helper/,
      /supernatural_servants_laboring_under_concealed_authority/,
      /divinity_grants_sleep/,
      /divine_helper_appears_as_mysterious_extra_passenger/,
      /authority_restores_separated_companions/  # divine reunion
    ]
  },
  {
    id: "divine_intervention_withheld_restrained",
    label: "Withheld and Restrained Divine Power",
    description: "Divine non-intervention or restraint: gods choosing not to act, wrath held back, divine aid withheld to encourage independence, restraint upon overpowering sacred forces.",
    rules: [
      /withheld/, /\brestrain/,
      /noninterven/, /non.intervention/,
      /refused.*intervene/, /refuse.*intervene/,
      /wrathful_sacred_power_restrained/,
      /repeated_petitions_to_restrain_destructive_animal_allies/,
      /divine_council_chooses_nonintervention/,
      /encouraging_independence/,
      /silent.*deity/, /deity_silent/,
      /\bbound_or_imprisoned_deity/,
      /divine.*non.act/,
      /divine_preservation_of_the_messenger_from_temptation/
    ]
  }
]

MANUAL = {
  # battle_aid
  "divine_intervention" => "divine_intervention_battle_aid",
  "divine_ally_empowers_a_mortal_hero_against_a_god" => "divine_intervention_battle_aid",
  "single_combat_delayed_by_divine_or_supernatural_intervention" => "divine_intervention_battle_aid",
  "swift_messenger_delivers_decisive_aid_at_daybreak" => "divine_intervention_battle_aid",
  "celestial_assistance_to_a_prophet" => "divine_intervention_messengers_prophets",
  "concealed_divine_assistance_or_attention" => "divine_intervention_rescue_protection",
  "divine_assistance_for_journey_by_weather" => "divine_intervention_rescue_protection",
  "divine_boon_empowering_an_oppressive_antagonist" => "divine_intervention_battle_aid",
  "divine_messenger_prompts_battle_during_hero_s_absence" => "divine_intervention_battle_aid",
  "human_vulnerability_at_sea_under_divine_power" => "divine_intervention_rescue_protection",
  "compassionate_marine_helper_appears_to_distressed_hero" => "divine_intervention_animal_nature_helpers",
  "hostile_sending_of_illness_against_a_community" => "divine_intervention_healing_provision",
  "nonlethal_supernatural_defeat_of_an_attacker" => "divine_intervention_battle_aid",
  "ritual_healing_by_striking_and_command" => "divine_intervention_healing_provision",
  "divine_provision_through_rain_and_vegetation" => "divine_intervention_healing_provision",
  "divine_provision_in_the_wilderness" => "divine_intervention_healing_provision",
  "magical_provisioning_in_wilderness_cold" => "divine_intervention_healing_provision",
  "divine_providence_supplies_the_devotee" => "divine_intervention_healing_provision",
  "miraculous_healing_by_touch_and_breath" => "divine_intervention_healing_provision",
  "miraculous_or_unusual_cure_through_indirect_medicine" => "divine_intervention_healing_provision",
  "intercessory_rain_miracle" => "divine_intervention_healing_provision",
  "rainmaking_specialist_restores_water_in_drought" => "divine_intervention_healing_provision",
  "miraculous_rain_in_kin_assembly" => "divine_intervention_healing_provision",
  "pestilence_relieved_by_invited_healing_deity" => "divine_intervention_healing_provision",
  "miraculous_creation_and_healing_by_divine_leave" => "divine_intervention_healing_provision",

  # rescue_protection (additional)
  "afflicted_bride_whose_marriage_is_blocked_by_a_supernatural_warning_voice" => "divine_intervention_rescue_protection",

  # animal_nature_helpers (a few without clear regex match)
  "animal_alarm_saves_a_city_stronghold" => "divine_intervention_animal_nature_helpers",
  "animal_allied_host_performs_superhuman_labor" => "divine_intervention_animal_nature_helpers",
  "animal_ally_fights_the_abductor" => "divine_intervention_animal_nature_helpers",
  "animal_counselor_directs_vengeance" => "divine_intervention_animal_nature_helpers",
  "animal_devotee_recognizes_and_venerates_a_buddha" => "divine_intervention_animal_nature_helpers",
  "animal_guarded_holy_figure_in_mountain_refuge" => "divine_intervention_animal_nature_helpers",
  "animal_guardian_pledges_protection_of_a_beloved_woman" => "divine_intervention_animal_nature_helpers",
  "animal_guide_marks_a_sacred_or_civic_site" => "divine_intervention_animal_nature_helpers",
  "animal_guide_marks_sacred_settlement_site" => "divine_intervention_animal_nature_helpers",
  "animal_guides_indicating_the_lost_person_s_path" => "divine_intervention_animal_nature_helpers",
  "animal_messenger_carries_death_tidings" => "divine_intervention_animal_nature_helpers",
  "animal_or_semi_divine_helper_as_messenger" => "divine_intervention_animal_nature_helpers",
  "animal_traits_explained_by_divine_boons" => "divine_intervention_animal_nature_helpers",
  "animal_war_interrupted_by_divine_intervention" => "divine_intervention_battle_aid",
  "animals_reveal_the_captor_s_trail" => "divine_intervention_animal_nature_helpers",
  "arrival_recognized_by_animals" => "divine_intervention_animal_nature_helpers",
  "bird_informants_on_the_fate_of_kin" => "divine_intervention_animal_nature_helpers",
  "bird_like_aerial_messenger" => "divine_intervention_animal_nature_helpers",
  "bird_messenger_bearing_royal_summons" => "divine_intervention_animal_nature_helpers",

  # saintly_miracle additions
  "miracle_validates_sanctity_and_produces_discipleship" => "divine_intervention_saintly_miracle",
  "transfer_of_cult_through_divine_consent" => "divine_intervention_saintly_miracle",
  "miracle_validates_sanctity" => "divine_intervention_saintly_miracle",

  # withheld
  "wrathful_sacred_power_restrained_for_the_world_s_welfare" => "divine_intervention_withheld_restrained",
  "withheld_divine_aid_encouraging_independence" => "divine_intervention_withheld_restrained",
  "repeated_petitions_to_restrain_destructive_animal_allies" => "divine_intervention_withheld_restrained",
  "bound_or_imprisoned_deity" => "divine_intervention_withheld_restrained",

  # bulk overrides — read line by line from the unbinned dump
  "absent_protectors_invoked_in_crisis" => "divine_intervention_rescue_protection",
  "abundance_giving_cow" => "divine_intervention_animal_nature_helpers",
  "aerial_conveyance_to_witness_battlefield_devastation" => "divine_intervention_battle_aid",
  "cosmic_response_to_the_future_buddha_s_wish" => "divine_intervention_saintly_miracle",
  "cosmic_sustainer_against_collapse" => "divine_intervention_rescue_protection",
  "council_broken_by_divine_alarm_and_mass_mobilization" => "divine_intervention_battle_aid",
  "creator_deity_with_winged_envoys" => "divine_intervention_messengers_prophets",
  "dead_or_departed_agent_mediating_rain" => "divine_intervention_healing_provision",
  "death_answers_a_summons" => "divine_intervention_withheld_restrained",
  "deceptive_adversaries_of_prophets" => "divine_intervention_messengers_prophets",
  "deities_as_patrons_of_temporal_human_needs" => "divine_intervention_healing_provision",
  "deity_induced_love" => "divine_intervention_possession_inspiration",
  "deity_of_good_fortune_and_blessings" => "divine_intervention_healing_provision",
  "delayed_aid_after_burned_dwelling" => "divine_intervention_rescue_protection",
  "demanded_miraculous_proof_of_prophecy" => "divine_intervention_messengers_prophets",
  "descent_of_divine_tranquility_upon_a_threatened_community" => "divine_intervention_rescue_protection",
  "destruction_by_birds_bearing_stones" => "divine_intervention_battle_aid",
  "divine_advice_reveals_the_necessary_weapon" => "divine_intervention_battle_aid",
  "divine_aid_concealed_in_household_action" => "divine_intervention_rescue_protection",
  "divine_aid_guiding_the_fatal_weapon" => "divine_intervention_battle_aid",
  "divine_aid_in_a_heroic_trial" => "divine_intervention_battle_aid",
  "divine_aid_sought_after_prior_vision" => "divine_intervention_rescue_protection",
  "divine_aid_sustaining_an_army" => "divine_intervention_battle_aid",
  "divine_aid_through_presence_and_heavenly_auxiliaries" => "divine_intervention_battle_aid",
  "divine_aid_to_an_unarmed_hero" => "divine_intervention_battle_aid",
  "divine_aid_to_captive_heroine" => "divine_intervention_rescue_protection",
  "divine_alert_to_righteous_distress" => "divine_intervention_rescue_protection",
  "divine_ally_assists_revenge_against_household_usurpers" => "divine_intervention_battle_aid",
  "divine_and_elemental_aid_requested_for_sea_voyage" => "divine_intervention_rescue_protection",
  "divine_animal_vehicle" => "divine_intervention_animal_nature_helpers",
  "divine_appeal_for_preservation_of_the_cosmos" => "divine_intervention_rescue_protection",
  "divine_assistance_in_battle" => "divine_intervention_battle_aid",
  "divine_assistance_leading_to_victory" => "divine_intervention_battle_aid",
  "divine_beautification_of_the_hero" => "divine_intervention_possession_inspiration",
  "divine_command_over_battle_waters" => "divine_intervention_battle_aid",
  "divine_conflict_interrupted_by_another_deity" => "divine_intervention_withheld_restrained",
  "divine_conflict_over_a_people_s_sea_journey" => "divine_intervention_rescue_protection",
  "divine_control_of_battle_through_weather_and_light" => "divine_intervention_battle_aid",
  "divine_council_authorizes_intervention_in_human_war" => "divine_intervention_battle_aid",
  "divine_counter_plot_against_hostile_plotters" => "divine_intervention_rescue_protection",
  "divine_counterplot_against_hostile_plotters" => "divine_intervention_rescue_protection",
  "divine_deflection_of_weapons_protecting_a_hero" => "divine_intervention_battle_aid",
  "divine_deflection_prevents_hero_s_death" => "divine_intervention_battle_aid",
  "divine_disarming_before_mortal_death" => "divine_intervention_battle_aid",
  "divine_easing_of_a_burdensome_weight" => "divine_intervention_rescue_protection",
  "divine_favor_brings_wealth_to_mortals" => "divine_intervention_healing_provision",
  "divine_granting_of_a_transformative_petition" => "divine_intervention_possession_inspiration",
  "divine_hearing_of_a_vulnerable_petition" => "divine_intervention_rescue_protection",
  "divine_helper_adorns_the_chosen_figure" => "divine_intervention_possession_inspiration",
  "divine_helper_as_charioteer_in_heroic_battle" => "divine_intervention_battle_aid",
  "divine_helper_reassures_and_protects_the_hero" => "divine_intervention_rescue_protection",
  "divine_hero_carried_by_animal_or_allied_bearer" => "divine_intervention_animal_nature_helpers",
  "divine_incarnation_completes_the_gods_task" => "divine_intervention_saintly_miracle",
  "divine_influence_over_human_displacement_and_rescue" => "divine_intervention_rescue_protection",
  "divine_injury_followed_by_invulnerability_boons" => "divine_intervention_battle_aid",
  "divine_intervention_determines_a_contest_outcome" => "divine_intervention_battle_aid",
  "divine_intervention_during_sea_voyage" => "divine_intervention_rescue_protection",
  "divine_intervention_in_contest_victory" => "divine_intervention_battle_aid",
  "divine_intervention_in_heroic_conflict" => "divine_intervention_battle_aid",
  "divine_intervention_in_single_combat" => "divine_intervention_battle_aid",
  "divine_intervention_opposed_by_another_god" => "divine_intervention_withheld_restrained",
  "divine_intervention_releases_war" => "divine_intervention_battle_aid",
  "divine_intervention_restrains_imminent_violence" => "divine_intervention_withheld_restrained",
  "divine_intervention_to_protect_or_halt_warriors" => "divine_intervention_withheld_restrained",
  "divine_intervention_triggered_by_a_crisis_sign" => "divine_intervention_rescue_protection",
  "divine_intervention_turns_the_battle" => "divine_intervention_battle_aid",
  "divine_machinery_in_epic_action" => "divine_intervention_battle_aid",
  "divine_madness_inciting_social_disorder" => "divine_intervention_possession_inspiration",
  "divine_obstruction_through_storm" => "divine_intervention_battle_aid",
  "divine_opening_or_constriction_of_the_inner_self" => "divine_intervention_possession_inspiration",
  "divine_patron_honored_across_multiple_realms" => "divine_intervention_saintly_miracle",
  "divine_patronage_of_a_hero_and_his_household" => "divine_intervention_rescue_protection",
  "divine_patronage_of_travel_by_sea_and_snow" => "divine_intervention_rescue_protection",
  "divine_patrons_pursued_by_hostile_ruler" => "divine_intervention_messengers_prophets",
  "divine_petition_to_a_high_god_on_behalf_of_a_hero" => "divine_intervention_rescue_protection",
  "divine_prayer_followed_by_hostile_natural_force" => "divine_intervention_battle_aid",
  "divine_presence_distributed_through_an_animal_species" => "divine_intervention_animal_nature_helpers",
  "divine_presence_reassures_endangered_companions" => "divine_intervention_rescue_protection",
  "divine_preservation_of_the_faithful_witness" => "divine_intervention_rescue_protection",
  "divine_prompting_of_secret_counsel" => "divine_intervention_possession_inspiration",
  "divine_protector_of_sea_voyages" => "divine_intervention_rescue_protection",
  "divine_provision_by_rain_and_supplied_food" => "divine_intervention_healing_provision",
  "divine_provision_for_all_living_creatures" => "divine_intervention_healing_provision",
  "divine_provision_in_sacred_seclusion" => "divine_intervention_healing_provision",
  "divine_provision_through_animals_and_plants" => "divine_intervention_healing_provision",
  "divine_provision_through_created_nature" => "divine_intervention_healing_provision",
  "divine_provision_through_rain_and_revived_land" => "divine_intervention_healing_provision",
  "divine_reassurance_after_apparent_abandonment" => "divine_intervention_rescue_protection",
  "divine_reassurance_after_distress" => "divine_intervention_rescue_protection",
  "divine_removal_of_human_sense" => "divine_intervention_possession_inspiration",
  "divine_restoration_of_a_wounded_warrior" => "divine_intervention_battle_aid",
  "divine_restraint_from_mortal_battle" => "divine_intervention_withheld_restrained",
  "divine_restraint_of_destructive_winds" => "divine_intervention_withheld_restrained",
  "divine_revelation_and_warning_through_descending_angels" => "divine_intervention_messengers_prophets",
  "divine_sign_confirming_heroic_action" => "divine_intervention_battle_aid",
  "divine_strengthening_before_combat" => "divine_intervention_battle_aid",
  "divine_suppression_of_war" => "divine_intervention_withheld_restrained",
  "divine_sustenance_during_ordeal" => "divine_intervention_healing_provision",
  "divine_transformation_of_harm_into_benefit" => "divine_intervention_rescue_protection",
  "divine_voice_amplification_through_a_heroic_voice" => "divine_intervention_battle_aid",
  "divine_weather_aid_in_a_heroic_task" => "divine_intervention_battle_aid",
  "divine_weather_intervention_in_a_heroic_pursuit" => "divine_intervention_battle_aid",
  "divinely_aided_passage_of_a_unique_vessel_through_deadly_rocks" => "divine_intervention_rescue_protection",
  "divinely_arranged_encounter_with_helper" => "divine_intervention_rescue_protection",
  "divinely_authorized_creation_of_a_living_bird_from_clay" => "divine_intervention_saintly_miracle",
  "divinely_authorized_miracle_worker" => "divine_intervention_saintly_miracle",
  "divinely_commanded_supernatural_agents" => "divine_intervention_messengers_prophets",
  "divinely_imposed_sleep_as_containment" => "divine_intervention_withheld_restrained",
  "divinely_limited_wound" => "divine_intervention_battle_aid",
  "divinely_sent_storm_diverts_the_traveler" => "divine_intervention_rescue_protection",
  "divinely_timed_sunset_suspends_battle" => "divine_intervention_withheld_restrained",
  "elder_warrior_renewed_by_divine_aid" => "divine_intervention_battle_aid",
  "escalating_invocation_of_stronger_helpers" => "divine_intervention_rescue_protection",
  "escape_through_prayer_and_dawn" => "divine_intervention_rescue_protection",
  "failed_binding_of_a_divine_being" => "divine_intervention_withheld_restrained",
  "faithful_minority_advises_trust_against_overwhelming_inhabitants" => "divine_intervention_battle_aid",
  "faithful_party_under_divine_patronage" => "divine_intervention_rescue_protection",
  "fall_of_a_heavenly_being_through_refusal_of_commanded_homage" => "divine_intervention_messengers_prophets",
  "fire_quenched_by_sudden_tempest" => "divine_intervention_rescue_protection",
  "fire_transformed_into_roses_for_abraham" => "divine_intervention_saintly_miracle",
  "first_believer_affirms_prophet_s_mission" => "divine_intervention_messengers_prophets",
  "god_disguised_as_a_human_rouses_heroes" => "divine_intervention_possession_inspiration",
  "god_incites_mortal_hero_to_dangerous_combat" => "divine_intervention_battle_aid",
  "goddess_aided_survival_at_the_edge_of_death" => "divine_intervention_rescue_protection",
  "guidance_after_transgression" => "divine_intervention_rescue_protection",
  "guiding_animals_lead_a_hero_to_a_sacred_branch" => "divine_intervention_animal_nature_helpers",
  "harmful_missiles_transformed_into_flowers" => "divine_intervention_battle_aid",
  "heaven_defended_city_resists_heroic_assault" => "divine_intervention_rescue_protection",
  "heavenly_water_overcomes_destructive_fire_after_supplication" => "divine_intervention_rescue_protection",
  "helper_requested_for_impaired_or_fearful_prophet" => "divine_intervention_messengers_prophets",
  "helpful_sea_maidens_guiding_favored_ships" => "divine_intervention_rescue_protection",
  "hero_wounded_through_supernatural_obstruction" => "divine_intervention_battle_aid",
  "hidden_animal_burial_ground_reveals_abundance" => "divine_intervention_animal_nature_helpers",
  "hidden_treasure_revealed_by_animal_guide" => "divine_intervention_animal_nature_helpers",
  "holy_scholar_s_death_accompanied_by_mass_conversion" => "divine_intervention_saintly_miracle",
  "honoring_a_nonhuman_defender_as_a_noble_friend" => "divine_intervention_animal_nature_helpers",
  "hostile_weather_spirit_immobilizes_a_voyager" => "divine_intervention_withheld_restrained",
  "human_being_endowed_with_divine_or_supernatural_power" => "divine_intervention_possession_inspiration",
  "human_control_of_natural_phenomena" => "divine_intervention_possession_inspiration",
  "humans_as_game_pieces_moved_by_a_higher_power" => "divine_intervention_withheld_restrained",
  "hunter_confronted_and_redirected_by_animals" => "divine_intervention_animal_nature_helpers",
  "immanent_spirit_becoming_external_deity" => "divine_intervention_saintly_miracle",
  "impossible_task_nearly_completed_by_supernatural_helper" => "divine_intervention_rescue_protection",
  "inexhaustible_material_supply" => "divine_intervention_healing_provision",
  "instrument_of_divine_action" => "divine_intervention_possession_inspiration",
  "intercession_for_the_righteous" => "divine_intervention_rescue_protection",
  "intercession_that_turns_away_heroic_wrath" => "divine_intervention_withheld_restrained",
  "intermediary_spirits_carry_prayers_and_divine_gifts" => "divine_intervention_messengers_prophets",
  "invisibility_or_illusion_protecting_travelers" => "divine_intervention_rescue_protection",
  "kin_betrayal_followed_by_supernatural_rescue" => "divine_intervention_rescue_protection",
  "lasting_sacred_exception_to_natural_disaster" => "divine_intervention_rescue_protection",
  "life_giving_rain_after_despair" => "divine_intervention_healing_provision",
  "magical_army_summoned_by_instrument" => "divine_intervention_battle_aid",
  "magical_helper_arising_from_vapor" => "divine_intervention_rescue_protection",
  "magical_helper_obeys_a_human_master_s_commands" => "divine_intervention_possession_inspiration",
  "magical_or_herbal_restoration_of_warriors_between_battle_days" => "divine_intervention_battle_aid",
  "magical_wind_disarms_warriors" => "divine_intervention_battle_aid",
  "malicious_suggestion_from_satan_countered_by_refuge_in_god" => "divine_intervention_rescue_protection",
  "maritime_danger_and_supplication_to_the_divine" => "divine_intervention_rescue_protection",
  "mediated_salvation_through_intercession" => "divine_intervention_rescue_protection",
  "mediating_subordinate_deities" => "divine_intervention_messengers_prophets",
  "miracle_as_proof_of_divine_human_status" => "divine_intervention_saintly_miracle",
  "miracle_as_proof_of_divine_status" => "divine_intervention_saintly_miracle",
  "miracle_compels_reluctant_kin_to_bow" => "divine_intervention_saintly_miracle",
  "miracle_contest_against_magicians" => "divine_intervention_saintly_miracle",
  "miracle_working_holy_person" => "divine_intervention_saintly_miracle",
  "miraculous_abundance_by_transforming_touch" => "divine_intervention_saintly_miracle",
  "miraculous_abundance_proves_divine_aid" => "divine_intervention_healing_provision",
  "miraculous_animal_emerging_from_stone" => "divine_intervention_saintly_miracle",
  "miraculous_animation_of_a_clay_bird" => "divine_intervention_saintly_miracle",
  "miraculous_army_generated_from_a_sacred_cow" => "divine_intervention_battle_aid",
  "miraculous_contest_between_prophet_and_magicians" => "divine_intervention_saintly_miracle",
  "miraculous_creation_of_armies_by_a_cow" => "divine_intervention_battle_aid",
  "miraculous_helper_in_dangerous_passage" => "divine_intervention_rescue_protection",
  "miraculous_mastery_over_water_fire_and_food" => "divine_intervention_saintly_miracle",
  "miraculous_multiplication_of_a_monk" => "divine_intervention_saintly_miracle",
  "miraculous_preservation_from_death" => "divine_intervention_rescue_protection",
  "miraculous_preservation_from_fire" => "divine_intervention_rescue_protection",
  "miraculous_provision_for_abraham_s_household" => "divine_intervention_healing_provision",
  "miraculous_sign_contest_against_magicians" => "divine_intervention_saintly_miracle",
  "miraculous_transformation_of_natural_objects_by_bodisat_command" => "divine_intervention_saintly_miracle",
  "misleading_demonic_companions" => "divine_intervention_withheld_restrained",
  "misled_wanderer_recalled_to_true_guidance" => "divine_intervention_rescue_protection",
  "mother_and_child_at_rock_and_sea_with_dolphin_rescue" => "divine_intervention_rescue_protection",
  "mysterious_helpers_serving_under_restrictive_conditions" => "divine_intervention_possession_inspiration",
  "mysterious_one_eyed_intervention_at_turning_points" => "divine_intervention_battle_aid",
  "nature_personified_as_divine_powers" => "divine_intervention_animal_nature_helpers",
  "nature_welcomes_and_serves_the_righteous_hero" => "divine_intervention_animal_nature_helpers",
  "night_vigil_over_the_sleeping_hero" => "divine_intervention_rescue_protection",
  "nonhuman_nature_and_spirits_subordinated_to_a_chosen_servant" => "divine_intervention_animal_nature_helpers",
  "obedience_of_inanimate_objects_to_a_saint" => "divine_intervention_saintly_miracle",
  "otherworld_hidden_allies_come_to_aid_in_battle" => "divine_intervention_battle_aid",
  "outnumbered_hero_turns_to_dangerous_supernatural_aid" => "divine_intervention_battle_aid",
  "patron_fortune_of_a_city" => "divine_intervention_rescue_protection",
  "permanent_indwelling_of_a_divine_spirit_in_a_human_body" => "divine_intervention_possession_inspiration",
  "persecuted_prophet_opposed_by_ruler" => "divine_intervention_messengers_prophets",
  "personification_of_winds_as_winged_divinities" => "divine_intervention_animal_nature_helpers",
  "personified_wind_as_demon_or_foe" => "divine_intervention_withheld_restrained",
  "plot_against_a_prophet_averted_by_warning" => "divine_intervention_messengers_prophets",
  "portable_household_divinities_in_migration" => "divine_intervention_rescue_protection",
  "praise_of_solar_deity_before_renewed_combat" => "divine_intervention_battle_aid",
  "prayer_for_weather_to_overcome_fire" => "divine_intervention_rescue_protection",
  "prayer_overcomes_a_troll_s_spell" => "divine_intervention_rescue_protection",
  "purification_and_solar_devotion_before_confrontation" => "divine_intervention_battle_aid",
  "pursuit_halted_by_divine_intervention_at_a_named_island" => "divine_intervention_rescue_protection",
  "rain_renewing_parched_land_as_a_sign" => "divine_intervention_healing_provision",
  "rally_of_routed_army_after_divine_message" => "divine_intervention_battle_aid",
  "reassurance_by_heavenly_voices" => "divine_intervention_rescue_protection",
  "recognition_of_divine_power_by_defeated_ritual_specialists" => "divine_intervention_saintly_miracle",
  "recurrent_divine_intervention_at_catastrophe" => "divine_intervention_rescue_protection",
  "refusal_of_commanded_homage" => "divine_intervention_messengers_prophets",
  "refusal_of_divine_command_by_eblis" => "divine_intervention_messengers_prophets",
  "refusal_to_honor_the_clay_created_human" => "divine_intervention_messengers_prophets",
  "refusal_to_honor_the_human_ancestor" => "divine_intervention_messengers_prophets",
  "reinforcement_causes_magical_withdrawal" => "divine_intervention_battle_aid",
  "rejuvenating_animal_guide_or_bearer" => "divine_intervention_animal_nature_helpers",
  "repentance_with_apostolic_intercession" => "divine_intervention_messengers_prophets",
  "reported_supernatural_or_heroic_ally_in_battle" => "divine_intervention_battle_aid",
  "revealed_conspiracy_and_miraculous_escape" => "divine_intervention_rescue_protection",
  "righteous_believer_within_tyrannical_household_seeks_divine_refuge" => "divine_intervention_rescue_protection",
  "righteous_figure_saved_from_lethal_fire" => "divine_intervention_rescue_protection",
  "ritual_and_magical_remedies_proposed_for_hidden_suffering" => "divine_intervention_healing_provision",
  "ritual_control_of_wind" => "divine_intervention_possession_inspiration",
  "ritual_petition_to_a_goddess_for_military_relief" => "divine_intervention_battle_aid",
  "rustic_deity_as_protector_and_fertility_power" => "divine_intervention_animal_nature_helpers",
  "sacred_animal_as_vulnerable_divine_or_saintly_vessel" => "divine_intervention_animal_nature_helpers",
  "satanic_instigation_of_failure_and_fear" => "divine_intervention_withheld_restrained",
  "saving_a_troop_or_group" => "divine_intervention_rescue_protection",
  "sea_deity_controls_storm_calm_and_safe_passage" => "divine_intervention_rescue_protection",
  "sea_deity_hears_lament_and_comes_to_comfort" => "divine_intervention_rescue_protection",
  "semi_divine_animal_helpers_or_peoples" => "divine_intervention_animal_nature_helpers",
  "sign_of_temporary_silence" => "divine_intervention_withheld_restrained",
  "sleep_of_the_high_god_enables_battlefield_intervention" => "divine_intervention_battle_aid",
  "small_animals_conceal_a_sacred_fugitive" => "divine_intervention_animal_nature_helpers",
  "socially_humble_believers_chosen_or_protected" => "divine_intervention_rescue_protection",
  "spirit_demon_or_soul_manifested_in_a_dust_column" => "divine_intervention_animal_nature_helpers",
  "storm_as_divine_manifestation_and_instrument" => "divine_intervention_battle_aid",
  "storm_beings_personified_as_violent_carriers_off" => "divine_intervention_animal_nature_helpers",
  "supernatural_battle_assistance_through_conjured_army_and_mist" => "divine_intervention_battle_aid",
  "supernatural_beings_amplify_a_hero_s_battle_terror" => "divine_intervention_battle_aid",
  "supernatural_cry_as_summons" => "divine_intervention_messengers_prophets",
  "supernatural_guide_in_dark_wood" => "divine_intervention_rescue_protection",
  "supernatural_helper_sustains_solitary_hero_against_overwhelming_host" => "divine_intervention_battle_aid",
  "supernatural_helper_with_limited_powers" => "divine_intervention_rescue_protection",
  "supernatural_keeper_grants_controlled_winds_for_a_voyage" => "divine_intervention_rescue_protection",
  "supernatural_or_divinely_sent_auxiliary_creatures" => "divine_intervention_animal_nature_helpers",
  "supernatural_unseen_helpers_in_battle" => "divine_intervention_battle_aid",
  "supernatural_woman_brings_an_extraordinary_battle_object_to_a_hero" => "divine_intervention_battle_aid",
  "suppliant_refuge_with_a_rival_or_alternative_holy_power" => "divine_intervention_rescue_protection",
  "talking_animal_warning_the_threatened_hero" => "divine_intervention_animal_nature_helpers",
  "tribal_patron_celestial_body" => "divine_intervention_rescue_protection",
  "trust_in_divine_aid_in_battle" => "divine_intervention_battle_aid",
  "trust_in_divine_sovereign_support" => "divine_intervention_rescue_protection",
  "unexpected_food_bearer_after_deprivation" => "divine_intervention_healing_provision",
  "victorious_bird_army_companion" => "divine_intervention_animal_nature_helpers",
  "water_as_divine_provision_and_trial" => "divine_intervention_healing_provision",
  "water_pouring_action_that_unleashes_destructive_weather" => "divine_intervention_battle_aid",
  "water_rises_to_hinder_the_enemy" => "divine_intervention_battle_aid",
  "weather_as_divine_sign_and_power" => "divine_intervention_battle_aid",
  "weather_dependent_fortune_under_divine_will" => "divine_intervention_withheld_restrained",
  "weather_explained_as_actions_of_a_goddess" => "divine_intervention_animal_nature_helpers",
  "winged_maiden_as_swift_supernatural_envoy" => "divine_intervention_messengers_prophets",
  "wonders_and_eloquence_winning_the_multitude" => "divine_intervention_saintly_miracle",
  "woodland_powers_govern_hunting_success_and_guidance" => "divine_intervention_animal_nature_helpers"
}.freeze

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def bin_motif_by_regex(motif_id)
  SUB_FAMILIES.each do |sub|
    sub[:rules].each do |rx|
      return sub[:id] if motif_id =~ rx
    end
  end
  nil
end

def main
  freq = load_yaml(FREQUENCY_PATH)
  family = freq.fetch("canonical_motifs").find { |g| g["canonical_motif_id"] == FAMILY_ID }
  motifs = family.fetch("mapped_motifs").map { |m| m["motif_id"] }

  bins = Hash.new { |h, k| h[k] = [] }
  unbinned = []

  motifs.each do |motif_id|
    bin = MANUAL[motif_id] || bin_motif_by_regex(motif_id)
    if bin
      bins[bin] << motif_id
    else
      unbinned << motif_id
    end
  end

  output = {
    "generated_on" => Date.today.iso8601,
    "family" => FAMILY_ID,
    "method" => "regex first pass + manual override for the rest",
    "total_motifs" => motifs.length,
    "binned" => motifs.length - unbinned.length,
    "unbinned" => unbinned.length,
    "sub_families" => SUB_FAMILIES.map do |sub|
      {
        "id" => sub[:id],
        "label" => sub[:label],
        "description" => sub[:description],
        "child_count" => bins[sub[:id]].length,
        "children" => bins[sub[:id]].sort
      }
    end,
    "unbinned_children" => unbinned.sort
  }

  FileUtils.mkdir_p(File.dirname(OUTPUT_PATH))
  File.write(OUTPUT_PATH, "---\n" + output.to_yaml(line_width: -1).sub(/\A---\n/, ""))

  puts "#{FAMILY_ID} sub-family binning"
  puts "================================"
  puts "Total motifs:  #{motifs.length}"
  puts "Binned:        #{motifs.length - unbinned.length}"
  puts "Unbinned:      #{unbinned.length}"
  puts ""
  puts "Counts per sub-family:"
  SUB_FAMILIES.each do |sub|
    puts "  %-50s %4d" % [sub[:id], bins[sub[:id]].length]
  end
  puts ""
  if unbinned.any?
    puts "Unbinned motifs (#{unbinned.length}):"
    unbinned.first(60).each { |m| puts "  #{m}" }
    puts "  ... +#{unbinned.length - 60} more" if unbinned.length > 60
  end

  puts ""
  puts "Wrote #{OUTPUT_PATH.sub(ROOT + '/', '')}"
end

main if $PROGRAM_NAME == __FILE__
