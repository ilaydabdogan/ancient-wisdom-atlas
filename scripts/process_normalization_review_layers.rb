#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "optparse"
require "set"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TODAY = Date.today.iso8601
RUN_ID = "normalization-suggestions-2026-04-29-full-gap-priority"
REVIEW_PATH = File.join(ROOT, "data", "reviews", "normalization-suggestions", RUN_ID, "auto-acceptance.yml")
TAXONOMY_PATH = File.join(ROOT, "taxonomy", "motif-normalization.yml")
MOTIF_INDEX_PATH = File.join(ROOT, "data", "indexes", "motif-occurrences.yml")
STATE_PATH = File.join(ROOT, "data", "reviews", "normalization-suggestions", RUN_ID, "layer-processing.yml")

STOPWORDS = %w[
  a an and are as at be by for from in into is its of on or the their through to under with without
  after before during whose who whom which this that these those
  motif sacred divine human mythic supernatural ritual
].to_set.freeze

options = { layer: nil }
OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/process_normalization_review_layers.rb --layer LAYER"
  parser.on("--layer LAYER", "layer1, layer2, layer3, or layer4") { |value| options[:layer] = value }
end.parse!

abort "--layer is required" unless options[:layer]

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def write_yaml(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "#{YAML.dump(data)}\n")
end

def slug(value)
  value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
end

def titleize(value)
  value.to_s.split(/[_\s-]+/).reject(&:empty?).map(&:capitalize).join(" ")
end

def compact_text(value)
  value.to_s.gsub(/\s+/, " ").strip
end

def tokens(value)
  value.to_s.downcase.split(/[^a-z0-9]+/).reject do |token|
    token.empty? || token.length < 3 || STOPWORDS.include?(token)
  end
end

def markdown_escape(value)
  compact_text(value).gsub("|", "\\|")
end

def code(value)
  text = value.to_s
  text.empty? ? "" : "`#{text}`"
end

def groups_by_id(normalization)
  Array(normalization["canonical_motif_groups"]).each_with_object({}) do |group, memo|
    next unless group.is_a?(Hash)

    memo[group.fetch("id").to_s] = group
  end
end

def group_keyword_index(group)
  children = Array(group["children"]).flat_map { |child| tokens(child) }
  aliases = Array(group["aliases"]).flat_map { |item| tokens(item) }
  label = tokens([group["id"], group["label"]].join(" "))
  {
    children: children.to_set,
    all: (children + aliases + label).to_set
  }
end

def group_indexes(groups)
  groups.transform_values { |group| group_keyword_index(group) }
end

def existing_group_for_motif(motif_id, normalization, groups)
  raw = normalization.fetch("raw_motif_group_index", {})[motif_id]
  return raw["group_id"].to_s if raw.is_a?(Hash) && groups.key?(raw["group_id"].to_s)

  groups.each do |group_id, group|
    return group_id if Array(group["children"]).map(&:to_s).include?(motif_id)
    return group_id if Array(group["aliases"]).map(&:to_s).include?(motif_id)
  end

  alias_entry = normalization.fetch("aliases", {})[motif_id]
  Array(alias_entry && alias_entry["canonical_refs"]).each do |ref|
    return ref.to_s if groups.key?(ref.to_s)
  end
  Array(alias_entry && alias_entry["parent_refs"]).each do |ref|
    return ref.to_s if groups.key?(ref.to_s)
  end

  nil
end

def append_group_alias(normalization, group_id, motif_id)
  group = Array(normalization["canonical_motif_groups"]).find { |item| item.is_a?(Hash) && item["id"].to_s == group_id.to_s }
  return false unless group
  return false if Array(group["children"]).map(&:to_s).include?(motif_id.to_s)

  group["aliases"] ||= []
  return false if group["aliases"].map(&:to_s).include?(motif_id.to_s)

  group["aliases"] << motif_id.to_s
  true
end

def row_notes(row)
  [row["rationale"].to_s, row["cautions"].to_s.empty? ? nil : "Caution: #{row["cautions"]}"].compact.join(" ")
end

