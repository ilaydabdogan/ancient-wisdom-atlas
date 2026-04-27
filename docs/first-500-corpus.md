# First 500 Corpus Plan

This is the first large collection target for the Ancient Wisdom Atlas.

A **corpus unit** is a complete ingestible unit: a short whole work, book, tablet, chapter, surah, hymn, chant, tale, or natural section of a large canonical work.

The full machine-readable list lives in `data/collections/first-500-corpus.yml`.

## Rules

- Prioritize ancient and classical primary sources over modern interpretation.
- Balance traditions across Near Eastern, Mediterranean, South Asian, East Asian, Islamic/Persianate, Northern European, Mesoamerican, African, and Oceanic material.
- Split long works into natural source units so each Markdown file can be complete and citable.
- Preserve original-language texts where possible and pair with rights-cleared translations.
- Mark living and Indigenous traditions for cultural permission review, even where older publications are technically public domain.

## Group Counts

| Culture Area | Tradition Cluster | Count | Wave | Rights Mode |
| --- | --- | ---: | --- | --- |
| Ancient Near East | `mesopotamian` | 25 | A | `original_language_public_domain_translation_rights_check` |
| Ancient Egypt | `egyptian` | 25 | A | `original_language_public_domain_translation_rights_check` |
| Biblical and Second Temple | `jewish_christian` | 70 | A | `original_language_public_domain_public_domain_translation_candidate` |
| Greek and Roman Mediterranean | `greek_roman` | 80 | A | `public_domain_translation_candidate` |
| South Asia | `hindu_jain_indian_philosophical` | 70 | A | `original_language_public_domain_translation_rights_check` |
| South and East Asian Buddhism | `buddhist` | 50 | A | `original_language_public_domain_translation_rights_check` |
| China and Japan | `daoist_confucian_shinto` | 50 | B | `original_language_public_domain_translation_rights_check` |
| Islamic and Persianate | `islamic_persian_sufi` | 45 | B | `original_language_public_domain_translation_rights_check` |
| Northern and Western Europe | `norse_celtic` | 45 | B | `public_domain_translation_candidate` |
| Mesoamerican, African, and Oceanic | `world_oral_and_living_traditions` | 40 | C | `rights_and_cultural_permission_review_required` |

Total: **500 corpus units**.

## Ingestion Order

1. Start with Wave A public-domain candidates that have reliable public-domain English translations or clean original-language texts.
2. Add original-language Markdown first when translation rights are unclear.
3. Add public-domain translations only after edition-level verification.
4. Keep culturally sensitive living-tradition material in planning or citation-only form until permission and context are reviewed.

## Full List

### Ancient Near East

- `first500.001` Epic of Gilgamesh Tablet 01
- `first500.002` Epic of Gilgamesh Tablet 02
- `first500.003` Epic of Gilgamesh Tablet 03
- `first500.004` Epic of Gilgamesh Tablet 04
- `first500.005` Epic of Gilgamesh Tablet 05
- `first500.006` Epic of Gilgamesh Tablet 06
- `first500.007` Epic of Gilgamesh Tablet 07
- `first500.008` Epic of Gilgamesh Tablet 08
- `first500.009` Epic of Gilgamesh Tablet 09
- `first500.010` Epic of Gilgamesh Tablet 10
- `first500.011` Epic of Gilgamesh Tablet 11
- `first500.012` Epic of Gilgamesh Tablet 12
- `first500.013` Enuma Elish Tablet 01
- `first500.014` Enuma Elish Tablet 02
- `first500.015` Enuma Elish Tablet 03
- `first500.016` Enuma Elish Tablet 04
- `first500.017` Enuma Elish Tablet 05
- `first500.018` Enuma Elish Tablet 06
- `first500.019` Enuma Elish Tablet 07
- `first500.020` Atrahasis Tablet 01
- `first500.021` Atrahasis Tablet 02
- `first500.022` Atrahasis Tablet 03
- `first500.023` Descent of Inanna
- `first500.024` Enki and Ninhursag
- `first500.025` Enmerkar and the Lord of Aratta

### Ancient Egypt

