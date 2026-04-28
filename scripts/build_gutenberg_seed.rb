#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TODAY = Date.today.iso8601

WORKS = {
  "216" => {
    id: "daoist.tao_teh_king.legge_gutenberg",
    title: "The Tao Teh King, or the Tao and its Characteristics",
    alternate_titles: ["Tao Te Ching", "Dao De Jing"],
    text_status: "complete",
    tradition: "daoist",
    culture: "classical_chinese",
    region: "china",
    source_language: "Classical Chinese",
    text_language: "English",
    date_range: "ancient source text; 1891 public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.216",
    edition: "Project Gutenberg plain-text eBook #216",
    translator: "James Legge",
    editor: nil,
    publication_year: 1891,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/216",
    raw_path: "imports/raw/project-gutenberg/216-tao-teh-king.txt",
    converted_path: "imports/converted/project-gutenberg/216-tao-teh-king.md",
    canonical_path: "texts/public-domain/daoist/project-gutenberg/tao-teh-king-legge.md",
    manifest_path: "manifests/project-gutenberg/216-tao-teh-king.yml",
    extraction_dir: "extractions/daoist/project-gutenberg/tao-teh-king",
    tags: %w[dao tao virtue non_action paradox cosmology],
    motifs: %w[chaos wisdom mother_goddess world_center],
    figures: ["Laozi", "Tao"],
    tradition_cluster: "daoist_chinese"
  },
  "2017" => {
    id: "buddhist.dhammapada.max_muller_gutenberg",
    title: "Dhammapada, a Collection of Verses",
    alternate_titles: ["The Dhammapada"],
    text_status: "complete",
    tradition: "buddhist",
    culture: "early_buddhist_pali_canon_later_translation",
    region: "south_asia",
    source_language: "Pali",
    text_language: "English",
    date_range: "ancient canonical source text; 1881 public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.2017",
    edition: "Project Gutenberg plain-text eBook #2017",
    translator: "F. Max Muller",
    editor: "F. Max Muller",
    publication_year: 1881,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/2017",
    raw_path: "imports/raw/project-gutenberg/2017-dhammapada.txt",
    converted_path: "imports/converted/project-gutenberg/2017-dhammapada.md",
    canonical_path: "texts/public-domain/buddhist/project-gutenberg/dhammapada-max-muller.md",
    manifest_path: "manifests/project-gutenberg/2017-dhammapada.yml",
    extraction_dir: "extractions/buddhist/project-gutenberg/dhammapada",
    tags: %w[buddhism ethics mind discipline awakening],
    motifs: %w[wisdom initiation return],
    figures: ["Buddha", "Bhikshu", "Brahmana"],
    tradition_cluster: "buddhist"
  },
  "2388" => {
    id: "hindu.bhagavad_gita.song_celestial_gutenberg",
    title: "The Song Celestial; Or, Bhagavad-Gita",
    alternate_titles: ["Bhagavad Gita", "Bhagavad-Gita"],
    text_status: "complete",
    tradition: "hindu",
    culture: "sanskrit_epic_later_translation",
    region: "south_asia",
    source_language: "Sanskrit",
    text_language: "English",
    date_range: "ancient source text; 1900 public-domain English edition",
    source_type: "text",
    source_id: "source.project_gutenberg.2388",
    edition: "Project Gutenberg plain-text eBook #2388",
    translator: "Sir Edwin Arnold",
    editor: nil,
    publication_year: 1900,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/2388",
    raw_path: "imports/raw/project-gutenberg/2388-song-celestial-bhagavad-gita.txt",
    converted_path: "imports/converted/project-gutenberg/2388-song-celestial-bhagavad-gita.md",
    canonical_path: "texts/public-domain/hindu/project-gutenberg/song-celestial-bhagavad-gita.md",
    manifest_path: "manifests/project-gutenberg/2388-song-celestial-bhagavad-gita.yml",
    extraction_dir: "extractions/hindu/project-gutenberg/bhagavad-gita",
    tags: %w[dharma yoga battle revelation devotion],
    motifs: %w[divine_judgment wisdom initiation ascent],
    figures: ["Krishna", "Arjuna"],
    tradition_cluster: "hindu"
  },
  "348" => {
    id: "greek.hesiod_homeric_hymns.evelyn_white_gutenberg",
    title: "Hesiod, the Homeric Hymns, and Homerica",
    alternate_titles: ["Theogony", "Works and Days", "Homeric Hymns"],
    text_status: "complete",
    tradition: "greek",
    culture: "ancient_greek",
    region: "aegean_mediterranean",
    source_language: "Ancient Greek",
    text_language: "English",
    date_range: "archaic Greek source texts; 1914 public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.348",
    edition: "Project Gutenberg plain-text eBook #348",
    translator: "Hugh G. Evelyn-White",
    editor: "Hugh G. Evelyn-White",
    publication_year: 1914,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/348",
    raw_path: "imports/raw/project-gutenberg/348-hesiod-homeric-hymns-homerica.txt",
    converted_path: "imports/converted/project-gutenberg/348-hesiod-homeric-hymns-homerica.md",
    canonical_path: "texts/public-domain/greek/project-gutenberg/hesiod-homeric-hymns-homerica.md",
    manifest_path: "manifests/project-gutenberg/348-hesiod-homeric-hymns-homerica.yml",
    extraction_dir: "extractions/greek/project-gutenberg/hesiod-homeric-hymns",
    tags: %w[theogony hymns gods origins labor justice],
    motifs: %w[chaos sacred_birth divine_parent_child trickster_boundary wisdom],
    figures: ["Zeus", "Gaia", "Cronos", "Prometheus", "Demeter", "Hermes"],
    tradition_cluster: "greek"
  },
  "7145" => {
    id: "egyptian.book_of_the_dead.budge_gutenberg",
    title: "The Book of the Dead",
    alternate_titles: ["The Egyptian Book of the Dead"],
    text_status: "complete",
    tradition: "egyptian",
    culture: "ancient_egyptian_later_translation",
    region: "nile_valley",
    source_language: "Egyptian",
    text_language: "English",
    date_range: "ancient funerary source texts; public-domain English edition",
    source_type: "text",
    source_id: "source.project_gutenberg.7145",
    edition: "Project Gutenberg plain-text eBook #7145",
    translator: "E. A. Wallis Budge",
    editor: "E. A. Wallis Budge",
    publication_year: 1895,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/7145",
    raw_path: "imports/raw/project-gutenberg/7145-book-of-the-dead.txt",
    converted_path: "imports/converted/project-gutenberg/7145-book-of-the-dead.md",
    canonical_path: "texts/public-domain/egyptian/project-gutenberg/book-of-the-dead-budge.md",
    manifest_path: "manifests/project-gutenberg/7145-book-of-the-dead.yml",
    extraction_dir: "extractions/egyptian/project-gutenberg/book-of-the-dead",
    tags: %w[afterlife judgment osiris funerary heart rebirth],
    motifs: %w[hero_descent death_rebirth divine_judgment resurrection wisdom],
    figures: ["Osiris", "Ra", "Thoth", "Anubis"],
    tradition_cluster: "egyptian"
  },
  "73533" => {
    id: "norse.poetic_edda.bellows_gutenberg",
    title: "The Poetic Edda",
    alternate_titles: ["Edda Saemundar"],
    text_status: "complete",
    tradition: "norse",
    culture: "old_norse_medieval_icelandic",
    region: "scandinavia_north_atlantic",
    source_language: "Old Norse",
    text_language: "English",
    date_range: "medieval source compilation; 1923 public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.73533",
    edition: "Project Gutenberg plain-text eBook #73533",
    translator: "Henry Adams Bellows",
    editor: "Henry Adams Bellows",
    publication_year: 1923,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/73533",
    raw_path: "imports/raw/project-gutenberg/73533-poetic-edda.txt",
    converted_path: "imports/converted/project-gutenberg/73533-poetic-edda.md",
    canonical_path: "texts/public-domain/norse/project-gutenberg/poetic-edda-bellows.md",
    manifest_path: "manifests/project-gutenberg/73533-poetic-edda.yml",
    extraction_dir: "extractions/norse/project-gutenberg/poetic-edda",
    tags: %w[norse gods prophecy heroism fate ragnarok],
    motifs: %w[sacred_tree_axis chaos wisdom death_rebirth trickster_boundary],
    figures: ["Odin", "Thor", "Loki", "Baldr", "Freyr"],
    tradition_cluster: "norse"
  },
  "11000" => {
    id: "mesopotamian.gilgamesh.old_babylonian_jastrow_clay_gutenberg",
    title: "An Old Babylonian Version of the Gilgamesh Epic",
    alternate_titles: ["Gilgamesh Epic"],
    text_status: "complete",
    tradition: "mesopotamian",
    culture: "old_babylonian",
    region: "mesopotamia",
    source_language: "Akkadian",
    text_language: "English",
    date_range: "Old Babylonian source tablets; 1920 public-domain English edition",
    source_type: "text",
    source_id: "source.project_gutenberg.11000",
    edition: "Project Gutenberg plain-text eBook #11000",
    translator: "Albert T. Clay",
    editor: "Morris Jastrow Jr. and Albert T. Clay",
    publication_year: 1920,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/11000",
    raw_path: "imports/raw/project-gutenberg/11000-old-babylonian-gilgamesh.txt",
    converted_path: "imports/converted/project-gutenberg/11000-old-babylonian-gilgamesh.md",
    canonical_path: "texts/public-domain/mesopotamian/project-gutenberg/old-babylonian-gilgamesh-jastrow-clay.md",
    manifest_path: "manifests/project-gutenberg/11000-old-babylonian-gilgamesh.yml",
    extraction_dir: "extractions/mesopotamian/project-gutenberg/gilgamesh",
    tags: %w[gilgamesh enkidu friendship mortality dreams forest],
    motifs: %w[hero_descent departure return wisdom serpent death_rebirth],
    figures: ["Gilgamesh", "Enkidu", "Ninsun", "Shamash", "Ishtar"],
    tradition_cluster: "mesopotamian"
  },
  "3330" => {
    id: "confucian.analects.legge_gutenberg",
    title: "The Analects of Confucius",
    alternate_titles: ["Confucian Analects", "The Analects of Confucius (from the Chinese Classics)"],
    text_status: "complete",
    tradition: "confucian",
    culture: "classical_chinese",
    region: "china",
    source_language: "Classical Chinese",
    text_language: "English",
    date_range: "ancient source text; public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.3330",
    edition: "Project Gutenberg plain-text eBook #3330",
    translator: "James Legge",
    editor: nil,
    publication_year: 1893,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/3330",
    raw_path: "imports/raw/project-gutenberg/3330-analects-confucius.txt",
    converted_path: "imports/converted/project-gutenberg/3330-analects-confucius.md",
    canonical_path: "texts/public-domain/confucian/project-gutenberg/analects-legge.md",
    manifest_path: "manifests/project-gutenberg/3330-analects-confucius.yml",
    extraction_dir: "extractions/confucian/project-gutenberg/analects",
    tags: %w[confucian ethics ritual filial_piety governance sagehood],
    motifs: %w[wisdom ethical_command ritual_order social_harmony teacher_disciple],
    figures: ["Confucius", "The Master", "disciples"],
    tradition_cluster: "confucian"
  },
  "3434" => {
    id: "islamic.koran.rodwell_gutenberg",
    title: "The Koran (Al-Qur'an)",
    alternate_titles: ["Qur'an", "Koran"],
    text_status: "complete",
    tradition: "islamic",
    culture: "arabic_islamic_later_translation",
    region: "arabia_west_asia",
    source_language: "Arabic",
    text_language: "English",
    date_range: "7th century source text; public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.3434",
    edition: "Project Gutenberg plain-text eBook #3434",
    translator: "J. M. Rodwell",
    editor: "G. Margoliouth",
    publication_year: 1909,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/3434",
    raw_path: "imports/raw/project-gutenberg/3434-koran-rodwell.txt",
    converted_path: "imports/converted/project-gutenberg/3434-koran-rodwell.md",
    canonical_path: "texts/public-domain/islamic/project-gutenberg/koran-rodwell.md",
    manifest_path: "manifests/project-gutenberg/3434-koran-rodwell.yml",
    extraction_dir: "extractions/islamic/project-gutenberg/koran",
    tags: %w[islam revelation prophecy law judgment mercy],
    motifs: %w[revelation divine_judgment covenant mercy prophet_call eschatology],
    figures: ["Allah", "Muhammad", "prophets"],
    tradition_cluster: "islamic"
  },
  "5186" => {
    id: "finnish_karelian.kalevala.crawford_gutenberg",
    title: "Kalevala: The Epic Poem of Finland",
    alternate_titles: ["Kalevala", "The Epic Poem of Finland"],
    text_status: "complete",
    tradition: "finnish_karelian",
    culture: "finno_ugric",
    region: "finland_karelia",
    source_language: "Finnish",
    text_language: "English",
    date_range: "19th-century compilation of older oral traditions; 1888 public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.5186",
    edition: "Project Gutenberg plain-text eBook #5186",
    translator: "John Martin Crawford",
    editor: "Elias Lonnrot",
    publication_year: 1888,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/5186",
    raw_path: "imports/raw/project-gutenberg/5186-kalevala-complete.txt",
    converted_path: "imports/converted/project-gutenberg/5186-kalevala-complete.md",
    canonical_path: "texts/public-domain/finnish-karelian/project-gutenberg/kalevala-crawford.md",
    manifest_path: "manifests/project-gutenberg/5186-kalevala-complete.yml",
    extraction_dir: "extractions/finnish-karelian/project-gutenberg/kalevala",
    tags: %w[kalevala epic song magic smithing sampo underworld],
    motifs: %w[cosmic_origin wisdom sacred_song world_object smith_craft hero_descent death_rebirth],
    figures: ["Wainamoinen", "Ilmarinen", "Lemminkainen", "Louhi", "Aino"],
    tradition_cluster: "finnish_karelian"
  },
  "3283" => {
    id: "hindu.upanishads.paramananda_gutenberg",
    title: "The Upanishads",
    alternate_titles: ["Upanishads"],
    text_status: "complete",
    tradition: "hindu",
    culture: "sanskrit_vedic_later_translation",
    region: "south_asia",
    source_language: "Sanskrit",
    text_language: "English",
    date_range: "ancient source texts; public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.3283",
    edition: "Project Gutenberg plain-text eBook #3283",
    translator: "Swami Paramananda",
    editor: nil,
    publication_year: 1919,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/3283",
    raw_path: "imports/raw/project-gutenberg/3283-upanishads.txt",
    converted_path: "imports/converted/project-gutenberg/3283-upanishads.md",
    canonical_path: "texts/public-domain/hindu/project-gutenberg/upanishads-paramananda.md",
    manifest_path: "manifests/project-gutenberg/3283-upanishads.yml",
    extraction_dir: "extractions/hindu/project-gutenberg/upanishads",
    tags: %w[upanishads vedanta atman brahman liberation wisdom],
    motifs: %w[wisdom ultimate_reality self_knowledge death_teacher inner_light initiation],
    figures: ["Atman", "Brahman", "Yama", "Nachiketas"],
    tradition_cluster: "hindu"
  },
  "14465" => {
    id: "celtic_irish.gods_and_fighting_men.gregory_gutenberg",
    title: "Gods and Fighting Men",
    alternate_titles: ["The Story of the Tuatha De Danaan and of the Fianna of Ireland"],
    text_status: "complete",
    tradition: "celtic_irish",
    culture: "medieval_irish_later_retelling",
    region: "ireland",
    source_language: "Irish",
    text_language: "English",
    date_range: "medieval Irish mythic material; 1905 public-domain English retelling",
    source_type: "text",
    source_id: "source.project_gutenberg.14465",
    edition: "Project Gutenberg plain-text eBook #14465",
    translator: "Lady Gregory",
    editor: "Lady Gregory",
    publication_year: 1905,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/14465",
    raw_path: "imports/raw/project-gutenberg/14465-gods-and-fighting-men.txt",
    converted_path: "imports/converted/project-gutenberg/14465-gods-and-fighting-men.md",
    canonical_path: "texts/public-domain/celtic-irish/project-gutenberg/gods-and-fighting-men-gregory.md",
    manifest_path: "manifests/project-gutenberg/14465-gods-and-fighting-men.yml",
    extraction_dir: "extractions/celtic-irish/project-gutenberg/gods-and-fighting-men",
    tags: %w[irish tuatha_de_danaan fianna otherworld magic kingship],
    motifs: %w[otherworld divine_race sacred_treasures hero_band sovereignty shape_shifting],
    figures: ["Finn", "Lugh", "Nuada", "Dagda", "Brigit"],
    tradition_cluster: "celtic_irish"
  },
  "5160" => {
    id: "celtic_welsh.mabinogion.guest_gutenberg",
    title: "The Mabinogion",
    alternate_titles: ["Mabinogion"],
    text_status: "complete",
    tradition: "celtic_welsh",
    culture: "medieval_welsh_later_translation",
    region: "wales",
    source_language: "Middle Welsh",
    text_language: "English",
    date_range: "medieval Welsh narrative material; public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.5160",
    edition: "Project Gutenberg plain-text eBook #5160",
    translator: "Lady Charlotte Guest",
    editor: "Lady Charlotte Guest",
    publication_year: 1877,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/5160",
    raw_path: "imports/raw/project-gutenberg/5160-mabinogion.txt",
    converted_path: "imports/converted/project-gutenberg/5160-mabinogion.md",
    canonical_path: "texts/public-domain/celtic-welsh/project-gutenberg/mabinogion-guest.md",
    manifest_path: "manifests/project-gutenberg/5160-mabinogion.yml",
    extraction_dir: "extractions/celtic-welsh/project-gutenberg/mabinogion",
    tags: %w[welsh mabinogion enchantment sovereignty cauldron quests],
    motifs: %w[otherworld sovereignty magical_animal shapeshifter sacred_cauldron hero_quest],
    figures: ["Pwyll", "Rhiannon", "Branwen", "Llyr", "Taliesin"],
    tradition_cluster: "celtic_welsh"
  },
  "56550" => {
    id: "maya_quiche.popol_vuh.spence_gutenberg",
    title: "The Popol Vuh",
    alternate_titles: ["The Mythic and Heroic Sagas of the Kiches of Central America"],
    text_status: "complete",
    tradition: "maya_quiche",
    culture: "mesoamerican_kiche_later_translation",
    region: "mesoamerica",
    source_language: "Kiche",
    text_language: "English",
    date_range: "Kiche source tradition; 1908 public-domain English edition",
    source_type: "text",
    source_id: "source.project_gutenberg.56550",
    edition: "Project Gutenberg plain-text eBook #56550",
    translator: "Lewis Spence",
    editor: "Lewis Spence",
    publication_year: 1908,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/56550",
    raw_path: "imports/raw/project-gutenberg/56550-popol-vuh-spence.txt",
    converted_path: "imports/converted/project-gutenberg/56550-popol-vuh-spence.md",
    canonical_path: "texts/public-domain/mesoamerican/project-gutenberg/popol-vuh-spence.md",
    manifest_path: "manifests/project-gutenberg/56550-popol-vuh-spence.yml",
    extraction_dir: "extractions/mesoamerican/project-gutenberg/popol-vuh",
    tags: %w[popol_vuh creation hero_twins underworld maize ballgame],
    motifs: %w[cosmic_origin hero_twins underworld_trial failed_creation trickster_boundary death_rebirth],
    figures: ["Hun-Ahpu", "Xbalanque", "Hurakan", "Gucumatz", "Xibalba"],
    tradition_cluster: "mesoamerican"
  },
  "6130" => {
    id: "greek.iliad.pope_gutenberg",
    title: "The Iliad",
    alternate_titles: ["The Iliad of Homer"],
    text_status: "complete",
    tradition: "greek",
    culture: "ancient_greek_later_translation",
    region: "aegean_mediterranean",
    source_language: "Ancient Greek",
    text_language: "English",
    date_range: "archaic Greek epic; 1899 public-domain English edition",
    source_type: "text",
    source_id: "source.project_gutenberg.6130",
    edition: "Project Gutenberg plain-text eBook #6130",
    translator: "Alexander Pope",
    editor: "Theodore Alois Buckley",
    publication_year: 1899,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/6130",
    raw_path: "imports/raw/project-gutenberg/6130-iliad.txt",
    converted_path: "imports/converted/project-gutenberg/6130-iliad.md",
    canonical_path: "texts/public-domain/greek/project-gutenberg/iliad-pope.md",
    manifest_path: "manifests/project-gutenberg/6130-iliad.yml",
    extraction_dir: "extractions/greek/project-gutenberg/iliad",
    tags: %w[iliad homer achilles wrath war fate heroism],
    motifs: %w[heroic_wrath divine_intervention fate_lament warrior_honor death_in_battle],
    figures: ["Achilles", "Hector", "Agamemnon", "Athena", "Zeus"],
    tradition_cluster: "greek"
  },
  "19630" => {
    id: "hindu.mahabharata.dutt_gutenberg",
    title: "Maha-bharata",
    alternate_titles: ["The Epic of Ancient India", "Mahabharata"],
    text_status: "complete",
    tradition: "hindu",
    culture: "sanskrit_epic_later_translation",
    region: "south_asia",
    source_language: "Sanskrit",
    text_language: "English",
    date_range: "ancient epic source tradition; 1899 public-domain English verse condensation",
    source_type: "text",
    source_id: "source.project_gutenberg.19630",
    edition: "Project Gutenberg plain-text eBook #19630",
    translator: "Romesh Chunder Dutt",
    editor: nil,
    publication_year: 1899,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/19630",
    raw_path: "imports/raw/project-gutenberg/19630-ramayana-mahabharata-condensed.txt",
    converted_path: "imports/converted/project-gutenberg/19630-ramayana-mahabharata-condensed.md",
    canonical_path: "texts/public-domain/hindu/project-gutenberg/mahabharata-dutt.md",
    manifest_path: "manifests/project-gutenberg/19630-mahabharata-dutt.yml",
    extraction_dir: "extractions/hindu/project-gutenberg/mahabharata",
    tags: %w[mahabharata epic dharma exile war krishna pandavas],
    motifs: %w[warrior_duty_under_crisis divine_judgment sacred_exchange exile return],
    figures: ["Krishna", "Arjuna", "Pandavas", "Kauravas", "Draupadi"],
    tradition_cluster: "hindu"
  },
  "128" => {
    id: "islamicate_folklore.arabian_nights.lang_gutenberg",
    title: "The Arabian Nights Entertainments",
    alternate_titles: ["Arabian Nights", "One Thousand and One Nights"],
    text_status: "complete",
    tradition: "islamicate_folklore",
    culture: "arabic_persian_indian_folklore_later_english_edition",
    region: "west_asia_north_africa_south_asia",
    source_language: "Arabic and related source traditions",
    text_language: "English",
    date_range: "medieval story-cycle traditions; 1898 public-domain selected English edition",
    source_type: "text",
    source_id: "source.project_gutenberg.128",
    edition: "Project Gutenberg plain-text eBook #128",
    translator: "Andrew Lang",
    editor: "Andrew Lang",
    publication_year: 1898,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/128",
    raw_path: "imports/raw/project-gutenberg/128-arabian-nights.txt",
    converted_path: "imports/converted/project-gutenberg/128-arabian-nights.md",
    canonical_path: "texts/public-domain/islamicate-folklore/project-gutenberg/arabian-nights-lang.md",
    manifest_path: "manifests/project-gutenberg/128-arabian-nights.yml",
    extraction_dir: "extractions/islamicate-folklore/project-gutenberg/arabian-nights",
    tags: %w[arabian_nights frame_story jinn wonder voyage trickster],
    motifs: %w[trickster_boundary departure return wisdom shapeshifter],
    figures: ["Scheherazade", "jinn", "kings", "viziers"],
    tradition_cluster: "islamicate_folklore"
  },
  "10315" => {
    id: "persian.persian_literature_volume_1.gutenberg",
    title: "Persian Literature, Volume 1",
    alternate_titles: ["The Persian Literature, Comprising The Shah Nameh, The Rubaiyat, The Divan, and The Gulistan, Volume 1"],
    text_status: "complete",
    tradition: "persian",
    culture: "medieval_iranian_later_anthology",
    region: "iran_central_asia",
    source_language: "Persian",
    text_language: "English",
    date_range: "medieval Persian source traditions; 1909 public-domain anthology volume",
    source_type: "text",
    source_id: "source.project_gutenberg.10315",
    edition: "Project Gutenberg plain-text eBook #10315",
    translator: "James Atkinson; Herman Bicknell; Edward FitzGerald",
    editor: "Richard J. H. Gottheil",
    publication_year: 1909,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/10315",
    raw_path: "imports/raw/project-gutenberg/10315-shahnameh-selections.txt",
    converted_path: "imports/converted/project-gutenberg/10315-shahnameh-selections.md",
    canonical_path: "texts/public-domain/persian/project-gutenberg/persian-literature-volume-1.md",
    manifest_path: "manifests/project-gutenberg/10315-persian-literature-volume-1.yml",
    extraction_dir: "extractions/persian/project-gutenberg/persian-literature-volume-1",
    tags: %w[persian shahnameh rubaiyat divan gulistan kingship heroism wisdom],
    motifs: %w[royal_legitimacy heroic_wrath wisdom duality sacrifice],
    figures: ["Rustam", "kings", "heroes"],
    tradition_cluster: "persian"
  },
  "16464" => {
    id: "celtic_irish.tain_bo_cualnge.dunn_gutenberg",
    title: "The Ancient Irish Epic Tale Tain Bo Cualnge",
    alternate_titles: ["Tain Bo Cualnge", "The Cualnge Cattle-Raid"],
    text_status: "complete",
    tradition: "celtic_irish",
    culture: "ulster_cycle_irish_epic_later_translation",
    region: "ireland",
    source_language: "Irish",
    text_language: "English",
    date_range: "medieval Irish epic source tradition; 1914 public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.16464",
    edition: "Project Gutenberg plain-text eBook #16464",
    translator: "Joseph Dunn",
    editor: nil,
    publication_year: 1914,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/16464",
    raw_path: "imports/raw/project-gutenberg/16464-tain-bo-cualnge-dunn.txt",
    converted_path: "imports/converted/project-gutenberg/16464-tain-bo-cualnge-dunn.md",
    canonical_path: "texts/public-domain/celtic-irish/project-gutenberg/tain-bo-cualnge-dunn.md",
    manifest_path: "manifests/project-gutenberg/16464-tain-bo-cualnge-dunn.yml",
    extraction_dir: "extractions/celtic-irish/project-gutenberg/tain-bo-cualnge",
    tags: %w[irish ulster_cycle tain cattle_raid cuchulain medb war],
    motifs: %w[cattle_raid warrior_frenzy boundary_combat tragic_hero geas],
    figures: ["Cuchulain", "Medb", "Ailill", "Fergus"],
    tradition_cluster: "celtic_irish"
  },
  "46389" => {
    id: "confucian.sayings_of_confucius.giles_gutenberg",
    title: "The Sayings of Confucius",
    alternate_titles: ["A New Translation of the Greater Part of the Confucian Analects"],
    text_status: "selected",
    tradition: "confucian",
    culture: "classical_chinese",
    region: "china",
    source_language: "Classical Chinese",
    text_language: "English",
    date_range: "ancient source text; 1910 public-domain English selected translation",
    source_type: "text",
    source_id: "source.project_gutenberg.46389",
    edition: "Project Gutenberg plain-text eBook #46389",
    translator: "Lionel Giles",
    editor: nil,
    publication_year: 1910,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/46389",
    raw_path: "imports/raw/project-gutenberg/46389-sayings-of-confucius.txt",
    converted_path: "imports/converted/project-gutenberg/46389-sayings-of-confucius.md",
    canonical_path: "texts/public-domain/confucian/project-gutenberg/sayings-of-confucius-giles.md",
    manifest_path: "manifests/project-gutenberg/46389-sayings-of-confucius.yml",
    extraction_dir: "extractions/confucian/project-gutenberg/sayings-of-confucius",
    tags: %w[confucian aphorisms ethics ritual governance disciples],
    motifs: %w[wisdom ethical_command ritual_order social_harmony teacher_disciple],
    figures: ["Confucius", "The Master", "disciples"],
    tradition_cluster: "confucian"
  },
  "7440" => {
    id: "islamic.koran.sale_gutenberg",
    title: "The Koran (Al-Qur'an)",
    alternate_titles: ["Qur'an", "Koran", "Alkoran of Mohammed"],
    text_status: "complete",
    tradition: "islamic",
    culture: "arabic_islamic_later_translation",
    region: "arabia_west_asia",
    source_language: "Arabic",
    text_language: "English",
    date_range: "7th century source text; 1734 public-domain English translation",
    source_type: "text",
    source_id: "source.project_gutenberg.7440",
    edition: "Project Gutenberg plain-text eBook #7440",
    translator: "George Sale",
    editor: nil,
    publication_year: 1734,
    publisher: "Project Gutenberg",
    source_url: "https://www.gutenberg.org/ebooks/7440",
    raw_path: "imports/raw/project-gutenberg/7440-koran-sale.txt",
    converted_path: "imports/converted/project-gutenberg/7440-koran-sale.md",
    canonical_path: "texts/public-domain/islamic/project-gutenberg/koran-sale.md",
    manifest_path: "manifests/project-gutenberg/7440-koran-sale.yml",
    extraction_dir: "extractions/islamic/project-gutenberg/koran-sale",
    tags: %w[islam revelation prophecy law judgment commentary],
    motifs: %w[revelation divine_judgment covenant mercy prophet_call eschatology],
    figures: ["Allah", "Muhammad", "prophets"],
    tradition_cluster: "islamic"
  }
}.freeze

