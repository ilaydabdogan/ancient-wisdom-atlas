#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "date"
require "fileutils"
require "json"
require "set"
require "yaml"

ROOT = File.expand_path("..", __dir__)
SITE_DIR = File.join(ROOT, "site")

NAV = [
  ["Home", "index.html"],
  ["Findings", "findings/index.html"],
  ["Explorer", "explorer/index.html"],
  ["Texts", "texts/index.html"],
  ["Motifs", "motifs/index.html"],
  ["Taxonomy", "taxonomy/index.html"],
  ["Timeline", "timeline/index.html"],
  ["Comparisons", "comparisons/index.html"],
  ["Patterns", "patterns/index.html"],
  ["Extractions", "extractions/index.html"]
].freeze

TRADITION_LABELS = {
  "jewish_christian" => "Biblical",
  "buddhist" => "Buddhist",
  "daoist" => "Daoist",
  "confucian" => "Confucian",
  "egyptian" => "Egyptian",
  "finnish_karelian" => "Finnish/Karelian",
  "greek" => "Greek",
  "hindu" => "Hindu",
  "islamic" => "Islamic",
  "islamicate_folklore" => "Islamicate Folklore",
  "sufi" => "Sufi",
  "maya_quiche" => "Maya/Kiche",
  "mesopotamian" => "Mesopotamian",
  "norse" => "Norse",
  "persian" => "Persian",
  "celtic_irish" => "Celtic Irish",
  "celtic_welsh" => "Celtic Welsh",
  "indigenous_australian" => "Indigenous Australian",
  "greek_roman" => "Greek/Roman",
  "comparative" => "Comparative",
  "roman" => "Roman",
  "japanese" => "Japanese",
  "ainu" => "Ainu"
}.freeze

def relative(path)
  path.sub("#{ROOT}/", "")
end

def site_path(*parts)
  File.join(SITE_DIR, *parts)
end

def slugify(value)
  value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
end

def esc(value)
  CGI.escapeHTML(value.to_s)
end

def format_count(value)
  value.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
end

def read_markdown(path)
  raw = File.read(path)
  if raw.start_with?("---\n")
    parts = raw.split(/^---\s*$/, 3)
    metadata = YAML.safe_load(parts[1] || "", permitted_classes: [Date, Time], aliases: false) || {}
    body = parts[2] || ""
  else
    metadata = {}
    body = raw
  end
  { metadata: metadata, body: body.strip }
end

def output_for_repo_path(path)
  case path
  when %r{\Atexts/(.+)\.md\z}
    ["texts", "#{slugify(Regexp.last_match(1))}.html"].join("/")
  when %r{\Apatterns/(.+)\.md\z}
    ["patterns", "#{slugify(Regexp.last_match(1))}.html"].join("/")
  when %r{\Acomparisons/(.+)\.md\z}
    name = Regexp.last_match(1)
    return "comparisons/index.html" if name == "README"

    ["comparisons", "#{slugify(name)}.html"].join("/")
  when %r{\Aextractions/(.+)\.ya?ml\z}
    ["extractions", "#{slugify(Regexp.last_match(1))}.html"].join("/")
  else
    nil
  end
end

def motif_output(motif_id)
  ["motifs", "#{slugify(motif_id)}.html"].join("/")
end

def relative_url(from_output, to_output)
  from_dir = File.dirname(from_output)
  PathnameRelative.relative(from_dir, to_output)
end

module PathnameRelative
  module_function

  def relative(from_dir, to_path)
    from_parts = from_dir == "." ? [] : from_dir.split("/")
    to_parts = to_path.split("/")
    while from_parts.any? && to_parts.any? && from_parts.first == to_parts.first
      from_parts.shift
      to_parts.shift
    end
    rel = ([".."] * from_parts.length + to_parts).join("/")
    rel.empty? ? "." : rel
  end
end

def nav_html(current_output)
  links = NAV.map do |label, target|
    href = relative_url(current_output, target)
    active = current_output == target || current_output.start_with?(File.dirname(target) + "/")
    %(<a class="nav-link#{active ? " active" : ""}" href="#{esc(href)}">#{esc(label)}</a>)
  end
  links.join("\n")
end

def layout(title:, subtitle: nil, current_output:, body:, page_class: nil, extra_head: nil)
  css = relative_url(current_output, "assets/style.css")
  js = relative_url(current_output, "assets/app.js")
  <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{esc(title)} | Ancient Wisdom Atlas</title>
      <meta name="description" content="A Markdown-first atlas of ancient wisdom, myth, sacred texts, motifs, and cross-cultural comparison.">
      <link rel="stylesheet" href="#{esc(css)}">
      #{extra_head}
    </head>
    <body class="#{esc(page_class)}">
      <header class="site-header">
        <a class="brand" href="#{esc(relative_url(current_output, "index.html"))}">
          <span class="brand-mark">AWA</span>
          <span>
            <strong>Ancient Wisdom Atlas</strong>
            <small>texts, motifs, patterns</small>
          </span>
        </a>
        <nav class="site-nav" aria-label="Primary navigation">
          #{nav_html(current_output)}
        </nav>
      </header>
      <main>
        <section class="page-heading">
          <p class="eyebrow">Comparative mythology corpus</p>
          <h1>#{esc(title)}</h1>
          #{subtitle ? "<p class=\"lead\">#{esc(subtitle)}</p>" : ""}
        </section>
        #{body}
      </main>
      <footer class="site-footer">
        <span>Generated from Markdown and YAML corpus files.</span>
        <a href="#{esc(relative_url(current_output, "motifs/index.html"))}">Browse motif evidence</a>
      </footer>
      <script src="#{esc(js)}" defer></script>
    </body>
    </html>
  HTML
end

def write_page(output, html)
  path = site_path(output)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, html)
end

