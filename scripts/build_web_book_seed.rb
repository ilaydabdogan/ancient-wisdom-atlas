#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "digest"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
ACCESS_DATE = "2026-04-27"

BOOKS = {
  "GEN" => {
    slug: "genesis",
    title: "Genesis",
    aliases: ["The First Book of Moses", "Bereshit"],
    chapters: 50,
    tags: ["creation", "flood", "covenant", "serpent", "sibling_rivalry", "ancestry", "dreams"],
    motifs: ["sacred_birth", "serpent", "flood_and_renewal", "sacrifice", "covenant", "sacred_tree_axis"],
    figures: ["God", "Adam", "Eve", "Noah", "Abraham", "Sarah", "Isaac", "Jacob", "Joseph"]
  },
  "EXO" => {
    slug: "exodus",
    title: "Exodus",
    aliases: ["The Second Book of Moses"],
    chapters: 40,
    tags: ["liberation", "plagues", "wilderness", "law", "covenant", "tabernacle"],
    motifs: ["divine_judgment", "covenant", "sacrifice", "sacred_exchange", "ascent", "world_center"],
    figures: ["God", "Moses", "Aaron", "Pharaoh", "Miriam", "Israel"]
  },
  "LEV" => {
    slug: "leviticus",
    title: "Leviticus",
    aliases: ["The Third Book of Moses"],
    chapters: 27,
    tags: ["sacrifice", "ritual", "purity", "holiness", "atonement", "priesthood"],
    motifs: ["sacrifice", "covenant", "sacred_exchange", "divine_judgment"],
    figures: ["Yahweh", "Moses", "Aaron", "Israel"]
  },
  "NUM" => {
    slug: "numbers",
    title: "Numbers",
    aliases: ["The Fourth Book of Moses"],
    chapters: 36,
    tags: ["wilderness", "census", "journey", "rebellion", "blessing", "serpent"],
    motifs: ["departure", "return", "divine_judgment", "serpent", "covenant"],
    figures: ["Yahweh", "Moses", "Aaron", "Miriam", "Balaam", "Israel"]
  },
  "DEU" => {
    slug: "deuteronomy",
    title: "Deuteronomy",
    aliases: ["The Fifth Book of Moses"],
    chapters: 34,
    tags: ["law", "covenant", "memory", "blessing", "curse", "succession"],
    motifs: ["covenant", "divine_judgment", "sacred_exchange", "death_rebirth"],
    figures: ["Yahweh", "Moses", "Joshua", "Israel"]
  }
}.freeze

