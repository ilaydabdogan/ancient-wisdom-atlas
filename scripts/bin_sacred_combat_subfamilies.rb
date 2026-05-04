#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bin the 696 sacred_combat child motifs into 9 sub-families.
# First pass: prioritized keyword regex rules (catches ~50% deterministically).
# Second pass: manual overrides for the rest, assigned by reading each motif slug.
#
# Writes a draft YAML at data/normalization/sub-family-bins-sacred-combat.yml.

require "yaml"
require "date"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
FREQUENCY_PATH = File.join(ROOT, "data/indexes/canonical-motif-frequency.yml")
OUTPUT_PATH = File.join(ROOT, "data/normalization/sub-family-bins-sacred-combat.yml")

SUB_FAMILIES = [
  {
    id: "sacred_combat_cattle_raid",
    label: "Cattle Raid and Livestock War",
    description: "Cattle, herds, and prized animals as the cause and object of combat. The Indo-European raid pattern is strongly Celtic but appears across traditions.",
    rules: [
      /cattle/, /livestock/, /\bherds?\b/, /\bbull\b/, /\bcows?\b/, /dairy/,
      /prized_animal/, /guardian_animal/, /seizure_of.*animal/,
      /\braid\b.*animal/, /quest.*bull/, /provisioning/,
      /restitution.*herd/, /raiders_camp/
    ]
  },
  {
    id: "sacred_combat_aftermath_spoils",
    label: "Aftermath and Spoils",
    description: "Post-combat events: beheading, severed heads as trophies and warnings, ornate spoils, ritual mourning of the fallen, sacred games after victory, heroic self-praise, sparing of the defeated, treaty and reconciliation.",
    rules: [
      /behead/, /decapitat/, /severed_head/, /heroic_cast_severs/,
      /spoils/, /trophy/, /tribute_after/, /tribute_extracted/,
      /sacred_games_after/, /games.*after.*victory/,
      /heroic_self_praise/, /heroic_self.*triumph/,
      /lament_demand/, /public_lament/, /threnody/,
      /battlefield_as_corpse/, /dead.*divided/, /dividing.*spoil/,
      /victor.*claim/, /heroic_funeral.*combat/, /battlefield_harvest/,
      /spared_defeated/, /supplication.*victor/,
      /battle_ended_by_lowering_a_banner/
    ]
  },
  {
    id: "sacred_combat_battle_preparation",
    label: "Battle Preparation and Ritual",
    description: "What precedes the fight: arming, ritual invocation, banner-rites, war oaths, divinations before battle, council of chiefs, exhortation of the host, sacred dressings, summoning warriors.",
    rules: [
      /arming.*before/, /\barming\b/, /\barms\b.*before/,
      /before_battle/, /before_combat/, /pre_combat/,
      /ritual_invocation/, /sacred_battle_array/, /battle_array/,
      /banner_rite/, /banner.*before/, /raised_standard/,
      /war_oath/, /vow.*before/, /pledged.*warrior/,
      /assembly_of_chiefs/, /war_council/, /war_summit/,
      /exhortation/, /exhort.*foretelling/, /attendant_warns/,
      /warriors_adorn_themselves/, /attendant.*praises_before/,
      /foretelling.*armed_conflict/, /announcing_armed/,
      /enemy_spy_surveys/, /muster.*war/, /army_musters/, /muster.*before/,
      /enemy_force_as_flood/
    ]
  },
  {
    id: "sacred_combat_vengeance_blood_feud",
    label: "Vengeance and Blood Feud",
    description: "Kin avenging slain kin, ancestral and inherited feud, retaliatory cycles, generations of blood, retaliation as a structural feature of the conflict.",
    rules: [
      /\bavenge/, /avenging/, /\bvengeance\b/, /retaliat/,
      /\bfeud\b/, /blood_feud/, /bloodline_feud/,
      /inherited_enmity/, /inherited.*foe/, /father_s_foe/,
      /kin_feud/, /revenge_cycle/, /revenge.*kin/,
      /kin.*injury/, /vengeance_for_kin/, /vengeance.*slain/,
      /night_raid_of_vengeance/, /retaliatory/,
      /devastation_avenged/, /bereaved_parent_incites/,
      /surviving.*brother_avenges/, /brother_avenges_fallen/,
      /welcomed_guest_becomes_target_of_kin_vengeance/
    ]
  },
  {
    id: "sacred_combat_causes_of_war",
    label: "Causes of War",
    description: "What sparks combat: honor disputes, bride-quest provoking war, broken parley and embassy, distorted messenger speech, contested feast portions, marriage-as-cause, rejected suitors, royal wealth contests.",
    rules: [
      /\bembassy\b/, /parley/, /failed_parley/, /failed_diplomacy/, /failed_mediation/,
      /\bbride/, /bride_quest/, /bride.*offer/, /marriage.*inducement/,
      /sexual.*promise.*truce/, /sexual.*promise.*military/,
      /\bdowry\b/, /marriage_like_settlement/,
      /messenger.*speech/, /messenger.*distort/, /messenger.*causes/,
      /disputed_feast/, /feast.*portion.*leading/,
      /honor_dispute/, /honour_dispute/, /honour_bound.*combat/, /claim_of_honor/,
      /\bcasus_belli\b/, /pretext_for_war/,
      /rejection_of_diplomacy/, /buy_off_the_defender/,
      /defense_of_women_and_herds/, /war_brought_by_a_woman/,
      /war_over_a_valued_animal_or_herd/
    ]
  },
  {
    id: "sacred_combat_treachery_kin_combat",
    label: "Treachery and Forbidden Kin Combat",
    description: "Combat that should not happen but is forced or schemed: kin against kin, foster brothers forced to fight, friendship broken in war, ambush, poisoned weapons, civil war, lured guests, substitution in armor.",
    rules: [
      /foster_brother/, /foster.*combat/, /former_foster/,
      /civil_war/, /kin.*civil/, /kinsmen_fighting/,
      /former_friends/, /former_friendship_broken/, /friendship_maintained_within_mortal/,
      /former.*pupil/, /tragic_duel.*pupil/,
      /\bambush\b/, /lured.*ambush/, /lured_guest/, /lured_to_combat/,
      /poisoned_weapon/, /poison.*ally/, /poison.*comrade/,
      /\btreacher/, /treachery/, /treacherous_kill/,
      /forced_duel/, /forced.*combat.*comrade/, /reluctant_combat_between/,
      /slaughter_of_sleeping/, /nocturnal_raid_on_sleeping/,
      /sleep_as_prelude_to_decapitation/,
      /ancestral_feud_continuing_through_bloodline/,
      /night_attack.*incendiary/,
      /invisible_or_magically_veiled_warrior_attacks_from_concealment/,
      /concealed_warriors_inside_a_fated_horse/,
      /deceptive_hollow_war_object/,
      /substitution_by_wearing_another_hero_s_armor/,
      /youth_disguised_as_adult_to_compel_combat/,
      /strategic_destruction_to_provoke_battle/,
      /banquet_transformed_into_battlefield/,
      /breach_of_hospitality_in_combat/
    ]
  },
  {
    id: "sacred_combat_cosmic_supernatural",
    label: "Cosmic and Supernatural Combat",
    description: "Battle imagery elevated to cosmic register: gods divided into factions, divine inspiration, supernatural opponents and aid, magic-assisted weapons, weapon-resistant or magically-veiled foes, battle compared to cosmic forces.",
    rules: [
      /cosmic/, /\bcelestial\b/, /elemental_opposition/, /elemental.*battle/,
      /divine_inspiration/, /divinely_authorized/, /opposing_armies_claim_divine/,
      /gods_divided/, /gods.*opposing/, /personified_natural_powers/,
      /battle_as_storm/, /battle_as_dance/, /battle_as_celestial_dance/,
      /battle_as_torrent/, /battle_disturbing_the_natural_world/,
      /supernatural_being/, /supernatural_binding/, /supernatural.*opponent/,
      /enchanted_weapon/, /magic.*duel/, /magic_assisted/, /magically_veiled/,
      /weapon_resistant/, /\bwitches\b/, /witch_aided/, /storm_causing_witches/,
      /invisible_warrior/, /invisible.*attack/,
      /\bblinding\b.*monster/, /single_eyed_monster/, /blinding_of_the_single_eyed/,
      /monstrous_husband_or_pursuer/, /monster_demands_battle/,
      /fiery_weapon_neutralized/, /fiery_weapon/, /flame_weapon/,
      /\bsacred_games_instituted/, /institution_of_sacred_games_after_a_divine_victory/,
      /heroic_destruction_of_an_enemy_sanctuary/,
      /paired_warriors_create_a_single_or_crossed_wound/,
      /battle_in_darkness_with_confused_identities/
    ]
  },
  {
    id: "sacred_combat_host_battle_siege",
    label: "Host Battle and Siege",
    description: "Large-scale combat: armies, hosts, sieges, fortified cities, breaches and walls, ships and last stands, battlefield rescues, mass actions and routs.",
    rules: [
      /\bsiege\b/, /\bbesieg/, /\bfortif/, /walled_city/, /city_walls/,
      /breach/, /city_defenses/, /city_gate/, /gate_surrender/,
      /\bships\b/, /burning.*ships/, /burning_of.*ships/, /attack_on_ships/, /threatened_burning/,
      /last_stand/, /trapped_warriors/, /shield_wall/, /compact_shield_wall/,
      /\bhost\b/, /\barmy\b/, /armies/, /\bmarching_host\b/,
      /battlefield/, /battle_tide/, /battle.*formation/,
      /isolated_hero_surrounded/, /single_hero_defeats_overwhelming/,
      /battlefield_rescue/, /rescue.*ally/, /rescue.*comrades/,
      /counter_attack.*ships/, /counterattack/,
      /night_battle/, /night_raid/, /night_assault/,
      /assault_on_an_island_fortress/, /fortified_island/,
      /civic_tools_transformed_into_weapons/,
      /heroic_aristeia_of_named_battlefield/,
      /army_breaches_city/, /\bcity\b.*\bbattle\b/,
      /opposing.*armies/, /armed.*defense/, /serial_killings_in_a_pitched_battle/,
      /improvised_natural_objects/,
      /champions_hurl_stones_across_a_battlefield/,
      /battlefield_arrow_storm/
    ]
  },
  {
    id: "sacred_combat_champion_duel",
    label: "Champion Combat and Duel",
    description: "Single combat as the structural center: hero vs hero, champion challenges, ford-fights, formal duels watched by armies, alternating-weapon contests, named challengers, mutual fall, lone warrior vs many.",
    rules: [
      /single_combat/, /duel/, /champion/, /one_to_one_combat/,
      /\bford\b/, /at_a_ford/,
      /\baristeia\b/,
      /heroic_single_combat/, /champion_chase/, /serial_single/,
      /heroic_challenge/, /armed_champion/, /champion_threatening/,
      /individual_combat/, /single_knight/, /lone_warrior/,
      /one_against_many/, /many_attackers_against_the_single/,
      /unarmed_boastful_wrestler/,
      /heroic_youth_challenges_elder/, /youth_challenges/,
      /female_warrior.*challenger/, /amazonian/,
      /balanced_combat_without_bloodshed/, /bloodless_battle/,
      /substitute_in_single_combat/,
      /three_day_combat_ordeal/,
      /enemy_champion/, /slay_enemy_champion/,
      /paired_warrior/, /matched_champion/, /mutual_death_of_matched/,
      /rival_warriors_challenge/, /volunteer_champion_precedes/,
      /armed_quest_to_recover/
    ]
  }
]