- `first500.026` Pyramid Texts: Cannibal Hymn
- `first500.027` Pyramid Texts: King's Ascension Utterances
- `first500.028` Coffin Texts: Book of Two Ways
- `first500.029` Coffin Texts: Spell 335
- `first500.030` Book of the Dead: Chapter 15
- `first500.031` Book of the Dead: Chapter 17
- `first500.032` Book of the Dead: Chapter 30B
- `first500.033` Book of the Dead: Chapter 42
- `first500.034` Book of the Dead: Chapter 64
- `first500.035` Book of the Dead: Chapter 110
- `first500.036` Book of the Dead: Chapter 125
- `first500.037` Book of the Dead: Chapter 175
- `first500.038` Amduat Hour 01
- `first500.039` Amduat Hour 02
- `first500.040` Amduat Hour 03
- `first500.041` Amduat Hour 04
- `first500.042` Amduat Hour 05
- `first500.043` Amduat Hour 06
- `first500.044` Amduat Hour 07
- `first500.045` Amduat Hour 08
- `first500.046` Amduat Hour 09
- `first500.047` Amduat Hour 10
- `first500.048` Amduat Hour 11
- `first500.049` Amduat Hour 12
- `first500.050` Tale of Isis and Ra

### Biblical and Second Temple

- `first500.051` Hebrew Bible: Genesis
- `first500.052` Hebrew Bible: Exodus
- `first500.053` Hebrew Bible: Leviticus
- `first500.054` Hebrew Bible: Numbers
- `first500.055` Hebrew Bible: Deuteronomy
- `first500.056` Hebrew Bible: Joshua
- `first500.057` Hebrew Bible: Judges
- `first500.058` Hebrew Bible: Ruth
- `first500.059` Hebrew Bible: 1 Samuel
- `first500.060` Hebrew Bible: 2 Samuel
- `first500.061` Hebrew Bible: 1 Kings
- `first500.062` Hebrew Bible: 2 Kings
- `first500.063` Hebrew Bible: 1 Chronicles
- `first500.064` Hebrew Bible: 2 Chronicles
- `first500.065` Hebrew Bible: Ezra
- `first500.066` Hebrew Bible: Nehemiah
- `first500.067` Hebrew Bible: Esther
- `first500.068` Hebrew Bible: Job
- `first500.069` Hebrew Bible: Psalms
- `first500.070` Hebrew Bible: Proverbs
- `first500.071` Hebrew Bible: Ecclesiastes
- `first500.072` Hebrew Bible: Song of Songs
- `first500.073` Hebrew Bible: Isaiah
- `first500.074` Hebrew Bible: Jeremiah
- `first500.075` Hebrew Bible: Lamentations
- `first500.076` Hebrew Bible: Ezekiel
- `first500.077` Hebrew Bible: Daniel
- `first500.078` Hebrew Bible: Hosea
- `first500.079` Hebrew Bible: Joel
- `first500.080` Hebrew Bible: Amos
- `first500.081` Hebrew Bible: Obadiah
- `first500.082` Hebrew Bible: Jonah
- `first500.083` Hebrew Bible: Micah
- `first500.084` Hebrew Bible: Nahum
- `first500.085` Hebrew Bible: Habakkuk
- `first500.086` Hebrew Bible: Zephaniah
- `first500.087` Hebrew Bible: Haggai
- `first500.088` Hebrew Bible: Zechariah
- `first500.089` Hebrew Bible: Malachi
- `first500.090` New Testament: Matthew
- `first500.091` New Testament: Mark
- `first500.092` New Testament: Luke
- `first500.093` New Testament: John
- `first500.094` New Testament: Acts
- `first500.095` New Testament: Romans
- `first500.096` New Testament: 1 Corinthians
- `first500.097` New Testament: 2 Corinthians
- `first500.098` New Testament: Galatians
- `first500.099` New Testament: Ephesians
- `first500.100` New Testament: Philippians
- `first500.101` New Testament: Colossians
- `first500.102` New Testament: 1 Thessalonians
- `first500.103` New Testament: 2 Thessalonians
- `first500.104` New Testament: 1 Timothy
- `first500.105` New Testament: 2 Timothy
- `first500.106` New Testament: Titus
- `first500.107` New Testament: Philemon
- `first500.108` New Testament: Hebrews
- `first500.109` New Testament: James
- `first500.110` New Testament: 1 Peter
- `first500.111` New Testament: 2 Peter
- `first500.112` New Testament: 1 John
- `first500.113` New Testament: 2 John
- `first500.114` New Testament: 3 John
- `first500.115` New Testament: Jude
- `first500.116` New Testament: Revelation
- `first500.117` 1 Enoch
- `first500.118` Jubilees
- `first500.119` Wisdom of Solomon
- `first500.120` Sirach