def raw_mapping(normalization, row, group_id, status, action, provisional: false, extra: {})
  motif_id = row.fetch("motif_id").to_s
  raw_index = normalization["raw_motif_group_index"] ||= {}
  previous = raw_index[motif_id]
  raw_index[motif_id] = {
    "group_id" => group_id.to_s,
    "relationship" => row["relationship"].to_s.empty? ? "reviewed_mapping" : row["relationship"].to_s,
    "confidence" => row["confidence"].to_s,
    "review_status" => status,
    "review_action" => action,
    "provisional" => provisional,
    "source" => "data/reviews/normalization-suggestions/#{RUN_ID}/auto-acceptance.yml",
    "accepted_on" => TODAY,
    "notes" => row_notes(row),
    "suggested_aliases" => Array(row["suggested_aliases"]).map(&:to_s)
  }.merge(extra)
  raw_index[motif_id]["previous_review_status"] = previous["review_status"] if previous.is_a?(Hash) && previous["review_status"]
end

def map_to_existing_group?(row, groups)
  groups.key?(row["suggested_group_id"].to_s)
end

def group_name_substring?(motif_id, group)
  haystack = motif_id.to_s.downcase
  names = [
    group["id"],
    slug(group["label"]),
    slug(group["label"].to_s.gsub(/\b(and|the|of)\b/i, " "))
  ].map(&:to_s).reject(&:empty?).uniq
  names.any? { |name| haystack.include?(name) }
end

def child_keyword_overlap?(motif_id, group, keyword_indexes)
  motif_tokens = tokens(motif_id).to_set
  overlap = motif_tokens & keyword_indexes.fetch(group.fetch("id")).fetch(:children)
  overlap.length >= 2
end

def best_group_for_text(text, groups, keyword_indexes, preferred = [])
  preferred.each do |group_id|
    return [group_id, "preferred_parent_or_suggested_group"] if groups.key?(group_id.to_s)
  end

  query_tokens = tokens(text).to_set
  best = groups.map do |group_id, group|
    label_tokens = tokens([group_id, group["label"]].join(" ")).to_set
    child_tokens = keyword_indexes.fetch(group_id).fetch(:children)
    score = ((query_tokens & label_tokens).length * 3) + (query_tokens & child_tokens).length
    [group_id, score]
  end.max_by { |(_group_id, score)| score }

  return [nil, "no_keyword_fit"] unless best && best[1].to_i >= 2

  [best[0], "keyword_fit_score_#{best[1]}"]
end

def review_rows
  load_yaml(REVIEW_PATH).fetch("review_needed")
end

def motif_index_ids
  load_yaml(MOTIF_INDEX_PATH).fetch("motifs").map { |motif| motif.fetch("motif_id").to_s }.to_set
end

def mapping_counts(normalization)
  ids = motif_index_ids
  mapped_ids = ids.select { |motif_id| normalization.fetch("raw_motif_group_index", {}).key?(motif_id) }.to_set
  groups_by_id(normalization).each_value do |group|
    Array(group["children"]).each { |motif_id| mapped_ids.add(motif_id.to_s) if ids.include?(motif_id.to_s) }
    Array(group["aliases"]).each { |motif_id| mapped_ids.add(motif_id.to_s) if ids.include?(motif_id.to_s) }
  end
  normalization.fetch("aliases", {}).each_key { |motif_id| mapped_ids.add(motif_id.to_s) if ids.include?(motif_id.to_s) }
  { "motif_count" => ids.length, "mapped" => mapped_ids.length, "unmapped" => ids.length - mapped_ids.length }
end

def write_state(layer, summary)
  state = File.file?(STATE_PATH) ? load_yaml(STATE_PATH) : {}
  state["run_id"] = RUN_ID
  state["updated_on"] = TODAY
  state["layers"] ||= {}
  state["layers"][layer] = summary
  write_yaml(STATE_PATH, state)
end

