#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
OUT_YAML = File.join(ROOT, "data/collections/first-500-corpus.yml")
OUT_DOC = File.join(ROOT, "docs/first-500-corpus.md")

items = []

def add_group(items, group, titles)
  titles.each do |title|
    items << {
      "id" => format("first500.%03d", items.length + 1),
      "title" => title,
      "culture_area" => group.fetch(:culture_area),
      "tradition_cluster" => group.fetch(:tradition_cluster),
      "era" => group.fetch(:era),
      "source_type" => group.fetch(:source_type),
      "ingestion_unit" => group.fetch(:ingestion_unit),
      "priority_wave" => group.fetch(:priority_wave),
      "candidate_rights" => group.fetch(:candidate_rights),
      "status" => "planned",
      "complete_text_goal" => true,
      "notes" => group.fetch(:notes)
    }
  end
end

def numbered(prefix, range, label = "Book")
  range.map { |n| "#{prefix} #{label} #{format("%02d", n)}" }
end

mesopotamian = [
  *numbered("Epic of Gilgamesh", 1..12, "Tablet"),
  *numbered("Enuma Elish", 1..7, "Tablet"),
  *numbered("Atrahasis", 1..3, "Tablet"),
  "Descent of Inanna",
  "Enki and Ninhursag",
  "Enmerkar and the Lord of Aratta"
]

egyptian = [
  "Pyramid Texts: Cannibal Hymn",
  "Pyramid Texts: King's Ascension Utterances",
  "Coffin Texts: Book of Two Ways",
  "Coffin Texts: Spell 335",
  "Book of the Dead: Chapter 15",
  "Book of the Dead: Chapter 17",
  "Book of the Dead: Chapter 30B",
  "Book of the Dead: Chapter 42",
  "Book of the Dead: Chapter 64",
  "Book of the Dead: Chapter 110",
  "Book of the Dead: Chapter 125",
  "Book of the Dead: Chapter 175",
  *numbered("Amduat", 1..12, "Hour"),
  "Tale of Isis and Ra"
]

hebrew_bible = %w[
  Genesis Exodus Leviticus Numbers Deuteronomy Joshua Judges Ruth
  1_Samuel 2_Samuel 1_Kings 2_Kings 1_Chronicles 2_Chronicles Ezra Nehemiah Esther
  Job Psalms Proverbs Ecclesiastes Song_of_Songs Isaiah Jeremiah Lamentations Ezekiel Daniel
  Hosea Joel Amos Obadiah Jonah Micah Nahum Habakkuk Zephaniah Haggai Zechariah Malachi
].map { |name| "Hebrew Bible: #{name.tr("_", " ")}" }

new_testament = [
  "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians",
  "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
  "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
  "1 John", "2 John", "3 John", "Jude", "Revelation"
].map { |name| "New Testament: #{name}" }

second_temple = [
  "1 Enoch",
  "Jubilees",
  "Wisdom of Solomon",
  "Sirach"
]

greek_roman = [
  *numbered("Iliad", 1..24),
  *numbered("Odyssey", 1..24),
  *numbered("Ovid Metamorphoses", 1..15),
  *numbered("Aeneid", 1..12),
  *numbered("Argonautica", 1..4),
  "Hesiod: Theogony"
]

upanishads = [
  "Isha Upanishad",
  "Kena Upanishad",
  "Katha Upanishad",
  "Prashna Upanishad",
  "Mundaka Upanishad",
  "Mandukya Upanishad",
  "Taittiriya Upanishad",
  "Aitareya Upanishad",
  "Chandogya Upanishad",
  "Brihadaranyaka Upanishad",
  "Shvetashvatara Upanishad",
  "Kaushitaki Upanishad",
  "Maitri Upanishad"
]

ramayana = %w[Bala Ayodhya Aranya Kishkindha Sundara Yuddha Uttara].map { |k| "Ramayana: #{k} Kanda" }

mahabharata = [
  "Adi Parva", "Sabha Parva", "Vana Parva", "Virata Parva", "Udyoga Parva", "Bhishma Parva",
  "Drona Parva", "Karna Parva", "Shalya Parva", "Sauptika Parva", "Stri Parva", "Shanti Parva",
  "Anushasana Parva", "Ashvamedhika Parva", "Ashramavasika Parva", "Mausala Parva",
  "Mahaprasthanika Parva", "Svargarohana Parva"
].map { |p| "Mahabharata: #{p}" }

indian = [
  *numbered("Bhagavad Gita", 1..18, "Chapter"),
  *upanishads,
  *numbered("Rigveda", 1..10, "Mandala"),
  *ramayana,
  *mahabharata,
  "Yoga Sutras of Patanjali",
  "Samkhya Karika",
  "Acaranga Sutra",
  "Kalpa Sutra"
]