### Greek and Roman Mediterranean

- `first500.121` Iliad Book 01
- `first500.122` Iliad Book 02
- `first500.123` Iliad Book 03
- `first500.124` Iliad Book 04
- `first500.125` Iliad Book 05
- `first500.126` Iliad Book 06
- `first500.127` Iliad Book 07
- `first500.128` Iliad Book 08
- `first500.129` Iliad Book 09
- `first500.130` Iliad Book 10
- `first500.131` Iliad Book 11
- `first500.132` Iliad Book 12
- `first500.133` Iliad Book 13
- `first500.134` Iliad Book 14
- `first500.135` Iliad Book 15
- `first500.136` Iliad Book 16
- `first500.137` Iliad Book 17
- `first500.138` Iliad Book 18
- `first500.139` Iliad Book 19
- `first500.140` Iliad Book 20
- `first500.141` Iliad Book 21
- `first500.142` Iliad Book 22
- `first500.143` Iliad Book 23
- `first500.144` Iliad Book 24
- `first500.145` Odyssey Book 01
- `first500.146` Odyssey Book 02
- `first500.147` Odyssey Book 03
- `first500.148` Odyssey Book 04
- `first500.149` Odyssey Book 05
- `first500.150` Odyssey Book 06
- `first500.151` Odyssey Book 07
- `first500.152` Odyssey Book 08
- `first500.153` Odyssey Book 09
- `first500.154` Odyssey Book 10
- `first500.155` Odyssey Book 11
- `first500.156` Odyssey Book 12
- `first500.157` Odyssey Book 13
- `first500.158` Odyssey Book 14
- `first500.159` Odyssey Book 15
- `first500.160` Odyssey Book 16
- `first500.161` Odyssey Book 17
- `first500.162` Odyssey Book 18
- `first500.163` Odyssey Book 19
- `first500.164` Odyssey Book 20
- `first500.165` Odyssey Book 21
- `first500.166` Odyssey Book 22
- `first500.167` Odyssey Book 23
- `first500.168` Odyssey Book 24
- `first500.169` Ovid Metamorphoses Book 01
- `first500.170` Ovid Metamorphoses Book 02
- `first500.171` Ovid Metamorphoses Book 03
- `first500.172` Ovid Metamorphoses Book 04
- `first500.173` Ovid Metamorphoses Book 05
- `first500.174` Ovid Metamorphoses Book 06
- `first500.175` Ovid Metamorphoses Book 07
- `first500.176` Ovid Metamorphoses Book 08
- `first500.177` Ovid Metamorphoses Book 09
- `first500.178` Ovid Metamorphoses Book 10
- `first500.179` Ovid Metamorphoses Book 11
- `first500.180` Ovid Metamorphoses Book 12
- `first500.181` Ovid Metamorphoses Book 13
- `first500.182` Ovid Metamorphoses Book 14
- `first500.183` Ovid Metamorphoses Book 15
- `first500.184` Aeneid Book 01
- `first500.185` Aeneid Book 02
- `first500.186` Aeneid Book 03
- `first500.187` Aeneid Book 04
- `first500.188` Aeneid Book 05
- `first500.189` Aeneid Book 06
- `first500.190` Aeneid Book 07
- `first500.191` Aeneid Book 08
- `first500.192` Aeneid Book 09
- `first500.193` Aeneid Book 10
- `first500.194` Aeneid Book 11
- `first500.195` Aeneid Book 12
- `first500.196` Argonautica Book 01
- `first500.197` Argonautica Book 02
- `first500.198` Argonautica Book 03
- `first500.199` Argonautica Book 04
- `first500.200` Hesiod: Theogony