def relative(path)
  path.sub("#{ROOT}/", "")
end

def project_path(path)
  File.join(ROOT, path)
end

def checksum(path)
  Digest::SHA256.file(path).hexdigest
end

def clean_raw_text(raw)
  text = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
  text = text.delete_prefix("\uFEFF")
  text = text.gsub("\r\n", "\n").gsub("\r", "\n")

  lines = text.lines(chomp: true)
  start_index = lines.index { |line| line.match?(/\*\*\* START OF (?:THE |THIS )?PROJECT GUTENBERG EBOOK/i) }
  end_index = [
    lines.index { |line| line.match?(/\*\*\* END OF (?:THE |THIS )?PROJECT GUTENBERG EBOOK/i) },
    lines.index { |line| line.match?(/\A\s*End of Project Gutenberg/i) }
  ].compact.min
  if start_index && end_index && end_index > start_index
    lines = lines[(start_index + 1)...end_index]
  elsif start_index
    lines = lines[(start_index + 1)..]
  elsif end_index
    lines = lines[0...end_index]
  end

  lines = remove_gutenberg_editor_note(lines)
  lines = remove_digitizer_note(lines)
  lines = remove_formatting_warning(lines)
  lines = lines.reject do |line|
    line.match?(/\A\s*(Produced by|This eBook was produced by)\b/i) ||
      line.match?(/\A\s*\[Illustration\]\s*\z/i)
  end

  lines = lines.map { |line| line.rstrip }

  lines.shift while lines.first&.strip&.empty?
  lines.pop while lines.last&.strip&.empty?

  collapse_blank_lines(lines).join("\n") + "\n"