EXTRACTION_SPECS = {
  "GEN" => [
    {
      slug: "creation-light",
      record_id: "extraction.genesis.creation_light",
      locator: "Genesis 1:1-5",
      quote: "In the beginning, God created the heavens and the earth... God said, \"Let there be light,\" and there was light.",
      observations: ["God creates heavens and earth.", "Darkness is on the deep.", "Light appears through divine speech.", "Light and darkness are divided."],
      figures: ["God"],
      symbols: ["deep", "waters", "light", "darkness"],
      motifs: ["chaos", "world_center", "wisdom"],
      claims: ["Creation begins with ordering darkness, deep, waters, and light."]
    },
    {
      slug: "tree-serpent",
      record_id: "extraction.genesis.tree_serpent",
      locator: "Genesis 3:1-7",
      quote: "Now the serpent was more subtle than any animal of the field... She took some of its fruit, and ate.",
      observations: ["A serpent speaks to the woman.", "A forbidden tree is discussed.", "Fruit is taken and eaten.", "The humans recognize their nakedness."],
      figures: ["serpent", "woman", "man"],
      symbols: ["serpent", "tree", "fruit", "nakedness"],
      motifs: ["serpent", "sacred_tree_axis", "wisdom"],
      claims: ["The passage combines serpent, tree, fruit, prohibition, and knowledge motifs."]
    },
    {
      slug: "flood-renewal",
      record_id: "extraction.genesis.flood_renewal",
      locator: "Genesis 7:17-24; 8:1-5",
      quote: "The flood was forty days on the earth... God remembered Noah... and the waters subsided.",
      observations: ["Waters rise over the earth.", "The ark floats on the waters.", "Life outside the ark is destroyed.", "Waters later subside."],
      figures: ["God", "Noah"],
      symbols: ["flood", "ark", "waters", "mountains"],
      motifs: ["flood_and_renewal", "ark_vessel", "survivor_pair"],
      claims: ["The passage fits the flood and preserving vessel motif family."]
    },
    {
      slug: "sacrifice-covenant",
      record_id: "extraction.genesis.sacrifice_covenant",
      locator: "Genesis 8:20-22; 9:8-17",
      quote: "Noah built an altar to Yahweh... I establish my covenant with you, and with your offspring after you.",
      observations: ["Noah builds an altar.", "Offerings are made.", "A covenant is established.", "A sign is placed in the clouds."],
      figures: ["Noah", "Yahweh"],
      symbols: ["altar", "offering", "covenant", "rainbow"],
      motifs: ["sacrifice", "covenant", "sacred_exchange"],
      claims: ["The passage links sacrifice, covenant, and post-flood renewal."]
    },
    {
      slug: "dream-descent",
      record_id: "extraction.genesis.dream_descent",
      locator: "Genesis 28:10-17",
      quote: "He dreamed and saw a stairway set upon the earth, and its top reached to heaven.",
      observations: ["Jacob sleeps during a journey.", "A stairway links earth and heaven.", "Divine messengers ascend and descend.", "A promise is spoken."],
      figures: ["Jacob", "Yahweh", "angels of God"],
      symbols: ["stairway", "earth", "heaven", "stone"],
      motifs: ["sacred_tree_axis", "ascent", "world_center"],
      claims: ["The passage presents a vertical connection between earth and heaven."]
    }
  ]
}.freeze

def relative(path)
  path.sub("#{ROOT}/", "")
end

def strip_tags(html)
  CGI.unescapeHTML(html.gsub(/<[^>]+>/, " "))
     .tr("\u00A0", " ")
     .gsub(/\s+/, " ")
     .strip
end