### South Asia

- `first500.201` Bhagavad Gita Chapter 01
- `first500.202` Bhagavad Gita Chapter 02
- `first500.203` Bhagavad Gita Chapter 03
- `first500.204` Bhagavad Gita Chapter 04
- `first500.205` Bhagavad Gita Chapter 05
- `first500.206` Bhagavad Gita Chapter 06
- `first500.207` Bhagavad Gita Chapter 07
- `first500.208` Bhagavad Gita Chapter 08
- `first500.209` Bhagavad Gita Chapter 09
- `first500.210` Bhagavad Gita Chapter 10
- `first500.211` Bhagavad Gita Chapter 11
- `first500.212` Bhagavad Gita Chapter 12
- `first500.213` Bhagavad Gita Chapter 13
- `first500.214` Bhagavad Gita Chapter 14
- `first500.215` Bhagavad Gita Chapter 15
- `first500.216` Bhagavad Gita Chapter 16
- `first500.217` Bhagavad Gita Chapter 17
- `first500.218` Bhagavad Gita Chapter 18
- `first500.219` Isha Upanishad
- `first500.220` Kena Upanishad
- `first500.221` Katha Upanishad
- `first500.222` Prashna Upanishad
- `first500.223` Mundaka Upanishad
- `first500.224` Mandukya Upanishad
- `first500.225` Taittiriya Upanishad
- `first500.226` Aitareya Upanishad
- `first500.227` Chandogya Upanishad
- `first500.228` Brihadaranyaka Upanishad
- `first500.229` Shvetashvatara Upanishad
- `first500.230` Kaushitaki Upanishad
- `first500.231` Maitri Upanishad
- `first500.232` Rigveda Mandala 01
- `first500.233` Rigveda Mandala 02
- `first500.234` Rigveda Mandala 03
- `first500.235` Rigveda Mandala 04
- `first500.236` Rigveda Mandala 05
- `first500.237` Rigveda Mandala 06
- `first500.238` Rigveda Mandala 07
- `first500.239` Rigveda Mandala 08
- `first500.240` Rigveda Mandala 09
- `first500.241` Rigveda Mandala 10
- `first500.242` Ramayana: Bala Kanda
- `first500.243` Ramayana: Ayodhya Kanda
- `first500.244` Ramayana: Aranya Kanda
- `first500.245` Ramayana: Kishkindha Kanda
- `first500.246` Ramayana: Sundara Kanda
- `first500.247` Ramayana: Yuddha Kanda
- `first500.248` Ramayana: Uttara Kanda
- `first500.249` Mahabharata: Adi Parva
- `first500.250` Mahabharata: Sabha Parva
- `first500.251` Mahabharata: Vana Parva
- `first500.252` Mahabharata: Virata Parva
- `first500.253` Mahabharata: Udyoga Parva
- `first500.254` Mahabharata: Bhishma Parva
- `first500.255` Mahabharata: Drona Parva
- `first500.256` Mahabharata: Karna Parva
- `first500.257` Mahabharata: Shalya Parva
- `first500.258` Mahabharata: Sauptika Parva
- `first500.259` Mahabharata: Stri Parva
- `first500.260` Mahabharata: Shanti Parva
- `first500.261` Mahabharata: Anushasana Parva
- `first500.262` Mahabharata: Ashvamedhika Parva
- `first500.263` Mahabharata: Ashramavasika Parva
- `first500.264` Mahabharata: Mausala Parva
- `first500.265` Mahabharata: Mahaprasthanika Parva
- `first500.266` Mahabharata: Svargarohana Parva
- `first500.267` Yoga Sutras of Patanjali
- `first500.268` Samkhya Karika
- `first500.269` Acaranga Sutra
- `first500.270` Kalpa Sutra

### South and East Asian Buddhism

