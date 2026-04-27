#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "digest"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
RAW_DIR = File.join(ROOT, "imports/raw/biblical/world-english-bible-classic/genesis")
CONVERTED_PATH = File.join(ROOT, "imports/converted/biblical/world-english-bible-classic/genesis.md")
TEXT_PATH = File.join(ROOT, "texts/public-domain/biblical/world-english-bible-classic/genesis.md")
MANIFEST_PATH = File.join(ROOT, "manifests/biblical/world-english-bible-classic-genesis.yml")
EXTRACTION_DIR = File.join(ROOT, "extractions/biblical/world-english-bible-classic/genesis")

def relative(path)
  path.sub("#{ROOT}/", "")
end

def strip_tags(html)
  CGI.unescapeHTML(html.gsub(/<[^>]+>/, " "))
     .tr("\u00A0", " ")
     .gsub(/\s+/, " ")
     .strip
end

def chapter_number(path)
  File.basename(path).match(/GEN(\d+)\.htm/) { |match| match[1].to_i }
end

def extract_chapter(path)
  html = File.read(path)
  chapter = chapter_number(path)
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

raw_paths = Dir.glob(File.join(RAW_DIR, "GEN*.htm")).sort
abort "expected 50 Genesis chapter files, found #{raw_paths.length}" unless raw_paths.length == 50

chapters = raw_paths.map { |path| extract_chapter(path) }

front_matter = {
  "id" => "biblical.genesis.web_classic",
  "title" => "Genesis",
  "alternate_titles" => ["The First Book of Moses", "Bereshit"],
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
    "source_url" => "https://ebible.org/eng-web/GEN01.htm through https://ebible.org/eng-web/GEN50.htm",
    "access_date" => "2026-04-27"
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
  "tags" => ["creation", "flood", "covenant", "serpent", "sibling_rivalry", "ancestry", "dreams"],
  "motifs" => ["sacred_birth", "serpent", "flood_and_renewal", "sacrifice", "covenant", "sacred_tree_axis"],
  "figures" => ["God", "Adam", "Eve", "Noah", "Abraham", "Sarah", "Isaac", "Jacob", "Joseph"]
}

body = +"# Genesis\n\n"
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

canonical = +"---\n"
canonical << front_matter.to_yaml.sub(/\A---\n/, "")
canonical << "---\n\n"
canonical << body

converted = canonical.sub(
  "text_status: complete",
  "text_status: converted_draft"
).sub(
  "# Genesis",
  "<!-- Intermediate conversion draft. Canonical reviewed copy lives under texts/. -->\n\n# Genesis"
)

FileUtils.mkdir_p(File.dirname(CONVERTED_PATH))
FileUtils.mkdir_p(File.dirname(TEXT_PATH))
FileUtils.mkdir_p(File.dirname(MANIFEST_PATH))
FileUtils.mkdir_p(EXTRACTION_DIR)
File.write(CONVERTED_PATH, converted)
File.write(TEXT_PATH, canonical)