dhammapada_chapters = [
  "Pairs", "Heedfulness", "Mind", "Flowers", "The Fool", "The Wise", "The Arahant",
  "The Thousands", "Evil", "Punishment", "Old Age", "Self", "The World", "The Buddha",
  "Happiness", "Affection", "Anger", "Impurity", "The Just", "The Path", "Miscellaneous",
  "Hell", "The Elephant", "Craving", "The Monk", "The Brahmin"
].map { |chapter| "Dhammapada: #{chapter}" }

buddhist = [
  *dhammapada_chapters,
  "Sutta Nipata: Uraga Vagga",
  "Sutta Nipata: Cula Vagga",
  "Sutta Nipata: Maha Vagga",
  "Sutta Nipata: Atthaka Vagga",
  "Sutta Nipata: Parayana Vagga",
  "Vessantara Jataka",
  "Sama Jataka",
  "Mahosadha Jataka",
  "Temiya Jataka",
  "Sibi Jataka",
  "Ruru Jataka",
  "Nigrodhamiga Jataka",
  "Nimi Jataka",
  "Kusa Jataka",
  "Khandahala Jataka",
  *numbered("Lotus Sutra", 1..9, "Chapter")
]

east_asian = [
  *numbered("Tao Te Ching", 1..20, "Chapter"),
  *numbered("Analects", 1..20),
  *numbered("Zhuangzi Inner Chapters", 1..7, "Chapter"),
  "Kojiki: Kamitsumaki",
  "Kojiki: Nakatsumaki",
  "Kojiki: Shimotsumaki"
]

quran_first_30 = [
  "Al-Fatihah", "Al-Baqarah", "Al Imran", "An-Nisa", "Al-Ma'idah", "Al-An'am", "Al-A'raf",
  "Al-Anfal", "At-Tawbah", "Yunus", "Hud", "Yusuf", "Ar-Ra'd", "Ibrahim", "Al-Hijr",
  "An-Nahl", "Al-Isra", "Al-Kahf", "Maryam", "Ta-Ha", "Al-Anbiya", "Al-Hajj",
  "Al-Mu'minun", "An-Nur", "Al-Furqan", "Ash-Shu'ara", "An-Naml", "Al-Qasas",
  "Al-Ankabut", "Ar-Rum"
].each_with_index.map { |name, i| "Qur'an: Surah #{format("%03d", i + 1)} #{name}" }

islamic_persian = [
  *quran_first_30,
  *numbered("Masnavi", 1..6),
  *numbered("Gulistan", 1..8, "Chapter"),
  "Conference of the Birds"
]

poetic_edda = [
  "Voluspa", "Havamal", "Vafthrudnismal", "Grimnismal", "Skirnismal", "Harbardsljod",
  "Hymiskvida", "Lokasenna", "Thrymskvida", "Alvissmal", "Baldrs draumar", "Rigsthula",
  "Hyndluljod", "Volundarkvida", "Helgakvida Hundingsbana I", "Helgakvida Hjorvardssonar",
  "Helgakvida Hundingsbana II", "Fra dauda Sinfjotla", "Gripisspa", "Reginsmal", "Fafnismal",
  "Sigrdrifumal", "Brot af Sigurdarkvidu", "Gudrunarkvida I", "Sigurdarkvida hin skamma",
  "Helreid Brynhildar", "Drap Niflunga", "Gudrunarkvida II", "Gudrunarkvida III", "Oddrunargratr"
].map { |poem| "Poetic Edda: #{poem}" }

mabinogion = [
  "Pwyll Prince of Dyfed",
  "Branwen Daughter of Llyr",
  "Manawydan Son of Llyr",
  "Math Son of Mathonwy",
  "Peredur Son of Efrawg",
  "Owain, or the Lady of the Fountain",
  "Geraint Son of Erbin",
  "The Dream of Macsen Wledig",
  "Lludd and Llefelys",
  "Culhwch and Olwen",
  "The Dream of Rhonabwy"
].map { |tale| "Mabinogion: #{tale}" }

norse_celtic = [
  *poetic_edda,
  "Prose Edda: Prologue",
  "Prose Edda: Gylfaginning",
  "Prose Edda: Skaldskaparmal",
  "Prose Edda: Hattatal",
  *mabinogion
]