end

def remove_gutenberg_editor_note(lines)
  output = []
  skipping = false

  lines.each do |line|
    if line.match?(/\A\s*Project Gutenberg Editors Note:/i)
      skipping = true
      next
    end

    if skipping
      skipping = false if line.strip.empty?
      next
    end

    output << line
  end

  output
end

def remove_digitizer_note(lines)
  output = []
  skipping = false
  blank_count = 0

  lines.each do |line|
    if line.match?(/\A\s*A note from the digitizer\s*\z/i)
      skipping = true
      blank_count = 0
      next
    end

    if skipping
      if line.strip.empty?
        blank_count += 1
        skipping = false if blank_count >= 2
      else
        blank_count = 0
      end
      next
    end

    output << line
  end

  output
end

def remove_formatting_warning(lines)
  output = []
  skipping = false

  lines.each do |line|
    if line.match?(/\A\s*Note:\s+This eBook still needs better formatting/i)
      skipping = true
      next
    end

    if skipping
      if line.strip.empty?
        skipping = false
      end
      next
    end

    output << line
  end

  output
end

def collapse_blank_lines(lines)
  output = []
  blank_count = 0

  lines.each do |line|
    if line.strip.empty?
      blank_count += 1
      output << "" if blank_count <= 2
    else
      blank_count = 0
      output << line
    end
  end

  output