- `first500.271` Dhammapada: Pairs
- `first500.272` Dhammapada: Heedfulness
- `first500.273` Dhammapada: Mind
- `first500.274` Dhammapada: Flowers
- `first500.275` Dhammapada: The Fool
- `first500.276` Dhammapada: The Wise
- `first500.277` Dhammapada: The Arahant
- `first500.278` Dhammapada: The Thousands
- `first500.279` Dhammapada: Evil
- `first500.280` Dhammapada: Punishment
- `first500.281` Dhammapada: Old Age
- `first500.282` Dhammapada: Self
- `first500.283` Dhammapada: The World
- `first500.284` Dhammapada: The Buddha
- `first500.285` Dhammapada: Happiness
- `first500.286` Dhammapada: Affection
- `first500.287` Dhammapada: Anger
- `first500.288` Dhammapada: Impurity
- `first500.289` Dhammapada: The Just
- `first500.290` Dhammapada: The Path
- `first500.291` Dhammapada: Miscellaneous
- `first500.292` Dhammapada: Hell
- `first500.293` Dhammapada: The Elephant
- `first500.294` Dhammapada: Craving
- `first500.295` Dhammapada: The Monk
- `first500.296` Dhammapada: The Brahmin
- `first500.297` Sutta Nipata: Uraga Vagga
- `first500.298` Sutta Nipata: Cula Vagga
- `first500.299` Sutta Nipata: Maha Vagga
- `first500.300` Sutta Nipata: Atthaka Vagga
- `first500.301` Sutta Nipata: Parayana Vagga
- `first500.302` Vessantara Jataka
- `first500.303` Sama Jataka
- `first500.304` Mahosadha Jataka
- `first500.305` Temiya Jataka
- `first500.306` Sibi Jataka
- `first500.307` Ruru Jataka
- `first500.308` Nigrodhamiga Jataka
- `first500.309` Nimi Jataka
- `first500.310` Kusa Jataka
- `first500.311` Khandahala Jataka
- `first500.312` Lotus Sutra Chapter 01
- `first500.313` Lotus Sutra Chapter 02
- `first500.314` Lotus Sutra Chapter 03
- `first500.315` Lotus Sutra Chapter 04
- `first500.316` Lotus Sutra Chapter 05
- `first500.317` Lotus Sutra Chapter 06
- `first500.318` Lotus Sutra Chapter 07
- `first500.319` Lotus Sutra Chapter 08
- `first500.320` Lotus Sutra Chapter 09

### China and Japan

- `first500.321` Tao Te Ching Chapter 01
- `first500.322` Tao Te Ching Chapter 02
- `first500.323` Tao Te Ching Chapter 03
- `first500.324` Tao Te Ching Chapter 04
- `first500.325` Tao Te Ching Chapter 05
- `first500.326` Tao Te Ching Chapter 06
- `first500.327` Tao Te Ching Chapter 07
- `first500.328` Tao Te Ching Chapter 08
- `first500.329` Tao Te Ching Chapter 09
- `first500.330` Tao Te Ching Chapter 10
- `first500.331` Tao Te Ching Chapter 11
- `first500.332` Tao Te Ching Chapter 12
- `first500.333` Tao Te Ching Chapter 13
- `first500.334` Tao Te Ching Chapter 14
- `first500.335` Tao Te Ching Chapter 15
- `first500.336` Tao Te Ching Chapter 16
- `first500.337` Tao Te Ching Chapter 17
- `first500.338` Tao Te Ching Chapter 18
- `first500.339` Tao Te Ching Chapter 19
- `first500.340` Tao Te Ching Chapter 20
- `first500.341` Analects Book 01
- `first500.342` Analects Book 02
- `first500.343` Analects Book 03
- `first500.344` Analects Book 04
- `first500.345` Analects Book 05
- `first500.346` Analects Book 06
- `first500.347` Analects Book 07
- `first500.348` Analects Book 08
- `first500.349` Analects Book 09
- `first500.350` Analects Book 10
- `first500.351` Analects Book 11
- `first500.352` Analects Book 12
- `first500.353` Analects Book 13
- `first500.354` Analects Book 14
- `first500.355` Analects Book 15
- `first500.356` Analects Book 16
- `first500.357` Analects Book 17
- `first500.358` Analects Book 18
- `first500.359` Analects Book 19
- `first500.360` Analects Book 20
- `first500.361` Zhuangzi Inner Chapters Chapter 01
- `first500.362` Zhuangzi Inner Chapters Chapter 02
- `first500.363` Zhuangzi Inner Chapters Chapter 03
- `first500.364` Zhuangzi Inner Chapters Chapter 04
- `first500.365` Zhuangzi Inner Chapters Chapter 05
- `first500.366` Zhuangzi Inner Chapters Chapter 06
- `first500.367` Zhuangzi Inner Chapters Chapter 07
- `first500.368` Kojiki: Kamitsumaki
- `first500.369` Kojiki: Nakatsumaki
- `first500.370` Kojiki: Shimotsumaki