world_oral = [
  *numbered("Kumulipo", 1..16, "Chant"),
  "Popol Vuh: Preamble",
  "Popol Vuh: Part 1",
  "Popol Vuh: Part 2",
  "Popol Vuh: Part 3",
  "Popol Vuh: Part 4",
  "Nahua Myth: Five Suns",
  "Nahua Myth: Birth of Huitzilopochtli",
  "Nahua Myth: Quetzalcoatl and Tollan",
  "Nahua Myth: Journey to Mictlan",
  "Nahua Myth: Tlalocan and the Rain Powers",
  "Ifa Odu: Eji Ogbe",
  "Ifa Odu: Oyeku Meji",
  "Ifa Odu: Iwori Meji",
  "Ifa Odu: Odi Meji",
  "Ifa Odu: Irosun Meji",
  "Ifa Odu: Owonrin Meji",
  "Ifa Odu: Obara Meji",
  "Ifa Odu: Okanran Meji",
  "Anansi Cycle: How Anansi Got the Stories",
  "Anansi Cycle: Anansi and the Pot of Wisdom",
  "Anansi Cycle: Anansi and Turtle",
  "Anansi Cycle: Anansi and Death",
  "Anansi Cycle: Anansi and the Sky God",
  "Maori Creation Cycle: Rangi and Papa"
]

groups = [
  {
    titles: mesopotamian,
    culture_area: "Ancient Near East",
    tradition_cluster: "mesopotamian",
    era: "Bronze Age to Iron Age",
    source_type: "myth_epic_hymn",
    ingestion_unit: "tablet_or_complete_short_work",
    priority_wave: "A",
    candidate_rights: "original_language_public_domain_translation_rights_check",
    notes: "Use reliable editions; many English translations are modern, so verify translation rights before full-text ingestion."
  },
  {
    titles: egyptian,
    culture_area: "Ancient Egypt",
    tradition_cluster: "egyptian",
    era: "Old Kingdom through New Kingdom and later reception",
    source_type: "funerary_ritual_myth",
    ingestion_unit: "chapter_spell_hour_or_complete_short_work",
    priority_wave: "A",
    candidate_rights: "original_language_public_domain_translation_rights_check",
    notes: "Prioritize public-domain translations first; track spell, chapter, utterance, and hour numbering carefully."
  },
  {
    titles: [*hebrew_bible, *new_testament, *second_temple],
    culture_area: "Biblical and Second Temple",
    tradition_cluster: "jewish_christian",
    era: "Iron Age through late antiquity",
    source_type: "scripture_apocrypha",
    ingestion_unit: "book",
    priority_wave: "A",
    candidate_rights: "original_language_public_domain_public_domain_translation_candidate",
    notes: "Use original-language texts and public-domain translations only; modern translations require separate permission."
  },
  {
    titles: greek_roman,
    culture_area: "Greek and Roman Mediterranean",
    tradition_cluster: "greek_roman",
    era: "archaic through imperial antiquity",
    source_type: "epic_poetry_mythography",
    ingestion_unit: "book_or_complete_short_work",
    priority_wave: "A",
    candidate_rights: "public_domain_translation_candidate",
    notes: "Use public-domain translations where possible; preserve book numbering for later motif linking."
  },
  {
    titles: indian,
    culture_area: "South Asia",
    tradition_cluster: "hindu_jain_indian_philosophical",
    era: "Vedic through classical and medieval reception",
    source_type: "scripture_epic_philosophy",
    ingestion_unit: "chapter_book_mandala_or_complete_short_work",
    priority_wave: "A",
    candidate_rights: "original_language_public_domain_translation_rights_check",
    notes: "Large works are split into natural units; use Sanskrit/Prakrit originals and public-domain translations where verified."
  },
  {
    titles: buddhist,
    culture_area: "South and East Asian Buddhism",
    tradition_cluster: "buddhist",
    era: "early Buddhist through Mahayana reception",
    source_type: "scripture_tale_teaching",
    ingestion_unit: "chapter_vagga_tale_or_sutra_chapter",
    priority_wave: "A",
    candidate_rights: "original_language_public_domain_translation_rights_check",
    notes: "Track Pali, Sanskrit, Chinese, Tibetan, and translation lineages separately."
  },
  {
    titles: east_asian,
    culture_area: "China and Japan",
    tradition_cluster: "daoist_confucian_shinto",
    era: "classical to early medieval",
    source_type: "philosophy_divination_myth_history",
    ingestion_unit: "chapter_book_or_section",
    priority_wave: "B",
    candidate_rights: "original_language_public_domain_translation_rights_check",
    notes: "For short aphoristic works, preserve chapter numbering and variant title metadata."
  },
  {
    titles: islamic_persian,
    culture_area: "Islamic and Persianate",
    tradition_cluster: "islamic_persian_sufi",
    era: "late antique through medieval",
    source_type: "scripture_poetry_wisdom",
    ingestion_unit: "surah_book_chapter_or_complete_short_work",
    priority_wave: "B",
    candidate_rights: "original_language_public_domain_translation_rights_check",
    notes: "The Arabic Qur'an text is handled separately from translations; Persian poetry translations require rights review."
  },
  {
    titles: norse_celtic,
    culture_area: "Northern and Western Europe",
    tradition_cluster: "norse_celtic",
    era: "medieval manuscripts preserving older mythic material",
    source_type: "myth_poem_saga_tale",
    ingestion_unit: "poem_section_or_tale",
    priority_wave: "B",
    candidate_rights: "public_domain_translation_candidate",
    notes: "Track manuscript, editor, and translator; avoid treating medieval attestations as direct prehistoric records."
  },
  {
    titles: world_oral,
    culture_area: "Mesoamerican, African, and Oceanic",
    tradition_cluster: "world_oral_and_living_traditions",
    era: "precolonial, colonial-recorded, and living traditions",
    source_type: "oral_tradition_creation_cycle_sacred_story",
    ingestion_unit: "chant_part_tale_odu_or_cycle",
    priority_wave: "C",
    candidate_rights: "rights_and_cultural_permission_review_required",
    notes: "Use special care: public-domain publication is not the same as cultural permission for sacred or living traditions."
  }
]