def write_layer1_report(summary, exclusions, duplicates)
  path = File.join(ROOT, "docs", "normalization-review-layer-1.md")
  lines = []
  lines << "# Normalization Review Layer 1"
  lines << ""
  lines << "Generated on #{TODAY}."
  lines << ""
  lines << "## Summary"
  lines << ""
  summary.each { |key, value| lines << "- #{key.tr("_", " ")}: #{value}" }
  lines << ""
  lines << "## Accepted Exclusions"
  lines << ""
  lines << "| Motif ID | Label | Occurrences | Traditions | Confidence | Reason |"
  lines << "| --- | --- | ---: | --- | --- | --- |"
  exclusions.sort_by { |row| [-row["occurrences"].to_i, row["motif_id"].to_s] }.each do |row|
    lines << "| #{code(row["motif_id"])} | #{markdown_escape(row["label"])} | #{row["occurrences"].to_i} | #{markdown_escape(Array(row["traditions"]).join(", "))} | #{markdown_escape(row["confidence"])} | accepted exclusion |"
  end
  lines << ""
  lines << "## Duplicate Motifs Merged As Aliases"
  lines << ""
  lines << "| Motif ID | Label | Merged Into | Occurrences | Traditions |"
  lines << "| --- | --- | --- | ---: | --- |"
  duplicates.sort_by { |row| [-row["occurrences"].to_i, row["motif_id"].to_s] }.each do |row|
    lines << "| #{code(row["motif_id"])} | #{markdown_escape(row["label"])} | #{code(row["merged_group_id"])} | #{row["occurrences"].to_i} | #{markdown_escape(Array(row["traditions"]).join(", "))} |"
  end
  File.write(path, lines.join("\n") + "\n")
end

def write_layer2_report(summary, accepted, held)
  path = File.join(ROOT, "docs", "normalization-review-layer-2.md")
  lines = []
  lines << "# Normalization Review Layer 2"
  lines << ""
  lines << "Generated on #{TODAY}."
  lines << ""
  lines << "Rule: accept low-confidence existing-group suggestions only when the group name appears in the motif ID or the motif ID shares at least two keywords with the suggested group's existing children. Accepted rows are marked provisional."
  lines << ""
  lines << "## Summary"
  lines << ""
  summary.each { |key, value| lines << "- #{key.tr("_", " ")}: #{value}" }
  lines << ""
  lines << "## Provisionally Accepted Low-Confidence Items"
  lines << ""
  lines << "| Motif ID | Label | Group | Match Rule | Occurrences | Traditions |"
  lines << "| --- | --- | --- | --- | ---: | --- |"
  accepted.sort_by { |row| [-row["occurrences"].to_i, row["motif_id"].to_s] }.each do |row|
    lines << "| #{code(row["motif_id"])} | #{markdown_escape(row["label"])} | #{code(row["accepted_group_id"])} | #{markdown_escape(row["match_rule"])} | #{row["occurrences"].to_i} | #{markdown_escape(Array(row["traditions"]).join(", "))} |"
  end
  lines << ""
  lines << "## Held For Later Review"
  lines << ""
  lines << "| Motif ID | Label | Suggested Group | Occurrences | Traditions | Reason Held |"
  lines << "| --- | --- | --- | ---: | --- | --- |"
  held.sort_by { |row| [-row["occurrences"].to_i, row["motif_id"].to_s] }.each do |row|
    lines << "| #{code(row["motif_id"])} | #{markdown_escape(row["label"])} | #{code(row["suggested_group_id"])} | #{row["occurrences"].to_i} | #{markdown_escape(Array(row["traditions"]).join(", "))} | #{markdown_escape(row["held_reason"])} |"
  end
  File.write(path, lines.join("\n") + "\n")
end

def new_group_key(row)
  candidate = row["suggested_new_group"].is_a?(Hash) ? row["suggested_new_group"] : {}
  label = candidate["label"].to_s.empty? ? row["suggested_group_label"].to_s : candidate["label"].to_s
  id = candidate["id"].to_s.empty? ? slug(label) : candidate["id"].to_s
  { "id" => id, "label" => label.empty? ? titleize(id) : label, "candidate" => candidate }
end

def near_duplicate_group?(left, right)
  left_tokens = tokens([left["id"], left["label"]].join(" ")).to_set
  right_tokens = tokens([right["id"], right["label"]].join(" ")).to_set
  return false if left_tokens.empty? || right_tokens.empty?

  intersection = (left_tokens & right_tokens).length
  union = (left_tokens | right_tokens).length
  return true if intersection >= 2 && (intersection.to_f / union) >= 0.55
  return true if intersection >= 2 && (left_tokens.subset?(right_tokens) || right_tokens.subset?(left_tokens))

  false
end