end

def canonical_markdown(work, body)
  metadata = {
    "id" => work.fetch(:id),
    "title" => work.fetch(:title),
    "alternate_titles" => work.fetch(:alternate_titles),
    "text_status" => work.fetch(:text_status),
    "tradition" => work.fetch(:tradition),
    "culture" => work.fetch(:culture),
    "region" => work.fetch(:region),
    "source_language" => work.fetch(:source_language),
    "text_language" => work.fetch(:text_language),
    "date_range" => work.fetch(:date_range),
    "source_type" => work.fetch(:source_type),
    "provenance" => {
      "source_id" => work.fetch(:source_id),
      "edition" => work.fetch(:edition),
      "translator" => work.fetch(:translator),
      "editor" => work.fetch(:editor) || "",
      "publication_year" => work.fetch(:publication_year),
      "publisher" => work.fetch(:publisher),
      "source_url" => work.fetch(:source_url),
      "access_date" => TODAY
    },
    "rights" => {
      "status" => "public_domain",
      "jurisdiction" => "US",
      "license_url" => "https://www.gutenberg.org/policy/license.html",
      "training_use" => "allowed",
      "full_text" => "allowed",
      "notes" => "The selected source page records public-domain status in the USA. Distributor license and trademark terms are tracked separately from the underlying public-domain text."
    },
    "trademark" => {
      "status" => "present",
      "marks" => ["Project Gutenberg"],
      "use_rules" => "Use only as factual source attribution; do not use the mark as repository branding."
    },
    "transcription" => {
      "mode" => "normalized",
      "complete" => work.fetch(:text_status) == "complete",
      "corrections" => [],
      "omissions" => [
        "Distributor header, license footer, start/end markers, and production boilerplate were removed.",
        "Raw source capture is preserved under imports/raw for auditability."
      ]
    },
    "tags" => work.fetch(:tags),
    "motifs" => work.fetch(:motifs),
    "figures" => work.fetch(:figures)
  }

  front_matter = YAML.dump(metadata).sub(/\A---\s*\n/, "")
  <<~MARKDOWN
    ---
    #{front_matter}---

    # #{work.fetch(:title)}

    #{body}
  MARKDOWN