def inline_markdown(text, current_output)
  escaped = esc(text)
  escaped.gsub!(/`([^`]+)`/, "<code>\\1</code>")
  escaped.gsub!(/\[([^\]]+)\]\(([^)]+)\)/) do
    label = Regexp.last_match(1)
    href = Regexp.last_match(2)
    href_path, href_anchor = href.split("#", 2)
    target = href_path.sub(/\A\.\.\//, "")
    mapped = output_for_repo_path(target)

    if mapped.nil? && href_path.match?(/\.(?:md|ya?ml)\z/) && !href_path.match?(/\A[a-z]+:/)
      current_repo_dir = File.dirname(current_output)
      candidate = File.join(current_repo_dir, href_path).sub(%r{\A\./}, "")
      mapped = output_for_repo_path(candidate)
    end

    if mapped
      final_href = relative_url(current_output, mapped)
      final_href = "#{final_href}##{href_anchor}" if href_anchor
      %(<a href="#{esc(final_href)}">#{label}</a>)
    elsif href_path.match?(/\A[a-z]+:/) || href_path.include?("/") || href_path.end_with?(".html") || href_path.start_with?("#")
      final_href = href_path
      final_href = "#{final_href}##{href_anchor}" if href_anchor
      %(<a href="#{esc(final_href)}">#{label}</a>)
    else
      esc("[#{label}](#{href})")
    end
  end
  escaped
end

def render_markdown(md, current_output)
  lines = md.lines(chomp: true)
  html = []
  paragraph = []
  in_ul = false
  in_ol = false
  in_code = false
  code_lines = []
  table_buffer = []

  flush_paragraph = lambda do
    next if paragraph.empty?

    html << "<p>#{inline_markdown(paragraph.join(' '), current_output)}</p>"
    paragraph = []
  end

  flush_lists = lambda do
    if in_ul
      html << "</ul>"
      in_ul = false
    end
    if in_ol
      html << "</ol>"
      in_ol = false
    end
  end

  flush_table = lambda do
    next if table_buffer.empty?

    rows = table_buffer.reject { |line| line.match?(/\A\|\s*[-: ]+\|/) }
    html << "<div class=\"table-wrap\"><table>"
    rows.each_with_index do |line, index|
      cells = line.strip.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map(&:strip)
      tag = index.zero? ? "th" : "td"
      html << "<tr>#{cells.map { |cell| "<#{tag}>#{inline_markdown(cell, current_output)}</#{tag}>" }.join}</tr>"
    end
    html << "</table></div>"
    table_buffer = []
  end

  lines.each do |line|
    if line.start_with?("```")
      flush_paragraph.call
      flush_lists.call
      flush_table.call
      if in_code
        html << "<pre><code>#{esc(code_lines.join("\n"))}</code></pre>"
        code_lines = []
        in_code = false
      else
        in_code = true
      end
      next
    end

    if in_code
      code_lines << line
      next
    end

    if line.strip.empty?
      flush_paragraph.call
      flush_lists.call
      flush_table.call
      next
    end

    if line.start_with?("|")
      flush_paragraph.call
      flush_lists.call
      table_buffer << line
      next
    else
      flush_table.call
    end

    if (match = line.match(/\A(#{'#'}{1,4})\s+(.+)\z/))
      flush_paragraph.call
      flush_lists.call
      level = [match[1].length + 1, 6].min
      html << "<h#{level}>#{inline_markdown(match[2], current_output)}</h#{level}>"
    elsif line.start_with?("> ")
      flush_paragraph.call
      flush_lists.call
      html << "<blockquote>#{inline_markdown(line[2..], current_output)}</blockquote>"
    elsif (match = line.match(/\A-\s+(.+)\z/))
      flush_paragraph.call
      unless in_ul
        flush_lists.call
        html << "<ul>"
        in_ul = true
      end
      html << "<li>#{inline_markdown(match[1], current_output)}</li>"
    elsif (match = line.match(/\A\d+\.\s+(.+)\z/))
      flush_paragraph.call
      unless in_ol
        flush_lists.call
        html << "<ol>"
        in_ol = true
      end
      html << "<li>#{inline_markdown(match[1], current_output)}</li>"
    else
      paragraph << line.strip
    end
  end

  flush_paragraph.call
  flush_lists.call
  flush_table.call
  html.join("\n")
end

def tradition_label(value)
  TRADITION_LABELS.fetch(value.to_s, value.to_s.split("_").map(&:capitalize).join(" "))
end

def titleize(value)
  value.to_s.tr("_-", " ").split.map(&:capitalize).join(" ")
end

def link_to_output(current_output, output, label)
  return esc(label) if output.nil? || output.empty?

  %(<a href="#{esc(relative_url(current_output, output))}">#{esc(label)}</a>)
end

def compact_text(value)
  value.to_s.strip.gsub(/\s+/, " ")
end

def taxonomy_anchor(group_id)
  "family-#{slugify(group_id)}"
end

def taxonomy_family_output(group_id)
  ["taxonomy", "families", "#{slugify(group_id)}.html"].join("/")
end

def taxonomy_value_chips(values, group_lookup = {}, current_output = nil)
  list = Array(values).compact.reject { |value| value.to_s.strip.empty? }
  return %(<span class="muted">None yet</span>) if list.empty?

  list.map do |value|
    id = value.to_s
    label = group_lookup.dig(id, "label") || titleize(id)
    if current_output && group_lookup.key?(id)
      %(<a class="chip" href="#{esc(taxonomy_family_href(current_output, id))}">#{esc(label)}</a>)
    else
      %(<span class="chip">#{esc(label)}</span>)
    end
  end.join
end

def safe_json_script(data)
  JSON.pretty_generate(data).gsub("</", "<\\/")
end

def taxonomy_family_href(current_output, group_id)
  relative_url(current_output, taxonomy_family_output(group_id))
end

def taxonomy_cluster_definitions
  [
    {
      "id" => "creation_cosmos",
      "label" => "Creation / Cosmos",
      "description" => "Origins, world renewal, sacred centers, and cosmic time.",
      "angle" => -2.45
    },
    {
      "id" => "death_afterlife",
      "label" => "Death / Afterlife",
      "description" => "Descent, the dead, soul logic, burial, and transformation.",
      "angle" => -1.50
    },
    {
      "id" => "hero_ordeal",
      "label" => "Hero / Ordeal",
      "description" => "Heroic trials, warriors, guardians, fate, and recognition.",
      "angle" => -0.35
    },
    {
      "id" => "knowledge_revelation",
      "label" => "Knowledge / Revelation",
      "description" => "Wisdom, visions, mystical quest, divine appearing, and sacred speech.",
      "angle" => 0.72
    },
    {
      "id" => "divine_spirit",
      "label" => "Divine / Spirit",
      "description" => "Gods, spirits, divine birth, intervention, tricksters, and enchanted realms.",
      "angle" => 1.62
    },
    {
      "id" => "sacred_order",
      "label" => "Sacred Order",
      "description" => "Law, covenant, offering, exchange, social order, and moral consequence.",
      "angle" => 2.55
    },
    {
      "id" => "liminal_forms",
      "label" => "Liminal Forms",
      "description" => "Boundary objects, vessels, paradox, beauty, fire, water, and other bridges.",
      "angle" => 3.40
    }
  ]
end

def taxonomy_cluster_for(group_or_id)
  group = group_or_id.is_a?(Hash) ? group_or_id : { "id" => group_or_id.to_s }
  id = group["id"].to_s
  explicit = {
    "cosmic_origin" => "creation_cosmos",
    "primordial_sacrifice" => "creation_cosmos",
    "axis_mundi" => "creation_cosmos",
    "flood_and_renewal" => "creation_cosmos",
    "sacred_time" => "creation_cosmos",
    "world_ages_cosmic_decline" => "creation_cosmos",
    "death_and_transformation" => "death_afterlife",
    "descent" => "death_afterlife",
    "afterlife_passage" => "death_afterlife",
    "external_soul" => "death_afterlife",
    "ancestor_rites" => "death_afterlife",
    "heroic_funeral_rites" => "death_afterlife",
    "immortality_without_renewal" => "death_afterlife",
    "soul_loss_restoration" => "death_afterlife",
    "death_by_fate" => "death_afterlife",
    "restless_dead_haunting_vengeance" => "death_afterlife",
    "hero_journey" => "hero_ordeal",
    "initiation" => "hero_ordeal",
    "threshold_guardian" => "hero_ordeal",
    "divine_warrior" => "hero_ordeal",
    "sacred_combat" => "hero_ordeal",
    "royal_legitimacy" => "hero_ordeal",
    "conditional_invulnerability_hidden_weakness" => "hero_ordeal",
    "betrayal_violated_trust" => "hero_ordeal",
    "recognition_tokens_hidden_identity" => "hero_ordeal",
    "fate_figures_cosmic_weaving" => "hero_ordeal",
    "theophany" => "knowledge_revelation",
    "sacred_knowledge" => "knowledge_revelation",
    "mystical_quest" => "knowledge_revelation",
    "ascent" => "knowledge_revelation",
    "dream_and_vision" => "knowledge_revelation",
    "storytelling_as_power" => "knowledge_revelation",
    "miraculous_child" => "divine_spirit",
    "mother_goddess" => "divine_spirit",
    "culture_hero" => "divine_spirit",
    "trickster" => "divine_spirit",
    "shapeshifter" => "divine_spirit",
    "divine_intervention" => "divine_spirit",
    "otherworld" => "divine_spirit",
    "divine_race" => "divine_spirit",
    "supreme_ruler" => "divine_spirit",
    "sacred_twins" => "divine_spirit",
    "serpent_guardian" => "divine_spirit",
    "sacrifice" => "sacred_order",
    "covenant" => "sacred_order",
    "sacred_exchange" => "sacred_order",
    "divine_judgment" => "sacred_order",
    "sacred_law" => "sacred_order",
    "pride_and_downfall" => "sacred_order",
    "hospitality_test_stranger_guest" => "sacred_order",
    "sacred_fire" => "liminal_forms",
    "sacred_vessel" => "liminal_forms",
    "sacred_treasures" => "liminal_forms",
    "sacred_waters" => "liminal_forms",
    "sacred_love" => "liminal_forms",
    "lament_and_mourning" => "liminal_forms",
    "beauty_and_paradox" => "liminal_forms",
    "sacred_craft" => "liminal_forms",
    "duality" => "liminal_forms"
  }
  return explicit[id] if explicit.key?(id)

  text = [id, group["label"], group["description"], group["children"], group["aliases"]].flatten.compact.join(" ").downcase
  return "death_afterlife" if text.match?(/death|dead|soul|afterlife|underworld|funeral|ancestor|haunt|rebirth|immortal/)
  return "creation_cosmos" if text.match?(/origin|creation|cosmic|world|flood|renewal|axis|time|earth|sky/)
  return "hero_ordeal" if text.match?(/hero|warrior|ordeal|guardian|battle|combat|fate|recognition|king/)
  return "knowledge_revelation" if text.match?(/wisdom|knowledge|quest|vision|dream|speech|story|theophany|ascent/)
  return "sacred_order" if text.match?(/law|covenant|sacrifice|offering|judgment|exchange|moral|rite|hospitality/)
  return "divine_spirit" if text.match?(/divine|god|goddess|spirit|trickster|child|birth|otherworld|serpent|shapeshift/)

  "liminal_forms"
end

def taxonomy_constellation_data(normalization, proposed_review, current_output, family_analyses = [])
  groups = normalization.fetch("canonical_motif_groups", []).reject { |group| group["id"].to_s.start_with?("_meta") }
  group_lookup = groups.to_h { |group| [group["id"].to_s, group] }
  analysis_lookup = family_analyses.to_h { |analysis| [analysis.fetch(:group_id).to_s, analysis] }
  nodes = []
  links = []
  link_keys = {}

  groups.each do |group|
    group_id = group["id"].to_s
    analysis = analysis_lookup[group_id]
    child_rows = Array(analysis && analysis[:child_motifs]).sort_by do |child|
      [-child[:occurrence_count].to_i, -child[:tradition_count].to_i, child[:label].to_s]
    end
    fallback_children = Array(group["children"]).map do |child_id|
      {
        "id" => child_id.to_s,
        "label" => titleize(child_id),
        "occurrence_count" => 0,
        "tradition_count" => 0,
        "relationship" => "child",
        "url" => relative_url(current_output, motif_output(child_id))
      }
    end
    children = if child_rows.any?
      child_rows.first(80).map do |child|
        {
          "id" => child[:motif_id].to_s,
          "label" => titleize(child[:label]),
          "occurrence_count" => child[:occurrence_count].to_i,
          "tradition_count" => child[:tradition_count].to_i,
          "relationship" => child[:relationship].to_s,
          "url" => relative_url(current_output, motif_output(child[:motif_id]))
        }
      end
    else
      fallback_children
    end
    related = Array(group["related"]).select { |id| group_lookup.key?(id.to_s) }
    nodes << {
      "id" => group_id,
      "label" => group["label"].to_s,
      "type" => "approved",
      "cluster" => taxonomy_cluster_for(group),
      "description" => compact_text(group["description"]),
      "child_count" => child_rows.any? ? child_rows.length : fallback_children.length,
      "visible_child_count" => children.length,
      "occurrence_count" => analysis ? analysis[:occurrence_count].to_i : 0,
      "tradition_count" => analysis ? analysis[:tradition_count].to_i : 0,
      "date_range" => analysis ? analysis[:date_range_label].to_s : "not yet dated",
      "children" => children,
      "related" => related.map do |id|
        {
          "id" => id.to_s,
          "label" => group_lookup.fetch(id.to_s)["label"].to_s,
          "url" => taxonomy_family_href(current_output, id)
        }
      end,
      "url" => taxonomy_family_href(current_output, group_id)
    }

    related.each do |target|
      pair = [group_id, target.to_s].sort
      key = pair.join("--")
      next if link_keys[key]

      link_keys[key] = true
      links << { "source" => pair.first, "target" => pair.last, "type" => "related" }
    end
  end

  proposed_review.fetch("genuine_new_group_candidates", []).each do |candidate|
    node_id = "pending:#{candidate["id"]}"
    children = Array(candidate["source_candidate_ids"]).map do |child_id|
      {
        "id" => child_id.to_s,
        "label" => titleize(child_id),
        "url" => relative_url(current_output, motif_output(child_id))
      }
    end
    parents = Array(candidate["suggested_parent_group_ids"]).select { |id| group_lookup.key?(id.to_s) }
    parent_group = parents.first ? group_lookup[parents.first.to_s] : nil
    nodes << {
      "id" => node_id,
      "label" => candidate["label"].to_s,
      "type" => "pending",
      "cluster" => parent_group ? taxonomy_cluster_for(parent_group) : "liminal_forms",
      "description" => candidate["rationale"].to_s,
      "child_count" => children.length,
      "visible_child_count" => children.length,
      "occurrence_count" => candidate["occurrence_count"].to_i,
      "tradition_count" => Array(candidate["traditions"]).length,
      "date_range" => "pending review",
      "children" => children,
      "related" => parents.map do |id|
        {
          "id" => id.to_s,
          "label" => group_lookup.fetch(id.to_s)["label"].to_s,
          "url" => taxonomy_family_href(current_output, id)
        }
      end,
      "url" => "#{relative_url(current_output, "taxonomy/index.html")}##{taxonomy_anchor(candidate["id"])}"
    }

    parents.each do |parent_id|
      links << { "source" => node_id, "target" => parent_id.to_s, "type" => "pending" }
    end
  end

  cluster_counts = nodes.each_with_object(Hash.new(0)) { |node, counts| counts[node["cluster"]] += 1 }
  clusters = taxonomy_cluster_definitions.map do |cluster|
    cluster.merge("node_count" => cluster_counts[cluster["id"]].to_i)
  end.select { |cluster| cluster["node_count"].positive? }

  cluster_order = clusters.each_with_index.to_h { |cluster, idx| [cluster["id"], idx] }
  grouped_nodes = nodes.group_by { |node| node["cluster"] }
  hierarchy_children = clusters.map do |cluster|
    bucket = Array(grouped_nodes[cluster["id"]]).sort_by do |node|
      [node["type"] == "pending" ? 1 : 0, -node["occurrence_count"].to_i, node["label"].to_s.downcase]
    end
    {
      "id" => cluster["id"],
      "label" => cluster["label"],
      "type" => "cluster",
      "description" => cluster["description"],
      "children" => bucket
    }
  end
  hierarchy = {
    "id" => "root",
    "label" => "",
    "type" => "root",
    "children" => hierarchy_children
  }

  node_id_set = nodes.to_h { |node| [node["id"], true] }
  cross_links = links.select { |link| node_id_set[link["source"]] && node_id_set[link["target"]] }

  {
    "clusters" => clusters,
    "hierarchy" => hierarchy,
    "cross_links" => cross_links
  }
end

def taxonomy_constellation_html(normalization, proposed_review, current_output, data_id:, family_analyses: [])
  data = taxonomy_constellation_data(normalization, proposed_review, current_output, family_analyses)
  <<~HTML
    <div class="constellation-map" data-source="#{esc(data_id)}">
      <div class="constellation-toolbar">
        <input type="search" class="constellation-search" placeholder="Find a family">
        <button type="button" class="constellation-expand-all" data-state="collapsed">Expand all clusters</button>
        <label class="constellation-toggle">
          <input type="checkbox" class="constellation-bundle-toggle" checked>
          <span>Show related-family links</span>
        </label>
        <div class="constellation-legend" aria-label="Constellation legend">
          <span><i></i> cluster &middot; click to expand</span>
          <span><i class="small"></i> family &middot; size = evidence</span>
          <span><i class="dash"></i> pending group</span>
        </div>
      </div>
      <div class="constellation-stage">
        <svg class="constellation-svg" role="img" aria-label="Radial dendrogram of motif taxonomy families"></svg>
        <aside class="constellation-panel" aria-live="polite">
          <span class="row-kicker">Selected Family</span>
          <h3>Choose A Family</h3>
          <p>Search or click a node to inspect evidence density, children, and related families.</p>
        </aside>
      </div>
    </div>
    <script type="application/json" id="#{esc(data_id)}">#{safe_json_script(data)}</script>
  HTML
end

def taxonomy_child_motif_ids(normalization, proposed_review)
  approved_children = normalization.fetch("canonical_motif_groups", []).flat_map { |group| Array(group["children"]) }
  pending_children = proposed_review.fetch("genuine_new_group_candidates", []).flat_map { |candidate| Array(candidate["source_candidate_ids"]) }
  (approved_children + pending_children).map(&:to_s).reject(&:empty?).uniq.sort
end

def build_taxonomy_family_pages(analyses)
  analysis_lookup = analyses.to_h { |analysis| [analysis.fetch(:group_id), analysis] }
  prototype_ids = analyses.first(5).map { |analysis| analysis.fetch(:group_id) }.to_set
  index_output = "taxonomy/families/index.html"
  family_list_id = "taxonomy-family-list"
  max_traditions = analyses.map { |analysis| analysis.fetch(:tradition_count).to_i }.max.to_i

  prototype_cards = analyses.first(5).map do |analysis|
    group = analysis.fetch(:group)
    body = "#{analysis.fetch(:occurrence_count)} occurrences across #{analysis.fetch(:tradition_count)} traditions; #{analysis.fetch(:child_motifs).length} mapped child motifs."
    card(group["label"], body, href: relative_url(index_output, taxonomy_family_output(group["id"])), meta: "high coverage")
  end.join

  family_rows = analyses.map do |analysis|
    group = analysis.fetch(:group)
    top_traditions = analysis.fetch(:traditions)
      .sort_by { |tradition, count| [-count.to_i, tradition_label(tradition)] }
      .first(5)
      .map { |tradition, count| "#{tradition_label(tradition)} (#{count})" }
      .join(", ")
    search_text = [
      group["id"],
      group["label"],
      group["description"],
      top_traditions,
      analysis.fetch(:child_motifs).map { |child| child[:label] }
    ].flatten.compact.join(" ")
    <<~HTML
      <article class="list-row searchable" data-search="#{esc(search_text)}" data-sort-item data-count="#{analysis.fetch(:occurrence_count).to_i}" data-label="#{esc(group["label"].to_s.downcase)}">
        <div>
          <span class="row-kicker">#{esc(group["id"])}#{prototype_ids.include?(analysis.fetch(:group_id)) ? " · prototype" : ""}</span>
          <h3><a href="#{esc(relative_url(index_output, taxonomy_family_output(group["id"])))}">#{esc(group["label"])}</a></h3>
          <p>#{esc(compact_text(group["description"])[0, 220])}</p>
          <p class="muted">#{esc(top_traditions)}</p>
        </div>
        <small>#{analysis.fetch(:occurrence_count)} occurrences · #{analysis.fetch(:tradition_count)} traditions</small>
      </article>
    HTML
  end.join

  index_body = <<~HTML
    <section class="stats-grid">
      <div class="stat"><strong>#{analyses.length}</strong><span>canonical families</span></div>
      <div class="stat"><strong>#{analyses.sum { |analysis| analysis.fetch(:occurrence_count) }}</strong><span>mapped occurrences</span></div>
      <div class="stat"><strong>#{analyses.sum { |analysis| analysis.fetch(:child_motifs).length }}</strong><span>mapped child motifs</span></div>
      <div class="stat"><strong>#{max_traditions}</strong><span>max traditions in one family</span></div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Most Evidenced Family Pages</h2>
        <a href="#{relative_url(index_output, "taxonomy/constellation.html")}">Open constellation</a>
      </div>
      <div class="card-grid">#{prototype_cards}</div>
    </section>

    <section class="toolbar">
      <input type="search" class="search-input" placeholder="Search families, motifs, or traditions" data-search-target=".searchable">
      <label class="sort-control">Sort
        <select data-sort-control="##{esc(family_list_id)}">
          <option value="count">Most occurrences</option>
          <option value="alpha">Alphabetical</option>
        </select>
      </label>
    </section>
    <section class="list-panel" id="#{esc(family_list_id)}">#{family_rows}</section>
  HTML

  write_page(index_output, layout(
    title: "Taxonomy Families",
    subtitle: "Canonical motif families as evidence-backed research pages, generated from the normalization taxonomy and extraction records.",
    current_output: index_output,
    body: index_body,
    page_class: "taxonomy-page"
  ))

  analyses.each do |analysis|
    group = analysis.fetch(:group)
    group_id = analysis.fetch(:group_id)
    current = taxonomy_family_output(group_id)
    child_sort_id = "child-motifs-#{slugify(group_id)}"
    max_tradition_count = analysis.fetch(:traditions).values.max.to_i
    comparison = family_comparison_summary(analysis)

    child_rows = analysis.fetch(:child_motifs)
      .sort_by { |child| [-child.fetch(:occurrence_count).to_i, child.fetch(:label).to_s] }
      .map do |child|
        count = child.fetch(:occurrence_count).to_i
        count_link = count.positive? ? %(<a href="#{esc(extraction_search_url(current, child.fetch(:motif_id)))}">#{format_count(count)}</a>) : %(<span class="muted">0</span>)
        <<~HTML
          <tr data-sort-item data-count="#{count}" data-label="#{esc(child.fetch(:label).downcase)}">
            <td>#{link_to_output(current, motif_output(child.fetch(:motif_id)), titleize(child.fetch(:label)))}</td>
            <td>#{esc(child.fetch(:relationship))}</td>
            <td>#{count_link}</td>
            <td>#{format_count(child.fetch(:tradition_count))}</td>
          </tr>
        HTML
      end.join

    tradition_rows = analysis.fetch(:traditions)
      .sort_by { |tradition, count| [-count.to_i, tradition_label(tradition)] }
      .map do |tradition, count|
        width = max_tradition_count.positive? ? ((count.to_f / max_tradition_count) * 100).round(1) : 0
        anchor = "tradition-#{slugify(tradition)}"
        <<~HTML
          <a class="family-tradition-row searchable" href="##{esc(anchor)}" data-search="#{esc([tradition, tradition_label(tradition)].join(" "))}">
            <span>#{esc(tradition_label(tradition))}</span>
            <strong>#{format_count(count)}</strong>
            <i style="width: #{width}%"></i>
          </a>
        HTML
      end.join

    tradition_sections = analysis.fetch(:occurrences)
      .group_by { |occurrence| occurrence["tradition"].to_s }
      .sort_by { |tradition, rows| [-rows.length, tradition_label(tradition)] }
      .map do |tradition, rows|
        sorted_rows = rows.sort_by { |occurrence| [occurrence["source_title"].to_s, occurrence["passage_locator"].to_s, occurrence["family_motif_label"].to_s] }
        preview_rows = sorted_rows.first(8)
        hidden_rows = sorted_rows.drop(8)
        more_rows = if hidden_rows.any?
          <<~HTML
            <details class="family-more-passages">
              <summary>Show #{format_count(hidden_rows.length)} more passages</summary>
              #{family_occurrence_table(hidden_rows, current)}
            </details>
          HTML
        else
          ""
        end
        tradition_search = [
          tradition,
          tradition_label(tradition),
          rows.map { |row| row["family_motif_label"] }.uniq.sort.first(80)
        ].flatten.join(" ")

        <<~HTML
          <details id="tradition-#{esc(slugify(tradition))}" class="family-tradition-section searchable" data-search="#{esc(tradition_search)}">
            <summary class="family-tradition-head">
              <div>
                <span class="row-kicker">#{esc(tradition_label(tradition))}</span>
                <h3>How This Tradition Tells It</h3>
              </div>
              <strong>#{format_count(rows.length)} occurrences</strong>
            </summary>
            <div class="family-tradition-body">
              <p>#{esc(family_tradition_summary(tradition, rows))}</p>
              #{family_occurrence_table(preview_rows, current)}
              #{more_rows}
            </div>
          </details>
        HTML
      end.join

    related_rows = Array(group["related"]).map(&:to_s).select { |id| analysis_lookup.key?(id) }.map do |related_id|
      related = analysis_lookup.fetch(related_id)
      <<~HTML
        <article class="related-family-row">
          <h3>#{link_to_output(current, taxonomy_family_output(related_id), related.fetch(:group)["label"])}</h3>
          <p>#{esc(related_family_note(analysis, related))}</p>
        </article>
      HTML
    end.join
    related_rows = %(<p class="muted">No explicit related families are listed yet.</p>) if related_rows.empty?

    timeline_rows = analysis.fetch(:timeline_entries)
      .sort_by { |entry| [timeline_sort_value(entry), entry["title"].to_s] }
      .map do |entry|
        count = analysis.fetch(:occurrences).count do |occurrence|
          Array(entry["current_text_paths"]).include?(occurrence["source_text_path"]) || occurrence["tradition"].to_s == entry["tradition_cluster"].to_s
        end
        <<~HTML
          <article class="family-timeline-row">
            <div class="timeline-date">#{esc(timeline_display(entry))}</div>
            <div>
              <h3>#{esc(entry["title"])}</h3>
              <p>#{esc([tradition_label(entry["tradition_cluster"]), entry["timeline_label"], "#{count} tagged occurrences"].compact.join(" - "))}</p>
            </div>
          </article>
        HTML
      end.join
    timeline_rows = %(<p class="muted">No timeline-backed source entry is available yet for this family.</p>) if timeline_rows.empty?

    top_child_chips = analysis.fetch(:child_motifs)
      .sort_by { |child| [-child.fetch(:occurrence_count).to_i, -child.fetch(:tradition_count).to_i, child.fetch(:label).to_s] }
      .first(10)
      .map do |child|
        count = child.fetch(:occurrence_count).to_i
        href = count.positive? ? extraction_search_url(current, child.fetch(:motif_id)) : relative_url(current, motif_output(child.fetch(:motif_id)))
        <<~HTML
          <a class="family-chip" href="#{esc(href)}">
            <span>#{esc(titleize(child.fetch(:label)))}</span>
            <strong>#{format_count(count)}</strong>
          </a>
        HTML
      end.join

    top_tradition_chips = analysis.fetch(:traditions)
      .sort_by { |tradition, count| [-count.to_i, tradition_label(tradition)] }
      .first(8)
      .map do |tradition, count|
        <<~HTML
          <a class="family-chip" href="#tradition-#{esc(slugify(tradition))}">
            <span>#{esc(tradition_label(tradition))}</span>
            <strong>#{format_count(count)}</strong>
          </a>
        HTML
      end.join

    body = <<~HTML
      <nav class="family-tabs" aria-label="Family page sections">
        <a href="#overview">Overview</a>
        <a href="#child-motifs">Child Motifs</a>
        <a href="#traditions">Traditions</a>
        <a href="#evidence">Evidence</a>
        <a href="#comparison">Comparison</a>
        <a href="#related">Related</a>
        <a href="#timeline">Timeline</a>
      </nav>

      <section id="overview" class="family-hero-panel">
        <p>#{esc(compact_text(group["description"]))}</p>
        <div class="family-stats">
          <div class="stat"><strong>#{format_count(analysis.fetch(:occurrence_count))}</strong><span>total occurrences</span></div>
          <div class="stat"><strong>#{format_count(analysis.fetch(:child_motifs).length)}</strong><span>child motifs</span></div>
          <div class="stat"><strong>#{format_count(analysis.fetch(:tradition_count))}</strong><span>traditions present</span></div>
          <div class="stat"><strong>#{esc(analysis.fetch(:date_range_label))}</strong><span>known era range</span></div>
        </div>
        <div class="family-highlight-grid">
          <article>
            <span class="row-kicker">Strongest Child Motifs</span>
            <div class="family-chip-list">#{top_child_chips}</div>
          </article>
          <article>
            <span class="row-kicker">Densest Traditions</span>
            <div class="family-chip-list">#{top_tradition_chips}</div>
          </article>
          <article>
            <span class="row-kicker">Reading Note</span>
            <p>These counts are generated from tagged extraction evidence. Similarity means structural or thematic recurrence unless a source record explicitly supports historical contact.</p>
          </article>
        </div>
        #{prototype_ids.include?(group_id) ? "<span class=\"pending-badge\">research prototype</span>" : ""}
      </section>

      <section id="child-motifs" class="section">
        <div class="section-heading">
          <h2>Child Motifs</h2>
          <label class="sort-control">Sort
            <select class="family-sort" data-sort-control="##{esc(child_sort_id)}">
              <option value="count">Most common first</option>
              <option value="alpha">Alphabetical</option>
            </select>
          </label>
        </div>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Child Motif</th><th>Relationship</th><th>Occurrences</th><th>Traditions</th></tr></thead>
            <tbody id="#{esc(child_sort_id)}">#{child_rows}</tbody>
          </table>
        </div>
      </section>

      <section id="traditions" class="section">
        <div class="section-heading">
          <h2>Tradition Frequency</h2>
          <span class="muted">Relative bars compare traditions inside this family.</span>
        </div>
        <div class="family-tradition-bars">#{tradition_rows}</div>
      </section>

      <section id="evidence" class="section">
        <div class="section-heading">
          <h2>How Each Tradition Tells It</h2>
          <span class="muted">Evidence is collapsed by default so the page stays scannable.</span>
        </div>
        <div class="family-evidence-toolbar">
          <input type="search" class="search-input" placeholder="Filter traditions or child motifs on this page" data-search-target=".family-tradition-section">
        </div>
        <div class="family-tradition-list">#{tradition_sections}</div>
      </section>

      <section id="comparison" class="section family-comparison-grid">
        <article>
          <span class="row-kicker">Converges</span>
          <h2>Shared Structure</h2>
          <p>#{esc(comparison.fetch(:convergence))}</p>
        </article>
        <article>
          <span class="row-kicker">Diverges</span>
          <h2>Local Emphasis</h2>
          <p>#{esc(comparison.fetch(:divergence))}</p>
        </article>
        <article>
          <span class="row-kicker">Comparison Mode</span>
          <h2>Reading Rule</h2>
          <div class="chip-row">#{comparison.fetch(:modes).map { |mode| "<span class=\"chip\">#{esc(mode)}</span>" }.join}</div>
        </article>
      </section>

      <section id="related" class="section">
        <div class="section-heading">
          <h2>Related Families</h2>
        </div>
        <div class="related-family-list">#{related_rows}</div>
      </section>

      <section id="timeline" class="section">
        <div class="section-heading">
          <h2>Timeline</h2>
          <span class="muted">Approximate eras from the cultural timeline index.</span>
        </div>
        <div class="family-timeline">#{timeline_rows}</div>
      </section>
    HTML

    write_page(current, layout(
      title: group["label"],
      subtitle: "#{analysis.fetch(:occurrence_count)} tagged occurrences across #{analysis.fetch(:tradition_count)} traditions.",
      current_output: current,
      body: body,
      page_class: "family-research-page"
    ))
  end
end

def tradition_totals(motifs)
  motifs.each_with_object(Hash.new(0)) do |motif, totals|
    motif.fetch("occurrences", []).each do |occurrence|
      totals[occurrence["tradition"]] += 1 if occurrence["tradition"]
    end
  end
end

def motif_bridge_rows(motifs)
  bridges = Hash.new { |hash, key| hash[key] = { count: 0, motifs: [] } }
  motifs.each do |motif|
    traditions = motif.fetch("traditions", {}).keys.compact.sort
    next if traditions.length < 2

    traditions.combination(2) do |left, right|
      bridge = bridges[[left, right]]
      bridge[:count] += 1
      bridge[:motifs] << motif
    end
  end
  bridges.sort_by { |(left, right), data| [-data[:count], left.to_s, right.to_s] }
end

def timeline_sort_value(entry)
  explicit = entry["sort_year"] || entry["start_year"] || entry["approx_start_year"] || entry.dig("approximate_date_range", "start_year")
  return explicit.to_i if explicit

  date_text = [entry["date_range"], entry["approx_date"], entry["date_label"], entry.dig("approximate_date_range", "display")].compact.join(" ")
  if (match = date_text.match(/(\d{1,4})\s*(?:BCE|BC)/i))
    -match[1].to_i
  elsif (match = date_text.match(/(\d{1,4})\s*(?:CE|AD)/i))
    match[1].to_i
  else
    999_999
  end
end

def year_label(year)
  return "unknown" if year.nil?

  value = year.to_i
  value.negative? ? "#{value.abs} BCE" : "#{value} CE"
end

def timeline_end_value(entry)
  explicit = entry["end_year"] || entry["approx_end_year"] || entry.dig("approximate_date_range", "end_year")
  explicit ? explicit.to_i : timeline_sort_value(entry)
end

def timeline_display(entry)
  entry.dig("approximate_date_range", "display") || entry["date_label"] || entry["date_range"] || year_label(timeline_sort_value(entry))
end

def extraction_search_url(current_output, query)
  "#{relative_url(current_output, "extractions/index.html")}?q=#{CGI.escape(query.to_s)}"
end

def family_occurrence_rows(rows, current_output)
  rows.map do |occurrence|
    source_output = output_for_repo_path(occurrence["source_text_path"])
    extraction_output = output_for_repo_path(occurrence["extraction_path"])
    <<~HTML
      <tr>
        <td>#{link_to_output(current_output, source_output, occurrence["source_title"].to_s.empty? ? occurrence["source_text_path"] : occurrence["source_title"])}</td>
        <td>#{esc(occurrence["passage_locator"])}</td>
        <td><span class="confidence #{esc(occurrence["confidence"])}">#{esc(occurrence["confidence"])}</span></td>
        <td>#{link_to_output(current_output, motif_output(occurrence["family_motif_id"]), titleize(occurrence["family_motif_label"]))}</td>
        <td>#{link_to_output(current_output, extraction_output, "record")}</td>
      </tr>
    HTML
  end.join
end

def family_occurrence_table(rows, current_output)
  <<~HTML
    <div class="table-wrap family-evidence-table">
      <table>
        <tr><th>Text</th><th>Line Range</th><th>Confidence</th><th>Child Motif</th><th>Extraction</th></tr>
        #{family_occurrence_rows(rows, current_output)}
      </table>
    </div>
  HTML
end

def normalized_group_id_for(motif_id, normalization, group_ids, seen = Set.new)
  motif_id = motif_id.to_s
  return nil if motif_id.empty? || seen.include?(motif_id)

  seen.add(motif_id)
  raw_index = normalization.fetch("raw_motif_group_index", {})
  aliases = normalization.fetch("aliases", {})
  groups = Array(normalization["canonical_motif_groups"])

  return raw_index.fetch(motif_id).fetch("group_id") if raw_index.key?(motif_id)
  return motif_id if group_ids.include?(motif_id)

  groups.each do |group|
    next unless group.is_a?(Hash)
    next unless Array(group["aliases"]).map(&:to_s).include?(motif_id) || Array(group["children"]).map(&:to_s).include?(motif_id)

    return group.fetch("id")
  end

  alias_entry = aliases[motif_id]
  return nil unless alias_entry

  (Array(alias_entry["canonical_refs"]) + Array(alias_entry["parent_refs"])).each do |ref|
    mapped = normalized_group_id_for(ref, normalization, group_ids, seen)
    return mapped if mapped
  end

  nil
end

def timeline_indexes(timeline)
  by_path = {}
  by_tradition = Hash.new { |hash, key| hash[key] = [] }
  timeline.fetch("entries", []).each do |entry|
    Array(entry["current_text_paths"]).each { |path| by_path[path.to_s] = entry }
    by_tradition[entry["tradition_cluster"].to_s] << entry if entry["tradition_cluster"]
  end
  { by_path: by_path, by_tradition: by_tradition }
end

def uniq_timeline_entries(entries)
  seen = {}
  entries.compact.select do |entry|
    key = entry["id"].to_s.empty? ? entry.object_id : entry["id"].to_s
    !seen.key?(key) && (seen[key] = true)
  end
end

def timeline_entries_for_occurrences(occurrences, timeline_lookup)
  by_path = timeline_lookup.fetch(:by_path)
  by_tradition = timeline_lookup.fetch(:by_tradition)
  entries = occurrences.flat_map do |occurrence|
    direct = by_path[occurrence["source_text_path"].to_s]
    direct ? [direct] : by_tradition[occurrence["tradition"].to_s]
  end
  uniq_timeline_entries(entries)
end

def timeline_range_label(entries)
  return "not yet dated" if entries.empty?

  starts = entries.map { |entry| timeline_sort_value(entry) }.reject { |year| year == 999_999 }
  ends = entries.map { |entry| timeline_end_value(entry) }.reject { |year| year == 999_999 }
  return "not yet dated" if starts.empty? && ends.empty?

  "#{year_label(starts.min || ends.min)} to #{year_label(ends.max || starts.max)}"
end

def canonical_family_analyses(normalization, motif_index, timeline)
  groups = normalization.fetch("canonical_motif_groups", []).reject { |group| group["id"].to_s.start_with?("_meta") }
  group_ids = groups.map { |group| group.fetch("id").to_s }.to_set
  raw_index = normalization.fetch("raw_motif_group_index", {})
  motifs = motif_index.fetch("motifs", [])
  motif_lookup = motifs.to_h { |motif| [motif.fetch("motif_id").to_s, motif] }
  mapped_motifs_by_group = Hash.new { |hash, key| hash[key] = [] }

  motifs.each do |motif|
    motif_id = motif.fetch("motif_id").to_s
    group_id = normalized_group_id_for(motif_id, normalization, group_ids)
    mapped_motifs_by_group[group_id] << motif if group_id && group_ids.include?(group_id)
  end

  timeline_lookup = timeline_indexes(timeline)

  groups.map do |group|
    group_id = group.fetch("id").to_s
    mapped_ids = mapped_motifs_by_group.fetch(group_id, []).map { |motif| motif.fetch("motif_id").to_s }.to_set
    Array(group["children"]).each { |motif_id| mapped_ids.add(motif_id.to_s) }
    Array(group["aliases"]).each { |motif_id| mapped_ids.add(motif_id.to_s) if motif_lookup.key?(motif_id.to_s) || raw_index.key?(motif_id.to_s) }

    child_motifs = mapped_ids.to_a.sort.map do |motif_id|
      motif = motif_lookup[motif_id]
      raw = raw_index[motif_id] || {}
      occurrences = Array(motif && motif["occurrences"])
      {
        motif_id: motif_id,
        label: motif ? motif["label"].to_s : titleize(motif_id),
        relationship: raw["relationship"] || (Array(group["children"]).map(&:to_s).include?(motif_id) ? "child" : "mapped"),
        occurrence_count: occurrences.length,
        tradition_count: motif ? motif.fetch("traditions", {}).keys.length : 0,
        traditions: motif ? motif.fetch("traditions", {}) : {},
        motif: motif
      }
    end

    occurrences = child_motifs.flat_map do |child|
      Array(child[:motif] && child[:motif]["occurrences"]).map do |occurrence|
        occurrence.merge(
          "family_motif_id" => child[:motif_id],
          "family_motif_label" => child[:label],
          "family_motif_relationship" => child[:relationship]
        )
      end
    end

    traditions = occurrences.each_with_object(Hash.new(0)) do |occurrence, counts|
      counts[occurrence["tradition"].to_s] += 1 unless occurrence["tradition"].to_s.empty?
    end.sort.to_h

    timeline_entries = timeline_entries_for_occurrences(occurrences, timeline_lookup)

    {
      group: group,
      group_id: group_id,
      child_motifs: child_motifs,
      occurrences: occurrences,
      occurrence_count: occurrences.length,
      traditions: traditions,
      tradition_count: traditions.length,
      timeline_entries: timeline_entries,
      date_range_label: timeline_range_label(timeline_entries)
    }
  end.sort_by { |analysis| [-analysis[:occurrence_count], -analysis[:tradition_count], analysis[:group]["label"].to_s] }
end

def family_tradition_summary(tradition, occurrences)
  top_motifs = occurrences
    .each_with_object(Hash.new(0)) { |occurrence, counts| counts[occurrence["family_motif_label"].to_s] += 1 }
    .sort_by { |label, count| [-count, label] }
    .first(3)
  top_sources = occurrences
    .each_with_object(Hash.new(0)) { |occurrence, counts| counts[occurrence["source_title"].to_s] += 1 }
    .sort_by { |title, count| [-count, title] }
    .first(2)
  motif_text = top_motifs.map { |label, count| "#{titleize(label)} (#{count})" }.join(", ")
  source_text = top_sources.map(&:first).reject(&:empty?).join(" and ")
  parts = ["In #{tradition_label(tradition)}, this family appears through #{motif_text.empty? ? "several tagged child motifs" : motif_text}."]
  parts << "The strongest concentration is currently in #{source_text}." unless source_text.empty?
  parts << "This is a deterministic summary of #{occurrences.length} tagged motif occurrences, not a claim of historical transmission."
  parts.join(" ")
end

def family_comparison_summary(analysis)
  occurrences = analysis.fetch(:occurrences)
  traditions = analysis.fetch(:traditions)
  child_motifs = analysis.fetch(:child_motifs)
  cross_children = child_motifs
    .select { |child| child[:tradition_count].to_i >= [3, traditions.length / 3].max }
    .sort_by { |child| [-child[:tradition_count].to_i, -child[:occurrence_count].to_i, child[:label]] }
    .first(6)
  convergence = if cross_children.any?
    "The strongest convergence is around #{cross_children.map { |child| titleize(child[:label]) }.join(", ")}. These child motifs recur across several tradition clusters and give the family its shared structure."
  else
    "The convergence is broad rather than concentrated in one child motif: traditions repeatedly tag passages into this family while emphasizing locally different scenes."
  end

  tradition_focus = occurrences.group_by { |occurrence| occurrence["tradition"].to_s }.map do |tradition, rows|
    top = rows.each_with_object(Hash.new(0)) { |occurrence, counts| counts[occurrence["family_motif_label"].to_s] += 1 }
      .sort_by { |label, count| [-count, label] }
      .first
    next unless top

    "#{tradition_label(tradition)} leans toward #{titleize(top.first)}"
  end.compact.first(6)
  divergence = tradition_focus.empty? ? "The current evidence is not dense enough to separate regional emphases cleanly." : "#{tradition_focus.join("; ")}."

  {
    convergence: convergence,
    divergence: divergence,
    modes: ["structural", "thematic", "contact not inferred"]
  }
end

def related_family_note(analysis, related_analysis)
  return "Linked as an interpretive neighbor in the normalization taxonomy." unless related_analysis

  left_records = analysis.fetch(:occurrences).map { |occurrence| occurrence["record_id"].to_s }.to_set
  right_records = related_analysis.fetch(:occurrences).map { |occurrence| occurrence["record_id"].to_s }.to_set
  overlap = (left_records & right_records).length
  return "#{overlap} extraction records currently carry motifs from both families." if overlap.positive?

  "Linked in the taxonomy as a neighboring symbolic function, even when the current passages do not overlap directly."
end

def card(title, body, href: nil, meta: nil)
  tag_open = href ? %(<a class="card" href="#{esc(href)}">) : %(<div class="card">)
  tag_close = href ? "</a>" : "</div>"
  <<~HTML
    #{tag_open}
      #{meta ? "<span class=\"card-meta\">#{esc(meta)}</span>" : ""}
      <h3>#{esc(title)}</h3>
      <p>#{esc(body)}</p>
    #{tag_close}
  HTML
end

def records_for_markdown(glob)
  Dir.glob(File.join(ROOT, glob)).sort.map do |path|
    parsed = read_markdown(path)
    rel = relative(path)
    {
      path: rel,
      output: output_for_repo_path(rel),
      metadata: parsed[:metadata],
      body: parsed[:body]
    }
  end
end

def extraction_records
  Dir.glob(File.join(ROOT, "extractions", "**", "*.{yml,yaml}")).sort.filter_map do |path|
    rel = relative(path)
    next if rel.start_with?("extractions/generated/experiential-batch/")
    data = load_yaml(path)
    next if data["source_text_path"].to_s.start_with?("texts/experiential/")
    {
      path: rel,
      output: output_for_repo_path(rel),
      data: data
    }
  end
end

def build_assets
  FileUtils.mkdir_p(site_path("assets"))
  File.write(site_path("assets", "style.css"), STYLE_CSS)
  File.write(site_path("assets", "app.js"), APP_JS)
  File.write(site_path(".nojekyll"), "")
  File.write(site_path("CNAME"), "ancientwisdomatlas.com\n")
end

def build_home(texts, comparisons, motif_index, extractions)
  current = "index.html"
  motif_count = motif_index["motif_count"]
  occurrence_count = motif_index["occurrence_count"]
  traditions = texts.map { |item| item[:metadata]["tradition"] }.compact.uniq.length
  motifs = motif_index.fetch("motifs", [])
  top_motifs = motifs.first(8)
  cross_tradition_motifs = motifs
    .select { |motif| motif.fetch("traditions", {}).length >= 2 }
    .sort_by { |motif| [-motif.fetch("traditions", {}).length, -motif.fetch("occurrences", []).length, motif["label"].to_s] }
    .first(4)

  body = <<~HTML
    <section class="home-intro">
      <p><strong>What is this?</strong> Humanity's oldest stories — from Gilgamesh to the Dreamtime — keep telling the same patterns: the descent into darkness, the flood, the divine mother, the return from death. This atlas collects the original texts, tags every recurring pattern with the exact passage as evidence, and maps where the same patterns appear in cultures that never met.</p>
      <p class="home-intro-links">
        New here? <a href="#{relative_url(current, "findings/index.html")}">Read what we've found so far, in plain language</a> — or dive into the <a href="#{relative_url(current, "explorer/index.html")}">Pattern Explorer</a>.
      </p>
    </section>

    <section class="stats-grid">
      <div class="stat"><strong>#{texts.length}</strong><span>complete texts</span></div>
      <div class="stat"><strong>#{traditions}</strong><span>traditions</span></div>
      <div class="stat"><strong>#{motif_count}</strong><span>motif groups</span></div>
      <div class="stat"><strong>#{occurrence_count}</strong><span>motif occurrences</span></div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Browse By Motif Family</h2>
        <a href="#{relative_url(current, "taxonomy/families/index.html")}">Open all families</a>
      </div>
      <div class="card-grid">
        #{card("Taxonomy Families", "Evidence-backed research pages for every canonical motif family, with child motifs, traditions, passages, comparisons, and timeline views.", href: relative_url(current, "taxonomy/families/index.html"), meta: "research index")}
        #{card("Taxonomy Cluster Map", "A calmer knowledge graph of motif families, evidence density, and related symbolic regions.", href: relative_url(current, "taxonomy/constellation.html"), meta: "visual map")}
        #{card("Pattern Explorer", "Filter motif evidence by tradition and confidence, then inspect the passages behind the pattern.", href: relative_url(current, "explorer/index.html"), meta: "interactive")}
        #{card("Text Library", "Browse the public-domain source texts that anchor the extraction evidence.", href: relative_url(current, "texts/index.html"), meta: "corpus")}
      </div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Start With The Patterns</h2>
        <a href="#{relative_url(current, "comparisons/index.html")}">View all comparisons</a>
      </div>
      <div class="card-grid">
        #{comparisons.reject { |item| item[:path].end_with?("README.md") || item[:path].end_with?("motif-index.md") }.first(4).map do |item|
          card(item[:metadata]["title"], item[:metadata]["motifs"].to_a.join(", "), href: relative_url(current, item[:output]), meta: item[:metadata]["claim_level"])
        end.join}
      </div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Most Connected Motifs</h2>
        <a href="#{relative_url(current, "motifs/index.html")}">Browse motif index</a>
      </div>
      <div class="motif-cloud">
        #{top_motifs.map do |motif|
          %(<a href="#{relative_url(current, motif_output(motif["motif_id"]))}"><strong>#{esc(motif["label"])}</strong><span>#{motif["occurrences"].length} appearances</span></a>)
        end.join}
      </div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Cross-Culture Signals</h2>
        <a href="#{relative_url(current, "motifs/index.html")}#bridges">Open bridge map</a>
      </div>
      <div class="card-grid">
        #{cross_tradition_motifs.map do |motif|
          traditions_text = motif.fetch("traditions", {}).keys.map { |name| tradition_label(name) }.join(", ")
          card(motif["label"], traditions_text, href: relative_url(current, motif_output(motif["motif_id"])), meta: "#{motif.fetch("traditions", {}).length} traditions")
        end.join}
      </div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Corpus</h2>
        <a href="#{relative_url(current, "texts/index.html")}">Open text library</a>
      </div>
      <div class="compact-list">
        #{texts.first(8).map do |item|
          %(<a href="#{relative_url(current, item[:output])}"><span>#{esc(item[:metadata]["title"])}</span><small>#{esc(tradition_label(item[:metadata]["tradition"]))}</small></a>)
        end.join}
      </div>
    </section>
  HTML

  write_page(current, layout(
    title: "Ancient Wisdom Atlas",
    subtitle: "A browsable corpus of public-domain wisdom texts, motif evidence, and cross-cultural comparison.",
    current_output: current,
    body: body,
    page_class: "home"
  ))
end

def build_findings(texts, motif_index)
  current = "findings/index.html"
  motif_count = motif_index["motif_count"]
  occurrence_count = motif_index["occurrence_count"]
  traditions = texts.map { |item| item[:metadata]["tradition"] }.compact.uniq.length

  agreement = load_yaml(File.join(ROOT, "data", "indexes", "replication-agreement.yml"))
  agreement_section = ""
  pairwise = agreement.fetch("pairwise", [])
  if pairwise.any?
    scores = pairwise.map { |pair| pair["mean_canonical_jaccard"] }.compact
    lo, hi = scores.minmax
    best_tradition = pairwise.filter_map { |pair| pair["per_tradition_canonical_jaccard"]&.first }.max_by { |_, value| value.to_f }
    agreement_section = <<~HTML
      <section class="section">
        <h2>Do different AIs see the same patterns?</h2>
        <p>We had <strong>three different AI models</strong> — built at different times, with no shared memory — each read the same ancient passages independently and tag the patterns they saw. If the patterns were imaginary, the three readers would disagree wildly. They don't.</p>
        <p>Across #{pairwise.map { |pair| pair["shared_passages"] }.max} shared passages, any two readers agreed on <strong>#{(lo * 100).round}–#{(hi * 100).round}%</strong> of the pattern families they tagged (a strict overlap measure where 100% means identical answers)#{best_tradition ? ", rising to <strong>#{(best_tradition[1] * 100).round}%</strong> for #{esc(tradition_label(best_tradition[0]))} texts" : ""}. For open-ended reading tasks, that is the level of agreement trained human researchers reach.</p>
        <p><em>Why it matters:</em> it means the patterns live in the texts themselves — not in one reader's imagination.</p>
      </section>
    HTML
  end

  body = <<~HTML
    <section class="section">
      <h2>The question</h2>
      <p>People who never met — separated by oceans and thousands of years — told strangely similar stories. A hero descends into the land of the dead and returns. A great flood wipes the world clean. A mother goddess loses and finds her child. Why?</p>
      <p>There are three boring explanations: the stories were <em>inherited</em> from common ancestors, <em>traded</em> along contact routes, or the similarity is <em>coincidence</em>. And there is one profound possibility, suggested a century ago by Carl Jung and Joseph Campbell: that these patterns rise from something shared in the human mind itself. They could never test it. We can.</p>
    </section>

    <section class="section">
      <h2>What we built</h2>
      <p>We collected <strong>#{texts.length} complete ancient and sacred texts</strong> from <strong>#{traditions} traditions</strong> — all public domain, all with provenance — and had AI read every passage and tag each recurring story-pattern (a <em>motif</em>) with the exact quote as evidence. Nothing is asserted without a passage you can click and read. So far: <strong>#{format_count(motif_count)} distinct motifs</strong> across <strong>#{format_count(occurrence_count)} tagged occurrences</strong>.</p>
      <p>Crucially, the corpus now includes traditions that <strong>could not have borrowed from each other</strong> — Australian Aboriginal Dreamtime tales, Inuit stories from Greenland sledge journeys, San narratives from the Kalahari, Siberian Koryak texts, Guiana Amerindian legends. When the same pattern appears there <em>and</em> in Gilgamesh, "they copied it" is off the table.</p>
    </section>

    #{agreement_section}

    <section class="section">
      <h2>What comes next</h2>
      <p><strong>Order:</strong> Campbell claimed stories don't just share ingredients — they share a <em>sequence</em> (departure → ordeal → return). We are testing whether that order actually recurs, with numbers.</p>
      <p><strong>Clusters:</strong> Jung claimed symbols travel in stable families — the Mother, the Trickster, the Descent. We are testing whether the same symbol-clusters re-form independently in unconnected cultures.</p>
      <p><strong>Chance:</strong> every claim above is checked against a simulation of what pure coincidence would produce. Only patterns that beat chance count.</p>
      <p><strong>The bridge:</strong> modern people in extraordinary states — near-death experiences, deep meditation — report imagery with no cultural source. We analyze those reports with a completely separate pipeline, so the two worlds can be compared without contaminating each other.</p>
    </section>

    <section class="section">
      <h2>What would prove us wrong</h2>
      <p>If the patterns only appear in cultures that had contact; if independent AI readers stop agreeing when texts get unfamiliar; if the "universal" patterns fail the chance test — then the profound explanation loses, and we will say so. That honesty is the whole point of building this as evidence instead of anecdote.</p>
    </section>
  HTML

  write_page(current, layout(
    title: "What We Have Found",
    subtitle: "The project, its first results, and what would prove it wrong — in plain language.",
    current_output: current,
    body: body,
    page_class: "findings"
  ))
end

def build_agent_files(texts, motif_index)
  repo_raw = "https://raw.githubusercontent.com/ilaydabdogan/ancient-wisdom-atlas/main"
  repo = "https://github.com/ilaydabdogan/ancient-wisdom-atlas"
  llms = <<~TXT
    # Ancient Wisdom Atlas

    > A source-grounded, machine-readable atlas of recurring motifs across
    > #{texts.map { |item| item[:metadata]["tradition"] }.compact.uniq.length} ancient and sacred text traditions. Every motif claim links to a
    > specific passage in a specific public-domain text. Built to test, with
    > falsifiable methods, whether cross-cultural motif recurrence exceeds
    > inheritance, diffusion, and chance.

    ## Data (canonical, machine-readable YAML in the repo)
    - Motif occurrences index: #{repo_raw}/data/indexes/motif-occurrences.yml
    - Canonical motif families + frequencies: #{repo_raw}/data/indexes/canonical-motif-frequency.yml
    - Inter-reader agreement (multi-model replication): #{repo_raw}/data/indexes/replication-agreement.yml
    - Cultural timeline: #{repo_raw}/data/indexes/cultural-timeline.yml
    - Extraction records (one YAML per passage): #{repo}/tree/main/extractions
    - Source texts (markdown with stable passage anchors): #{repo}/tree/main/texts/public-domain
    - Extraction JSON Schema: #{repo_raw}/schemas/extraction.schema.json

    ## Site sections
    - /findings/ : plain-language summary of results
    - /motifs/ : per-motif evidence pages
    - /taxonomy/ : canonical family research pages + constellation map
    - /extractions/ : per-passage extraction records
    - /texts/ : the corpus
    - /api/atlas.json : machine-readable site summary

    ## Method invariants (do not violate when extending)
    - Every motif claim must cite a passage ID in a canonical text.
    - Experiential (NDE/contemplative) data is analyzed by a separate
      pipeline and never mixed with the ancient corpus.
    - Taxonomy families follow evidence; they are never declared a priori.
  TXT
  File.write(site_path("llms.txt"), llms)

  FileUtils.mkdir_p(site_path("api"))
  File.write(site_path("api", "atlas.json"), JSON.pretty_generate({
    "name" => "Ancient Wisdom Atlas",
    "generated_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "counts" => {
      "texts" => texts.length,
      "traditions" => texts.map { |item| item[:metadata]["tradition"] }.compact.uniq.length,
      "motifs" => motif_index["motif_count"],
      "occurrences" => motif_index["occurrence_count"]
    },
    "data" => {
      "repository" => repo,
      "motif_occurrences" => "#{repo_raw}/data/indexes/motif-occurrences.yml",
      "canonical_families" => "#{repo_raw}/data/indexes/canonical-motif-frequency.yml",
      "replication_agreement" => "#{repo_raw}/data/indexes/replication-agreement.yml",
      "extraction_schema" => "#{repo_raw}/schemas/extraction.schema.json"
    }
  }))
end

def build_explorer(motif_index, patterns)
  current = "explorer/index.html"
  motifs = motif_index.fetch("motifs", [])
  occurrence_count = motif_index["occurrence_count"].to_i
  tradition_counts = tradition_totals(motifs).sort_by { |name, count| [-count, tradition_label(name)] }
  cross_tradition = motifs.select { |motif| motif.fetch("traditions", {}).length >= 2 }
  bridge_count = motif_bridge_rows(motifs).length
  max_occurrences = motifs.map { |motif| motif.fetch("occurrences", []).length }.max.to_i
  tradition_options = tradition_counts.map do |name, count|
    %(<option value="#{esc(name)}">#{esc(tradition_label(name))} (#{count})</option>)
  end.join

  top_matrix_motifs = cross_tradition
    .sort_by { |motif| [-motif.fetch("traditions", {}).length, -motif.fetch("occurrences", []).length, motif["label"].to_s] }
    .first(12)

  matrix_rows = tradition_counts.map do |tradition, _count|
    cells = top_matrix_motifs.map do |motif|
      count = motif.fetch("traditions", {}).fetch(tradition, 0).to_i
      content = count.positive? ? link_to_output(current, motif_output(motif["motif_id"]), count.to_s) : " "
      %(<td class="#{count.positive? ? "matrix-hit" : "matrix-empty"}">#{content}</td>)
    end.join
    "<tr><th>#{esc(tradition_label(tradition))}</th>#{cells}</tr>"
  end.join

  explorer_rows = motifs.map do |motif|
    occurrences = motif.fetch("occurrences", [])
    traditions = motif.fetch("traditions", {})
    confidence_counts = occurrences.each_with_object(Hash.new(0)) { |occ, counts| counts[occ["confidence"].to_s] += 1 }
    confidence_labels = confidence_counts.keys.reject(&:empty?).sort
    best_occurrence = occurrences.sort_by do |occ|
      rank = { "high" => 0, "medium" => 1, "low" => 2 }.fetch(occ["confidence"].to_s, 3)
      [rank, occ["source_title"].to_s]
    end.first || {}
    quote = (best_occurrence.fetch("evidence", []).first || {})["quote_or_summary"].to_s.strip
    evidence_text = quote.empty? ? best_occurrence["basis"].to_s : quote
    tradition_chips = traditions.sort_by { |name, count| [-count.to_i, tradition_label(name)] }.first(8).map do |name, count|
      %(<span class="chip">#{esc(tradition_label(name))}<strong>#{count}</strong></span>)
    end.join
    width = max_occurrences.positive? ? ((occurrences.length.to_f / max_occurrences) * 100).round(1) : 0
    search_text = [
      motif["motif_id"],
      motif["label"],
      traditions.keys,
      traditions.keys.map { |name| tradition_label(name) },
      occurrences.map { |occ| [occ["source_title"], occ["passage_locator"], occ["motif_label"], occ["basis"]] }
    ].flatten.compact.join(" ")

    <<~HTML
      <article class="explorer-row searchable"
        data-search="#{esc(search_text)}"
        data-traditions="#{esc(traditions.keys.join(" "))}"
        data-confidences="#{esc(confidence_labels.join(" "))}"
        data-cross="#{traditions.length >= 2}"
        data-occurrences="#{occurrences.length}">
        <div class="explorer-main">
          <span class="row-kicker">#{esc(motif["motif_id"])}</span>
          <h3><a href="#{esc(relative_url(current, motif_output(motif["motif_id"])))}">#{esc(titleize(motif["label"]))}</a></h3>
          <p>#{esc(evidence_text[0, 260])}</p>
          <div class="chip-row">#{tradition_chips}</div>
        </div>
        <aside class="explorer-metrics" aria-label="Motif metrics">
          <strong>#{occurrences.length}</strong>
          <span>appearances</span>
          <small>#{traditions.length} traditions</small>
          <i style="width: #{width}%"></i>
        </aside>
      </article>
    HTML
  end.join

  evidence_rows = motifs
    .select { |motif| motif.fetch("traditions", {}).length >= 2 }
    .flat_map { |motif| motif.fetch("occurrences", []).map { |occ| [motif, occ] } }
    .sort_by do |motif, occ|
      rank = { "high" => 0, "medium" => 1, "low" => 2 }.fetch(occ["confidence"].to_s, 3)
      [rank, -motif.fetch("traditions", {}).length, motif["label"].to_s, tradition_label(occ["tradition"])]
    end
    .first(80)
    .map do |motif, occ|
      source_output = output_for_repo_path(occ["source_text_path"])
      quote = (occ.fetch("evidence", []).first || {})["quote_or_summary"].to_s.strip
      evidence = quote.empty? ? occ["basis"].to_s : quote
      <<~HTML
        <tr class="searchable" data-search="#{esc([motif["label"], occ["tradition"], occ["source_title"], occ["passage_locator"], evidence].join(" "))}">
          <td>#{link_to_output(current, motif_output(motif["motif_id"]), titleize(motif["label"]))}</td>
          <td>#{esc(tradition_label(occ["tradition"]))}</td>
          <td>#{link_to_output(current, source_output, occ["source_title"])}</td>
          <td>#{esc(occ["passage_locator"])}</td>
          <td><span class="confidence #{esc(occ["confidence"])}">#{esc(occ["confidence"])}</span></td>
          <td>#{esc(evidence[0, 220])}</td>
        </tr>
      HTML
    end.join

  lens_cards = patterns.first(8).map do |item|
    metadata = item[:metadata]
    card(
      metadata["title"] || File.basename(item[:path], ".md"),
      metadata["motifs"].to_a.join(", "),
      href: relative_url(current, item[:output]),
      meta: metadata["claim_level"] || "pattern lens"
    )
  end.join

  body = <<~HTML
    <section class="explorer-dashboard">
      <div class="stat"><strong>#{motifs.length}</strong><span>motif groups</span></div>
      <div class="stat"><strong>#{occurrence_count}</strong><span>linked appearances</span></div>
      <div class="stat"><strong>#{cross_tradition.length}</strong><span>cross-tradition motifs</span></div>
      <div class="stat"><strong>#{bridge_count}</strong><span>tradition bridges</span></div>
    </section>

    <section class="explorer-controls" aria-label="Pattern explorer filters">
      <input type="search" class="search-input explorer-search" placeholder="Search motifs, sources, passages, cultures">
      <select class="explorer-filter" data-filter="tradition" aria-label="Filter by tradition">
        <option value="">All traditions</option>
        #{tradition_options}
      </select>
      <select class="explorer-filter" data-filter="confidence" aria-label="Filter by confidence">
        <option value="">All confidence levels</option>
        <option value="high">High confidence</option>
        <option value="medium">Medium confidence</option>
        <option value="low">Low confidence</option>
      </select>
      <label class="toggle-control"><input type="checkbox" class="explorer-toggle" data-toggle="cross"> Cross-tradition only</label>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Motif Explorer</h2>
        <span class="result-count"><strong data-explorer-count>#{motifs.length}</strong> visible</span>
      </div>
      <div class="explorer-list">#{explorer_rows}</div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Tradition Motif Matrix</h2>
        <span class="muted">Counts for the most connected cross-tradition motifs</span>
      </div>
      <div class="table-wrap matrix-wrap">
        <table class="matrix-table">
          <tr>
            <th>Tradition</th>
            #{top_matrix_motifs.map { |motif| "<th>#{link_to_output(current, motif_output(motif["motif_id"]), titleize(motif["label"]))}</th>" }.join}
          </tr>
          #{matrix_rows}
        </table>
      </div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Evidence Preview</h2>
        <span class="muted">A high-signal slice from cross-tradition motifs</span>
      </div>
      <div class="table-wrap">
        <table>
          <tr><th>Motif</th><th>Tradition</th><th>Source</th><th>Passage</th><th>Confidence</th><th>Evidence</th></tr>
          #{evidence_rows}
        </table>
      </div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Curated Pattern Lenses</h2>
        <a href="#{relative_url(current, "patterns/index.html")}">Open all pattern essays</a>
      </div>
      <div class="card-grid">#{lens_cards}</div>
    </section>
  HTML

  write_page(current, layout(
    title: "Pattern Explorer",
    subtitle: "Filter motifs by tradition and confidence, scan evidence, and see where symbolic structures bridge cultures.",
    current_output: current,
    body: body,
    page_class: "explorer-page"
  ))
end

def build_markdown_collection(title:, subtitle:, records:, index_output:, item_type:)
  cards = records.map do |item|
    metadata = item[:metadata]
    description = metadata["motifs"].is_a?(Array) ? metadata["motifs"].join(", ") : metadata["pattern_type"].to_s
    %(<article class="list-row searchable" data-search="#{esc([metadata["title"], metadata["tradition"], metadata["motifs"], item[:path]].flatten.compact.join(" "))}">
      <div>
        <span class="row-kicker">#{esc(item_type)}</span>
        <h3><a href="#{esc(relative_url(index_output, item[:output]))}">#{esc(metadata["title"] || File.basename(item[:path]))}</a></h3>
        <p>#{esc(description)}</p>
      </div>
      <small>#{esc(item[:path])}</small>
    </article>)
  end.join

  body = <<~HTML
    <section class="toolbar">
      <input type="search" class="search-input" placeholder="Search #{esc(title.downcase)}" data-search-target=".searchable">
    </section>
    <section class="list-panel">#{cards}</section>
  HTML

  write_page(index_output, layout(title: title, subtitle: subtitle, current_output: index_output, body: body))

  records.each do |item|
    metadata = item[:metadata]
    output = item[:output]
    body = <<~HTML
      <section class="doc-shell">
        <aside class="metadata-panel">
          <dl>
            #{metadata.map { |key, value| "<dt>#{esc(key)}</dt><dd>#{esc(value.is_a?(Array) ? value.join(", ") : value)}</dd>" }.join}
          </dl>
        </aside>
        <article class="document">#{render_markdown(item[:body], output)}</article>
      </section>
    HTML
    write_page(output, layout(title: metadata["title"] || File.basename(item[:path]), current_output: output, body: body))
  end
end

def build_texts(texts)
  build_markdown_collection(
    title: "Texts",
    subtitle: "Complete rights-cleared Markdown source texts with provenance.",
    records: texts,
    index_output: "texts/index.html",
    item_type: "source text"
  )
end

def build_patterns(patterns)
  build_markdown_collection(
    title: "Pattern Essays",
    subtitle: "Longer interpretive pattern notes with cautions and claim levels.",
    records: patterns,
    index_output: "patterns/index.html",
    item_type: "pattern"
  )
end

def build_comparisons(comparisons)
  build_markdown_collection(
    title: "Comparisons",
    subtitle: "Evidence-backed cross-cultural comparison pages and generated motif browsing.",
    records: comparisons,
    index_output: "comparisons/index.html",
    item_type: "comparison"
  )
end

def build_motifs(motif_index, extra_motif_ids = [])
  current = "motifs/index.html"
  motifs = motif_index.fetch("motifs", [])
  cross_tradition = motifs
    .select { |motif| motif.fetch("traditions", {}).length >= 2 }
    .sort_by { |motif| [-motif.fetch("traditions", {}).length, -motif.fetch("occurrences", []).length, motif["label"].to_s] }
  totals = tradition_totals(motifs).sort_by { |name, count| [-count, tradition_label(name)] }
  bridge_rows = motif_bridge_rows(motifs).first(14)

  motif_cards = motifs.map do |motif|
    traditions = motif.fetch("traditions", {}).sort.map { |name, count| "#{tradition_label(name)} (#{count})" }.join(", ")
    <<~HTML
      <article id="motif-#{esc(motif["motif_id"])}" class="list-row searchable" data-search="#{esc([motif["motif_id"], motif["label"], traditions].join(" "))}">
        <div>
          <span class="row-kicker">#{esc(motif["motif_id"])}</span>
          <h3><a href="#{esc(relative_url(current, motif_output(motif["motif_id"])))}">#{esc(titleize(motif["label"]))}</a></h3>
          <p>#{esc(traditions)}</p>
        </div>
        <small>#{motif.fetch("occurrences", []).length} appearances</small>
      </article>
    HTML
  end.join

  body = <<~HTML
    <section class="insight-band">
      <div>
        <span class="row-kicker">Pattern discovery</span>
        <h2>Motifs That Travel Across Worlds</h2>
        <p>The atlas does not treat resemblance as proof of copying. It makes recurring symbolic structures visible, then keeps the evidence close enough to inspect.</p>
      </div>
      <div class="insight-stats">
        <strong>#{cross_tradition.length}</strong>
        <span>motifs appear in more than one tradition</span>
      </div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Cross-Tradition Motifs</h2>
      </div>
      <div class="card-grid">
        #{cross_tradition.first(8).map do |motif|
          traditions_text = motif.fetch("traditions", {}).keys.map { |name| tradition_label(name) }.join(", ")
          card(titleize(motif["label"]), traditions_text, href: relative_url(current, motif_output(motif["motif_id"])), meta: "#{motif.fetch("traditions", {}).length} traditions")
        end.join}
      </div>
    </section>

    <section id="bridges" class="section">
      <div class="section-heading">
        <h2>Tradition Bridges</h2>
      </div>
      <div class="table-wrap">
        <table>
          <tr><th>Tradition Pair</th><th>Shared Motifs</th><th>Motifs</th></tr>
          #{bridge_rows.map do |(left, right), data|
            motif_links = data[:motifs].first(8).map { |motif| link_to_output(current, motif_output(motif["motif_id"]), titleize(motif["label"])) }.join(", ")
            "<tr><td>#{esc(tradition_label(left))} + #{esc(tradition_label(right))}</td><td>#{data[:count]}</td><td>#{motif_links}</td></tr>"
          end.join}
        </table>
      </div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Tradition Signal Strength</h2>
      </div>
      <div class="signal-bars">
        #{totals.map do |name, count|
          width = motif_index["occurrence_count"].to_i.positive? ? ((count.to_f / motif_index["occurrence_count"].to_i) * 100).round(1) : 0
          %(<div class="signal-bar"><span>#{esc(tradition_label(name))}</span><strong>#{count}</strong><i style="width: #{width}%"></i></div>)
        end.join}
      </div>
    </section>

    <section class="toolbar">
      <input type="search" class="search-input" placeholder="Search motifs, traditions, or sources" data-search-target=".searchable">
    </section>
    <section class="list-panel">#{motif_cards}</section>
  HTML

  write_page(current, layout(
    title: "Motif Index",
    subtitle: "#{motif_index["motif_count"]} motif groups and #{motif_index["occurrence_count"]} evidence-linked appearances.",
    current_output: current,
    body: body
  ))

  motifs.each do |motif|
    output = motif_output(motif["motif_id"])
    traditions = motif.fetch("traditions", {}).sort.map { |name, count| "#{tradition_label(name)} (#{count})" }.join(", ")
    occurrence_rows = motif.fetch("occurrences", []).map do |occ|
      source_output = output_for_repo_path(occ["source_text_path"])
      extraction_output = output_for_repo_path(occ["extraction_path"])
      evidence = occ.fetch("evidence", []).first || {}
      quote_or_summary = evidence["quote_or_summary"].to_s.strip
      <<~HTML
        <tr>
          <td>#{esc(tradition_label(occ["tradition"]))}</td>
          <td>#{link_to_output(output, source_output, occ["source_title"])}</td>
          <td>#{esc(occ["passage_locator"])}</td>
          <td><span class="confidence #{esc(occ["confidence"])}">#{esc(occ["confidence"])}</span></td>
          <td>#{esc(quote_or_summary.empty? ? occ["basis"] : quote_or_summary)}</td>
          <td>#{link_to_output(output, extraction_output, "record")}</td>
        </tr>
      HTML
    end.join

    body = <<~HTML
      <section class="motif-detail-grid">
        <aside class="metadata-panel">
          <dl>
            <dt>Motif id</dt><dd>#{esc(motif["motif_id"])}</dd>
            <dt>Appearances</dt><dd>#{motif.fetch("occurrences", []).length}</dd>
            <dt>Traditions</dt><dd>#{esc(traditions)}</dd>
          </dl>
        </aside>
        <article class="document">
          <h2>Evidence</h2>
          <p class="muted">Each row links back to the complete public-domain source text and the structured extraction record.</p>
          <div class="table-wrap">
            <table>
              <tr><th>Tradition</th><th>Source</th><th>Passage</th><th>Confidence</th><th>Evidence</th><th>Record</th></tr>
              #{occurrence_rows}
            </table>
          </div>
        </article>
      </section>
    HTML

    write_page(output, layout(
      title: titleize(motif["label"]),
      subtitle: "#{motif.fetch("occurrences", []).length} appearances across #{motif.fetch("traditions", {}).length} tradition groups.",
      current_output: output,
      body: body
    ))
  end

  existing_ids = motifs.map { |motif| motif["motif_id"].to_s }.to_set
  extra_motif_ids.reject { |motif_id| existing_ids.include?(motif_id.to_s) }.each do |motif_id|
    output = motif_output(motif_id)
    label = titleize(motif_id)
    body = <<~HTML
      <section class="motif-detail-grid">
        <aside class="metadata-panel">
          <dl>
            <dt>Motif id</dt><dd>#{esc(motif_id)}</dd>
            <dt>Appearances</dt><dd>0</dd>
            <dt>Status</dt><dd>taxonomy child reference</dd>
          </dl>
        </aside>
        <article class="document">
          <h2>#{esc(label)}</h2>
          <p class="muted">This motif id is referenced by the taxonomy but does not yet have direct extracted occurrences in the generated motif index. It is kept as a stable destination so taxonomy child links never break.</p>
          <p><a href="#{esc(relative_url(output, "taxonomy/index.html"))}">Return to taxonomy</a></p>
        </article>
      </section>
    HTML
    write_page(output, layout(
      title: label,
      subtitle: "Taxonomy child reference awaiting direct evidence-linked occurrences.",
      current_output: output,
      body: body
    ))
  end
end

def build_taxonomy(normalization, proposed_review, motif_index, timeline)
  current = "taxonomy/index.html"
  groups = normalization.fetch("canonical_motif_groups", [])
  hierarchies = normalization.fetch("hierarchies", {})
  proposed_candidates = proposed_review.fetch("genuine_new_group_candidates", [])
  family_analyses = canonical_family_analyses(normalization, motif_index, timeline)
  build_taxonomy_family_pages(family_analyses)
  approved_groups = groups.reject { |group| group["id"].to_s.start_with?("_meta") }
  group_ids = approved_groups.map { |group| group["id"].to_s }.to_set
  motif_rows = motif_index.fetch("motifs", [])
  motif_count = motif_index["motif_count"].to_i.positive? ? motif_index["motif_count"].to_i : motif_rows.length
  mapped_motif_count = motif_rows.count do |motif|
    group_id = normalized_group_id_for(motif.fetch("motif_id").to_s, normalization, group_ids)
    group_id && group_ids.include?(group_id)
  end
  unmapped_motif_count = [motif_count - mapped_motif_count, 0].max
  total_mapped_occurrences = family_analyses.sum { |analysis| analysis.fetch(:occurrence_count).to_i }

  hierarchy_rows = hierarchies.map do |id, data|
    refs = [data["parent_refs"], data["child_refs"]].flatten.compact
    search_text = [id, data["label"], data["description"], refs].flatten.compact.join(" ")
    <<~HTML
      <article class="taxonomy-family taxonomy-searchable searchable" data-search="#{esc(search_text)}">
        <div class="taxonomy-family-head">
          <span class="row-kicker">Hierarchy</span>
          <h3 id="#{esc(taxonomy_anchor(id))}">#{esc(data["label"] || titleize(id))}</h3>
        </div>
        <p>#{esc(compact_text(data["description"]))}</p>
        <div class="taxonomy-card-metrics">
          <span><b>#{format_count(Array(data["parent_refs"]).length)}</b><small>parent refs</small></span>
          <span><b>#{format_count(Array(data["child_refs"]).length)}</b><small>child refs</small></span>
        </div>
      </article>
    HTML
  end.join

  core_family_cards = family_analyses.first(8).map do |analysis|
    group = analysis.fetch(:group)
    <<~HTML
      <a class="taxonomy-core-card taxonomy-searchable searchable" href="#{esc(relative_url(current, taxonomy_family_output(group["id"])))}" data-search="#{esc([group["id"], group["label"], group["description"], group["aliases"]].flatten.compact.join(" "))}">
        <span class="row-kicker">#{esc(taxonomy_cluster_definitions.find { |cluster| cluster["id"] == taxonomy_cluster_for(group) }.fetch("label", "Family"))}</span>
        <h3>#{esc(group["label"])}</h3>
        <p>#{esc(compact_text(group["description"])[0, 150])}</p>
        <div class="taxonomy-card-metrics">
          <span><b>#{format_count(analysis.fetch(:occurrence_count))}</b><small>occurrences</small></span>
          <span><b>#{format_count(analysis.fetch(:tradition_count))}</b><small>traditions</small></span>
          <span><b>#{format_count(analysis.fetch(:child_motifs).length)}</b><small>motifs</small></span>
        </div>
      </a>
    HTML
  end.join

  cluster_sections = taxonomy_cluster_definitions.map do |cluster|
    analyses = family_analyses
      .select { |analysis| taxonomy_cluster_for(analysis.fetch(:group)) == cluster["id"] }
      .sort_by { |analysis| [-analysis.fetch(:occurrence_count).to_i, -analysis.fetch(:tradition_count).to_i, analysis.fetch(:group)["label"].to_s] }
    next if analyses.empty?

    cluster_occurrences = analyses.sum { |analysis| analysis.fetch(:occurrence_count).to_i }
    cluster_traditions = analyses.flat_map { |analysis| analysis.fetch(:traditions).keys }.uniq.length
    cluster_motifs = analyses.sum { |analysis| analysis.fetch(:child_motifs).length }
    rows = analyses.map do |analysis|
      group = analysis.fetch(:group)
      search_text = [
        group["id"],
        group["label"],
        group["description"],
        group["aliases"],
        group["related"]
      ].flatten.compact.join(" ")
      <<~HTML
        <a class="taxonomy-family-row taxonomy-searchable searchable" href="#{esc(relative_url(current, taxonomy_family_output(group["id"])))}" data-search="#{esc(search_text)}">
          <div>
            <span class="row-kicker">#{esc(group["id"])}</span>
            <h3>#{esc(group["label"])}</h3>
            <p>#{esc(compact_text(group["description"])[0, 180])}</p>
          </div>
          <div class="taxonomy-row-metrics">
            <span><b>#{format_count(analysis.fetch(:occurrence_count))}</b><small>occurrences</small></span>
            <span><b>#{format_count(analysis.fetch(:tradition_count))}</b><small>traditions</small></span>
            <span><b>#{format_count(analysis.fetch(:child_motifs).length)}</b><small>motifs</small></span>
          </div>
        </a>
      HTML
    end.join

    <<~HTML
      <details class="taxonomy-cluster" open>
        <summary>
          <div>
            <span class="row-kicker">#{format_count(analyses.length)} families</span>
            <h3>#{esc(cluster["label"])}</h3>
            <p>#{esc(cluster["description"])}</p>
          </div>
          <div class="taxonomy-row-metrics">
            <span><b>#{format_count(cluster_occurrences)}</b><small>occurrences</small></span>
            <span><b>#{format_count(cluster_traditions)}</b><small>traditions</small></span>
            <span><b>#{format_count(cluster_motifs)}</b><small>motifs</small></span>
          </div>
        </summary>
        <div class="taxonomy-cluster-body">#{rows}</div>
      </details>
    HTML
  end.compact.join

  route_cards = [
    {
      title: "Explore The Map",
      meta: "visual graph",
      href: relative_url(current, "taxonomy/constellation.html"),
      counts: [["#{format_count(approved_groups.length)}", "families"], ["#{format_count(taxonomy_constellation_data(normalization, proposed_review, current, family_analyses)["cross_links"].length)}", "links"]]
    },
    {
      title: "Browse Family Pages",
      meta: "research index",
      href: relative_url(current, "taxonomy/families/index.html"),
      counts: [["#{format_count(total_mapped_occurrences)}", "occurrences"], ["#{format_count(family_analyses.sum { |analysis| analysis.fetch(:child_motifs).length })}", "motifs"]]
    },
    {
      title: "Review Pending Groups",
      meta: "normalization",
      href: "#review",
      counts: [["#{format_count(proposed_candidates.length)}", "pending"], ["#{format_count(proposed_review.dig("summary", "source_candidates_folded").to_i)}", "folded"]]
    }
  ].map do |item|
    <<~HTML
      <a class="taxonomy-route-card" href="#{esc(item.fetch(:href))}">
        <span class="row-kicker">#{esc(item.fetch(:meta))}</span>
        <h3>#{esc(item.fetch(:title))}</h3>
        <div class="taxonomy-card-metrics">
          #{item.fetch(:counts).map { |value, label| "<span><b>#{esc(value)}</b><small>#{esc(label)}</small></span>" }.join}
        </div>
      </a>
    HTML
  end.join

  proposed_rows = proposed_candidates.map do |candidate|
    search_text = [
      candidate["id"],
      candidate["label"],
      candidate["rationale"],
      candidate["traditions"],
      candidate["source_candidate_ids"]
    ].flatten.compact.join(" ")
    <<~HTML
      <article class="taxonomy-family proposed taxonomy-searchable searchable" data-search="#{esc(search_text)}">
        <div class="taxonomy-family-head">
          <span class="row-kicker">Pending Review</span>
          <h3 id="#{esc(taxonomy_anchor(candidate["id"]))}">#{esc(candidate["label"])}</h3>
          <span class="pending-badge">#{esc(candidate["recommendation"].to_s.tr("_", " "))}</span>
        </div>
        <p>#{esc(compact_text(candidate["rationale"]))}</p>
        <div class="taxonomy-card-metrics">
          <span><b>#{format_count(candidate["occurrence_count"])}</b><small>occurrences</small></span>
          <span><b>#{format_count(candidate["child_motif_count"])}</b><small>child motifs</small></span>
          <span><b>#{format_count(Array(candidate["traditions"]).length)}</b><small>traditions</small></span>
          <span><b>#{format_count(Array(candidate["suggested_parent_group_ids"]).length)}</b><small>parents</small></span>
        </div>
      </article>
    HTML
  end.join
  proposed_rows = %(<p class="muted">No pending proposed groups are waiting in the current review file.</p>) if proposed_rows.empty?

  body = <<~HTML
    <section class="taxonomy-dashboard">
      <div class="stat"><strong>#{format_count(approved_groups.length)}</strong><span>approved families</span></div>
      <div class="stat"><strong>#{format_count(mapped_motif_count)}</strong><span>mapped motif IDs</span></div>
      <div class="stat"><strong>#{format_count(unmapped_motif_count)}</strong><span>unmapped motif IDs</span></div>
      <div class="stat"><strong>#{format_count(total_mapped_occurrences)}</strong><span>family occurrences</span></div>
    </section>

    <section class="taxonomy-route-grid">
      #{route_cards}
    </section>

    <section class="toolbar taxonomy-searchbar">
      <input type="search" class="search-input" placeholder="Search families, clusters, aliases, or review items" data-search-target=".taxonomy-searchable">
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Most Evidenced Families</h2>
        <a href="#{relative_url(current, "taxonomy/families/index.html")}">View all family pages</a>
      </div>
      <div class="taxonomy-core-grid">#{core_family_cards}</div>
    </section>

    <section class="section" id="families">
      <div class="section-heading">
        <h2>Browse Families by Cluster</h2>
        <span class="muted">Compact rows show evidence counts. Open a family for child motifs and passages.</span>
      </div>
      <div class="taxonomy-clusters">#{cluster_sections}</div>
    </section>

    <details class="taxonomy-secondary-section" id="review">
      <summary>
        <div>
          <span class="row-kicker">Normalization</span>
          <h2>Pending Review Queue</h2>
          <p>Draft new groups and normalization candidates that still need human review.</p>
        </div>
        <div class="taxonomy-row-metrics">
          <span><b>#{format_count(proposed_candidates.length)}</b><small>pending</small></span>
          <span><b>#{format_count(proposed_review.dig("summary", "accepted_new_groups").to_i)}</b><small>accepted</small></span>
          <span><b>#{format_count(proposed_review.dig("summary", "source_candidates_folded").to_i)}</b><small>folded</small></span>
        </div>
      </summary>
      <div class="taxonomy-grid">#{proposed_rows}</div>
    </details>

    <details class="taxonomy-secondary-section" id="methodology">
      <summary>
        <div>
          <span class="row-kicker">Methodology</span>
          <h2>Taxonomy Methodology</h2>
          <p>Broad parent structures used during normalization.</p>
        </div>
        <div class="taxonomy-row-metrics">
          <span><b>#{format_count(hierarchies.length)}</b><small>hierarchies</small></span>
        </div>
      </summary>
      <div class="taxonomy-grid">#{hierarchy_rows}</div>
    </details>
  HTML

  write_page(current, layout(
    title: "Taxonomy",
    subtitle: "A portal into canonical motif families, clustered symbolic regions, and normalization review status.",
    current_output: current,
    body: body,
    page_class: "taxonomy-page"
  ))

  standalone_output = "taxonomy/constellation.html"
  standalone_body = <<~HTML
    <section class="section">
      <div class="section-heading">
        <h2>Motif Family Cluster Map</h2>
        <a href="#{relative_url(standalone_output, "taxonomy/index.html")}">Back to taxonomy</a>
      </div>
      #{taxonomy_constellation_html(normalization, proposed_review, standalone_output, data_id: "taxonomy-constellation-data-full", family_analyses: family_analyses)}
    </section>
  HTML
  write_page(standalone_output, layout(
    title: "Taxonomy Cluster Map",
    subtitle: "A clustered knowledge graph of canonical motif families and pending new group candidates.",
    current_output: standalone_output,
    body: standalone_body,
    page_class: "taxonomy-page constellation-page",
    extra_head: %(<script src="https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js" defer></script>)
  ))
end

def build_extractions(extractions)
  current = "extractions/index.html"
  rows = extractions.map do |item|
    data = item[:data]
    motif_terms = data.fetch("candidate_motifs", []).flat_map do |motif|
      [motif["label"], motif["taxonomy_refs"]]
    end.flatten.compact.map(&:to_s)
    motifs = motif_terms.join(", ")
    source_output = output_for_repo_path(data["source_text_path"])
    <<~HTML
      <article class="list-row searchable" data-search="#{esc([data["record_id"], data.dig("passage_locator", "label"), motifs, data["source_text_path"]].join(" "))}">
        <div>
          <span class="row-kicker">#{esc(data.dig("passage_locator", "label"))}</span>
          <h3><a href="#{esc(relative_url(current, item[:output]))}">#{esc(data["record_id"])}</a></h3>
          <p>#{esc(motifs)}</p>
        </div>
        <small><a href="#{esc(relative_url(current, source_output))}">source</a></small>
      </article>
    HTML
  end.join

  body = <<~HTML
    <section class="toolbar">
      <input type="search" class="search-input" placeholder="Search extraction records" data-search-target=".searchable" data-query-param="q">
    </section>
    <section class="list-panel">#{rows}</section>
  HTML
  write_page(current, layout(title: "Extraction Records", subtitle: "Structured evidence records for motifs, figures, symbols, scenes, and claims.", current_output: current, body: body))

  extractions.each do |item|
    data = item[:data]
    output = item[:output]
    pretty = esc(YAML.dump(data))
    body = <<~HTML
      <section class="doc-shell">
        <aside class="metadata-panel">
          <dl>
            <dt>Record</dt><dd>#{esc(data["record_id"])}</dd>
            <dt>Passage</dt><dd>#{esc(data.dig("passage_locator", "label"))}</dd>
            <dt>Source</dt><dd>#{esc(data["source_text_path"])}</dd>
            <dt>Status</dt><dd>#{esc(data.dig("reviewer_status", "status"))}</dd>
          </dl>
        </aside>
        <article class="document">
          <h2>#{esc(data["record_id"])}</h2>
          <pre><code>#{pretty}</code></pre>
        </article>
      </section>
    HTML
    write_page(output, layout(title: data["record_id"], current_output: output, body: body))
  end
end

def build_timeline(timeline, texts)
  current = "timeline/index.html"
  entries = timeline.fetch("entries", [])
  if entries.empty?
    entries = texts.map do |item|
      metadata = item[:metadata]
      {
        "id" => metadata["id"],
        "title" => metadata["title"],
        "tradition" => metadata["tradition"],
        "culture" => metadata["culture"],
        "date_range" => metadata["date_range"],
        "text_path" => item[:path],
        "notes" => "Generated from source-text metadata until curated chronology is added."
      }
    end
  end

  rows = entries.sort_by { |entry| [timeline_sort_value(entry), entry["title"].to_s] }.map do |entry|
    tradition_key = entry["tradition"] || entry["tradition_cluster"]
    text_paths = entry["current_text_paths"] || entry["text_paths"] || [entry["text_path"]].compact
    text_links = text_paths.map do |path|
      label = File.basename(path.to_s, ".md").split("-").map(&:capitalize).join(" ")
      link_to_output(current, output_for_repo_path(path.to_s), label)
    end.join(", ")
    date_label = entry.dig("approximate_date_range", "display") || entry["date_label"] || entry["date_range"] || entry["approx_date"] || "undated / uncertain"
    notes = entry["uncertainty"] || entry["uncertainty_note"] || entry["notes"] || entry["method_note"]
    <<~HTML
      <article class="timeline-row searchable" data-search="#{esc([entry["title"], tradition_key, entry["culture"], date_label, notes].join(" "))}">
        <div class="timeline-date">#{esc(date_label)}</div>
        <div class="timeline-body">
          <span class="row-kicker">#{esc(tradition_label(tradition_key))}</span>
          <h3>#{esc(entry["title"] || entry["id"])}</h3>
          <p>#{esc([entry["timeline_label"], entry["culture"], notes].compact.join(" - "))}</p>
          #{text_links.empty? ? "" : "<small>#{text_links}</small>"}
        </div>
      </article>
    HTML
  end.join

  body = <<~HTML
    <section class="insight-band">
      <div>
        <span class="row-kicker">Chronology</span>
        <h2>Approximate Dates, Not False Precision</h2>
        <p>The timeline is a scaffold for comparison. It keeps date uncertainty explicit so similarities can be studied without pretending every tradition has a single clean timestamp.</p>
      </div>
      <div class="insight-stats">
        <strong>#{entries.length}</strong>
        <span>dated corpus anchors</span>
      </div>
    </section>
    <section class="toolbar">
      <input type="search" class="search-input" placeholder="Search eras, cultures, or texts" data-search-target=".searchable">
    </section>
    <section class="timeline-list">#{rows}</section>
  HTML

  write_page(current, layout(
    title: "Timeline",
    subtitle: "A cautious chronology for comparing texts, traditions, motifs, and reception layers.",
    current_output: current,
    body: body
  ))
end

STYLE_CSS = <<~CSS
  @import url("https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600;700&family=JetBrains+Mono:wght@600;800&display=swap");

  :root {
    --ink: #20231f;
    --muted: #62675f;
    --paper: #fbfbf8;
    --surface: #ffffff;
    --line: #dcded6;
    --teal: #167c80;
    --brick: #a9472b;
    --gold: #b88417;
    --violet: #4f4a85;
    --shadow: 0 12px 30px rgba(32, 35, 31, 0.08);
  }

  * { box-sizing: border-box; }

  body {
    margin: 0;
    background: var(--paper);
    color: var(--ink);
    font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    line-height: 1.55;
  }

  a { color: var(--teal); text-decoration-thickness: 1px; text-underline-offset: 3px; }
  a:hover { color: var(--brick); }

  .site-header {
    position: sticky;
    top: 0;
    z-index: 10;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 24px;
    padding: 14px clamp(16px, 4vw, 48px);
    background: rgba(251, 251, 248, 0.94);
    border-bottom: 1px solid var(--line);
    backdrop-filter: blur(12px);
  }

  .brand {
    display: inline-flex;
    align-items: center;
    gap: 12px;
    color: var(--ink);
    text-decoration: none;
    min-width: 220px;
  }

  .brand-mark {
    display: grid;
    place-items: center;
    width: 42px;
    height: 42px;
    border: 1px solid var(--ink);
    border-radius: 6px;
    font-weight: 800;
    letter-spacing: 0;
  }

  .brand small {
    display: block;
    color: var(--muted);
    font-size: 12px;
  }

  .site-nav {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    justify-content: flex-end;
  }

  .nav-link {
    padding: 8px 10px;
    border-radius: 6px;
    color: var(--ink);
    font-size: 14px;
    text-decoration: none;
  }

  .nav-link.active, .nav-link:hover {
    background: #eef3ee;
    color: var(--ink);
  }

  main {
    width: min(1180px, calc(100% - 32px));
    margin: 0 auto;
    padding: 40px 0 72px;
  }

  .page-heading {
    padding: 28px 0 34px;
    border-bottom: 1px solid var(--line);
  }

  .eyebrow, .row-kicker, .card-meta {
    margin: 0 0 8px;
    color: var(--brick);
    font-size: 12px;
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  h1, h2, h3 {
    margin: 0;
    line-height: 1.08;
    letter-spacing: 0;
  }

  h1 {
    max-width: 900px;
    font-size: clamp(42px, 7vw, 86px);
  }

  h2 { font-size: clamp(26px, 3vw, 40px); }
  h3 { font-size: 20px; }

  .lead {
    max-width: 760px;
    color: var(--muted);
    font-size: 20px;
  }

  .home-intro {
    max-width: 46rem;
    margin: 0 auto 2.2rem;
    text-align: center;
  }
  .home-intro p {
    font-size: 1.06rem;
    line-height: 1.65;
    margin: 0 0 0.9rem;
  }
  .home-intro-links {
    font-size: 0.98rem;
    opacity: 0.92;
  }
  .findings .section p {
    max-width: 44rem;
    line-height: 1.7;
  }
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
    margin: 28px 0;
  }

  .explorer-dashboard {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
    margin: 28px 0 18px;
  }

  .stat {
    padding: 18px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    box-shadow: var(--shadow);
  }

  .stat strong {
    display: block;
    font-size: 34px;
    line-height: 1;
  }

  .stat span { color: var(--muted); }

  .section { margin-top: 46px; }

  .section-heading, .motif-section-heading {
    display: flex;
    align-items: end;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 16px;
  }

  .card-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 14px;
  }

  .card {
    display: block;
    min-height: 180px;
    padding: 18px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    box-shadow: var(--shadow);
    color: var(--ink);
    text-decoration: none;
  }

  .card h3 { margin-bottom: 12px; }
  .card p, .muted { color: var(--muted); }

  .motif-cloud {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 10px;
  }

  .motif-cloud a {
    display: flex;
    justify-content: space-between;
    gap: 14px;
    padding: 14px;
    background: #f2f5f1;
    border: 1px solid var(--line);
    border-left: 4px solid var(--gold);
    border-radius: 6px;
    color: var(--ink);
    text-decoration: none;
  }

  .motif-cloud span { color: var(--muted); font-size: 13px; }

  .compact-list, .list-panel {
    display: grid;
    gap: 10px;
  }

  .compact-list a, .list-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 18px;
    padding: 14px 16px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    color: var(--ink);
    text-decoration: none;
  }

  .compact-list small, .list-row small { color: var(--muted); overflow-wrap: anywhere; }
  .list-row h3 { margin: 2px 0 8px; }
  .list-row p { margin: 0; color: var(--muted); }

  .toolbar {
    margin: 28px 0;
  }

  .explorer-controls {
    display: grid;
    grid-template-columns: minmax(260px, 1fr) minmax(180px, 240px) minmax(180px, 240px) auto;
    gap: 10px;
    align-items: center;
    margin: 18px 0 34px;
    padding: 12px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
  }

  .search-input,
  .explorer-filter {
    width: 100%;
    min-height: 48px;
    padding: 12px 14px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    color: var(--ink);
    font: inherit;
  }

  .toggle-control {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    min-height: 48px;
    padding: 0 10px;
    color: var(--muted);
    white-space: nowrap;
  }

  .toggle-control input { width: 18px; height: 18px; }

  .result-count {
    color: var(--muted);
    font-weight: 700;
  }

  .explorer-list {
    display: grid;
    gap: 12px;
  }

  .explorer-row {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 150px;
    gap: 18px;
    align-items: stretch;
    padding: 16px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    box-shadow: var(--shadow);
  }

  .explorer-main h3 { margin: 2px 0 10px; }
  .explorer-main p { margin: 0 0 12px; color: var(--muted); }

  .chip-row {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 5px 8px;
    background: #eef3ee;
    border: 1px solid var(--line);
    border-radius: 999px;
    color: var(--ink);
    font-size: 12px;
    font-weight: 700;
  }

  .chip strong {
    display: inline-grid;
    place-items: center;
    min-width: 20px;
    min-height: 20px;
    padding: 0 5px;
    background: var(--surface);
    border-radius: 999px;
    color: var(--brick);
  }

  .explorer-metrics {
    position: relative;
    display: grid;
    align-content: center;
    justify-items: end;
    gap: 2px;
    padding: 12px;
    overflow: hidden;
    background: #fbfaf2;
    border: 1px solid var(--line);
    border-radius: 8px;
    text-align: right;
  }

  .explorer-metrics strong,
  .explorer-metrics span,
  .explorer-metrics small {
    position: relative;
    z-index: 1;
  }

  .explorer-metrics strong {
    font-size: 34px;
    line-height: 1;
  }

  .explorer-metrics span,
  .explorer-metrics small { color: var(--muted); }

  .explorer-metrics i {
    position: absolute;
    inset: auto 0 0 auto;
    height: 6px;
    background: var(--gold);
  }

  .matrix-wrap { border: 1px solid var(--line); border-radius: 8px; }
  .matrix-table th:first-child { min-width: 180px; }
  .matrix-table th:not(:first-child) { min-width: 120px; }
  .matrix-table td { text-align: center; }
  .matrix-hit {
    background: rgba(22, 124, 128, 0.12);
    font-weight: 800;
  }
  .matrix-empty { background: #f6f7f2; color: transparent; }

  .doc-shell {
    display: grid;
    grid-template-columns: 280px minmax(0, 1fr);
    gap: 28px;
    align-items: start;
    margin-top: 28px;
  }

  .metadata-panel {
    position: sticky;
    top: 86px;
    padding: 16px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
  }

  .metadata-panel dl { margin: 0; }
  .metadata-panel dt { color: var(--brick); font-size: 12px; font-weight: 800; text-transform: uppercase; }
  .metadata-panel dd { margin: 0 0 12px; overflow-wrap: anywhere; color: var(--muted); }

  .document {
    min-width: 0;
    padding: 28px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
  }

  .document h2, .document h3, .document h4 { margin: 28px 0 12px; }
  .document p { margin: 0 0 16px; }
  .document blockquote {
    margin: 18px 0;
    padding: 14px 18px;
    border-left: 4px solid var(--teal);
    background: #eef6f5;
  }

  .document pre {
    overflow: auto;
    padding: 16px;
    background: #20231f;
    color: #f6f7f2;
    border-radius: 8px;
  }

  code {
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 0.92em;
  }

  .table-wrap { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; background: var(--surface); }
  th, td { padding: 10px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }
  th { color: var(--brick); font-size: 13px; }

  .motif-section {
    margin: 22px 0;
    padding: 18px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
  }

  .taxonomy-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 14px;
  }

  .taxonomy-family {
    display: grid;
    gap: 14px;
    padding: 18px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    box-shadow: var(--shadow);
  }

  .taxonomy-family.proposed {
    border-left: 4px solid var(--gold);
  }

  .taxonomy-family-head {
    display: grid;
    gap: 6px;
  }

  .taxonomy-family p {
    margin: 0;
    color: var(--muted);
  }

  .taxonomy-fields {
    display: grid;
    gap: 12px;
  }

  .taxonomy-field strong {
    display: block;
    margin-bottom: 8px;
    color: var(--brick);
    font-size: 12px;
    text-transform: uppercase;
  }

  .taxonomy-dashboard {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
    margin: 28px 0 14px;
  }

  .taxonomy-route-grid,
  .taxonomy-core-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 14px;
  }

  .taxonomy-route-card,
  .taxonomy-core-card,
  .taxonomy-family-row {
    color: var(--ink);
    text-decoration: none;
  }

  .taxonomy-route-card,
  .taxonomy-core-card {
    display: grid;
    align-content: start;
    gap: 12px;
    min-height: 164px;
    padding: 18px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    box-shadow: var(--shadow);
  }

  .taxonomy-route-card {
    min-height: 132px;
    background: #f4f0e5;
    border-color: #ded2ae;
  }

  .taxonomy-route-card h3,
  .taxonomy-core-card h3,
  .taxonomy-family-row h3,
  .taxonomy-cluster summary h3 {
    margin: 0;
  }

  .taxonomy-core-card p,
  .taxonomy-family-row p,
  .taxonomy-cluster summary p,
  .taxonomy-secondary-section summary p {
    margin: 6px 0 0;
    color: var(--muted);
  }

  .taxonomy-searchbar {
    position: sticky;
    top: 0;
    z-index: 8;
    padding: 10px;
    background: rgba(246, 247, 242, 0.92);
    border: 1px solid var(--line);
    border-radius: 8px;
    backdrop-filter: blur(12px);
  }

  .taxonomy-card-metrics,
  .taxonomy-row-metrics {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .taxonomy-card-metrics span,
  .taxonomy-row-metrics span {
    min-width: 90px;
    padding: 8px 10px;
    background: #f8f7f1;
    border: 1px solid var(--line);
    border-radius: 6px;
  }

  .taxonomy-route-card .taxonomy-card-metrics span {
    background: rgba(255, 255, 255, 0.58);
    border-color: #ded2ae;
  }

  .taxonomy-card-metrics b,
  .taxonomy-row-metrics b {
    display: block;
    color: var(--brick);
    font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 16px;
    line-height: 1;
  }

  .taxonomy-card-metrics small,
  .taxonomy-row-metrics small {
    color: var(--muted);
    font-size: 11px;
  }

  .taxonomy-clusters {
    display: grid;
    gap: 12px;
  }

  .taxonomy-cluster,
  .taxonomy-secondary-section {
    overflow: hidden;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    box-shadow: var(--shadow);
  }

  .taxonomy-cluster > summary,
  .taxonomy-secondary-section > summary {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    gap: 18px;
    align-items: center;
    padding: 18px;
    cursor: pointer;
    list-style: none;
  }

  .taxonomy-cluster > summary::-webkit-details-marker,
  .taxonomy-secondary-section > summary::-webkit-details-marker {
    display: none;
  }

  .taxonomy-cluster-body {
    display: grid;
    gap: 8px;
    padding: 0 12px 12px;
  }

  .taxonomy-family-row {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    gap: 18px;
    align-items: center;
    padding: 14px;
    background: #fbfaf6;
    border: 1px solid var(--line);
    border-radius: 6px;
  }

  .taxonomy-family-row:hover,
  .taxonomy-core-card:hover,
  .taxonomy-route-card:hover {
    border-color: #cbb76d;
    box-shadow: 0 12px 26px rgba(36, 31, 21, 0.10);
  }

  .taxonomy-secondary-section {
    margin-top: 28px;
  }

  .taxonomy-secondary-section > .taxonomy-grid {
    padding: 0 18px 18px;
  }

  .pending-badge {
    width: fit-content;
    padding: 4px 8px;
    background: #fff3d8;
    border: 1px solid #ead49a;
    border-radius: 999px;
    color: #755313;
    font-size: 12px;
    font-weight: 800;
    text-transform: capitalize;
  }

  .constellation-map {
    isolation: isolate;
    overflow: hidden;
    background:
      radial-gradient(circle at 24% 22%, rgba(186, 160, 79, 0.14), transparent 26%),
      radial-gradient(circle at 76% 34%, rgba(106, 142, 134, 0.10), transparent 24%),
      radial-gradient(circle at 50% 86%, rgba(157, 72, 45, 0.09), transparent 30%),
      #0b0b09;
    border: 1px solid #242219;
    border-radius: 8px;
    box-shadow: 0 22px 60px rgba(11, 11, 9, 0.34);
  }

  .constellation-toolbar {
    display: grid;
    grid-template-columns: minmax(220px, 1fr) auto auto auto;
    gap: 14px;
    align-items: center;
    padding: 12px;
    background: rgba(15, 15, 12, 0.96);
    border-bottom: 1px solid #242219;
  }

  .constellation-expand-all {
    min-height: 42px;
    padding: 0 14px;
    background: rgba(186, 160, 79, 0.14);
    border: 1px solid rgba(186, 160, 79, 0.42);
    border-radius: 6px;
    color: #f4ead0;
    font: inherit;
    font-size: 13px;
    cursor: pointer;
    transition: background 140ms ease;
  }

  .constellation-expand-all:hover {
    background: rgba(186, 160, 79, 0.26);
  }

  .constellation-search {
    min-height: 42px;
    padding: 10px 12px;
    background: rgba(255, 255, 255, 0.045);
    border: 1px solid rgba(186, 160, 79, 0.24);
    border-radius: 6px;
    color: #f4ead0;
    font: inherit;
  }

  .constellation-search::placeholder {
    color: rgba(244, 234, 208, 0.52);
  }

  .constellation-toggle {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    color: rgba(244, 234, 208, 0.78);
    font-size: 12px;
    cursor: pointer;
    user-select: none;
  }

  .constellation-toggle input {
    accent-color: #baa04f;
  }

  .constellation-legend {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-end;
    gap: 12px;
    color: rgba(244, 234, 208, 0.68);
    font-size: 12px;
  }

  .constellation-legend span {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    white-space: nowrap;
  }

  .constellation-legend i {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 999px;
    background: #baa04f;
    box-shadow: 0 0 10px rgba(186, 160, 79, 0.7);
  }

  .constellation-legend i.small {
    width: 8px;
    height: 8px;
  }

  .constellation-legend i.dash {
    width: 18px;
    height: 0;
    border-radius: 0;
    background: transparent;
    border-top: 1px dashed rgba(186, 160, 79, 0.82);
    box-shadow: none;
  }

  .constellation-stage {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 360px;
    min-height: 720px;
  }

  .constellation-svg {
    width: 100%;
    height: 720px;
    min-height: 600px;
    display: block;
    background:
      radial-gradient(circle at 50% 50%, rgba(186, 160, 79, 0.08), transparent 48%),
      radial-gradient(circle at 12% 88%, rgba(244, 234, 208, 0.05), transparent 18%),
      linear-gradient(180deg, rgba(255,255,255,0.02), transparent);
    touch-action: manipulation;
  }

  .dendro-cluster-arc {
    pointer-events: none;
    fill: none;
    stroke: rgba(186, 160, 79, 0.42);
    stroke-width: 1.2;
    opacity: 0.85;
  }

  .dendro-cluster-label {
    pointer-events: none;
    fill: rgba(246, 231, 180, 0.86);
    font-family: "Cormorant Garamond", Georgia, serif;
    font-size: 14px;
    font-weight: 700;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    text-anchor: middle;
    text-shadow: 0 1px 10px #0b0b09;
  }

  .dendro-spoke {
    pointer-events: none;
    fill: none;
    stroke: rgba(186, 160, 79, 0.16);
    stroke-width: 1;
    transition: stroke 160ms ease, stroke-width 160ms ease, opacity 160ms ease;
  }

  .dendro-spoke.is-active {
    stroke: rgba(255, 226, 143, 0.78);
    stroke-width: 1.4;
  }

  .dendro-bundle {
    pointer-events: none;
    fill: none;
    stroke: rgba(186, 160, 79, 0.20);
    stroke-width: 0.9;
    opacity: 0.55;
    mix-blend-mode: screen;
    transition: stroke 160ms ease, stroke-width 160ms ease, opacity 160ms ease;
  }

  .dendro-bundle.pending {
    stroke-dasharray: 4 5;
    opacity: 0.55;
  }

  .dendro-bundle.is-active {
    stroke: rgba(255, 226, 143, 0.95);
    stroke-width: 1.6;
    opacity: 1;
  }

  .constellation-map.bundles-hidden .dendro-bundle:not(.is-active) {
    opacity: 0;
  }

  .dendro-cluster-node {
    cursor: pointer;
    fill: rgba(186, 160, 79, 0.34);
    stroke: rgba(255, 241, 179, 0.78);
    stroke-width: 1.6;
    filter: drop-shadow(0 0 14px rgba(186, 160, 79, 0.55));
    transition: stroke-width 140ms ease, filter 140ms ease, fill 140ms ease;
  }

  .dendro-cluster-node:hover {
    fill: rgba(186, 160, 79, 0.5);
  }

  .dendro-cluster-node.expanded {
    fill: rgba(186, 160, 79, 0.16);
    stroke-dasharray: 2 3;
  }

  .dendro-cluster-node-label {
    pointer-events: none;
    fill: #f6e7b4;
    font-family: "Cormorant Garamond", Georgia, serif;
    font-size: 14px;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    text-shadow: 0 1px 8px #0b0b09;
  }

  .dendro-cluster-count {
    pointer-events: none;
    fill: rgba(244, 234, 208, 0.72);
    font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 10px;
    font-weight: 700;
    text-anchor: middle;
  }

  .dendro-node {
    cursor: pointer;
    fill: #baa04f;
    stroke: rgba(255, 241, 179, 0.82);
    stroke-width: 1.2;
    filter: drop-shadow(0 0 7px rgba(186, 160, 79, 0.58));
    transition: stroke-width 140ms ease, filter 140ms ease, opacity 140ms ease;
  }

  .dendro-node.pending {
    fill: rgba(186, 160, 79, 0.55);
    stroke: rgba(255, 241, 179, 0.48);
    stroke-dasharray: 3 3;
    filter: drop-shadow(0 0 5px rgba(186, 160, 79, 0.4));
  }

  .dendro-node.is-active {
    stroke-width: 2.4;
    filter: drop-shadow(0 0 16px rgba(255, 226, 143, 0.96));
  }

  .dendro-node.is-dim,
  .dendro-label.is-dim,
  .dendro-spoke.is-dim,
  .dendro-bundle.is-dim {
    opacity: 0.18;
  }

  .dendro-label {
    pointer-events: none;
    fill: rgba(244, 234, 208, 0.86);
    font-family: "Cormorant Garamond", Georgia, serif;
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 0;
    text-shadow: 0 1px 6px #0b0b09;
    transition: fill 140ms ease, font-size 140ms ease, opacity 140ms ease;
  }

  .dendro-label.pending {
    fill: rgba(233, 219, 173, 0.62);
    font-style: italic;
  }

  .dendro-label.is-active {
    fill: #fff1b3;
    font-size: 13.5px;
    font-weight: 700;
  }

  .constellation-panel {
    display: flex;
    flex-direction: column;
    gap: 14px;
    padding: 24px;
    background: rgba(15, 15, 12, 0.94);
    border-left: 1px solid #242219;
    color: #f4ead0;
    overflow: auto;
  }

  .constellation-panel h3 {
    color: #f6e7b4;
    font-family: "Cormorant Garamond", Georgia, serif;
    font-size: 32px;
    line-height: 0.96;
  }

  .constellation-panel p {
    margin: 0;
    color: rgba(244, 234, 208, 0.74);
  }

  .constellation-panel a {
    color: #e6c76d;
  }

  .constellation-panel-section {
    margin-top: 4px;
  }

  .constellation-panel-section strong {
    display: flex;
    justify-content: space-between;
    gap: 10px;
    margin-bottom: 8px;
    color: #baa04f;
    font-size: 12px;
    text-transform: uppercase;
  }

  .constellation-panel-list {
    display: flex;
    flex-wrap: wrap;
    gap: 7px;
    max-height: 170px;
    overflow: auto;
    padding-right: 4px;
  }

  .constellation-panel-list a,
  .constellation-panel-list span {
    display: inline-flex;
    align-items: baseline;
    gap: 5px;
    padding: 5px 8px;
    background: rgba(186, 160, 79, 0.12);
    border: 1px solid rgba(186, 160, 79, 0.28);
    border-radius: 999px;
    color: #f4ead0;
    font-size: 12px;
    text-decoration: none;
  }

  .constellation-panel-list small {
    color: rgba(244, 234, 208, 0.58);
    font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 10px;
  }

  .constellation-panel-metrics {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
  }

  .constellation-panel-metrics span,
  .constellation-panel-action {
    padding: 9px 10px;
    background: rgba(186, 160, 79, 0.10);
    border: 1px solid rgba(186, 160, 79, 0.24);
    border-radius: 6px;
  }

  .constellation-panel-metrics b {
    display: block;
    color: #f6e7b4;
    font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 17px;
  }

  .constellation-panel-metrics small {
    color: rgba(244, 234, 208, 0.66);
  }

  .constellation-panel-action {
    display: inline-flex;
    justify-content: center;
    color: #0b0b09 !important;
    background: #baa04f;
    border-color: #d8c67e;
    font-weight: 800;
    text-decoration: none;
  }

  .constellation-page main {
    width: min(1440px, calc(100% - 32px));
  }

  .constellation-page .constellation-stage {
    min-height: 860px;
  }

  .constellation-page .constellation-svg {
    height: 860px;
  }

  .insight-band {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 220px;
    gap: 18px;
    align-items: stretch;
    margin: 28px 0 42px;
    padding: 22px;
    background: #eef6f5;
    border: 1px solid #c7dfdc;
    border-radius: 8px;
  }

  .insight-band p { max-width: 760px; margin: 12px 0 0; color: var(--muted); }

  .insight-stats {
    display: grid;
    place-content: center;
    padding: 18px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    text-align: center;
  }

  .insight-stats strong {
    display: block;
    font-size: 44px;
    line-height: 1;
  }

  .insight-stats span { color: var(--muted); }

  .signal-bars {
    display: grid;
    gap: 10px;
  }

  .signal-bar {
    position: relative;
    display: grid;
    grid-template-columns: minmax(160px, 1fr) 60px;
    gap: 12px;
    align-items: center;
    min-height: 42px;
    padding: 9px 12px;
    overflow: hidden;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 6px;
  }

  .signal-bar span, .signal-bar strong { position: relative; z-index: 1; }
  .signal-bar strong { text-align: right; }
  .signal-bar i {
    position: absolute;
    inset: 0 auto 0 0;
    background: rgba(184, 132, 23, 0.18);
  }

  .family-research-page main {
    width: min(1320px, calc(100% - 32px));
  }

  .family-tabs {
    position: sticky;
    top: 0;
    z-index: 9;
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin: 18px 0 22px;
    padding: 10px;
    background: rgba(246, 247, 242, 0.92);
    border: 1px solid var(--line);
    border-radius: 8px;
    backdrop-filter: blur(12px);
  }

  .family-tabs a {
    display: inline-flex;
    align-items: center;
    min-height: 34px;
    padding: 7px 10px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 6px;
    color: var(--ink);
    font-size: 13px;
    font-weight: 800;
    text-decoration: none;
  }

  .family-tabs a:hover {
    border-color: #cbb76d;
    background: #f4f0e5;
  }

  .family-hero-panel {
    margin-top: 28px;
    padding: 22px;
    background: #f4f0e5;
    border: 1px solid #ded2ae;
    border-radius: 8px;
  }

  .family-hero-panel > p {
    max-width: 920px;
    margin: 0 0 18px;
    color: var(--muted);
    font-size: 18px;
  }

  .family-stats {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
    margin-bottom: 12px;
  }

  .family-stats .stat {
    box-shadow: none;
  }

  .family-stats .stat strong {
    font-size: clamp(22px, 2.3vw, 34px);
    overflow-wrap: anywhere;
  }

  .family-highlight-grid {
    display: grid;
    grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr) minmax(260px, 0.8fr);
    gap: 12px;
    margin: 4px 0 12px;
  }

  .family-highlight-grid article {
    min-width: 0;
    padding: 14px;
    background: rgba(255, 255, 255, 0.52);
    border: 1px solid #ded2ae;
    border-radius: 8px;
  }

  .family-highlight-grid p {
    margin: 8px 0 0;
    color: var(--muted);
  }

  .family-chip-list {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 10px;
  }

  .family-chip {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    max-width: 100%;
    padding: 6px 8px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 999px;
    color: var(--ink);
    font-size: 12px;
    font-weight: 800;
    text-decoration: none;
  }

  .family-chip span {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .family-chip strong {
    color: var(--brick);
    font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 11px;
  }

  .sort-control {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    color: var(--muted);
    font-weight: 700;
  }

  .sort-control select {
    min-height: 40px;
    padding: 8px 10px;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--surface);
    color: var(--ink);
    font: inherit;
  }

  .family-tradition-bars,
  .family-tradition-list,
  .related-family-list,
  .family-timeline {
    display: grid;
    gap: 12px;
  }

  .family-tradition-row {
    position: relative;
    display: grid;
    grid-template-columns: minmax(170px, 1fr) 80px;
    gap: 16px;
    align-items: center;
    min-height: 48px;
    padding: 12px 14px;
    overflow: hidden;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    color: var(--ink);
    text-decoration: none;
  }

  .family-tradition-row span,
  .family-tradition-row strong {
    position: relative;
    z-index: 1;
  }

  .family-tradition-row strong {
    text-align: right;
  }

  .family-tradition-row i {
    position: absolute;
    inset: 0 auto 0 0;
    background: rgba(22, 124, 128, 0.13);
  }

  .family-tradition-section,
  .related-family-row,
  .family-timeline-row,
  .family-comparison-grid article {
    padding: 18px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    box-shadow: var(--shadow);
  }

  details.family-tradition-section {
    padding: 0;
    overflow: hidden;
  }

  .family-tradition-head {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    align-items: start;
    margin-bottom: 0;
  }

  details.family-tradition-section > summary.family-tradition-head {
    cursor: pointer;
    padding: 16px 18px;
    list-style: none;
  }

  details.family-tradition-section > summary.family-tradition-head::-webkit-details-marker {
    display: none;
  }

  details.family-tradition-section > summary.family-tradition-head::after {
    content: "+";
    display: inline-grid;
    place-items: center;
    width: 26px;
    height: 26px;
    margin-left: auto;
    border: 1px solid var(--line);
    border-radius: 999px;
    color: var(--brick);
    font-weight: 900;
  }

  details.family-tradition-section[open] > summary.family-tradition-head::after {
    content: "-";
  }

  .family-tradition-head strong {
    color: var(--brick);
    white-space: nowrap;
  }

  .family-tradition-body {
    display: grid;
    gap: 14px;
    padding: 0 18px 18px;
  }

  .family-tradition-body > p {
    margin: 0;
    color: var(--muted);
  }

  .family-evidence-toolbar {
    margin-bottom: 14px;
  }

  .family-evidence-table table {
    font-size: 14px;
  }

  .family-more-passages {
    padding: 10px 12px;
    background: #f8f7f1;
    border: 1px dashed var(--line);
    border-radius: 8px;
  }

  .family-more-passages > summary {
    cursor: pointer;
    color: var(--teal);
    font-weight: 800;
  }

  .family-more-passages .table-wrap {
    margin-top: 12px;
  }

  .family-comparison-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 14px;
  }

  .related-family-row h3,
  .family-timeline-row h3 {
    margin-bottom: 8px;
  }

  .related-family-row p,
  .family-timeline-row p {
    margin: 0;
    color: var(--muted);
  }

  .family-timeline-row {
    display: grid;
    grid-template-columns: 240px minmax(0, 1fr);
    gap: 18px;
  }

  .motif-detail-grid {
    display: grid;
    grid-template-columns: 260px minmax(0, 1fr);
    gap: 28px;
    align-items: start;
    margin-top: 28px;
  }

  .confidence {
    display: inline-block;
    min-width: 62px;
    padding: 3px 7px;
    border-radius: 999px;
    background: #eef3ee;
    color: var(--ink);
    font-size: 12px;
    font-weight: 700;
    text-align: center;
  }

  .confidence.high { background: #e6f3ea; color: #23613a; }
  .confidence.medium { background: #fff3d8; color: #755313; }
  .confidence.low { background: #f4e9e5; color: #8a3d27; }

  .timeline-list {
    position: relative;
    display: grid;
    gap: 14px;
  }

  .timeline-row {
    display: grid;
    grid-template-columns: 260px minmax(0, 1fr);
    gap: 18px;
    padding: 16px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    box-shadow: var(--shadow);
  }

  .timeline-date {
    color: var(--brick);
    font-weight: 800;
  }

  .timeline-body p { margin: 8px 0 0; color: var(--muted); }

  .site-footer {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    padding: 24px clamp(16px, 4vw, 48px);
    border-top: 1px solid var(--line);
    color: var(--muted);
  }

  .is-hidden { display: none !important; }

  @media (max-width: 900px) {
    .site-header, .section-heading, .motif-section-heading, .site-footer {
      align-items: flex-start;
      flex-direction: column;
    }

    .stats-grid, .explorer-dashboard, .card-grid, .motif-cloud, .family-stats, .family-comparison-grid, .family-highlight-grid, .taxonomy-dashboard, .taxonomy-route-grid, .taxonomy-core-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .doc-shell, .motif-detail-grid, .timeline-row, .insight-band, .explorer-controls, .explorer-row, .taxonomy-grid, .constellation-stage, .family-timeline-row, .constellation-toolbar, .taxonomy-family-row, .taxonomy-cluster > summary, .taxonomy-secondary-section > summary {
      grid-template-columns: 1fr;
    }

    .metadata-panel { position: static; }
    .explorer-metrics { justify-items: start; text-align: left; }
    .constellation-legend { justify-content: flex-start; }
    .constellation-panel { border-left: 0; border-top: 1px solid #242219; }
  }

  @media (max-width: 560px) {
    main { width: min(100% - 24px, 1180px); padding-top: 20px; }
    h1 { font-size: 40px; }
    .stats-grid, .explorer-dashboard, .card-grid, .motif-cloud, .family-stats, .family-comparison-grid, .family-highlight-grid, .taxonomy-dashboard, .taxonomy-route-grid, .taxonomy-core-grid {
      grid-template-columns: 1fr;
    }
    .document { padding: 18px; }
  }
CSS

APP_JS = <<~JS
  (() => {
    document.querySelectorAll(".search-input").forEach((input) => {
      const selector = input.dataset.searchTarget;
      if (!selector) return;
      const items = Array.from(document.querySelectorAll(selector));
      const applySearch = () => {
        const query = input.value.trim().toLowerCase();
        items.forEach((item) => {
          const haystack = (item.dataset.search || item.textContent).toLowerCase();
          item.classList.toggle("is-hidden", query.length > 0 && !haystack.includes(query));
        });
      };
      const queryParam = input.dataset.queryParam;
      if (queryParam) {
        const params = new URLSearchParams(window.location.search);
        if (params.has(queryParam)) input.value = params.get(queryParam);
      }
      input.addEventListener("input", applySearch);
      applySearch();
    });

    document.querySelectorAll("[data-sort-control]").forEach((control) => {
      const target = document.querySelector(control.dataset.sortControl);
      if (!target) return;
      const sortItems = () => {
        const rows = Array.from(target.querySelectorAll("[data-sort-item]"));
        const mode = control.value;
        rows.sort((left, right) => {
          if (mode === "alpha") {
            return (left.dataset.label || "").localeCompare(right.dataset.label || "");
          }
          return Number(right.dataset.count || 0) - Number(left.dataset.count || 0) ||
            (left.dataset.label || "").localeCompare(right.dataset.label || "");
        });
        rows.forEach((row) => target.appendChild(row));
      };
      control.addEventListener("change", sortItems);
      sortItems();
    });

    const openFamilyHashTarget = () => {
      if (!window.location.hash) return;
      const target = document.getElementById(window.location.hash.slice(1));
      if (target && target.matches("details")) {
        target.open = true;
      }
    };
    openFamilyHashTarget();
    window.addEventListener("hashchange", openFamilyHashTarget);

    const explorerRows = Array.from(document.querySelectorAll(".explorer-row"));
    const explorerSearch = document.querySelector(".explorer-search");
    const traditionFilter = document.querySelector('.explorer-filter[data-filter="tradition"]');
    const confidenceFilter = document.querySelector('.explorer-filter[data-filter="confidence"]');
    const crossToggle = document.querySelector('.explorer-toggle[data-toggle="cross"]');
    const explorerCount = document.querySelector("[data-explorer-count]");

    if (explorerRows.length && explorerSearch && traditionFilter && confidenceFilter && crossToggle) {
      const applyExplorerFilters = () => {
        const query = explorerSearch.value.trim().toLowerCase();
        const tradition = traditionFilter.value;
        const confidence = confidenceFilter.value;
        const crossOnly = crossToggle.checked;
        let visibleCount = 0;

        explorerRows.forEach((row) => {
          const haystack = (row.dataset.search || row.textContent).toLowerCase();
          const traditions = (row.dataset.traditions || "").split(/\\s+/).filter(Boolean);
          const confidences = (row.dataset.confidences || "").split(/\\s+/).filter(Boolean);
          const isCross = row.dataset.cross === "true";
          const visible =
            (!query || haystack.includes(query)) &&
            (!tradition || traditions.includes(tradition)) &&
            (!confidence || confidences.includes(confidence)) &&
            (!crossOnly || isCross);

          row.classList.toggle("is-hidden", !visible);
          if (visible) visibleCount += 1;
        });

        if (explorerCount) explorerCount.textContent = visibleCount.toString();
      };

      [explorerSearch, traditionFilter, confidenceFilter, crossToggle].forEach((control) => {
        control.addEventListener("input", applyExplorerFilters);
        control.addEventListener("change", applyExplorerFilters);
      });

      applyExplorerFilters();
    }

    document.querySelectorAll(".constellation-map").forEach((map) => {
      const dataScript = document.getElementById(map.dataset.source);
      const svg = map.querySelector(".constellation-svg");
      const panel = map.querySelector(".constellation-panel");
      const search = map.querySelector(".constellation-search");
      const bundleToggle = map.querySelector(".constellation-bundle-toggle");
      const expandAllBtn = map.querySelector(".constellation-expand-all");
      if (!dataScript || !svg || !panel) return;
      if (typeof d3 === "undefined") {
        console.warn("d3 not loaded; constellation dendrogram unavailable");
        return;
      }

      const data = JSON.parse(dataScript.textContent);
      const numberFormat = new Intl.NumberFormat("en");

      const root = d3.hierarchy(
        data.hierarchy,
        (datum) => (datum.type === "root" || datum.type === "cluster") ? datum.children : null
      );

      const allFamilyLeaves = root.descendants().filter((node) => node.depth === 2);
      const familyById = new Map(allFamilyLeaves.map((leaf) => [leaf.data.id, leaf]));
      const allClusters = root.children || [];
      const clusterById = new Map(allClusters.map((cluster) => [cluster.data.id, cluster]));

      // Collapse all clusters by default
      allClusters.forEach((cluster) => {
        cluster._children = cluster.children;
        cluster.children = null;
      });

      const crossLinks = (data.cross_links || [])
        .map((link) => ({
          ...link,
          sourceNode: familyById.get(link.source),
          targetNode: familyById.get(link.target)
        }))
        .filter((link) => link.sourceNode && link.targetNode);

      const connected = new Map(allFamilyLeaves.map((leaf) => [leaf.data.id, new Set([leaf.data.id])]));
      crossLinks.forEach((link) => {
        connected.get(link.source).add(link.target);
        connected.get(link.target).add(link.source);
      });

      let selectedFamilyId = null;
      let selectedClusterId = null;
      let bundlesVisible = bundleToggle ? bundleToggle.checked : true;

      const htmlEscape = (value) => String(value || "").replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;"
      })[char]);

      const metricFor = (datum) => Math.max(
        Number(datum.occurrence_count || 0),
        Number(datum.child_count || 0),
        1
      );

      const nodeRadius = (datum) => {
        if (datum.type === "pending") return Math.min(10, 4 + Math.sqrt(metricFor(datum)) * 0.45);
        return Math.min(16, 4.5 + Math.sqrt(metricFor(datum)) * 0.27);
      };

      const isClusterExpanded = (cluster) => Boolean(cluster.children);

      const toggleCluster = (cluster) => {
        if (cluster.children) {
          cluster._children = cluster.children;
          cluster.children = null;
          if (selectedFamilyId && cluster._children.some((c) => c.data.id === selectedFamilyId)) {
            selectedFamilyId = null;
          }
        } else if (cluster._children) {
          cluster.children = cluster._children;
          cluster._children = null;
        }
      };

      const setAllExpanded = (expand) => {
        allClusters.forEach((cluster) => {
          if (expand && !cluster.children && cluster._children) {
            cluster.children = cluster._children;
            cluster._children = null;
          } else if (!expand && cluster.children) {
            cluster._children = cluster.children;
            cluster.children = null;
          }
        });
        if (!expand) selectedFamilyId = null;
      };

      function ancestorPath(a, b) {
        const aPath = a.ancestors();
        const aSet = new Set(aPath);
        const bPath = b.ancestors();
        const lca = bPath.find((node) => aSet.has(node));
        const aBranch = [];
        for (const node of aPath) {
          aBranch.push(node);
          if (node === lca) break;
        }
        const bBranch = [];
        for (const node of bPath) {
          if (node === lca) break;
          bBranch.push(node);
        }
        return aBranch.concat(bBranch.reverse());
      }

      const showFamilyPanel = (datum) => {
        const childItems = datum.children || [];
        const relatedItems = datum.related || [];
        const visibleChildren = childItems.slice(0, 14);
        const hiddenChildCount = Math.max(0, Number(datum.child_count || childItems.length) - visibleChildren.length);
        const clusterNode = clusterById.get(datum.cluster);
        const clusterLabel = clusterNode ? clusterNode.data.label : "";
        const childLabel = datum.type === "pending" ? "Draft Children" : "Top Child Motifs";
        const children = visibleChildren.length
          ? visibleChildren.map((child) => {
            const count = Number(child.occurrence_count || 0);
            const suffix = count > 0 ? ` <small>${numberFormat.format(count)}</small>` : "";
            return `<a href="${htmlEscape(child.url)}">${htmlEscape(child.label)}${suffix}</a>`;
          }).join("") + (hiddenChildCount > 0 ? `<span>+${numberFormat.format(hiddenChildCount)} more</span>` : "")
          : "<span>None yet</span>";
        const related = relatedItems.length
          ? relatedItems.map((item) => `<a href="${htmlEscape(item.url)}">${htmlEscape(item.label)}</a>`).join("")
          : "<span>None yet</span>";
        const kicker = datum.type === "pending" ? "Pending Proposed Group" : "Canonical Family";
        const relationLabel = datum.type === "pending" ? "suggested parents" : "related families";
        panel.innerHTML = `
          <span class="row-kicker">${htmlEscape(kicker)}${clusterLabel ? ` / ${htmlEscape(clusterLabel)}` : ""}</span>
          <h3>${htmlEscape(datum.label)}</h3>
          <p>${htmlEscape(datum.description || "")}</p>
          <div class="constellation-panel-metrics">
            <span><b>${numberFormat.format(Number(datum.occurrence_count || 0))}</b><small>occurrences</small></span>
            <span><b>${numberFormat.format(Number(datum.tradition_count || 0))}</b><small>traditions</small></span>
            <span><b>${numberFormat.format(Number(datum.child_count || 0))}</b><small>child motifs</small></span>
            <span><b>${relatedItems.length}</b><small>${relationLabel}</small></span>
          </div>
          ${datum.date_range ? `<p><strong>Date range:</strong> ${htmlEscape(datum.date_range)}</p>` : ""}
          ${datum.url ? `<a class="constellation-panel-action" href="${htmlEscape(datum.url)}">${datum.type === "pending" ? "Open review entry" : "Open research page"}</a>` : ""}
          <div class="constellation-panel-section">
            <strong>${childLabel} <span>${numberFormat.format(Number(datum.child_count || childItems.length))}</span></strong>
            <div class="constellation-panel-list">${children}</div>
          </div>
          <div class="constellation-panel-section">
            <strong>${datum.type === "pending" ? "Suggested Parents" : "Related Families"}</strong>
            <div class="constellation-panel-list">${related}</div>
          </div>
        `;
      };

      const showClusterPanel = (clusterNode) => {
        const datum = clusterNode.data;
        const childList = clusterNode.children || clusterNode._children || [];
        const familyDatums = childList.map((c) => c.data);
        const totalOcc = familyDatums.reduce((s, d) => s + Number(d.occurrence_count || 0), 0);
        const totalChild = familyDatums.reduce((s, d) => s + Number(d.child_count || 0), 0);
        const familyList = familyDatums
          .slice()
          .sort((a, b) => Number(b.occurrence_count || 0) - Number(a.occurrence_count || 0))
          .slice(0, 30)
          .map((d) => `<a href="${htmlEscape(d.url)}">${htmlEscape(d.label)} <small>${numberFormat.format(Number(d.occurrence_count || 0))}</small></a>`)
          .join("");
        const expanded = isClusterExpanded(clusterNode);
        panel.innerHTML = `
          <span class="row-kicker">Cluster</span>
          <h3>${htmlEscape(datum.label)}</h3>
          <p>${htmlEscape(datum.description || "")}</p>
          <div class="constellation-panel-metrics">
            <span><b>${familyDatums.length}</b><small>families</small></span>
            <span><b>${numberFormat.format(totalOcc)}</b><small>occurrences</small></span>
            <span><b>${numberFormat.format(totalChild)}</b><small>child motifs</small></span>
            <span><b>${expanded ? "open" : "closed"}</b><small>state</small></span>
          </div>
          <button type="button" class="constellation-panel-action" data-cluster-toggle>${expanded ? "Collapse cluster" : "Expand to see families"}</button>
          <div class="constellation-panel-section">
            <strong>Families <span>${familyDatums.length}</span></strong>
            <div class="constellation-panel-list">${familyList || "<span>None</span>"}</div>
          </div>
        `;
        const actionBtn = panel.querySelector("[data-cluster-toggle]");
        if (actionBtn) {
          actionBtn.addEventListener("click", () => {
            toggleCluster(clusterNode);
            render();
          });
        }
      };

      const showIntroPanel = () => {
        panel.innerHTML = `
          <span class="row-kicker">Map</span>
          <h3>Choose A Cluster</h3>
          <p>Click any cluster around the rim to expand its families. Use search to jump straight to a family.</p>
        `;
      };

      const updateExpandAllBtn = () => {
        if (!expandAllBtn) return;
        const anyExpanded = allClusters.some(isClusterExpanded);
        expandAllBtn.textContent = anyExpanded ? "Collapse all clusters" : "Expand all clusters";
        expandAllBtn.dataset.state = anyExpanded ? "expanded" : "collapsed";
      };

      const render = () => {
        const stage = map.querySelector(".constellation-stage");
        const stageRect = stage.getBoundingClientRect();
        const panelWidth = window.innerWidth > 900 ? (panel.getBoundingClientRect().width || 360) : 0;
        const width = Math.max(640, Math.floor(stageRect.width - panelWidth));
        const height = Math.max(660, Math.floor(svg.getBoundingClientRect().height || 860));
        svg.setAttribute("viewBox", `${-width / 2} ${-height / 2} ${width} ${height}`);

        const svgD3 = d3.select(svg);
        svgD3.selectAll("*").remove();

        const radius = Math.min(width, height) / 2 - 130;
        d3.cluster()
          .size([2 * Math.PI, radius])
          .separation((a, b) => (a.parent === b.parent ? 1 : 1.5))(root);

        const arcLayer = svgD3.append("g").attr("class", "dendro-arcs");
        const spokeLayer = svgD3.append("g").attr("class", "dendro-spokes");
        const bundleLayer = svgD3.append("g").attr("class", "dendro-bundles");
        const nodeLayer = svgD3.append("g").attr("class", "dendro-nodes");
        const labelLayer = svgD3.append("g").attr("class", "dendro-labels");

        const polar = (n) => [
          Math.cos(n.x - Math.PI / 2) * n.y,
          Math.sin(n.x - Math.PI / 2) * n.y
        ];

        const allVisibleNodes = root.descendants().slice(1);
        const visibleFamilies = allVisibleNodes.filter((n) => n.depth === 2);
        const visibleFamilyIds = new Set(visibleFamilies.map((f) => f.data.id));
        const expandedClusters = allClusters.filter(isClusterExpanded);
        const collapsedClusters = allClusters.filter((c) => !isClusterExpanded(c));
        const totalLeafCount = root.leaves().length;

        // Cluster arcs (only for expanded clusters)
        const arcRadius = radius + 32;
        const arcGen = d3.arc().innerRadius(arcRadius).outerRadius(arcRadius + 1);
        expandedClusters.forEach((cluster) => {
          const childAngles = cluster.children.map((child) => child.x);
          const minAngle = Math.min(...childAngles);
          const maxAngle = Math.max(...childAngles);
          const pad = (2 * Math.PI / Math.max(totalLeafCount, 1)) * 0.6;
          const startAngle = minAngle - pad;
          const endAngle = maxAngle + pad;
          arcLayer.append("path")
            .attr("class", "dendro-cluster-arc")
            .attr("d", arcGen({ startAngle, endAngle }));
          const midAngle = (startAngle + endAngle) / 2;
          const labelR = arcRadius + 26;
          arcLayer.append("text")
            .attr("class", "dendro-cluster-label")
            .attr("x", (Math.cos(midAngle - Math.PI / 2) * labelR).toFixed(1))
            .attr("y", (Math.sin(midAngle - Math.PI / 2) * labelR).toFixed(1))
            .attr("dy", "0.32em")
            .text(cluster.data.label);
        });

        // Tree spokes (only the visible tree contributes links)
        const linkRadial = d3.linkRadial().angle((d) => d.x).radius((d) => d.y);
        const spokeEls = [];
        root.links().forEach((link) => {
          const path = spokeLayer.append("path")
            .attr("class", "dendro-spoke")
            .attr("d", linkRadial(link))
            .attr("data-source", link.source.data.id)
            .attr("data-target", link.target.data.id);
          spokeEls.push(path.node());
        });

        // Cross-link bundles (only between currently visible families)
        const lineRadial = d3.lineRadial()
          .curve(d3.curveBundle.beta(0.85))
          .angle((d) => d.x)
          .radius((d) => d.y);
        const visibleCrossLinks = crossLinks.filter((link) =>
          visibleFamilyIds.has(link.source) && visibleFamilyIds.has(link.target)
        );
        const bundleEls = visibleCrossLinks.map((link) => {
          const path = ancestorPath(link.sourceNode, link.targetNode);
          return bundleLayer.append("path")
            .attr("class", `dendro-bundle ${link.type || ""}`)
            .attr("d", lineRadial(path))
            .attr("data-source", link.source)
            .attr("data-target", link.target)
            .node();
        });

        // Cluster bubbles
        const clusterEls = [];
        expandedClusters.forEach((cluster) => {
          const [cx, cy] = polar(cluster);
          const r = 11;
          const circle = nodeLayer.append("circle")
            .attr("class", "dendro-cluster-node expanded")
            .attr("cx", cx.toFixed(1)).attr("cy", cy.toFixed(1))
            .attr("r", r)
            .attr("data-id", cluster.data.id)
            .attr("data-kind", "cluster")
            .attr("tabindex", "0").attr("role", "button")
            .attr("aria-label", `${cluster.data.label} (expanded)`);
          clusterEls.push(circle.node());
          labelLayer.append("text")
            .attr("class", "dendro-cluster-count")
            .attr("x", cx.toFixed(1)).attr("y", cy.toFixed(1))
            .attr("dy", "0.32em")
            .text((cluster.children || []).length);
        });

        collapsedClusters.forEach((cluster) => {
          const [cx, cy] = polar(cluster);
          const childCount = (cluster._children || []).length;
          const r = Math.min(26, 12 + Math.sqrt(childCount) * 2.4);
          const circle = nodeLayer.append("circle")
            .attr("class", "dendro-cluster-node")
            .attr("cx", cx.toFixed(1)).attr("cy", cy.toFixed(1))
            .attr("r", r)
            .attr("data-id", cluster.data.id)
            .attr("data-kind", "cluster")
            .attr("tabindex", "0").attr("role", "button")
            .attr("aria-label", `${cluster.data.label} (${childCount} families)`);
          clusterEls.push(circle.node());

          const angleDeg = (cluster.x * 180 / Math.PI) - 90;
          const flip = cluster.x >= Math.PI;
          const labelOffset = cluster.y + r + 12;
          labelLayer.append("text")
            .attr("class", "dendro-cluster-node-label")
            .attr("data-id", cluster.data.id)
            .attr("dy", "0.32em")
            .attr("text-anchor", flip ? "end" : "start")
            .attr("transform", `rotate(${angleDeg}) translate(${labelOffset.toFixed(1)},0)${flip ? " rotate(180)" : ""}`)
            .text(cluster.data.label);

          labelLayer.append("text")
            .attr("class", "dendro-cluster-count")
            .attr("x", cx.toFixed(1)).attr("y", cy.toFixed(1))
            .attr("dy", "0.32em")
            .text(childCount);
        });

        // Family leaves (only visible)
        const familyEls = [];
        const familyLabelEls = [];
        visibleFamilies.forEach((leaf) => {
          const datum = leaf.data;
          const [cx, cy] = polar(leaf);
          const r = nodeRadius(datum);
          const circle = nodeLayer.append("circle")
            .attr("class", `dendro-node ${datum.type === "pending" ? "pending" : ""}`)
            .attr("cx", cx.toFixed(1)).attr("cy", cy.toFixed(1))
            .attr("r", r.toFixed(1))
            .attr("data-id", datum.id)
            .attr("data-kind", "family")
            .attr("tabindex", "0").attr("role", "button")
            .attr("aria-label", datum.label);
          familyEls.push(circle.node());

          const angleDeg = (leaf.x * 180 / Math.PI) - 90;
          const flip = leaf.x >= Math.PI;
          const labelOffset = leaf.y + r + 8;
          const labelEl = labelLayer.append("text")
            .attr("class", `dendro-label ${datum.type === "pending" ? "pending" : ""}`)
            .attr("data-id", datum.id)
            .attr("dy", "0.32em")
            .attr("text-anchor", flip ? "end" : "start")
            .attr("transform", `rotate(${angleDeg}) translate(${labelOffset.toFixed(1)},0)${flip ? " rotate(180)" : ""}`)
            .text(datum.label);
          familyLabelEls.push(labelEl.node());
        });

        const setBundlesVisible = (flag) => {
          bundlesVisible = Boolean(flag);
          map.classList.toggle("bundles-hidden", !bundlesVisible);
        };
        setBundlesVisible(bundlesVisible);

        function highlight(id) {
          const activeSet = id ? connected.get(id) : null;
          familyEls.forEach((el) => {
            const isThis = id && el.dataset.id === id;
            const isRelated = activeSet && activeSet.has(el.dataset.id);
            el.classList.toggle("is-active", Boolean(isThis));
            el.classList.toggle("is-dim", Boolean(activeSet && !isRelated));
          });
          familyLabelEls.forEach((el) => {
            const isThis = id && el.dataset.id === id;
            const isRelated = activeSet && activeSet.has(el.dataset.id);
            el.classList.toggle("is-active", Boolean(isThis));
            el.classList.toggle("is-dim", Boolean(activeSet && !isRelated));
          });
          spokeEls.forEach((el) => {
            const active = id && el.dataset.target === id;
            el.classList.toggle("is-active", Boolean(active));
          });
          bundleEls.forEach((el) => {
            const active = id && (el.dataset.source === id || el.dataset.target === id);
            el.classList.toggle("is-active", Boolean(active));
            el.classList.toggle("is-dim", Boolean(id && !active));
          });
        }

        const selectFamily = (leaf) => {
          if (!leaf) return;
          selectedFamilyId = leaf.data.id;
          selectedClusterId = null;
          showFamilyPanel(leaf.data);
          highlight(selectedFamilyId);
        };

        const selectCluster = (cluster) => {
          selectedClusterId = cluster.data.id;
          selectedFamilyId = null;
          showClusterPanel(cluster);
          highlight(null);
        };

        // Family interactions
        familyEls.forEach((circle) => {
          const leaf = familyById.get(circle.dataset.id);
          circle.addEventListener("mouseenter", () => highlight(circle.dataset.id));
          circle.addEventListener("mouseleave", () => highlight(selectedFamilyId));
          circle.addEventListener("focus", () => highlight(circle.dataset.id));
          circle.addEventListener("blur", () => highlight(selectedFamilyId));
          circle.addEventListener("click", () => selectFamily(leaf));
          circle.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") {
              event.preventDefault();
              selectFamily(leaf);
            }
          });
        });

        // Cluster interactions: click toggles expand/collapse + opens panel
        clusterEls.forEach((circle) => {
          const cluster = clusterById.get(circle.dataset.id);
          const handleToggle = () => {
            toggleCluster(cluster);
            selectedClusterId = cluster.data.id;
            selectedFamilyId = null;
            render();
          };
          circle.addEventListener("click", handleToggle);
          circle.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") {
              event.preventDefault();
              handleToggle();
            }
          });
        });

        if (search) {
          search.oninput = () => {
            const query = search.value.trim().toLowerCase();
            if (!query) {
              highlight(selectedFamilyId);
              return;
            }
            const familyMatch = allFamilyLeaves.find((leaf) => {
              const datum = leaf.data;
              const childText = (datum.children || []).map((child) => `${child.id} ${child.label}`).join(" ");
              return `${datum.id} ${datum.label} ${childText}`.toLowerCase().includes(query);
            });
            if (familyMatch) {
              const parent = familyMatch.parent;
              if (parent && !isClusterExpanded(parent)) {
                toggleCluster(parent);
                selectedFamilyId = familyMatch.data.id;
                selectedClusterId = null;
                render();
              } else {
                selectFamily(familyMatch);
              }
              return;
            }
            const clusterMatch = allClusters.find((c) =>
              `${c.data.id} ${c.data.label}`.toLowerCase().includes(query)
            );
            if (clusterMatch) selectCluster(clusterMatch);
          };
        }

        if (bundleToggle) {
          bundleToggle.onchange = () => setBundlesVisible(bundleToggle.checked);
        }

        if (expandAllBtn) {
          expandAllBtn.onclick = () => {
            const anyExpanded = allClusters.some(isClusterExpanded);
            setAllExpanded(!anyExpanded);
            if (!anyExpanded) {
              const fallback = familyById.get("death_and_transformation") ||
                allFamilyLeaves.slice().sort((a, b) =>
                  Number(b.data.occurrence_count || 0) - Number(a.data.occurrence_count || 0)
                )[0];
              if (fallback) {
                selectedFamilyId = fallback.data.id;
                selectedClusterId = null;
              }
            } else {
              selectedFamilyId = null;
              selectedClusterId = null;
            }
            render();
          };
        }

        updateExpandAllBtn();

        if (selectedFamilyId && visibleFamilyIds.has(selectedFamilyId)) {
          const leaf = familyById.get(selectedFamilyId);
          showFamilyPanel(leaf.data);
          highlight(selectedFamilyId);
        } else if (selectedClusterId && clusterById.has(selectedClusterId)) {
          showClusterPanel(clusterById.get(selectedClusterId));
        } else {
          showIntroPanel();
        }
      };

      render();
      let resizeTimer;
      window.addEventListener("resize", () => {
        window.clearTimeout(resizeTimer);
        resizeTimer = window.setTimeout(render, 160);
      });
    });
  })();