def consolidate_new_groups(rows)
  clusters = []
  rows.each do |row|
    key = new_group_key(row)
    cluster = clusters.find { |existing| near_duplicate_group?(existing, key) }
    unless cluster
      cluster = {
        "id" => key["id"],
        "label" => key["label"],
        "rows" => [],
        "parent_group_ids" => [],
        "related_group_ids" => []
      }
      clusters << cluster
    end
    cluster["rows"] << row
    candidate = key["candidate"]
    cluster["parent_group_ids"].concat(Array(candidate["parent_group_ids"]).map(&:to_s))
    cluster["related_group_ids"].concat(Array(candidate["related_group_ids"]).map(&:to_s))
  end

  clusters.each do |cluster|
    best_key = cluster["rows"].map { |row| new_group_key(row) }.group_by { |key| key["id"] }.max_by { |_id, keys| keys.length }[1].first
    cluster["id"] = best_key["id"]
    cluster["label"] = best_key["label"]
    cluster["parent_group_ids"].uniq!
    cluster["related_group_ids"].uniq!
  end
  clusters
end

def write_layer3_report(summary, genuine, folds)
  yaml_path = File.join(ROOT, "data", "reviews", "normalization-suggestions", RUN_ID, "new-group-candidates-condensed.yml")
  markdown_path = File.join(ROOT, "docs", "normalization-review-layer-3-new-groups.md")
  write_yaml(yaml_path, {
    "generated_on" => TODAY,
    "run_id" => RUN_ID,
    "summary" => summary,
    "genuine_new_group_candidates" => genuine,
    "folded_single_tradition_candidates" => folds
  })

  lines = []
  lines << "# Normalization Review Layer 3: New Group Candidates"
  lines << ""
  lines << "Generated on #{TODAY}."
  lines << ""
  lines << "Rule: consolidate near-duplicates, keep only candidates with evidence from two or more traditions as genuine new group candidates, and fold one-tradition candidates into the nearest existing family."
  lines << ""
  lines << "## Summary"
  lines << ""
  summary.each { |key, value| lines << "- #{key.tr("_", " ")}: #{value}" }
  lines << ""
  lines << "## Genuine New Group Candidates"
  lines << ""
  lines << "| Candidate | Traditions | Source Motifs | Suggested Parents | Recommendation |"
  lines << "| --- | ---: | ---: | --- | --- |"
  genuine.each do |item|
    lines << "| #{code(item["id"])} #{markdown_escape(item["label"])} | #{Array(item["traditions"]).length} | #{Array(item["source_motif_ids"]).length} | #{markdown_escape(Array(item["suggested_parent_group_ids"]).join(", "))} | keep pending for human review |"
  end
  lines << ""
  lines << "## Folded Single-Tradition Candidates"
  lines << ""
  lines << "| Candidate | Traditions | Source Motifs | Fold Target | Basis |"
  lines << "| --- | --- | ---: | --- | --- |"
  folds.each do |item|
    lines << "| #{code(item["id"])} #{markdown_escape(item["label"])} | #{markdown_escape(Array(item["traditions"]).join(", "))} | #{Array(item["source_motif_ids"]).length} | #{code(item["fold_target_group_id"])} | #{markdown_escape(item["fold_basis"])} |"
  end
  File.write(markdown_path, lines.join("\n") + "\n")
end

def write_layer4_report(summary, accepted, held)
  path = File.join(ROOT, "docs", "normalization-review-layer-4-best-fit.md")
  lines = []
  lines << "# Normalization Review Layer 4"
  lines << ""
  lines << "Generated on #{TODAY}."
  lines << ""
  lines << "Rule: attempt best-fit provisional placement for missing-group and human-review items. Items without a confident keyword or preferred-parent fit remain unmapped."
  lines << ""
  lines << "## Summary"
  lines << ""
  summary.each { |key, value| lines << "- #{key.tr("_", " ")}: #{value}" }
  lines << ""
  lines << "## Provisionally Placed"
  lines << ""
  lines << "| Motif ID | Label | Group | Basis | Occurrences | Traditions |"
  lines << "| --- | --- | --- | --- | ---: | --- |"
  accepted.sort_by { |row| [-row["occurrences"].to_i, row["motif_id"].to_s] }.each do |row|
    lines << "| #{code(row["motif_id"])} | #{markdown_escape(row["label"])} | #{code(row["accepted_group_id"])} | #{markdown_escape(row["fit_basis"])} | #{row["occurrences"].to_i} | #{markdown_escape(Array(row["traditions"]).join(", "))} |"
  end
  lines << ""
  lines << "## Still Unmapped"
  lines << ""
  lines << "| Motif ID | Label | Suggested Group | Reason | Occurrences | Traditions |"
  lines << "| --- | --- | --- | --- | ---: | --- |"
  held.sort_by { |row| [-row["occurrences"].to_i, row["motif_id"].to_s] }.each do |row|
    lines << "| #{code(row["motif_id"])} | #{markdown_escape(row["label"])} | #{code(row["suggested_group_id"])} #{markdown_escape(row["suggested_group_label"])} | #{markdown_escape(row["held_reason"])} | #{row["occurrences"].to_i} | #{markdown_escape(Array(row["traditions"]).join(", "))} |"
  end
  File.write(path, lines.join("\n") + "\n")