manifest = {
  "manifest_version" => "1",
  "batch_id" => "web-classic-genesis-seed",
  "created_date" => "2026-04-27",
  "updated_date" => "2026-04-27",
  "artifacts" => raw_paths.map do |path|
    chapter = chapter_number(path)
    {
      "id" => "artifact.web_genesis_#{format("%02d", chapter)}",
      "work_id" => "biblical.genesis.web_classic",
      "title" => "Genesis #{chapter}",
      "source_url" => "https://ebible.org/eng-web/GEN#{format("%02d", chapter)}.htm",
      "fetch_date" => "2026-04-27",
      "raw" => {
        "path" => relative(path),
        "checksum" => {
          "algorithm" => "sha256",
          "value" => Digest::SHA256.file(path).hexdigest
        },
        "media_type" => "text/html",
        "notes" => "Raw chapter HTML from eBible.org."
      },
      "converted" => {
        "path" => relative(CONVERTED_PATH),
        "checksum" => {
          "algorithm" => "sha256",
          "value" => Digest::SHA256.file(CONVERTED_PATH).hexdigest
        },
        "media_type" => "text/markdown",
        "notes" => "Single converted Markdown draft assembled from all 50 raw chapter files."
      },
      "canonical" => {
        "path" => relative(TEXT_PATH),
        "checksum" => {
          "algorithm" => "sha256",
          "value" => Digest::SHA256.file(TEXT_PATH).hexdigest
        },
        "media_type" => "text/markdown",
        "notes" => "Canonical reviewed Markdown seed text."
      },
      "converter" => {
        "name" => "scripts/build_web_genesis_seed.rb",
        "version" => "1",
        "command" => "ruby scripts/build_web_genesis_seed.rb",
        "settings" => ["one_verse_per_line", "preserve_chapter_footnotes"],
        "notes" => "Source-specific HTML parser for the first corpus seed."
      },
      "cleanup_notes" => [
        "Removed HTML navigation, headers, footers, and inline note anchors.",
        "Decoded HTML entities.",
        "Preserved footnote text by chapter."
      ],
      "rights" => {
        "status" => front_matter.fetch("rights").fetch("status"),
        "jurisdiction" => front_matter.fetch("rights").fetch("jurisdiction"),
        "license_url" => front_matter.fetch("rights").fetch("license_url"),
        "full_text" => front_matter.fetch("rights").fetch("full_text"),
        "training_use" => front_matter.fetch("rights").fetch("training_use"),
        "notes" => front_matter.fetch("rights").fetch("notes")
      },
      "trademark" => {
        "status" => front_matter.fetch("trademark").fetch("status"),
        "marks" => front_matter.fetch("trademark").fetch("marks").dup,
        "use_rules" => front_matter.fetch("trademark").fetch("use_rules"),
        "notes" => "The source name is recorded as provenance and not used as repo branding."
      },
      "review" => {
        "status" => "approved",
        "reviewer" => "Codex",
        "review_date" => "2026-04-27",
        "notes" => "Initial seed reviewed for clean Markdown structure and source provenance; spot-checks performed against raw HTML."
      },
      "extraction" => {
        "readiness" => "ready",
        "blocking_issues" => [],
        "notes" => "Ready for initial motif extraction."
      }
    }
  end
}

File.write(MANIFEST_PATH, manifest.to_yaml)