### Islamic and Persianate

- `first500.371` Qur'an: Surah 001 Al-Fatihah
- `first500.372` Qur'an: Surah 002 Al-Baqarah
- `first500.373` Qur'an: Surah 003 Al Imran
- `first500.374` Qur'an: Surah 004 An-Nisa
- `first500.375` Qur'an: Surah 005 Al-Ma'idah
- `first500.376` Qur'an: Surah 006 Al-An'am
- `first500.377` Qur'an: Surah 007 Al-A'raf
- `first500.378` Qur'an: Surah 008 Al-Anfal
- `first500.379` Qur'an: Surah 009 At-Tawbah
- `first500.380` Qur'an: Surah 010 Yunus
- `first500.381` Qur'an: Surah 011 Hud
- `first500.382` Qur'an: Surah 012 Yusuf
- `first500.383` Qur'an: Surah 013 Ar-Ra'd
- `first500.384` Qur'an: Surah 014 Ibrahim
- `first500.385` Qur'an: Surah 015 Al-Hijr
- `first500.386` Qur'an: Surah 016 An-Nahl
- `first500.387` Qur'an: Surah 017 Al-Isra
- `first500.388` Qur'an: Surah 018 Al-Kahf
- `first500.389` Qur'an: Surah 019 Maryam
- `first500.390` Qur'an: Surah 020 Ta-Ha
- `first500.391` Qur'an: Surah 021 Al-Anbiya
- `first500.392` Qur'an: Surah 022 Al-Hajj
- `first500.393` Qur'an: Surah 023 Al-Mu'minun
- `first500.394` Qur'an: Surah 024 An-Nur
- `first500.395` Qur'an: Surah 025 Al-Furqan
- `first500.396` Qur'an: Surah 026 Ash-Shu'ara
- `first500.397` Qur'an: Surah 027 An-Naml
- `first500.398` Qur'an: Surah 028 Al-Qasas
- `first500.399` Qur'an: Surah 029 Al-Ankabut
- `first500.400` Qur'an: Surah 030 Ar-Rum
- `first500.401` Masnavi Book 01
- `first500.402` Masnavi Book 02
- `first500.403` Masnavi Book 03
- `first500.404` Masnavi Book 04
- `first500.405` Masnavi Book 05
- `first500.406` Masnavi Book 06
- `first500.407` Gulistan Chapter 01
- `first500.408` Gulistan Chapter 02
- `first500.409` Gulistan Chapter 03
- `first500.410` Gulistan Chapter 04
- `first500.411` Gulistan Chapter 05
- `first500.412` Gulistan Chapter 06
- `first500.413` Gulistan Chapter 07
- `first500.414` Gulistan Chapter 08
- `first500.415` Conference of the Birds

### Northern and Western Europe

