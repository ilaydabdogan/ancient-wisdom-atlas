#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bin the 449 sacred_law child motifs into 10 sub-families.

require "yaml"
require "date"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
FREQUENCY_PATH = File.join(ROOT, "data/indexes/canonical-motif-frequency.yml")
OUTPUT_PATH = File.join(ROOT, "data/normalization/sub-family-bins-sacred-law.yml")
FAMILY_ID = "sacred_law"

SUB_FAMILY_DEFS = [
  ["sacred_law_taboo_and_restriction", "Taboo and Ritual Restriction",
    "Prohibitions on what may be touched, eaten, said, or approached: dietary taboos, contact taboos, royal taboos, restrictions around sacred persons and dangerous substances."],
  ["sacred_law_purification_and_pollution", "Purification and Pollution",
    "Ritual cleansing after bloodshed, contact with death, sexual or menstrual states; the structure of pollution and the means of removing it."],
  ["sacred_law_sanctuary_and_asylum", "Sanctuary and Asylum",
    "Sacred precincts, altar-asylum, the protection extended to fugitives and suppliants, the inviolability of sacred space."],
  ["sacred_law_apotropaic_protection", "Apotropaic Protection and Sympathetic Magic",
    "Charms, plants, mirrors, smoke, ritual gestures, and other devices that ward off malign forces; sympathetic and imitative magic."],
  ["sacred_law_family_and_kinship", "Family and Kinship Order",
    "Filial duty, marriage law, inheritance, kinship boundaries on union, paternal authority, household relations."],
  ["sacred_law_revealed_command", "Revealed Command and Divine Authorization",
    "Divinely authorized law, prophetic abrogation of earlier custom, scripture as source, the structure of permitted-and-forbidden as revealed."],
  ["sacred_law_hospitality_and_strangers", "Hospitality and Treatment of Strangers",
    "Guest-right, the inviolability of envoys and heralds, suppliant protection, the consequences of broken hospitality."],
  ["sacred_law_justice_and_mercy", "Justice, Mercy, and Judicial Procedure",
    "Proportional retribution, restraint of revenge, four-witness proof, fair distribution of spoils, mercy and forgiveness, care for the vulnerable, warrior-code restraint."],
  ["sacred_law_civic_order", "Civic Order and the Body Politic",
    "The ideal commonwealth, communal property, division of labor, the body politic as analogy, ordered correspondence of state and soul."],
  ["sacred_law_idolatry_and_false_worship", "Idolatry and False Worship",
    "Prohibitions of idolatry, condemnation of false gods, refusal to deify creatures or partners, rejection of unauthorized intermediaries."]
]