end

normalization = load_yaml(TAXONOMY_PATH)
groups = groups_by_id(normalization)
keyword_indexes = group_indexes(groups)
rows = review_rows
summary = {}

case options[:layer]
when "layer1"
  exclusions = rows.select { |row| row["reason"].to_s == "suggested exclusion" }
  duplicates = rows.select { |row| row["reason"].to_s == "already mapped in main taxonomy" }
  normalization["excluded_from_pattern_queries"] ||= {}

  exclusions.each do |row|
    motif_id = row.fetch("motif_id").to_s
    normalization["excluded_from_pattern_queries"][motif_id] = {
      "label" => row["label"].to_s,
      "reason" => row_notes(row),
      "confidence" => row["confidence"].to_s,
      "accepted_on" => TODAY,
      "source" => "data/reviews/normalization-suggestions/#{RUN_ID}/auto-acceptance.yml"
    }
    raw_mapping(normalization, row, "_excluded_from_pattern_queries", "human_reviewed_excluded", "excluded_from_pattern_queries")
  end

  duplicate_records = []
  duplicates.each do |row|
    motif_id = row.fetch("motif_id").to_s
    group_id = existing_group_for_motif(motif_id, normalization, groups)
    group_id ||= row["suggested_group_id"].to_s if groups.key?(row["suggested_group_id"].to_s)
    next unless group_id && groups.key?(group_id)

    append_group_alias(normalization, group_id, motif_id)
    raw_mapping(normalization, row, group_id, "human_reviewed_duplicate_alias", "merged_as_alias", extra: { "duplicate_alias" => true })
    duplicate_records << row.merge("merged_group_id" => group_id)
  end

  summary = {
    "accepted_exclusions" => exclusions.length,
    "duplicate_aliases_merged" => duplicate_records.length,
    "mapping_counts_after_layer" => mapping_counts(normalization)
  }
  write_layer1_report(summary, exclusions, duplicate_records)
when "layer2"
  accepted = []
  held = []
  rows.select { |row| row["reason"].to_s == "low confidence" }.each do |row|
    motif_id = row.fetch("motif_id").to_s
    group_id = row["suggested_group_id"].to_s
    unless groups.key?(group_id)
      held << row.merge("held_reason" => "no existing suggested group")
      next
    end
    group = groups.fetch(group_id)
    match_rule =
      if group_name_substring?(motif_id, group)
        "group_name_substring"
      elsif child_keyword_overlap?(motif_id, group, keyword_indexes)
        "two_child_keyword_overlap"
      end

    if match_rule
      raw_mapping(
        normalization,
        row,
        group_id,
        "provisional_low_confidence_keyword_match",
        "mapped_provisionally",
        provisional: true,
        extra: { "match_rule" => match_rule }
      )
      accepted << row.merge("accepted_group_id" => group_id, "match_rule" => match_rule)
    else
      held << row.merge("held_reason" => "no substring or two-keyword child overlap")
    end
  end

  summary = {
    "low_confidence_reviewed" => accepted.length + held.length,
    "provisionally_mapped" => accepted.length,
    "held_unmapped" => held.length,
    "mapping_counts_after_layer" => mapping_counts(normalization)
  }
  write_layer2_report(summary, accepted, held)