# Manual overrides — assignments for motifs the regex couldn't reach.
# Read by hand from the unbinned list. Each motif goes to its single best-fit
# sub-family (per the "most central feature" rule).
MANUAL = {
  # cattle / livestock
  "bull_centered_conflict" => "sacred_combat_cattle_raid",
  "prized_bull_carried_off_while_the_defender_is_occupied" => "sacred_combat_cattle_raid",
  "threefold_taking_of_valued_animals" => "sacred_combat_cattle_raid",
  "non_supernatural_non_lethal_raid_with_good_ending" => "sacred_combat_cattle_raid",

  # battle preparation
  "arming_against_a_feared_special_weapon" => "sacred_combat_battle_preparation",
  "arming_for_combat_with_animal_marked_equipment" => "sacred_combat_battle_preparation",
  "battle_associated_female_ritual_specialists" => "sacred_combat_battle_preparation",
  "decisive_arming_against_a_feared_weapon" => "sacred_combat_battle_preparation",
  "feast_and_rest_before_renewed_battle" => "sacred_combat_battle_preparation",
  "heroic_rally_before_opposed_battle" => "sacred_combat_battle_preparation",
  "heroic_reproach_to_rouse_warriors" => "sacred_combat_battle_preparation",
  "judgment_delegated_to_a_warrior_assembly" => "sacred_combat_battle_preparation",
  "night_reconnaissance_into_the_enemy_camp" => "sacred_combat_battle_preparation",
  "obstruction_of_weapon_preparation_by_releasing_water" => "sacred_combat_battle_preparation",
  "ordered_martial_muster_on_a_height" => "sacred_combat_battle_preparation",
  "prayer_for_courage_restrained_by_peace" => "sacred_combat_battle_preparation",
  "reconnaissance_before_assault_on_a_fortified_enemy_city" => "sacred_combat_battle_preparation",
  "refusal_of_love_and_aid_during_martial_duty" => "sacred_combat_battle_preparation",
  "ritual_opening_of_war_gates" => "sacred_combat_battle_preparation",
  "ritualized_public_declaration_of_war_by_spear_casting" => "sacred_combat_battle_preparation",
  "silent_signal_initiating_armed_alliance" => "sacred_combat_battle_preparation",
  "spoken_praise_restores_or_increases_hero_s_courage" => "sacred_combat_battle_preparation",
  "summoning_aid_through_sorrowful_warrior_music" => "sacred_combat_battle_preparation",
  "summoning_of_a_warrior_host_after_warning" => "sacred_combat_battle_preparation",
  "summoning_warriors_by_three_great_shouts" => "sacred_combat_battle_preparation",
  "warrior_band_rejects_an_unfit_companion" => "sacred_combat_battle_preparation",
  "warrior_excess_restrained_before_dawn" => "sacred_combat_battle_preparation",

  # vengeance / blood feud
  "blood_as_promised_satisfaction_for_injury" => "sacred_combat_vengeance_blood_feud",
  "boast_counter_boast_and_vengeance_duel" => "sacred_combat_vengeance_blood_feud",
  "captives_reclaimed_after_killing_their_captors" => "sacred_combat_vengeance_blood_feud",
  "champion_avenges_insult_to_a_lady_s_maiden" => "sacred_combat_vengeance_blood_feud",
  "engineered_kin_vengeance_through_a_doomed_challenger" => "sacred_combat_vengeance_blood_feud",
  "feud_violence_against_associated_or_innocent_groups" => "sacred_combat_vengeance_blood_feud",
  "hereditary_feud_over_a_slain_father" => "sacred_combat_vengeance_blood_feud",
  "household_reversal" => "sacred_combat_treachery_kin_combat",
  "inherited_feud_and_vengeance_across_generations" => "sacred_combat_vengeance_blood_feud",
  "inherited_feud_reopened_by_account_of_father_s_death" => "sacred_combat_vengeance_blood_feud",
  "injured_figure_flees_to_powerful_kin_or_ally_and_reports_wrong" => "sacred_combat_vengeance_blood_feud",
  "kin_vengeance_after_mass_killing" => "sacred_combat_vengeance_blood_feud",
  "kinsman_s_death_triggers_feud_and_revenge_threats" => "sacred_combat_vengeance_blood_feud",
  "lament_leading_to_revenge_battle" => "sacred_combat_vengeance_blood_feud",
  "leader_drawn_into_combat_by_the_death_of_a_beloved_younger_kinsman" => "sacred_combat_vengeance_blood_feud",
  "mutilated_sister_rouses_brother_s_vengeance" => "sacred_combat_vengeance_blood_feud",
  "mutual_destruction_in_revenge" => "sacred_combat_vengeance_blood_feud",
  "public_humiliation_of_a_royal_woman_leading_to_vengeance_vow" => "sacred_combat_vengeance_blood_feud",
  "public_insult_requiring_vengeance_by_a_champion" => "sacred_combat_vengeance_blood_feud",
  "rival_hero_clans_and_strongholds" => "sacred_combat_vengeance_blood_feud",
  "sons_avenge_slain_fathers" => "sacred_combat_vengeance_blood_feud",
  "sons_urged_to_avenge_slain_father" => "sacred_combat_vengeance_blood_feud",
  "vengeance_by_burning_the_enemy_hall" => "sacred_combat_vengeance_blood_feud",
  "vengeance_killing_restores_ancestral_treasure" => "sacred_combat_vengeance_blood_feud",
  "vengeance_preparation_with_war_chariot" => "sacred_combat_vengeance_blood_feud",
  "vengeful_refusal_of_ransom_or_supplication" => "sacred_combat_vengeance_blood_feud",
  "violated_queen_as_trigger_of_vengeance" => "sacred_combat_vengeance_blood_feud",
  "weak_avenger_against_the_strong" => "sacred_combat_vengeance_blood_feud",
  "wounded_cherished_animal_as_trigger_of_feud" => "sacred_combat_vengeance_blood_feud",

  # causes of war
  "broken_truce_followed_by_failed_mass_attack" => "sacred_combat_causes_of_war",
  "combat_induced_by_gifts_and_promised_bride" => "sacred_combat_causes_of_war",
  "combat_to_be_proven_in_a_feast_hall_or_house_setting" => "sacred_combat_causes_of_war",
  "competitive_inventory_of_royal_wealth" => "sacred_combat_causes_of_war",
  "contest_of_renown_for_the_right_to_divide_a_feast_animal" => "sacred_combat_causes_of_war",
  "contested_division_of_a_feast_animal_by_martial_precedence" => "sacred_combat_causes_of_war",
  "deceptive_provocation_to_secure_a_champion_s_pledge" => "sacred_combat_causes_of_war",
  "dispute_over_division_of_a_special_animal_leading_to_renewed_violence" => "sacred_combat_causes_of_war",
  "disrupted_wedding_feast_turns_into_combat" => "sacred_combat_causes_of_war",
  "division_of_a_prestigious_boar" => "sacred_combat_causes_of_war",
  "embassy_before_war" => "sacred_combat_causes_of_war",
  "ending_wrath_and_public_reconciliation_before_war" => "sacred_combat_causes_of_war",
  "enemy_s_ambiguous_warning" => "sacred_combat_causes_of_war",
  "failed_negotiated_exchange" => "sacred_combat_causes_of_war",
  "fatal_combat_prompted_by_promised_woman_or_prize" => "sacred_combat_causes_of_war",
  "fatal_game_leading_to_dishonor_and_vengeance" => "sacred_combat_causes_of_war",
  "hall_seating_insult_leading_to_mobilization" => "sacred_combat_causes_of_war",
  "honor_and_reputation_compel_combat" => "sacred_combat_causes_of_war",
  "honor_at_feast_requiring_valor_in_battle" => "sacred_combat_causes_of_war",
  "insult_escalating_into_factional_combat" => "sacred_combat_causes_of_war",
  "intra_allied_conflict_over_honour_and_marriage_pledge" => "sacred_combat_causes_of_war",
  "multiple_warriors_promised_the_same_bride_for_military_service" => "sacred_combat_causes_of_war",
  "quarrel_over_warrior_weapon_as_cause_of_conflict" => "sacred_combat_causes_of_war",
  "refusal_of_compensatory_gifts_to_preserve_communal_honour" => "sacred_combat_causes_of_war",
  "refused_embassy_to_a_wrathful_hero" => "sacred_combat_causes_of_war",
  "rejected_suitor_s_war_over_a_bride" => "sacred_combat_causes_of_war",
  "royal_spouses_compare_wealth_and_status" => "sacred_combat_causes_of_war",
  "threat_and_counter_threat_before_future_conflict" => "sacred_combat_causes_of_war",
  "threefold_ultimatum_before_conflict" => "sacred_combat_causes_of_war",
  "ultimatum_between_restitution_and_war" => "sacred_combat_causes_of_war",
  "war_contagion_through_collective_outcry" => "sacred_combat_causes_of_war",
  "war_following_contention" => "sacred_combat_causes_of_war",
  "war_for_a_woman_or_beloved" => "sacred_combat_causes_of_war",
  "warning_to_avoid_a_dangerous_hero" => "sacred_combat_causes_of_war",
  "warrior_drawn_into_combat_by_gifts_and_an_alluring_woman" => "sacred_combat_causes_of_war",
  "warrior_wins_or_claims_bride_through_promised_conquest" => "sacred_combat_causes_of_war",
  "wealth_contest_between_rulers" => "sacred_combat_causes_of_war",
  "wine_and_promised_woman_as_inducement_to_dangerous_combat" => "sacred_combat_causes_of_war",
  "woman_as_martial_prize_or_lure" => "sacred_combat_causes_of_war",
  "women_as_messengers_and_mediators_between_raiding_and_rescue_parties" => "sacred_combat_causes_of_war",

  # treachery / forbidden kin combat
  "ambush_overcome_with_lone_survivor" => "sacred_combat_treachery_kin_combat",
  "battle_between_members_of_a_warrior_band" => "sacred_combat_treachery_kin_combat",
  "beloved_companions_forced_into_mortal_combat" => "sacred_combat_treachery_kin_combat",
  "betrayed_safe_conduct" => "sacred_combat_treachery_kin_combat",
  "breaking_fair_combat_by_group_attack_or_ambush" => "sacred_combat_treachery_kin_combat",
  "concealed_warriors_in_a_peace_house" => "sacred_combat_treachery_kin_combat",
  "counsel_to_betray_or_encircle_the_hero" => "sacred_combat_treachery_kin_combat",
  "fatal_ambush_at_a_sacred_wedding_setting" => "sacred_combat_treachery_kin_combat",
  "fatal_combat_caused_by_deception_or_inducement" => "sacred_combat_treachery_kin_combat",
  "fatal_combat_caused_by_night_misrecognition" => "sacred_combat_treachery_kin_combat",
  "former_companions_forced_into_deadly_combat" => "sacred_combat_treachery_kin_combat",
  "former_companions_forced_into_duel" => "sacred_combat_treachery_kin_combat",
  "former_comrades_become_mortal_opponents" => "sacred_combat_treachery_kin_combat",
  "foster_bond_invoked_in_battle" => "sacred_combat_treachery_kin_combat",
  "foster_master_mediates_between_hero_and_opposing_host" => "sacred_combat_treachery_kin_combat",
  "fosterage_or_master_pupil_obligation_in_heroic_conflict" => "sacred_combat_treachery_kin_combat",
  "friend_against_friend_combat" => "sacred_combat_treachery_kin_combat",
  "friend_versus_friend_duel" => "sacred_combat_treachery_kin_combat",
  "hero_sent_against_a_deadly_adversary_to_bring_about_his_death" => "sacred_combat_treachery_kin_combat",
  "honour_bound_restraint_because_of_another_warrior_s_safeguard" => "sacred_combat_treachery_kin_combat",
  "honour_protection_restraining_violence" => "sacred_combat_treachery_kin_combat",
  "inside_helper_enables_entry_to_enemy_fort" => "sacred_combat_treachery_kin_combat",
  "internal_threat_against_an_overmighty_allied_troop" => "sacred_combat_treachery_kin_combat",
  "jealous_slaying_of_a_companion_or_guest" => "sacred_combat_treachery_kin_combat",
  "jealousy_prompts_treacherous_ambush_against_the_hero" => "sacred_combat_treachery_kin_combat",
  "king_killed_as_suppliant_at_an_altar" => "sacred_combat_treachery_kin_combat",
  "kinship_loyalty_opposed_to_heroic_honour" => "sacred_combat_treachery_kin_combat",
  "kinship_restraint_in_internal_warfare" => "sacred_combat_treachery_kin_combat",
  "kinship_warning_ignored_because_of_pledged_honor" => "sacred_combat_treachery_kin_combat",
  "mistaken_killing_of_allies_by_night" => "sacred_combat_treachery_kin_combat",
  "night_attack_on_sleeping_army_in_reported_battle" => "sacred_combat_treachery_kin_combat",
  "oath_bound_companions_forced_into_fatal_combat" => "sacred_combat_treachery_kin_combat",
  "paired_attackers_seek_glory_by_killing_a_wounded_warrior" => "sacred_combat_treachery_kin_combat",
  "reluctant_duel_with_a_beloved_foster_companion" => "sacred_combat_treachery_kin_combat",
  "shared_fosterage_and_arms_preceding_fatal_conflict" => "sacred_combat_treachery_kin_combat",
  "substitute_warrior_in_another_hero_s_armor" => "sacred_combat_treachery_kin_combat",
  "substitute_warrior_in_borrowed_armor" => "sacred_combat_treachery_kin_combat",
  "substitute_warrior_wears_hero_s_armor" => "sacred_combat_treachery_kin_combat",
  "unfair_killing_of_a_rival_ruler" => "sacred_combat_treachery_kin_combat",

  # cosmic / supernatural
  "ally_restrained_from_unleashing_an_overpowering_weapon" => "sacred_combat_cosmic_supernatural",
  "animal_attackers_in_heroic_combat" => "sacred_combat_cosmic_supernatural",
  "animal_chooses_a_side_in_battle" => "sacred_combat_cosmic_supernatural",
  "battle_as_divine_or_celestial_dance" => "sacred_combat_cosmic_supernatural",
  "collective_heroic_hunt_against_a_monstrous_beast" => "sacred_combat_cosmic_supernatural",
  "combat_of_giant_bird_and_monstrous_water_creature" => "sacred_combat_cosmic_supernatural",
  "combat_on_or_in_supernatural_seeming_water_setting" => "sacred_combat_cosmic_supernatural",
  "contest_between_divine_people_and_heroic_band" => "sacred_combat_cosmic_supernatural",
  "continual_war_between_small_people_and_cranes" => "sacred_combat_cosmic_supernatural",
  "dangerous_quarry_resists_or_defeats_heroic_weapons" => "sacred_combat_cosmic_supernatural",
  "dangerous_threshold_time_in_combat" => "sacred_combat_cosmic_supernatural",
  "destruction_of_supernatural_or_mound_dwellings_in_war" => "sacred_combat_cosmic_supernatural",
  "divine_patronage_of_opposing_mortal_champions" => "sacred_combat_cosmic_supernatural",
  "divine_suspension_of_battle_through_a_champion_duel" => "sacred_combat_cosmic_supernatural",
  "elemental_magical_warfare" => "sacred_combat_cosmic_supernatural",
  "encounter_with_an_obscured_opponent_in_mist" => "sacred_combat_cosmic_supernatural",
  "fiery_eyed_hero_and_monster_boar_combat" => "sacred_combat_cosmic_supernatural",
  "hero_counters_supernatural_threats_with_reciprocal_injury_threats" => "sacred_combat_cosmic_supernatural",
  "hero_goes_to_battle_as_to_a_love_tryst" => "sacred_combat_cosmic_supernatural",
  "hero_incapacitated_by_hidden_magical_attack" => "sacred_combat_cosmic_supernatural",
  "hero_overpowers_local_water_being" => "sacred_combat_cosmic_supernatural",
  "heroic_animal_slays_a_communal_predator" => "sacred_combat_cosmic_supernatural",
  "heroic_combat_at_a_god_s_sacred_precinct" => "sacred_combat_cosmic_supernatural",
  "hidden_weapon_exposes_hero_to_monster_danger" => "sacred_combat_cosmic_supernatural",
  "ineffective_hero_s_weapon_against_giant_sleeper" => "sacred_combat_cosmic_supernatural",
  "invasion_while_defenders_are_under_a_curse" => "sacred_combat_cosmic_supernatural",
  "landscape_mobilized_as_battle_ally" => "sacred_combat_cosmic_supernatural",
  "magic_aided_feud_attack" => "sacred_combat_cosmic_supernatural",
  "magical_concealment_before_an_attack" => "sacred_combat_cosmic_supernatural",
  "magical_concealment_in_combat" => "sacred_combat_cosmic_supernatural",
  "magical_invisibility_covering_in_battle" => "sacred_combat_cosmic_supernatural",
  "night_attack_by_supernatural_battalions" => "sacred_combat_cosmic_supernatural",
  "personified_discord_rejoices_in_war" => "sacred_combat_cosmic_supernatural",
  "personified_horrors_of_war" => "sacred_combat_cosmic_supernatural",
  "predatory_war_rush_as_hungry_wolves" => "sacred_combat_cosmic_supernatural",
  "refusal_to_undo_another_hero_s_binding" => "sacred_combat_cosmic_supernatural",
  "ritual_combat_with_invisible_foes" => "sacred_combat_cosmic_supernatural",
  "ritual_object_turned_weapon" => "sacred_combat_cosmic_supernatural",
  "special_opponent_overcome_by_matching_feat_or_weapon" => "sacred_combat_cosmic_supernatural",
  "spiritual_authority_defeats_martial_power" => "sacred_combat_cosmic_supernatural",
  "storm_like_attacking_host" => "sacred_combat_cosmic_supernatural",
  "supernatural_obstruction_in_battle" => "sacred_combat_cosmic_supernatural",
  "withheld_martial_advantage_or_secret_body_protection" => "sacred_combat_cosmic_supernatural",
  "world_shaking_duel_of_hero_and_giant_king" => "sacred_combat_cosmic_supernatural",

  # aftermath / spoils
  "appeasement_of_heroic_wrath" => "sacred_combat_aftermath_spoils",
  "capture_of_divine_horses_as_battle_spoil" => "sacred_combat_aftermath_spoils",
  "champion_spares_defeated_challengers" => "sacred_combat_aftermath_spoils",
  "choosing_the_harder_living_capture_over_killing" => "sacred_combat_aftermath_spoils",
  "closure_and_binding_of_war" => "sacred_combat_aftermath_spoils",
  "compelled_messenger_carries_proof_of_defeat" => "sacred_combat_aftermath_spoils",
  "cooling_battle_frenzy_with_water" => "sacred_combat_aftermath_spoils",
  "defeated_adversary_becomes_sworn_ally" => "sacred_combat_aftermath_spoils",
  "defeated_enemy_spared_and_combat_deferred" => "sacred_combat_aftermath_spoils",
  "defeated_opponent_spared_and_sent_as_messenger" => "sacred_combat_aftermath_spoils",
  "defeated_warrior_hidden_while_victor_seeks_him" => "sacred_combat_aftermath_spoils",
  "display_of_enemy_body_parts_as_trophies" => "sacred_combat_aftermath_spoils",
  "enemy_heads_displayed_as_battle_trophies" => "sacred_combat_aftermath_spoils",
  "enemy_healers_compelled_to_treat_a_foe" => "sacred_combat_aftermath_spoils",
  "fallen_heroic_brothers_under_enemy_triumph_claim" => "sacred_combat_aftermath_spoils",
  "hero_s_incomplete_victory_leaves_antagonist_alive" => "sacred_combat_aftermath_spoils",
  "hero_spares_vulnerable_enemy_because_attack_would_lack_honour" => "sacred_combat_aftermath_spoils",
  "lone_messenger_after_a_rout" => "sacred_combat_aftermath_spoils",
  "merciful_release_of_a_captured_enemy_spy" => "sacred_combat_aftermath_spoils",
  "merciful_release_of_enemy_envoys" => "sacred_combat_aftermath_spoils",
  "negotiated_respite_through_return_of_captured_goods_and_captives" => "sacred_combat_aftermath_spoils",
  "posthumous_proof_of_victory_from_position_of_bodies" => "sacred_combat_aftermath_spoils",
  "preventing_the_enemy_survivor_from_carrying_the_tale_home" => "sacred_combat_aftermath_spoils",
  "rejection_of_domestic_wealth_for_battle_won_treasure" => "sacred_combat_aftermath_spoils",
  "reused_weapon_links_separate_killings" => "sacred_combat_aftermath_spoils",
  "rival_warriors_reconciled_into_shared_command" => "sacred_combat_aftermath_spoils",
  "seizure_of_chariot_as_martial_prize" => "sacred_combat_aftermath_spoils",
  "severed_enemy_head_as_proof_of_superior_prowess" => "sacred_combat_aftermath_spoils",
  "survivor_of_combat_left_permanently_maimed" => "sacred_combat_aftermath_spoils",
  "victor_spares_defeated_opponent" => "sacred_combat_aftermath_spoils",
  "war_prize_carried_off_from_enemy_territory" => "sacred_combat_aftermath_spoils",
  "warrior_displays_severed_enemy_head_and_taunts_opponents" => "sacred_combat_aftermath_spoils",
  "weapon_recovered_from_the_slain_body" => "sacred_combat_aftermath_spoils",

  # champion / duel
  "anonymous_champion_defeats_repeated_challengers" => "sacred_combat_champion_duel",
  "army_seeks_a_champion_to_face_an_overwhelming_hero" => "sacred_combat_champion_duel",
  "battle_at_a_liminal_crossing" => "sacred_combat_champion_duel",
  "borrowed_arms_for_a_challenge" => "sacred_combat_champion_duel",
  "challenge_cry_draws_a_royal_opponent_from_his_stronghold" => "sacred_combat_champion_duel",
  "challenge_to_renewed_combat_at_an_appointed_time_and_place" => "sacred_combat_champion_duel",
  "challenger_seeks_a_worthy_combatant" => "sacred_combat_champion_duel",
  "challengers_humiliated_by_prior_defeats_recalled_in_public" => "sacred_combat_champion_duel",
  "champion_combat_against_the_enemy_s_best_fighter" => "sacred_combat_champion_duel",
  "champion_recruited_with_reward_to_fight_the_hero" => "sacred_combat_champion_duel",
  "champion_s_challenge_to_enemy_king" => "sacred_combat_champion_duel",
  "champion_s_missile_assault_with_stones_and_earth" => "sacred_combat_champion_duel",
  "combat_halted_by_sacred_mediation_and_nightfall" => "sacred_combat_champion_duel",
  "communal_intervention_to_halt_dangerous_heroic_combat" => "sacred_combat_champion_duel",
  "companions_secretly_depart_and_are_slain_before_the_hero_s_duel" => "sacred_combat_champion_duel",
  "contest_game_as_outlet_for_warrior_rivalry" => "sacred_combat_champion_duel",
  "courteous_or_chivalric_speech_between_opposing_heroes" => "sacred_combat_champion_duel",
  "daily_champion_compact_controlling_army_movement" => "sacred_combat_champion_duel",
  "dangerous_ally_sent_against_enemy_as_expendable_champion" => "sacred_combat_champion_duel",
  "dangerous_narrow_way_overtake_in_a_contest" => "sacred_combat_champion_duel",
  "daylong_combat_followed_by_temporary_truce" => "sacred_combat_champion_duel",
  "deadly_intervention_by_allied_archer_in_a_duel" => "sacred_combat_champion_duel",
  "defeat_of_champion_prompts_escalation" => "sacred_combat_champion_duel",
  "exchange_of_arms_becomes_fatal_exchange" => "sacred_combat_champion_duel",
  "female_archer_wins_first_blood_in_a_male_heroic_contest" => "sacred_combat_champion_duel",
  "female_warrior_routs_multiple_male_opponents" => "sacred_combat_champion_duel",
  "final_duel_of_life_long_rivals" => "sacred_combat_champion_duel",
  "ford_as_site_of_decisive_combat_and_mourning" => "sacred_combat_champion_duel",
  "ford_duel_as_crisis_point" => "sacred_combat_champion_duel",
  "ford_duel_decided_by_a_spear_throw" => "sacred_combat_champion_duel",
  "formal_alternation_of_weapon_choice_in_heroic_combat" => "sacred_combat_champion_duel",
  "formal_combat_challenge_and_threat" => "sacred_combat_champion_duel",
  "friend_secures_victory_by_obstructing_a_rival" => "sacred_combat_champion_duel",
  "giant_stone_hurling_combat" => "sacred_combat_champion_duel",
  "hero_defeats_multiple_champions_in_sequence" => "sacred_combat_champion_duel",
  "hero_defeats_successive_pursuit_animals_and_leaders" => "sacred_combat_champion_duel",
  "hero_pauses_battle_to_restore_exhausted_steeds" => "sacred_combat_champion_duel",
  "hero_rescues_threatened_woman_by_killing_enemy" => "sacred_combat_champion_duel",
  "heroic_boast_and_counter_boast_as_status_contest" => "sacred_combat_champion_duel",
  "heroic_boast_of_foretold_victory" => "sacred_combat_champion_duel",
  "heroic_duel_with_boasts_and_exchanged_missiles" => "sacred_combat_champion_duel",
  "heroic_opposition_in_combat" => "sacred_combat_champion_duel",
  "heroic_rivalry_measured_by_martial_prowess" => "sacred_combat_champion_duel",
  "honorable_face_to_face_combat_contrasted_with_distant_or_stealthy_killing" => "sacred_combat_champion_duel",
  "impartial_judge_killed_by_the_contest_he_witnesses" => "sacred_combat_champion_duel",
  "incited_conflict_between_paired_champions" => "sacred_combat_champion_duel",
  "lot_ordered_heroic_contest" => "sacred_combat_champion_duel",
  "low_status_mediator_rejected_by_powerful_combatants" => "sacred_combat_champion_duel",
  "maiden_s_worth_vindicated_through_tournament_challenge" => "sacred_combat_champion_duel",
  "martial_sport_feat_as_boast_and_challenge" => "sacred_combat_champion_duel",
  "mutual_death_in_combat_by_engulfing_water" => "sacred_combat_champion_duel",
  "mutual_fall_of_last_combatants" => "sacred_combat_champion_duel",
  "mutual_refusal_of_victory_after_equal_combat" => "sacred_combat_champion_duel",
  "nightfall_delaying_destined_combat" => "sacred_combat_champion_duel",
  "nightly_truce_between_dueling_companions" => "sacred_combat_champion_duel",
  "non_wounding_display_of_elite_skill" => "sacred_combat_champion_duel",
  "outnumbered_defenders_facing_successive_foreign_champions" => "sacred_combat_champion_duel",
  "pathos_and_honor_in_combat_between_champions" => "sacred_combat_champion_duel",
  "recurring_heroic_combats_and_slayings" => "sacred_combat_champion_duel",
  "reluctant_champion_compelled_by_taunts" => "sacred_combat_champion_duel",
  "rescue_from_execution_by_fire_through_offered_combat" => "sacred_combat_champion_duel",
  "rival_heroes_first_meeting_as_foes" => "sacred_combat_champion_duel",
  "ritualized_equal_combat_with_weapon_choice_by_arrival_at_the_ford" => "sacred_combat_champion_duel",
  "single_defender_harrying_a_whole_host" => "sacred_combat_champion_duel",
  "single_hero_against_overwhelming_host" => "sacred_combat_champion_duel",
  "single_hero_defeats_multiple_challengers_at_fords" => "sacred_combat_champion_duel",
  "single_hero_defeats_multiple_elite_captains" => "sacred_combat_champion_duel",
  "single_hero_overwhelmed_by_unfair_combat" => "sacred_combat_champion_duel",
  "single_warrior_halts_or_redirects_an_armed_group" => "sacred_combat_champion_duel",
  "single_warrior_holding_a_ford" => "sacred_combat_champion_duel",
  "slayer_overcome_by_stronger_slayer" => "sacred_combat_champion_duel",
  "taunt_provoking_or_redirecting_warrior_action" => "sacred_combat_champion_duel",
  "taunt_provoking_renewed_martial_force" => "sacred_combat_champion_duel",
  "taunt_that_rouses_a_warrior" => "sacred_combat_champion_duel",
  "threatened_submersion_of_an_opponent" => "sacred_combat_champion_duel",
  "unlikely_object_used_as_lethal_projectile" => "sacred_combat_champion_duel",
  "warning_to_the_hero_before_a_scheduled_duel" => "sacred_combat_champion_duel",
  "warrior_s_fame_through_repeated_contests" => "sacred_combat_champion_duel",
  "warrior_s_vaunting_challenge_to_the_opposing_host" => "sacred_combat_champion_duel",
  "weapon_returned_against_its_thrower" => "sacred_combat_champion_duel",
  "weapon_substitution_or_disarmed_warrior" => "sacred_combat_champion_duel",

  # host battle / siege
  "allied_host_gathered_for_heroic_war" => "sacred_combat_host_battle_siege",
  "allies_recognize_comrades_by_the_sound_of_blows" => "sacred_combat_host_battle_siege",
  "army_mustered_for_siege_of_enemy_city" => "sacred_combat_host_battle_siege",
  "army_suffers_under_extraordinary_snow_without_shelter" => "sacred_combat_host_battle_siege",
  "arrival_and_recognition_of_heroic_companies" => "sacred_combat_host_battle_siege",
  "attempted_fiery_destruction_of_enemy_ships" => "sacred_combat_host_battle_siege",
  "body_shielding_failed_protection" => "sacred_combat_host_battle_siege",
  "bridge_over_water_to_enemy_stronghold" => "sacred_combat_host_battle_siege",
  "burning_of_a_hostile_city" => "sacred_combat_host_battle_siege",
  "city_destroyed_by_nocturnal_assault_and_fire" => "sacred_combat_host_battle_siege",
  "city_destruction_by_fire_after_capture" => "sacred_combat_host_battle_siege",
  "city_sacked_for_a_woman" => "sacred_combat_host_battle_siege",
  "city_under_emergency_defense" => "sacred_combat_host_battle_siege",
  "combat_with_fire_trees_stones_and_improvised_natural_weapons" => "sacred_combat_host_battle_siege",
  "communal_warrior_discipline_as_civic_salvation" => "sacred_combat_host_battle_siege",
  "conquest_before_plunder" => "sacred_combat_host_battle_siege",
  "crossing_water_or_bridging_to_enemy_stronghold" => "sacred_combat_host_battle_siege",
  "deadly_spiked_battle_vehicle" => "sacred_combat_host_battle_siege",
  "disciplined_communal_warrior_state" => "sacred_combat_host_battle_siege",
  "encircling_barrier_that_prevents_enemy_escape" => "sacred_combat_host_battle_siege",
  "enemy_standard_cut_down_in_battle" => "sacred_combat_host_battle_siege",
  "fall_of_a_heroic_warrior_band" => "sacred_combat_host_battle_siege",
  "fall_of_the_city_with_royal_blood_captive_women_and_child_killing" => "sacred_combat_host_battle_siege",
  "female_warrior_leading_cavalry" => "sacred_combat_host_battle_siege",
  "fire_attack_on_enemy_vessels" => "sacred_combat_host_battle_siege",
  "foreign_host_invades_to_impose_tribute" => "sacred_combat_host_battle_siege",
  "foreign_or_extraordinary_ally_arrives_to_aid_a_doomed_city_and_dies" => "sacred_combat_host_battle_siege",
  "game_continued_while_battle_rages" => "sacred_combat_host_battle_siege",
  "great_war_as_center_of_a_legendary_epic_cycle" => "sacred_combat_host_battle_siege",
  "hero_awakened_by_battle_distress" => "sacred_combat_host_battle_siege",
  "hero_cuts_a_gap_through_enemy_ranks" => "sacred_combat_host_battle_siege",
  "hero_harassing_and_reducing_a_marching_host" => "sacred_combat_host_battle_siege",
  "hero_rescues_endangered_elder_in_battle" => "sacred_combat_host_battle_siege",
  "heroes_fighting_back_to_back_while_surrounded" => "sacred_combat_host_battle_siege",
  "heroic_contests_between_opposed_peoples" => "sacred_combat_host_battle_siege",
  "heroic_defense_against_overseas_raiders" => "sacred_combat_host_battle_siege",
  "heroic_gate_defense_by_a_small_number_against_a_larger_force" => "sacred_combat_host_battle_siege",
  "heroic_harrying_of_an_army_with_supplied_missiles" => "sacred_combat_host_battle_siege",
  "heroic_slaughter_in_a_river" => "sacred_combat_host_battle_siege",
  "homeland_defended_by_heroic_war_band" => "sacred_combat_host_battle_siege",
  "improvised_objects_of_feast_and_house_turned_into_weapons" => "sacred_combat_host_battle_siege",
  "kin_rescue_that_turns_the_battle" => "sacred_combat_host_battle_siege",
  "landscape_altered_to_mark_a_raid_route" => "sacred_combat_host_battle_siege",
  "maiden_accompanies_raiders_and_dies_in_battle" => "sacred_combat_host_battle_siege",
  "martial_defense_of_bride_and_sacred_object" => "sacred_combat_host_battle_siege",
  "mobile_fortress_assault" => "sacred_combat_host_battle_siege",
  "mountain_stronghold_overcome_by_concealed_night_ambush" => "sacred_combat_host_battle_siege",
  "noncombatant_drawn_into_battle" => "sacred_combat_host_battle_siege",
  "one_day_war_ending_at_sunset" => "sacred_combat_host_battle_siege",
  "queen_led_foray_and_triumph" => "sacred_combat_host_battle_siege",
  "recognition_catalogue_of_warriors" => "sacred_combat_host_battle_siege",
  "refuge_from_weapons_and_battle" => "sacred_combat_host_battle_siege",
  "rescue_of_an_imperiled_comrade_by_shielded_companions" => "sacred_combat_host_battle_siege",
  "routed_forces_rallied_for_renewed_assault" => "sacred_combat_host_battle_siege",
  "royal_war_sally_after_champions_are_slain" => "sacred_combat_host_battle_siege",
  "seven_leaders_against_seven_gates" => "sacred_combat_host_battle_siege",
  "shamed_warriors_storm_a_fortress_after_reproach" => "sacred_combat_host_battle_siege",
  "siege_assault_under_shield_cover" => "sacred_combat_host_battle_siege",
  "siege_tower_destroyed_by_fire" => "sacred_combat_host_battle_siege",
  "slaughter_of_grouped_royal_kin" => "sacred_combat_host_battle_siege",
  "small_advance_party_attacks_before_the_main_host" => "sacred_combat_host_battle_siege",
  "small_champion_band_withstands_larger_force_through_skill" => "sacred_combat_host_battle_siege",
  "small_gap_becomes_rout_of_a_larger_formation" => "sacred_combat_host_battle_siege",
  "small_war_band_inflicts_disproportionate_losses_before_annihilation" => "sacred_combat_host_battle_siege",
  "son_follows_father_to_war_and_dies_far_from_home" => "sacred_combat_host_battle_siege",
  "storming_and_sacking_of_a_fortified_hold" => "sacred_combat_host_battle_siege",
  "threat_of_total_destruction_of_enemy_city" => "sacred_combat_host_battle_siege",
  "threatened_destruction_of_a_city_by_fire" => "sacred_combat_host_battle_siege",
  "threatened_destruction_of_a_city_by_fire_and_slaughter" => "sacred_combat_host_battle_siege",
  "threefold_escalation_of_victories_and_restitution" => "sacred_combat_host_battle_siege",
  "uprooted_tree_as_heroic_battle_weapon" => "sacred_combat_host_battle_siege",
  "war_band_of_lovers_and_beloveds" => "sacred_combat_host_battle_siege",
  "war_engine_defeated_by_hidden_pitfall" => "sacred_combat_host_battle_siege",
  "war_leader_queen_lays_waste_and_executes_captives" => "sacred_combat_host_battle_siege",
  "warrior_band_destroyed_while_its_leader_survives_wounded" => "sacred_combat_host_battle_siege",
  "warriors_using_trees_and_rocks_as_weapons" => "sacred_combat_host_battle_siege",
  "weaponized_war_chariot_massacre" => "sacred_combat_host_battle_siege",
  "wild_mountain_people_against_town_builders" => "sacred_combat_host_battle_siege",
  "youthful_war_band_attempts_rescue_and_is_annihilated" => "sacred_combat_host_battle_siege",
  "religion_established_by_the_sword" => "sacred_combat_host_battle_siege"
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
  family = freq.fetch("canonical_motifs").find { |g| g["canonical_motif_id"] == "sacred_combat" }
  motifs = family.fetch("mapped_motifs").map { |m| m["motif_id"] }

  bins = Hash.new { |h, k| h[k] = [] }
  unbinned = []

  motifs.each do |motif_id|
    bin = bin_motif_by_regex(motif_id) || MANUAL[motif_id]
    if bin
      bins[bin] << motif_id
    else
      unbinned << motif_id
    end
  end

  output = {
    "generated_on" => Date.today.iso8601,
    "family" => "sacred_combat",
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

  puts "Sacred Combat sub-family binning"
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
    puts "Unbinned motifs (first 30):"
    unbinned.first(30).each { |m| puts "  #{m}" }
    puts "  ... +#{unbinned.length - 30} more" if unbinned.length > 30
  end

  puts ""
  puts "Wrote #{OUTPUT_PATH.sub(ROOT + '/', '')}"
end

main if $PROGRAM_NAME == __FILE__