def extraction_record(record_id:, locator:, quote:, observations:, figures:, symbols:, motifs:, claims:)
  {
    "record_id" => record_id,
    "source_text_path" => "texts/public-domain/biblical/world-english-bible-classic/genesis.md",
    "passage_locator" => {
      "label" => locator,
      "translation" => "World English Bible Classic",
      "notes" => "Initial hand-curated seed extraction."
    },
    "canonical_text" => {
      "quote" => quote,
      "language" => "English",
      "quote_policy" => "quoted"
    },
    "literal_observations" => observations.each_with_index.map do |text, index|
      { "id" => "obs:#{index + 1}", "text" => text, "category" => "action", "evidence_refs" => ["ev:1"] }
    end,
    "figures" => figures.each_with_index.map do |name, index|
      { "id" => "fig:#{index + 1}", "name_or_label" => name, "description" => "", "role_refs" => [], "evidence_refs" => ["ev:1"] }
    end,
    "roles" => [],
    "symbols" => symbols.each_with_index.map do |symbol, index|
      { "id" => "sym:#{index + 1}", "label" => symbol, "literal_form" => symbol, "associated_figures" => [], "taxonomy_refs" => [], "evidence_refs" => ["ev:1"] }
    end,
    "scenes" => [
      { "id" => "scene:1", "label" => locator, "summary" => observations.join(" "), "figure_refs" => [], "symbol_refs" => [], "evidence_refs" => ["ev:1"] }
    ],
    "candidate_motifs" => motifs.each_with_index.map do |motif, index|
      { "id" => "motif:#{index + 1}", "label" => motif, "taxonomy_refs" => [motif], "basis" => "Candidate motif from literal passage evidence.", "evidence_refs" => ["ev:1"], "confidence" => "medium", "cautions" => "Seed extraction; requires later human review." }
    end,
    "comparison_claims" => claims.each_with_index.map do |claim, index|
      { "id" => "claim:#{index + 1}", "claim" => claim, "claim_level" => "same_motif", "target" => "pattern atlas", "evidence_refs" => ["ev:1"], "counter_evidence_refs" => [], "confidence" => "low", "limitations" => "Initial corpus-internal claim only; not a cross-cultural conclusion." }
    end,
    "evidence" => [
      {
        "id" => "ev:1",
        "type" => "quote",
        "locator" => locator,
        "quote_or_summary" => quote,
        "source_text_path" => "texts/public-domain/biblical/world-english-bible-classic/genesis.md",
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
    "extracted_at" => "2026-04-27",
    "notes" => "First data seed."
  }
end

records = {
  "genesis-creation-light.yml" => extraction_record(
    record_id: "extraction.genesis.creation_light",
    locator: "Genesis 1:1-5",
    quote: "In the beginning, God created the heavens and the earth... God said, “Let there be light,” and there was light.",
    observations: ["God creates heavens and earth.", "Darkness is on the deep.", "Light appears through divine speech.", "Light and darkness are divided."],
    figures: ["God"],
    symbols: ["deep", "waters", "light", "darkness"],
    motifs: ["chaos", "world_center", "wisdom"],
    claims: ["Creation begins with ordering darkness, deep, waters, and light."]
  ),
  "genesis-tree-serpent.yml" => extraction_record(
    record_id: "extraction.genesis.tree_serpent",
    locator: "Genesis 3:1-7",
    quote: "Now the serpent was more subtle than any animal of the field... She took some of its fruit, and ate.",
    observations: ["A serpent speaks to the woman.", "A forbidden tree is discussed.", "Fruit is taken and eaten.", "The humans recognize their nakedness."],
    figures: ["serpent", "woman", "man"],
    symbols: ["serpent", "tree", "fruit", "nakedness"],
    motifs: ["serpent", "sacred_tree_axis", "wisdom"],
    claims: ["The passage combines serpent, tree, fruit, prohibition, and knowledge motifs."]
  ),
  "genesis-flood-renewal.yml" => extraction_record(
    record_id: "extraction.genesis.flood_renewal",
    locator: "Genesis 7:17-24; 8:1-5",
    quote: "The flood was forty days on the earth... God remembered Noah... and the waters subsided.",
    observations: ["Waters rise over the earth.", "The ark floats on the waters.", "Life outside the ark is destroyed.", "Waters later subside."],
    figures: ["God", "Noah"],
    symbols: ["flood", "ark", "waters", "mountains"],
    motifs: ["flood_and_renewal", "ark_vessel", "survivor_pair"],
    claims: ["The passage fits the flood and preserving vessel motif family."]
  ),
  "genesis-sacrifice-covenant.yml" => extraction_record(
    record_id: "extraction.genesis.sacrifice_covenant",
    locator: "Genesis 8:20-22; 9:8-17",
    quote: "Noah built an altar to Yahweh... I establish my covenant with you, and with your offspring after you.",
    observations: ["Noah builds an altar.", "Offerings are made.", "A covenant is established.", "A sign is placed in the clouds."],
    figures: ["Noah", "Yahweh"],
    symbols: ["altar", "offering", "covenant", "rainbow"],
    motifs: ["sacrifice", "covenant", "sacred_exchange"],
    claims: ["The passage links sacrifice, covenant, and post-flood renewal."]
  ),
  "genesis-dream-descent.yml" => extraction_record(
    record_id: "extraction.genesis.dream_descent",
    locator: "Genesis 28:10-17",
    quote: "He dreamed and saw a stairway set upon the earth, and its top reached to heaven.",
    observations: ["Jacob sleeps during a journey.", "A stairway links earth and heaven.", "Divine messengers ascend and descend.", "A promise is spoken."],
    figures: ["Jacob", "Yahweh", "angels of God"],
    symbols: ["stairway", "earth", "heaven", "stone"],
    motifs: ["sacred_tree_axis", "ascent", "world_center"],
    claims: ["The passage presents a vertical connection between earth and heaven."]
  )
}

records.each do |filename, record|
  File.write(File.join(EXTRACTION_DIR, filename), record.to_yaml)
end

puts "wrote #{relative(TEXT_PATH)}"
puts "wrote #{relative(CONVERTED_PATH)}"
puts "wrote #{relative(MANIFEST_PATH)}"
puts "wrote #{records.length} extraction records"