groups.each { |group| add_group(items, group, group.fetch(:titles)) }

unless items.length == 500
  abort "expected 500 items, got #{items.length}"
end

collection = {
  "collection_id" => "first_500_corpus",
  "title" => "First 500 Corpus Plan",
  "generated_on" => "2026-04-27",
  "unit_definition" => "A corpus unit is a complete ingestible unit: a short whole work, book, tablet, chapter, surah, hymn, chant, tale, or natural section of a large canonical work.",
  "rights_policy" => "Every item is planned only. Verify copyright, translation rights, license terms, trademark restrictions, and cultural permissions before adding full text.",
  "selection_logic" => [
    "Prioritize ancient and classical primary sources over modern interpretation.",
    "Balance traditions across Near Eastern, Mediterranean, South Asian, East Asian, Islamic/Persianate, Northern European, Mesoamerican, African, and Oceanic material.",
    "Split long works into natural source units so each Markdown file can be complete and citable.",
    "Preserve original-language texts where possible and pair with rights-cleared translations.",
    "Mark living and Indigenous traditions for cultural permission review, even where older publications are technically public domain."
  ],
  "groups" => groups.map do |group|
    {
      "culture_area" => group.fetch(:culture_area),
      "tradition_cluster" => group.fetch(:tradition_cluster),
      "count" => group.fetch(:titles).length,
      "priority_wave" => group.fetch(:priority_wave),
      "candidate_rights" => group.fetch(:candidate_rights)
    }
  end,
  "items" => items
}

FileUtils.mkdir_p(File.dirname(OUT_YAML))
File.write(OUT_YAML, YAML.dump(collection))

doc = +"# First 500 Corpus Plan\n\n"
doc << "This is the first large collection target for the Ancient Wisdom Atlas.\n\n"
doc << "A **corpus unit** is a complete ingestible unit: a short whole work, book, tablet, chapter, surah, hymn, chant, tale, or natural section of a large canonical work.\n\n"
doc << "The full machine-readable list lives in `data/collections/first-500-corpus.yml`.\n\n"
doc << "## Rules\n\n"
collection.fetch("selection_logic").each { |rule| doc << "- #{rule}\n" }
doc << "\n## Group Counts\n\n"
doc << "| Culture Area | Tradition Cluster | Count | Wave | Rights Mode |\n"
doc << "| --- | --- | ---: | --- | --- |\n"
collection.fetch("groups").each do |group|
  doc << "| #{group.fetch("culture_area")} | `#{group.fetch("tradition_cluster")}` | #{group.fetch("count")} | #{group.fetch("priority_wave")} | `#{group.fetch("candidate_rights")}` |\n"
end
doc << "\nTotal: **#{items.length} corpus units**.\n\n"
doc << "## Ingestion Order\n\n"
doc << "1. Start with Wave A public-domain candidates that have reliable public-domain English translations or clean original-language texts.\n"
doc << "2. Add original-language Markdown first when translation rights are unclear.\n"
doc << "3. Add public-domain translations only after edition-level verification.\n"
doc << "4. Keep culturally sensitive living-tradition material in planning or citation-only form until permission and context are reviewed.\n\n"
doc << "## Full List\n\n"
groups.each do |group|
  group_items = items.select { |item| item.fetch("tradition_cluster") == group.fetch(:tradition_cluster) }
  doc << "### #{group.fetch(:culture_area)}\n\n"
  group_items.each do |item|
    doc << "- `#{item.fetch("id")}` #{item.fetch("title")}\n"
  end
  doc << "\n"
end

File.write(OUT_DOC, doc)

puts "wrote #{OUT_YAML.sub("#{ROOT}/", "")}"
puts "wrote #{OUT_DOC.sub("#{ROOT}/", "")}"
puts "count #{items.length}"