when "layer3"
  source_rows = rows.select { |row| row["reason"].to_s == "new group candidate" }
  clusters = consolidate_new_groups(source_rows)
  genuine = []
  folds = []

  clusters.each do |cluster|
    cluster_rows = cluster.fetch("rows")
    traditions = cluster_rows.flat_map { |row| Array(row["traditions"]).map(&:to_s) }.reject(&:empty?).uniq.sort
    source_motif_ids = cluster_rows.map { |row| row.fetch("motif_id").to_s }.uniq.sort
    preferred = cluster["parent_group_ids"].select { |id| groups.key?(id.to_s) }
    preferred += cluster["related_group_ids"].select { |id| groups.key?(id.to_s) }
    group_id, basis = best_group_for_text(
      [cluster["id"], cluster["label"], cluster_rows.map { |row| [row["label"], row["rationale"], row["cautions"]] }].flatten.join(" "),
      groups,
      keyword_indexes,
      preferred
    )

    if traditions.length >= 2
      genuine << {
        "id" => cluster["id"],
        "label" => cluster["label"],
        "traditions" => traditions,
        "source_motif_ids" => source_motif_ids,
        "suggested_parent_group_ids" => cluster["parent_group_ids"],
        "suggested_related_group_ids" => cluster["related_group_ids"],
        "recommended_action" => "keep_as_genuine_new_group_candidate"
      }
    elsif group_id
      cluster_rows.each do |row|
        raw_mapping(
          normalization,
          row,
          group_id,
          "human_reviewed_new_group_folded_single_tradition",
          "folded_into_existing_group",
          provisional: true,
          extra: { "fold_basis" => basis, "folded_candidate_id" => cluster["id"] }
        )
      end
      folds << {
        "id" => cluster["id"],
        "label" => cluster["label"],
        "traditions" => traditions,
        "source_motif_ids" => source_motif_ids,
        "fold_target_group_id" => group_id,
        "fold_basis" => basis,
        "recommended_action" => "fold_into_existing_group"
      }
    else
      genuine << {
        "id" => cluster["id"],
        "label" => cluster["label"],
        "traditions" => traditions,
        "source_motif_ids" => source_motif_ids,
        "suggested_parent_group_ids" => cluster["parent_group_ids"],
        "suggested_related_group_ids" => cluster["related_group_ids"],
        "recommended_action" => "needs_manual_review_no_fold_target"
      }
    end
  end

  summary = {
    "source_new_group_rows" => source_rows.length,
    "consolidated_candidates" => clusters.length,
    "genuine_new_group_candidates" => genuine.length,
    "folded_single_tradition_candidates" => folds.length,
    "folded_source_motifs_mapped" => folds.sum { |item| Array(item["source_motif_ids"]).length },
    "mapping_counts_after_layer" => mapping_counts(normalization)
  }
  write_layer3_report(summary, genuine, folds)
when "layer4"
  accepted = []
  held = []
  source_rows = rows.select do |row|
    ["suggested group is not present in main taxonomy", "model requested human review"].include?(row["reason"].to_s)
  end

  source_rows.each do |row|
    preferred = []
    preferred << row["suggested_group_id"].to_s if groups.key?(row["suggested_group_id"].to_s)
    candidate = row["suggested_new_group"].is_a?(Hash) ? row["suggested_new_group"] : {}
    preferred.concat(Array(candidate["parent_group_ids"]).map(&:to_s).select { |id| groups.key?(id) })
    preferred.concat(Array(candidate["related_group_ids"]).map(&:to_s).select { |id| groups.key?(id) })

    group_id, basis = best_group_for_text(
      [row["motif_id"], row["label"], row["suggested_group_label"], row["rationale"], row["cautions"]].join(" "),
      groups,
      keyword_indexes,
      preferred
    )

    if group_id
      raw_mapping(
        normalization,
        row,
        group_id,
        "provisional_human_review_best_fit",
        "best_fit_provisional",
        provisional: true,
        extra: { "fit_basis" => basis }
      )
      accepted << row.merge("accepted_group_id" => group_id, "fit_basis" => basis)
    else
      held << row.merge("held_reason" => basis)
    end
  end

  summary = {
    "reviewed" => source_rows.length,
    "provisionally_mapped" => accepted.length,
    "held_unmapped" => held.length,
    "mapping_counts_after_layer" => mapping_counts(normalization)
  }
  write_layer4_report(summary, accepted, held)
else
  abort "unknown layer: #{options[:layer]}"
end

normalization["updated_on"] = TODAY
normalization["review_queue_layer_processing"] ||= {}
normalization["review_queue_layer_processing"][options[:layer]] = summary
write_yaml(TAXONOMY_PATH, normalization)
write_state(options[:layer], summary)

puts "processed #{options[:layer]}"
summary.each { |key, value| puts "#{key}=#{value.inspect}" }