JS

warn "resetting site" if ENV["PAGES_DEBUG"]
FileUtils.rm_rf(SITE_DIR)
FileUtils.mkdir_p(SITE_DIR)

warn "loading texts" if ENV["PAGES_DEBUG"]
texts = records_for_markdown("texts/public-domain/**/*.md")
warn "loading patterns" if ENV["PAGES_DEBUG"]
patterns = records_for_markdown("patterns/**/*.md")
warn "loading comparisons" if ENV["PAGES_DEBUG"]
comparisons = records_for_markdown("comparisons/**/*.md")
warn "loading extractions" if ENV["PAGES_DEBUG"]
extractions = extraction_records
warn "loading motif index" if ENV["PAGES_DEBUG"]
motif_index = load_yaml(File.join(ROOT, "data", "indexes", "motif-occurrences.yml"))
normalization = load_yaml(File.join(ROOT, "taxonomy", "motif-normalization.yml"))
proposed_new_groups_path = File.join(ROOT, "taxonomy", "proposed-new-groups-review.yml")
proposed_new_groups = File.exist?(proposed_new_groups_path) ? load_yaml(proposed_new_groups_path) : {}
timeline_path = File.join(ROOT, "data", "indexes", "cultural-timeline.yml")
warn "loading timeline" if ENV["PAGES_DEBUG"]
timeline = File.exist?(timeline_path) ? load_yaml(timeline_path) : {}

def build_step(label)
  warn "building #{label}" if ENV["PAGES_DEBUG"]
  yield
end

build_step("assets") { build_assets }
build_step("home") { build_home(texts, comparisons, motif_index, extractions) }
build_step("findings") { build_findings(texts, motif_index) }
build_step("agent files") { build_agent_files(texts, motif_index) }
build_step("explorer") { build_explorer(motif_index, patterns) }
build_step("texts") { build_texts(texts) }
build_step("patterns") { build_patterns(patterns) }
build_step("comparisons") { build_comparisons(comparisons) }
build_step("motifs") { build_motifs(motif_index, taxonomy_child_motif_ids(normalization, proposed_new_groups)) }
build_step("taxonomy") { build_taxonomy(normalization, proposed_new_groups, motif_index, timeline) }
build_step("timeline") { build_timeline(timeline, texts) }
build_step("extractions") { build_extractions(extractions) }

puts "wrote #{relative(SITE_DIR)}"