- `first500.416` Poetic Edda: Voluspa
- `first500.417` Poetic Edda: Havamal
- `first500.418` Poetic Edda: Vafthrudnismal
- `first500.419` Poetic Edda: Grimnismal
- `first500.420` Poetic Edda: Skirnismal
- `first500.421` Poetic Edda: Harbardsljod
- `first500.422` Poetic Edda: Hymiskvida
- `first500.423` Poetic Edda: Lokasenna
- `first500.424` Poetic Edda: Thrymskvida
- `first500.425` Poetic Edda: Alvissmal
- `first500.426` Poetic Edda: Baldrs draumar
- `first500.427` Poetic Edda: Rigsthula
- `first500.428` Poetic Edda: Hyndluljod
- `first500.429` Poetic Edda: Volundarkvida
- `first500.430` Poetic Edda: Helgakvida Hundingsbana I
- `first500.431` Poetic Edda: Helgakvida Hjorvardssonar
- `first500.432` Poetic Edda: Helgakvida Hundingsbana II
- `first500.433` Poetic Edda: Fra dauda Sinfjotla
- `first500.434` Poetic Edda: Gripisspa
- `first500.435` Poetic Edda: Reginsmal
- `first500.436` Poetic Edda: Fafnismal
- `first500.437` Poetic Edda: Sigrdrifumal
- `first500.438` Poetic Edda: Brot af Sigurdarkvidu
- `first500.439` Poetic Edda: Gudrunarkvida I
- `first500.440` Poetic Edda: Sigurdarkvida hin skamma
- `first500.441` Poetic Edda: Helreid Brynhildar
- `first500.442` Poetic Edda: Drap Niflunga
- `first500.443` Poetic Edda: Gudrunarkvida II
- `first500.444` Poetic Edda: Gudrunarkvida III
- `first500.445` Poetic Edda: Oddrunargratr
- `first500.446` Prose Edda: Prologue
- `first500.447` Prose Edda: Gylfaginning
- `first500.448` Prose Edda: Skaldskaparmal
- `first500.449` Prose Edda: Hattatal
- `first500.450` Mabinogion: Pwyll Prince of Dyfed
- `first500.451` Mabinogion: Branwen Daughter of Llyr
- `first500.452` Mabinogion: Manawydan Son of Llyr
- `first500.453` Mabinogion: Math Son of Mathonwy
- `first500.454` Mabinogion: Peredur Son of Efrawg
- `first500.455` Mabinogion: Owain, or the Lady of the Fountain
- `first500.456` Mabinogion: Geraint Son of Erbin
- `first500.457` Mabinogion: The Dream of Macsen Wledig
- `first500.458` Mabinogion: Lludd and Llefelys
- `first500.459` Mabinogion: Culhwch and Olwen
- `first500.460` Mabinogion: The Dream of Rhonabwy

### Mesoamerican, African, and Oceanic

- `first500.461` Kumulipo Chant 01
- `first500.462` Kumulipo Chant 02
- `first500.463` Kumulipo Chant 03
- `first500.464` Kumulipo Chant 04
- `first500.465` Kumulipo Chant 05
- `first500.466` Kumulipo Chant 06
- `first500.467` Kumulipo Chant 07
- `first500.468` Kumulipo Chant 08
- `first500.469` Kumulipo Chant 09
- `first500.470` Kumulipo Chant 10
- `first500.471` Kumulipo Chant 11
- `first500.472` Kumulipo Chant 12
- `first500.473` Kumulipo Chant 13
- `first500.474` Kumulipo Chant 14
- `first500.475` Kumulipo Chant 15
- `first500.476` Kumulipo Chant 16
- `first500.477` Popol Vuh: Preamble
- `first500.478` Popol Vuh: Part 1
- `first500.479` Popol Vuh: Part 2
- `first500.480` Popol Vuh: Part 3
- `first500.481` Popol Vuh: Part 4
- `first500.482` Nahua Myth: Five Suns
- `first500.483` Nahua Myth: Birth of Huitzilopochtli
- `first500.484` Nahua Myth: Quetzalcoatl and Tollan
- `first500.485` Nahua Myth: Journey to Mictlan
- `first500.486` Nahua Myth: Tlalocan and the Rain Powers
- `first500.487` Ifa Odu: Eji Ogbe
- `first500.488` Ifa Odu: Oyeku Meji
- `first500.489` Ifa Odu: Iwori Meji
- `first500.490` Ifa Odu: Odi Meji
- `first500.491` Ifa Odu: Irosun Meji
- `first500.492` Ifa Odu: Owonrin Meji
- `first500.493` Ifa Odu: Obara Meji
- `first500.494` Ifa Odu: Okanran Meji
- `first500.495` Anansi Cycle: How Anansi Got the Stories
- `first500.496` Anansi Cycle: Anansi and the Pot of Wisdom
- `first500.497` Anansi Cycle: Anansi and Turtle
- `first500.498` Anansi Cycle: Anansi and Death
- `first500.499` Anansi Cycle: Anansi and the Sky God
- `first500.500` Maori Creation Cycle: Rangi and Papa