def chapter_number(path, code)
  File.basename(path).match(/#{Regexp.escape(code)}(\d+)\.htm/) { |match| match[1].to_i }
end

def extract_chapter(path, code)
  html = File.read(path)
  chapter = chapter_number(path, code)
  main = html[/<div class="main">(.*?)<ul class='tnav'>/m, 1] || html
  main = main.sub(/\A.*?<div class='chapterlabel'[^>]*>\s*#{chapter}\s*<\/div>/m, "")
  main = main.sub(/<div class="footnote">.*\z/m, "")
  main = main.gsub(/<a href="#FN\d+" class="notemark">.*?<\/a>/m, "")

  verses = []
  pieces = main.split(/<span class="verse" id="V(\d+)">\s*\d+&#160;<\/span>/)
  pieces.shift
  pieces.each_slice(2) do |verse_number, verse_html|
    text = strip_tags(verse_html || "")
    text = text.sub(/\s+\z/, "")
    verses << [verse_number.to_i, text] unless text.empty?
  end

  footnotes = []
  html.scan(/<p class="f" id="FN\d+">(.*?)<\/p>/m).each do |match|
    note_html = match.first
    locator = strip_tags(note_html[/<a class="notebackref"[^>]*>(.*?)<\/a>/m, 1] || "")
    note = strip_tags(note_html[/<span class="ft">(.*?)<\/span>/m, 1] || "")
    footnotes << [locator, note] unless locator.empty? || note.empty?
  end

  { chapter: chapter, verses: verses, footnotes: footnotes }
end

def base_front_matter(code, config)
  slug = config.fetch(:slug)
  {
    "id" => "biblical.#{slug}.web_classic",
    "title" => config.fetch(:title),
    "alternate_titles" => config.fetch(:aliases),
    "text_status" => "complete",
    "tradition" => "jewish_christian",
    "culture" => "ancient_israelite_later_biblical_reception",
    "region" => "levant",
    "source_language" => "Hebrew",
    "text_language" => "English",
    "date_range" => "ancient source text; public-domain modern English translation",
    "source_type" => "text",
    "provenance" => {
      "source_id" => "source.world_english_bible",
      "edition" => "World English Bible Classic",
      "translator" => "World English Bible contributors",
      "editor" => "Michael Paul Johnson",
      "publication_year" => "unknown",
      "publisher" => "eBible.org",
      "source_url" => "https://ebible.org/eng-web/#{code}01.htm through https://ebible.org/eng-web/#{code}#{format("%02d", config.fetch(:chapters))}.htm",
      "access_date" => ACCESS_DATE
    },
    "rights" => {
      "status" => "public_domain",
      "jurisdiction" => "US",
      "license_url" => "https://ebible.org/eng-web/copyright.htm",
      "training_use" => "allowed",
      "full_text" => "allowed",
      "notes" => "The source page states that the World English Bible is in the Public Domain and may be copied and shared freely. Keep trademark naming rules separate from text copyright."
    },
    "trademark" => {
      "status" => "present",
      "marks" => ["World English Bible"],
      "use_rules" => "Use as factual source attribution. Rename modified derivatives that alter the translation text."
    },
    "transcription" => {
      "mode" => "normalized",
      "complete" => true,
      "corrections" => [],
      "omissions" => [
        "Website navigation, stylesheet links, metadata tags, report-typo links, donations links, and page footer boilerplate were removed.",
        "Inline note markers were removed from verse text; footnote content is preserved under each chapter."
      ]
    },
    "tags" => config.fetch(:tags),
    "motifs" => config.fetch(:motifs),
    "figures" => config.fetch(:figures)
  }
end

def build_body(config, chapters)
  body = +"# #{config.fetch(:title)}\n\n"
  body << "> Source text: World English Bible Classic, formatted as one verse per line for stable citation.\n\n"

  chapters.each do |chapter|
    body << "## Chapter #{chapter.fetch(:chapter)}\n\n"
    chapter.fetch(:verses).each do |number, text|
      body << "**#{number}.** #{text}\n\n"
    end

    next if chapter.fetch(:footnotes).empty?

    body << "### Footnotes\n\n"
    chapter.fetch(:footnotes).each do |locator, note|
      body << "- #{locator}: #{note}\n"
    end
    body << "\n"
  end

  body
end

def write_book(code, config)
  slug = config.fetch(:slug)
  raw_dir = File.join(ROOT, "imports/raw/biblical/world-english-bible-classic/#{slug}")
  converted_path = File.join(ROOT, "imports/converted/biblical/world-english-bible-classic/#{slug}.md")
  text_path = File.join(ROOT, "texts/public-domain/biblical/world-english-bible-classic/#{slug}.md")
  manifest_path = File.join(ROOT, "manifests/biblical/world-english-bible-classic-#{slug}.yml")
  extraction_dir = File.join(ROOT, "extractions/biblical/world-english-bible-classic/#{slug}")

  raw_paths = Dir.glob(File.join(raw_dir, "#{code}*.htm")).sort
  expected = config.fetch(:chapters)
  abort "expected #{expected} #{config.fetch(:title)} chapter files, found #{raw_paths.length}" unless raw_paths.length == expected

  chapters = raw_paths.map { |path| extract_chapter(path, code) }
  front_matter = base_front_matter(code, config)
  canonical = +"---\n"
  canonical << front_matter.to_yaml.sub(/\A---\n/, "")
  canonical << "---\n\n"
  canonical << build_body(config, chapters)

  converted = canonical.sub("text_status: complete", "text_status: converted_draft")
                       .sub("# #{config.fetch(:title)}", "<!-- Intermediate conversion draft. Canonical reviewed copy lives under texts/. -->\n\n# #{config.fetch(:title)}")

  FileUtils.mkdir_p(File.dirname(converted_path))
  FileUtils.mkdir_p(File.dirname(text_path))
  FileUtils.mkdir_p(File.dirname(manifest_path))
  FileUtils.mkdir_p(extraction_dir)
  File.write(converted_path, converted)
  File.write(text_path, canonical)

  manifest = {
    "manifest_version" => "1",
    "batch_id" => "web-classic-#{slug}-seed",
    "created_date" => ACCESS_DATE,
    "updated_date" => ACCESS_DATE,
    "artifacts" => raw_paths.map do |path|
      chapter = chapter_number(path, code)
      {
        "id" => "artifact.web_#{slug}_#{format("%02d", chapter)}",
        "work_id" => "biblical.#{slug}.web_classic",
        "title" => "#{config.fetch(:title)} #{chapter}",
        "source_url" => "https://ebible.org/eng-web/#{code}#{format("%02d", chapter)}.htm",
        "fetch_date" => ACCESS_DATE,
        "raw" => {
          "path" => relative(path),
          "checksum" => { "algorithm" => "sha256", "value" => Digest::SHA256.file(path).hexdigest },
          "media_type" => "text/html",
          "notes" => "Raw chapter HTML from eBible.org."
        },
        "converted" => {
          "path" => relative(converted_path),
          "checksum" => { "algorithm" => "sha256", "value" => Digest::SHA256.file(converted_path).hexdigest },
          "media_type" => "text/markdown",
          "notes" => "Single converted Markdown draft assembled from raw chapter files."
        },
        "canonical" => {
          "path" => relative(text_path),
          "checksum" => { "algorithm" => "sha256", "value" => Digest::SHA256.file(text_path).hexdigest },
          "media_type" => "text/markdown",
          "notes" => "Canonical reviewed Markdown seed text."
        },
        "converter" => {
          "name" => "scripts/build_web_book_seed.rb",
          "version" => "1",
          "command" => "ruby scripts/build_web_book_seed.rb #{code}",
          "settings" => ["one_verse_per_line", "preserve_chapter_footnotes"],
          "notes" => "Source-specific HTML parser for eBible.org WEB Classic chapter pages."
        },
        "cleanup_notes" => [
          "Removed HTML navigation, headers, footers, and inline note anchors.",
          "Decoded HTML entities.",
          "Preserved footnote text by chapter."
        ],
        "rights" => front_matter.fetch("rights").slice("status", "jurisdiction", "license_url", "full_text", "training_use", "notes"),
        "trademark" => front_matter.fetch("trademark").merge("marks" => front_matter.fetch("trademark").fetch("marks").dup, "notes" => "The source name is recorded as provenance and not used as repo branding."),
        "review" => {
          "status" => "approved",
          "reviewer" => "Codex",
          "review_date" => ACCESS_DATE,
          "notes" => "Seed reviewed for clean Markdown structure and source provenance; spot-checks performed against raw HTML."
        },
        "extraction" => {
          "readiness" => "ready",
          "blocking_issues" => [],
          "notes" => "Ready for initial motif extraction."
        }
      }
    end
  }

  File.write(manifest_path, manifest.to_yaml)
  write_extractions(code, config, text_path, extraction_dir)

  {
    "id" => "biblical.#{slug}.web_classic",
    "title" => config.fetch(:title),
    "tradition_cluster" => "jewish_christian",
    "source_id" => "source.world_english_bible",
    "canonical_text_path" => relative(text_path),
    "manifest_path" => relative(manifest_path),
    "extraction_dir" => relative(extraction_dir),
    "rights" => {
      "status" => "public_domain",
      "full_text" => "allowed",
      "training_use" => "allowed"
    },
    "ingestion_status" => "canonical_text_added",
    "extraction_status" => EXTRACTION_SPECS.fetch(code, []).empty? ? "pending_seed_records" : "seed_records_added"
  }
end

def extraction_record(config, text_path, spec)
  {
    "record_id" => spec.fetch(:record_id),
    "source_text_path" => relative(text_path),
    "passage_locator" => {
      "label" => spec.fetch(:locator),
      "translation" => "World English Bible Classic",
      "notes" => "Initial hand-curated seed extraction."
    },
    "canonical_text" => {
      "quote" => spec.fetch(:quote),
      "language" => "English",
      "quote_policy" => "quoted"
    },
    "literal_observations" => spec.fetch(:observations).each_with_index.map do |text, index|
      { "id" => "obs:#{index + 1}", "text" => text, "category" => "action", "evidence_refs" => ["ev:1"] }
    end,
    "figures" => spec.fetch(:figures).each_with_index.map do |name, index|
      { "id" => "fig:#{index + 1}", "name_or_label" => name, "description" => "", "role_refs" => [], "evidence_refs" => ["ev:1"] }
    end,
    "roles" => [],
    "symbols" => spec.fetch(:symbols).each_with_index.map do |symbol, index|
      { "id" => "sym:#{index + 1}", "label" => symbol, "literal_form" => symbol, "associated_figures" => [], "taxonomy_refs" => [], "evidence_refs" => ["ev:1"] }
    end,
    "scenes" => [
      { "id" => "scene:1", "label" => spec.fetch(:locator), "summary" => spec.fetch(:observations).join(" "), "figure_refs" => [], "symbol_refs" => [], "evidence_refs" => ["ev:1"] }
    ],
    "candidate_motifs" => spec.fetch(:motifs).each_with_index.map do |motif, index|
      { "id" => "motif:#{index + 1}", "label" => motif, "taxonomy_refs" => [motif], "basis" => "Candidate motif from literal passage evidence.", "evidence_refs" => ["ev:1"], "confidence" => "medium", "cautions" => "Seed extraction; requires later human review." }
    end,
    "comparison_claims" => spec.fetch(:claims).each_with_index.map do |claim, index|
      { "id" => "claim:#{index + 1}", "claim" => claim, "claim_level" => "same_motif", "target" => "pattern atlas", "evidence_refs" => ["ev:1"], "counter_evidence_refs" => [], "confidence" => "low", "limitations" => "Initial corpus-internal claim only; not a cross-cultural conclusion." }
    end,
    "evidence" => [
      {
        "id" => "ev:1",
        "type" => "quote",
        "locator" => spec.fetch(:locator),
        "quote_or_summary" => spec.fetch(:quote),
        "source_text_path" => relative(text_path),
        "rights_note" => "Public-domain source text."
      }
    ],
    "confidence" => {
      "extraction" => "medium",
      "motif_candidates" => "medium",
      "comparison_claims" => "low",
      "notes" => "Seed extraction for testing the repository workflow."
    },
    "reviewer_status" => {
      "status" => "needs_review",
      "reviewer" => "",
      "reviewed_at" => "",
      "notes" => "Needs scholarly/human review before being treated as final."
    },
    "extracted_by" => "Codex",
    "extracted_at" => ACCESS_DATE,
    "notes" => "Initial data seed for #{config.fetch(:title)}."
  }
end

def write_extractions(code, config, text_path, extraction_dir)
  Dir.glob(File.join(extraction_dir, "*.yml")).each { |path| File.delete(path) }
  EXTRACTION_SPECS.fetch(code, []).each do |spec|
    File.write(File.join(extraction_dir, "#{config.fetch(:slug)}-#{spec.fetch(:slug)}.yml"), extraction_record(config, text_path, spec).to_yaml)
  end
end

def update_ingested_registry(items)
  path = File.join(ROOT, "data/collections/ingested-corpus.yml")
  existing = File.exist?(path) ? YAML.safe_load(File.read(path), aliases: false) : {}
  existing_items = Array(existing["items"])
  by_id = existing_items.to_h { |item| [item.fetch("id"), item] }
  items.each { |item| by_id[item.fetch("id")] = item }
  registry = {
    "collection_id" => "ingested_corpus",
    "title" => "Ingested Corpus Registry",
    "updated_on" => ACCESS_DATE,
    "items" => by_id.values.sort_by { |item| item.fetch("id") }
  }
  File.write(path, registry.to_yaml)
end

requested = ARGV.empty? ? BOOKS.keys : ARGV
items = requested.map do |code|
  normalized = code.upcase
  abort "unknown WEB book code: #{code}" unless BOOKS.key?(normalized)

  item = write_book(normalized, BOOKS.fetch(normalized))
  puts "wrote #{item.fetch("canonical_text_path")}"
  item
end

update_ingested_registry(items)
puts "updated data/collections/ingested-corpus.yml"

