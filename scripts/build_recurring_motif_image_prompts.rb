#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DEFAULT_INDEX_PATH = "data/indexes/motif-occurrences.yml"
DEFAULT_TAXONOMY_PATH = "taxonomy/motifs.yml"
DEFAULT_PROMPTS_PATH = "tmp/imagegen/recurring-motif-prompts.jsonl"
DEFAULT_MANIFEST_PATH = "output/imagegen/recurring-motifs/manifest.yml"
DEFAULT_OUTPUT_DIR = "output/imagegen/recurring-motifs"
DEFAULT_MODEL = ENV.fetch("IMAGEGEN_MODEL", "gpt-image-2")
DEFAULT_SIZE = ENV.fetch("IMAGEGEN_SIZE", "1536x1024")
DEFAULT_QUALITY = ENV.fetch("IMAGEGEN_QUALITY", "high")

def relative_path(path)
  File.expand_path(path, ROOT).sub("#{ROOT}/", "")
end

def project_path(path)
  File.expand_path(path, ROOT)
end

def safe_slug(value)
  value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
end

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def write_jsonl(path, records)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, records.map { |record| JSON.generate(record) }.join("\n") + "\n")
end

def write_yaml(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "#{YAML.dump(data)}\n")
end

def motif_description(motif_id, motif_data)
  return motif_data.fetch("description") if motif_data.is_a?(Hash) && motif_data["description"].to_s.strip != ""

  "A recurring sacred or mythic pattern attested in more than one tradition."
end

def prompt_for(motif, taxonomy_entry)
  motif_id = motif.fetch("motif_id")
  label = motif.fetch("label")
  traditions = motif.fetch("traditions").keys.sort
  description = motif_description(motif_id, taxonomy_entry)
  related = Array(taxonomy_entry && taxonomy_entry["related"]).join(", ")

  subject = [
    "A symbolic cross-cultural image for the motif '#{label}'.",
    "Core meaning: #{description}",
    ("Related symbolic ideas: #{related}." unless related.empty?),
    "Traditions represented in the data: #{traditions.join(", ")}."
  ].compact.join(" ")

  {
    "prompt" => [
      "Create one refined image for the Ancient Wisdom Atlas recurring motif '#{label}'.",
      subject,
      "Show the motif as a universal symbolic scene, not as a literal collage of religions.",
      "Use layered archetypal imagery: ancient stone, luminous sky, ritual objects, threshold spaces, water, fire, trees, mountains, stars, veils, vessels, or paths only where they fit the motif.",
      "Make it contemplative, numinous, and scholarly: a sacred atlas plate that a mystic and a historian would both respect.",
      "No written words, no labels, no logos, no modern objects, no imitation of a living tradition's private ritual, no caricature, no gore."
    ].join(" "),
    "use_case" => "stylized-concept",
    "style" => "museum-quality mythic concept art, illuminated manuscript texture blended with ancient fresco and subtle cinematic realism",
    "composition" => "square atlas plate, central symbolic composition, balanced negative space, clear silhouette, no border text",
    "lighting" => "numinous dawn-and-twilight glow, soft volumetric light, sacred but restrained",
    "palette" => "deep lapis, warm gold, mineral red, bone white, charcoal, weathered stone; varied accents so the set is not one-note",
    "constraints" => "respectful cross-cultural symbolism; no text, no watermark, no logo, no modern typography, no specific copyrighted character",
    "negative" => "new age poster cliches, neon fantasy excess, horror, gore, photoreal celebrity faces, random letters, illegible script, UI elements",
    "size" => DEFAULT_SIZE,
    "quality" => DEFAULT_QUALITY,
    "model" => DEFAULT_MODEL,
    "out" => "#{safe_slug(motif_id)}.png"
  }
end

index_path = project_path(ARGV[0] || DEFAULT_INDEX_PATH)
taxonomy_path = project_path(ARGV[1] || DEFAULT_TAXONOMY_PATH)
prompts_path = project_path(ARGV[2] || DEFAULT_PROMPTS_PATH)
manifest_path = project_path(ARGV[3] || DEFAULT_MANIFEST_PATH)
output_dir = DEFAULT_OUTPUT_DIR

occurrence_index = load_yaml(index_path)
taxonomy = load_yaml(taxonomy_path).fetch("motif_families", {})
recurring = occurrence_index.fetch("motifs").select do |motif|
  motif.fetch("traditions", {}).keys.size > 1
end

jobs = recurring.map do |motif|
  prompt_for(motif, taxonomy[motif.fetch("motif_id")])
end

manifest = {
  "motif_image_prompt_manifest_version" => "1",
  "generated_on" => Date.today.iso8601,
  "source_index_path" => relative_path(index_path),
  "taxonomy_path" => relative_path(taxonomy_path),
  "prompt_jsonl_path" => relative_path(prompts_path),
  "output_dir" => output_dir,
  "model" => DEFAULT_MODEL,
  "size" => DEFAULT_SIZE,
  "quality" => DEFAULT_QUALITY,
  "recurring_motif_count" => recurring.length,
  "motifs" => recurring.map do |motif|
    {
      "motif_id" => motif.fetch("motif_id"),
      "label" => motif.fetch("label"),
      "tradition_count" => motif.fetch("traditions", {}).keys.size,
      "occurrence_count" => motif.fetch("occurrences", []).size,
      "traditions" => motif.fetch("traditions", {}).keys.sort,
      "output_path" => File.join(output_dir, "#{safe_slug(motif.fetch("motif_id"))}.png")
    }
  end
}

write_jsonl(prompts_path, jobs)
write_yaml(manifest_path, manifest)

puts "wrote #{relative_path(prompts_path)}"
puts "wrote #{relative_path(manifest_path)}"
puts "recurring motifs: #{recurring.length}"