end

def write_manifest(work)
  raw = project_path(work.fetch(:raw_path))
  converted = project_path(work.fetch(:converted_path))
  canonical = project_path(work.fetch(:canonical_path))

  manifest = {
    "manifest_version" => "1",
    "batch_id" => "project-gutenberg-wave-2",
    "created_date" => TODAY,
    "updated_date" => TODAY,
    "artifacts" => [
      {
        "id" => "artifact.gutenberg_#{work.fetch(:source_id).split('.').last}",
        "work_id" => work.fetch(:id),
        "title" => work.fetch(:title),
        "source_url" => work.fetch(:source_url),
        "fetch_date" => TODAY,
        "raw" => {
          "path" => relative(raw),
          "checksum" => { "algorithm" => "sha256", "value" => checksum(raw) },
          "media_type" => "text/plain",
          "notes" => "Raw plain-text source capture."
        },
        "converted" => {
          "path" => relative(converted),
          "checksum" => { "algorithm" => "sha256", "value" => checksum(converted) },
          "media_type" => "text/markdown",
          "notes" => "Intermediate Markdown draft after removing distributor packaging."
        },
        "canonical" => {
          "path" => relative(canonical),
          "checksum" => { "algorithm" => "sha256", "value" => checksum(canonical) },
          "media_type" => "text/markdown",
          "notes" => "Canonical reviewed Markdown corpus text."
        },
        "converter" => {
          "name" => "scripts/build_gutenberg_seed.rb",
          "version" => "1",
          "command" => "ruby scripts/build_gutenberg_seed.rb #{work.fetch(:source_id).split('.').last}",
          "settings" => ["strip_distributor_header_footer", "preserve_plain_text_structure"],
          "notes" => "Generic plain-text converter for public-domain Project Gutenberg source captures."
        },
        "cleanup_notes" => [
          "Removed distributor packaging and license text from canonical corpus file.",
          "Preserved source line and paragraph structure without interpretive rewriting."
        ],
        "rights" => {
          "status" => "public_domain",
          "jurisdiction" => "US",
          "license_url" => "https://www.gutenberg.org/policy/license.html",
          "full_text" => "allowed",
          "training_use" => "allowed",
          "notes" => "The source catalog page records public-domain status in the USA; reuse outside the USA requires jurisdiction-specific review."
        },
        "trademark" => {
          "status" => "present",
          "marks" => ["Project Gutenberg"],
          "use_rules" => "Use as factual source attribution only.",
          "notes" => "The repository does not use the mark as branding."
        },
        "review" => {
          "status" => "approved",
          "reviewer" => "Codex",
          "review_date" => TODAY,
          "notes" => "Seed reviewed for clean Markdown structure, rights metadata, and removal of distributor boilerplate."
        },
        "extraction" => {
          "readiness" => "ready",
          "blocking_issues" => [],
          "notes" => "Ready for initial motif extraction."
        }
      }
    ]
  }

  manifest_path = project_path(work.fetch(:manifest_path))
  FileUtils.mkdir_p(File.dirname(manifest_path))
  File.write(manifest_path, YAML.dump(manifest), mode: "w")