CHILDREN = {
  "sacred_law_taboo_and_restriction" => %w[
    abstention_from_animal_slaughter_because_animals_may_contain_human_souls
    animal_avoidance_and_sacred_animal_protection
    animal_reverence_through_tabooed_killing_and_eating
    animal_taboo_based_on_mythic_death
    archaic_or_non_iron_tool_retained_for_ritual_use
    avoid_corrupting_contact
    avoidance_naming_of_feared_underworld_deity
    avoidance_of_ground_sunlight_and_open_air_for_a_restricted_person
    avoidance_of_raw_flesh_or_blood_to_prevent_spirit_contact
    avoidance_of_sharp_instruments_near_the_dead_or_the_soul
    blood_as_life
    blood_as_prohibited_food_and_transgressive_preparation
    blood_contains_the_animal_s_life_or_soul
    blood_must_not_fall_on_the_ground
    chiefly_blood_creates_taboo_or_sacred_property
    consecrated_food_by_divine_name
    contact_taboo_through_touched_objects
    danger_of_a_sacred_or_spirit_bearing_substance_over_a_tabooed_head
    dangerous_contagion_of_sacred_objects
    dangerous_menstrual_blood_touch_glance_or_footprint
    dangerous_sacred_contact_through_personal_objects
    dangerous_track_avoidance
    dangerous_transitional_state_marked_by_untouchability_and_separate_objects
    delayed_cutting_of_girls_nails_with_consequence_explanation
    dietary_holiness_with_necessity_exception
    dietary_taboo_with_emergency_exception
    divination_by_lots_prohibited
    divine_person_forbidden_to_touch_the_earth
    divine_sleep_requiring_ritual_silence
    euphemistic_naming_to_avert_divine_wrath
    exclusive_vessel_taboo_for_sacred_or_ritual_persons
    fatal_breach_of_taboo
    final_prohibitions_tied_to_death_site_waters
    food_made_licit_by_divine_naming
    food_taboo_against_swine_s_flesh
    food_taboo_and_purity_boundary
    food_taboo_protecting_an_animal_heart_from_a_dog
    forbidden_fishing_in_royal_water
    forbidden_intoxicants_and_divinatory_objects_as_satanic_instruments
    gender_separation_in_worship
    group_taboo_protecting_life_linked_animal_species
    iron_taboo_in_sacred_persons_rites_and_structures
    killed_animal_soul_or_spirit_monitors_human_treatment
    malicious_relatives_provoke_breach_of_taboo
    marked_animal_released_from_ordinary_human_use
    marked_boundary_respected_by_animals
    menstrual_seclusion_and_avoidance_taboo
    menstruous_woman_as_agricultural_protector
    milk_guarded_against_loss_to_mana_strangers_and_wild_places
    mirror_avoidance_during_sickness_or_dying
    mutilation_or_alteration_of_natural_form_brings_suffering
    myth_explaining_a_ritual_or_dietary_custom
    origin_and_consecration_of_a_sacred_animal
    patriarchal_abstinence_and_food_prohibition_aetiology
    plant_juice_as_blood_and_soul_of_the_plant
    privacy_or_concealment_to_protect_the_soul_during_meals
    prohibition_of_intoxicants_and_gaming
    protective_prohibition_arising_from_enchanted_kinship_with_animals
    refusal_of_dangerous_or_improper_food
    religious_prohibition_of_gaming
    religious_prohibition_of_intoxicants
    religious_rejection_of_games_of_chance
    restricted_remarriage_of_wives_of_sacred_or_ruling_figure
    ritual_abstention_from_specific_foods
    ritual_avoidance_of_fire_during_fasting_probation_or_purification
    ritual_avoidance_of_killing_a_mythologically_significant_animal
    ritual_exclusion_due_to_mythic_injury
    ritual_relocation_of_a_tree_spirit_before_or_after_felling
    ritual_restriction_of_priestly_office
    ritual_taboo_around_liminal_persons
    royal_and_priestly_taboos_around_the_soul
    royal_taboos_as_safeguards_for_a_ruler_s_life
    sacred_boundary_between_lawful_and_forbidden_food
    sacred_field_under_taboo
    sacred_food_taboo_whose_violation_brings_disease_or_death
    sacred_or_polluted_persons_as_dangerous_and_in_danger
    sacred_person_taboo_and_dangerous_holiness
    sacred_status_as_protective_avoidance
    sexual_taboo_linked_to_household_fortune
    shunned_contaminating_touch
    skill_game_conditionally_distinguished_from_gambling
    slain_animal_retains_agency_or_communicative_danger
    soul_vulnerable_during_eating_and_drinking
    special_disposal_of_bodily_remnants
    special_doorway_avoidance_for_game_or_fish
    taboo_against_touching_guarded_sacred_trees
    taboo_as_insulation_of_spiritual_force
    taboo_on_eating_a_vital_animal_part
    taboo_restrictions_around_royal_or_sacred_presence
    tabooed_persons_or_things_isolated_from_earth_and_heaven
    tabooed_sacred_animal_causing_illness_or_death
    totemic_animal_or_insect_linked_to_social_divisions
    totemic_animal_taboo_connected_with_descent_or_obligation
    transgression_and_status_specific_killing_taboo
  ],
  "sacred_law_purification_and_pollution" => %w[
    blood_pollution_makes_a_warrior_unfit_for_prayer
    blood_pollution_of_a_sacred_hermitage
    clinging_spirit_contagion_after_contact_with_death_or_persons
    contagious_ritual_uncleanness_attached_to_persons_objects_houses_and_places
    cross_traditional_lustration_by_sand_in_necessity
    death_pollution_transmitted_through_spouse
    delayed_purification_until_funeral_duty_is_complete
    destruction_or_purification_of_objects_after_dangerous_seclusion
    divine_purification_after_a_wrongful_killing
    expanded_purity_boundary_around_a_forbidden_substance
    hero_abandoned_because_of_polluted_or_unbearable_wound
    land_named_from_divine_pollution_and_cleansing
    neutralizing_strange_sacred_ground_before_entry
    pollution_cleansed_by_sacred_herbs_and_roots
    purification_after_accidental_homicide
    purification_after_bloodshed
    purification_after_violent_household_restoration
    purification_before_sacred_speech_or_prayer
    purification_by_beating_inanimate_objects
    purification_through_substitute_earth_when_water_is_absent
    purity_and_divine_favor
    purity_separation_and_cleansing
    quarantine_or_destruction_of_arrivals_and_foreign_goods
    removal_of_harmful_substance_from_community_before_rain
    ritual_beating_to_avert_harm_or_purify
    ritual_cleansing_after_bloodshed
    ritual_direction_and_purification_before_prayer
    ritual_licence_before_or_after_purification
    ritual_pollution_affecting_hunting_and_fishing_success
    ritual_pollution_from_contact_with_death
    ritual_purification_after_contact_with_the_sacred
    ritual_purification_before_fertility_oriented_rite
    ritual_purification_before_prayer
    ritual_purification_before_sacred_duty
    ritual_purification_with_water_or_earth_substitute
    ritual_purity_before_prayer
    ritualized_prayer_requiring_purity_and_auspicious_speech
    sacred_contagion_as_dangerous_force
    sacred_text_requiring_ritual_purity
    substitute_medium_for_sacred_washing
    tabooed_kin_threatened_by_the_slain_person_s_ghost
    zealous_purification_of_forbidden_social_practices
  ],
  "sacred_law_sanctuary_and_asylum" => %w[
    animal_refuses_to_violate_sacred_space
    blood_revenge_contained_by_asylum_and_waiting_period
    false_sanctuary_versus_pious_foundation
    forbidden_sacred_precinct_transgression
    fugitive_suppliant_granted_passage
    protected_asylum_for_one_seeking_divine_word
    protected_sacred_place_with_conditional_violence
    protecting_sacred_natural_space_from_royal_violence
    protection_of_the_suppliant
    restraint_of_the_armed_hero_in_a_sacred_refuge
    ritual_boundary_around_pilgrimage
    sacred_asylum_at_altar
    sacred_boundary_and_limited_retaliation
    sacred_boundary_and_transgression
    sacred_island_protected_by_taboo_against_violence
    sacred_persons_protected_from_battle_violence
    sacred_places_preserved_through_divinely_sanctioned_opposition_to_violence
    sacred_precinct_access_and_rightful_guardianship
    sacred_precinct_and_pilgrimage_restriction
    sacred_precinct_exclusion_by_purity_status
    sacred_refuge_violated_at_the_altar
    sacred_sanctuary_protected_from_hostility
    sacred_secure_asylum
    sanctuary_access_restricted_to_approved_worshippers
    sanctuary_at_altar_in_danger
    sanctuary_boundary_with_nonviolence_and_nature_taboos
    weaponless_sanctuary_of_a_peace_and_fertility_deity
  ],
  "sacred_law_apotropaic_protection" => %w[
    animal_remains_as_medium_for_harmful_magic
    apotropaic_diversion_of_predator_hunger
    apotropaic_mirror_repels_spirits
    apotropaic_plant_against_evil_spirits
    apotropaic_refuge_prayer_against_harmful_forces
    apotropaic_removal_of_death_and_disease_from_village_or_house
    apotropaic_smoke_averts_the_evil_eye
    blessed_ritual_greeting_at_domestic_threshold
    counter_image_used_as_antidote_or_guarantee
    covered_mouth_or_face_blocks_spiritual_danger
    demon_as_source_of_disease_and_misfortune
    elemental_protective_barriers_after_battle
    fire_as_protection_from_disease_demons
    fire_used_against_represented_demons
    harmful_magic_by_knotted_cord
    illness_transferred_through_bodily_tokens
    imitative_sympathetic_magic
    improvised_thorn_enclosure_protects_the_survivor
    leftover_food_as_magical_link_to_the_eater
    mistletoe_as_healing_and_hunting_luck_plant
    non_return_condition_for_removed_disease
    ordeal_like_one_foot_posture_against_evil_spirits
    pain_or_pungency_used_to_expel_harmful_influence
    plant_amulet_protects_against_harmful_beings_and_misfortune
    protected_threshold_and_household_privacy
    protective_animal_quality_charm
    protective_charm_taken_from_ritually_killed_animal
    protective_holy_boundary_around_a_flock
    protective_invocation_before_danger
    protective_invocation_of_cosmic_and_natural_powers
    protective_magical_or_medicinal_herb
    protective_plant_charm_against_supernatural_harm
    protective_plant_sign_placed_at_the_threshold
    protective_plant_suspended_or_placed_at_thresholds_against_hostile_beings
    protective_wonder_animal_circles_a_hero_under_taboos
    refuge_from_demonic_promptings
    refuge_from_demonic_suggestions
    ritual_fire_used_to_send_away_harm
    ritual_vulnerability_to_hostile_beings
    ruler_protected_from_foreign_magical_danger_or_contamination
    sacral_regulation_of_household_thresholds
    sacred_regulation_of_household_thresholds
    sealing_the_household_before_combat
    sympathetic_magic_by_resemblance
    sympathetic_magic_through_dramatic_representation
    sympathetic_magic_to_secure_game_supply
    veiled_or_screened_sacred_domestic_space
  ],
  "sacred_law_family_and_kinship" => %w[
    abolition_of_coercive_widow_inheritance
    anger_restrained_by_dharmic_kinship_appeal
    beloved_refuses_elopement_from_kin_duty
    binding_parental_word_causes_shared_marriage
    bride_as_skilled_weaver_and_household_producer
    burying_daughters_alive_female_infanticide
    compensation_for_dishonoured_marriage_bed
    concern_for_female_honor_within_household_relations
    conflict_of_duty_toward_teacher_and_vengeance_against_enemy
    conflict_of_kinship_duties
    divinely_ordained_inheritance_and_family_order
    dutiful_child_sustains_aged_helpless_parents
    dutiful_daughter_supports_ruined_father
    dying_mother_s_moral_injunction_to_child
    elder_brother_as_father_and_refuge
    equal_legitimacy_of_children_across_maternal_status
    estate_distribution_by_fixed_kinship_proportions
    faithful_wife_contrasted_with_women_of_luxury
    filial_and_hierarchical_reverence_through_touching_feet
    filial_loyalty_against_maternal_ambition
    filial_obedience_above_personal_desire
    filial_obedience_in_marriage_choice
    filial_obedience_over_personal_gain
    filial_obedience_to_a_father_s_decree
    filial_obligation_as_reason_for_spared_life
    filial_piety_and_grateful_maturity
    filial_piety_and_mature_gratitude
    filial_piety_revealed_through_misunderstanding
    forbidden_kinship_union_concealed_by_night_and_deception
    kin_solidarity_signaled_by_joined_fingers
    kinship_boundaries_regulating_marriage
    kinship_obligation_constraining_punishment
    kinship_roles_inverted_by_taboo_union
    marital_reconciliation_under_divine_oversight
    obedient_son_accepts_harsh_command
    ordered_union_contrasted_with_licentiousness
    post_marital_waiting_and_nursing_obligation
    rejection_of_unjust_paternal_command
    religious_lawgiver_regulates_marriage_and_divorce
    repentance_and_forgiveness_between_brothers_before_battle
    restored_household_harmony_after_confession_and_forgiveness
    virgin_maiden_guarding_purity
  ],
  "sacred_law_revealed_command" => %w[
    ancestral_custom_resisting_revealed_correction
    ancestral_dispossession_used_to_justify_taking_from_outsiders
    ancestral_exempla_for_harsh_obedience
    angelic_obedience_and_restricted_intercession
    consecrated_priestly_hierarchy
    corruption_of_sacred_writing_for_material_gain
    desecration_of_sacred_book_as_defiant_self_identification
    devil_s_path_as_moral_danger
    dispute_over_new_or_marginal_substances_within_religious_law
    divine_authorization_of_spoil_distribution
    divine_command_regulating_social_transition
    divine_path_opposed_to_scattering_paths
    divine_precedent_invoked_to_suspend_human_law
    divine_warning_against_forbidden_action_under_survival_pressure
    divinely_aided_resistance_to_seduction
    divinely_authorized_law
    divinely_authorized_redistribution_of_captured_property
    divinely_authorized_social_and_marital_order
    divinely_regulated_social_transition
    exception_for_coerced_denial_with_inward_fidelity
    exemplary_heroes_and_gods_must_not_model_lamentation
    expulsion_of_cultural_innovation_to_preserve_sacred_order
    heavenly_ideal_as_rule_for_earthly_life
    heavenly_model_for_earthly_life
    heavenly_model_for_earthly_order
    human_helplessness_before_command_and_prohibition
    law_as_boundary_between_permitted_and_forbidden_action
    loyal_refusal_of_rich_terms
    non_coercive_persuasion_in_religious_conversion
    obedience_tested_through_arbitrary_divine_rites
    obedience_to_sacred_messenger_within_communal_order
    ordered_celestial_or_pious_ranks_praising_god
    outward_profession_contrasted_with_inward_faith
    outward_submission_distinguished_from_inward_faith
    principles_transformed_into_law
    prohibition_against_following_the_adversary
    prohibition_of_usury_in_religious_law
    prophetic_abrogation_of_earlier_law
    rejection_of_a_prior_model_of_disobedience
    religious_adoption_of_earlier_customary_law
    religious_correction_of_self_imposed_prohibition
    religious_law_abolishes_harmful_custom
    removal_of_purity_or_commensality_scruples
    revealed_law_superseding_or_clarifying_earlier_scripture
    right_and_duty_before_happiness
    right_path_versus_scattering_paths
    ritual_austerity_criticized_as_excess
    ritual_disarmament_marking_peace
    ritual_establishment_of_property_boundaries
    ritual_fasting_as_obedient_fear_of_god
    ritual_prayer_maintained_under_danger
    ritual_prostration_and_righteous_striving
    sacred_charge_forsaken_under_emotional_pressure
    sacred_duty_competing_with_commerce_and_entertainment
    sacred_immutability_of_ancestral_law
    sacred_laurel_carried_in_procession
    sacred_law_as_bounded_order
    sacred_regulation_of_clothing_food_and_worship
    sacred_social_boundaries_and_bodily_modesty
    saintly_criticism_of_corrupt_religious_authority
    saving_silence_through_bodily_restraint
    scriptural_book_as_source_of_doctrines_precepts_and_institutions
    temperance_as_obedience_and_self_control
    true_saint_tested_by_observance_of_sacred_law
    universal_divine_orientation
    wine_and_sensual_pleasure_as_causes_of_neglected_duty
    written_sign_as_enforceable_warning
  ],
  "sacred_law_hospitality_and_strangers" => %w[
    breach_of_hospitality_condition_brings_mortal_danger
    denied_hospitality_to_strangers
    disordered_household_under_exploitative_guests
    guest_host_restraint_in_competition
    guest_right_defense_against_hostile_hosts
    inviolability_and_release_of_a_herald
    law_of_the_protected_envoy
    protector_refuses_betrayal_of_one_under_his_safeguard
    ritual_neutralization_of_the_dangerous_stranger
    ritual_observance_before_night_lodging
    suppliant_stranger_under_protection
    temptation_to_kill_a_sleeping_or_powerless_host_resisted
    violation_of_hospitality_by_murderous_host
    violation_of_hospitality_toward_a_poor_stranger
  ],
  "sacred_law_justice_and_mercy" => %w[
    appetite_leads_to_captivity_or_control
    authority_halts_excessive_combat_to_spare_the_defeated
    backbiting_as_cannibalistic_abomination
    backbiting_figured_as_eating_a_dead_brother
    blood_compensation_replacing_or_competing_with_retaliation
    burden_limited_to_capacity
    community_refuses_aid_for_wrongful_act
    concealed_believer_defends_the_threatened_righteous_man
    deceptive_legal_speech_exploiting_probability
    dishonest_custodian_denies_entrusted_property_through_impossible_explanation
    disputed_prize_settled_through_public_arbitration
    divine_care_for_orphan_wanderer_and_needy_person
    equal_sharing_of_war_spoil_between_fighters_and_rear_guard
    ethical_protection_of_orphan_and_beggar
    exceptional_booty_rule_based_on_mode_of_expedition
    exemption_of_the_incapable_and_blame_of_the_able_who_refuse
    forgiveness_if_enemies_desist
    forgiveness_preferred_over_proportionate_retaliation
    four_witness_legal_proof_before_punishment
    giving_each_person_what_is_due
    intervening_outsider_urges_an_end_to_quarrel
    just_stewardship_and_equitable_judgment
    justice_and_injustice_arising_in_social_dealings
    justice_for_vulnerable_persons_and_fair_dealing
    law_as_restraint_on_private_revenge
    manumission_associated_with_generosity
    measure_and_limit_as_ethical_good
    merciful_release_of_captured_spies
    mercy_exception_under_necessity
    moral_community_enjoining_good_and_forbidding_wrong
    moral_reciprocity_of_good_and_ill
    obedient_slave_gains_liberty_through_grateful_endurance
    primordial_age_of_justice_without_law_or_punishment
    protection_of_widows_and_orphans_through_inheritance_reform
    reciprocity_as_ethical_command
    refusal_of_returning_evil_for_evil
    restraint_in_retaliation_and_preference_for_patience
    retaliation_transformed_into_proportional_retribution
    royal_protection_and_feeding_of_animals_after_moral_instruction
    sexual_accusation_requiring_multiple_witnesses
    sincere_inability_distinguished_from_culpable_refusal
    social_care
    supplication_restrained_by_social_caution
    true_religion_measured_by_care_for_vulnerable_people
    warrior_code_invoked_by_a_helpless_combatant_and_violated
    warrior_honor_code_forbids_killing_the_unarmed
    warrior_refuses_to_slay_revered_teacher
    warrior_spares_noncombatant_attendant
    wrongdoing_within_the_ruler_s_household_answered_by_compensation_and_punishment
  ],
  "sacred_law_civic_order" => %w[
    absorbing_collective_order_over_kinship
    animal_nature_corrupted_by_training_instruments
    authorized_falsehood_for_civic_good
    banishment_of_poets_from_the_ideal_order
    body_as_model_for_collective_order
    body_politic_as_diseased_body
    boundary_between_faithful_community_and_hostile_foes
    civic_order_mirrored_in_the_individual
    collective_replacement_of_family_bonds
    communal_boundary_through_prohibited_friendship
    communal_family_like_polity_preventing_internal_strife
    communal_family_order_replacing_private_parent_child_recognition
    communal_guardian_life_with_shared_children_and_duties
    communal_guardian_order_without_private_possessions
    communal_kinship_as_civic_unity
    community_founded_from_human_need
    community_of_goods_or_common_property_as_ideal_order
    community_of_spouses_and_children_replacing_private_kinship
    construction_of_an_ideal_commonwealth
    decline_of_a_city_through_misregulated_birth
    divine_manufacture_of_human_social_types_with_a_moral_ingredient
    family_as_rival_of_the_state
    founding_of_a_community_from_mutual_need
    human_diversity_ordered_for_mutual_recognition
    ideal_commonwealth_based_on_shared_goods
    loss_through_internal_dispute
    music_as_foundation_of_law_and_order
    national_cult_gathering_uniting_divided_communities
    ordered_correspondence_of_state_and_soul
    ordered_society_through_division_of_labor
    ordered_soul_as_ordered_city
    ordered_transformation_of_wilderness_into_a_ceremonial_route
    parasitic_drone_class_feeding_on_civic_wealth
    parasitic_drones_as_civic_plague
    peace_maintained_by_elder_authority_and_internalized_restraint
    purification_of_the_civic_order_by_excluding_harmful_performance
    rebellion_of_body_parts_against_the_belly
    restoration_by_suppressing_disruptive_sects
    ritual_inversion_of_masters_and_servants
    ritual_reversal_of_social_hierarchy
    ruler_backed_doctrinal_coercion
    selective_breeding_for_civic_improvement
    selective_healer_refusing_to_preserve_intemperate_lives
    single_role_social_order
    social_body_as_wounded_body
    social_disorder_expressed_as_litigation_and_disease
    social_exclusion_through_forbidden_birth
    temple_as_repository_of_civic_wealth_and_law
    toleration_bounded_by_civic_order
    unity_enables_escape_from_captivity
    unity_through_shared_joy_and_sorrow
    utopian_common_household_and_state_formation_of_children
    virtue_distributed_among_social_orders
  ],
  "sacred_law_idolatry_and_false_worship" => %w[
    deification_condemned_as_idolatry
    exemplary_ancestor_renounces_idolatrous_people
    exemplary_ancestral_monotheist
    false_gods_as_lifeless_powerless_objects
    idol_maker_marked_by_avoidance_taboo
    non_idolatrous_monotheists_outside_established_religions
    prohibited_image_bearing_game_pieces
    prohibition_of_figurative_images_in_game_pieces
    protection_from_corrupting_images
    refusal_to_deify_prophets_or_angels
    rejection_of_unauthorized_divine_intermediaries
    rejection_of_unauthorized_divine_partners
    supernatural_being_hostile_to_church_bells
    warning_against_idolatry_inserted_into_wisdom_instruction
  ]
}.freeze

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def main
  freq = load_yaml(FREQUENCY_PATH)
  family = freq.fetch("canonical_motifs").find { |g| g["canonical_motif_id"] == FAMILY_ID }
  motifs = family.fetch("mapped_motifs").map { |m| m["motif_id"] }

  # Build inverse: motif_id -> sub_family_id
  motif_to_sub = {}
  CHILDREN.each do |sub_id, list|
    list.each { |m| motif_to_sub[m] = sub_id }
  end

  bins = Hash.new { |h, k| h[k] = [] }
  unbinned = []
  motifs.each do |m|
    bin = motif_to_sub[m]
    if bin
      bins[bin] << m
    else
      unbinned << m
    end
  end

  output = {
    "generated_on" => Date.today.iso8601,
    "family" => FAMILY_ID,
    "method" => "manual binning by reading slugs",
    "total_motifs" => motifs.length,
    "binned" => motifs.length - unbinned.length,
    "unbinned" => unbinned.length,
    "sub_families" => SUB_FAMILY_DEFS.map do |id, label, description|
      { "id" => id, "label" => label, "description" => description, "child_count" => bins[id].length, "children" => bins[id].sort }
    end,
    "unbinned_children" => unbinned.sort
  }

  FileUtils.mkdir_p(File.dirname(OUTPUT_PATH))
  File.write(OUTPUT_PATH, "---\n" + output.to_yaml(line_width: -1).sub(/\A---\n/, ""))

  puts "#{FAMILY_ID} sub-family binning"
  puts "================================"
  puts "Total: #{motifs.length}  Binned: #{motifs.length - unbinned.length}  Unbinned: #{unbinned.length}"
  SUB_FAMILY_DEFS.each { |id, _, _| puts "  %-50s %4d" % [id, bins[id].length] }
  unbinned.each { |m| puts "  UNBINNED: #{m}" } if unbinned.any?
  puts "\nWrote #{OUTPUT_PATH.sub(ROOT + '/', '')}"
end

main if $PROGRAM_NAME == __FILE__