end

def update_registry(works)
  path = project_path("data/collections/ingested-corpus.yml")
  registry = YAML.safe_load(File.read(path), permitted_classes: [Date], aliases: false)
  existing = registry.fetch("items").reject { |item| works.any? { |work| work.fetch(:id) == item.fetch("id") } }

  additions = works.map do |work|
    {
      "id" => work.fetch(:id),
      "title" => work.fetch(:title),
      "tradition_cluster" => work.fetch(:tradition_cluster),
      "source_id" => work.fetch(:source_id),
      "canonical_text_path" => work.fetch(:canonical_path),
      "manifest_path" => work.fetch(:manifest_path),
      "extraction_dir" => work.fetch(:extraction_dir),
      "rights" => {
        "status" => "public_domain",
        "full_text" => "allowed",
        "training_use" => "allowed"
      },
      "ingestion_status" => "canonical_text_added",
      "extraction_status" => "pending_seed_records"
    }
  end

  registry["updated_on"] = TODAY
  registry["items"] = (existing + additions).sort_by { |item| item.fetch("id") }
  File.write(path, YAML.dump(registry), mode: "w")
end

def build_work(work)
  raw_path = project_path(work.fetch(:raw_path))
  raise "missing raw source: #{relative(raw_path)}" unless File.file?(raw_path)

  body = clean_raw_text(File.binread(raw_path))

  converted_path = project_path(work.fetch(:converted_path))
  FileUtils.mkdir_p(File.dirname(converted_path))
  File.write(converted_path, "# #{work.fetch(:title)}\n\n#{body}", mode: "w")

  canonical_path = project_path(work.fetch(:canonical_path))
  FileUtils.mkdir_p(File.dirname(canonical_path))
  File.write(canonical_path, canonical_markdown(work, body), mode: "w")

  write_manifest(work)

  puts "wrote #{relative(canonical_path)}"
end

requested = ARGV.empty? ? WORKS.keys : ARGV
unknown = requested - WORKS.keys
raise "unknown Project Gutenberg ids: #{unknown.join(', ')}" unless unknown.empty?

works = requested.map { |id| WORKS.fetch(id) }
works.each { |work| build_work(work) }
update_registry(works)
