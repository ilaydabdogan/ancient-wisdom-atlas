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

def layout(title:, subtitle: nil, current_output:, body:, page_class: nil)
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
      <script src="#{esc(js)}"></script>
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

def taxonomy_constellation_data(normalization, proposed_review, current_output)
  groups = normalization.fetch("canonical_motif_groups", []).reject { |group| group["id"].to_s.start_with?("_meta") }
  group_lookup = groups.to_h { |group| [group["id"].to_s, group] }
  nodes = []
  links = []
  link_keys = {}

  groups.each do |group|
    children = Array(group["children"]).map do |child_id|
      {
        "id" => child_id.to_s,
        "label" => titleize(child_id),
        "url" => relative_url(current_output, motif_output(child_id))
      }
    end
    related = Array(group["related"]).select { |id| group_lookup.key?(id.to_s) }
    nodes << {
      "id" => group["id"].to_s,
      "label" => group["label"].to_s,
      "type" => "approved",
      "description" => compact_text(group["description"]),
      "child_count" => children.length,
      "children" => children,
      "related" => related.map do |id|
        {
          "id" => id.to_s,
          "label" => group_lookup.fetch(id.to_s)["label"].to_s,
          "url" => taxonomy_family_href(current_output, id)
        }
      end,
      "url" => taxonomy_family_href(current_output, group["id"])
    }

    related.each do |target|
      pair = [group["id"].to_s, target.to_s].sort
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
    nodes << {
      "id" => node_id,
      "label" => candidate["label"].to_s,
      "type" => "pending",
      "description" => candidate["rationale"].to_s,
      "child_count" => children.length,
      "children" => children,
      "related" => parents.map do |id|
        {
          "id" => id.to_s,
          "label" => group_lookup.fetch(id.to_s)["label"].to_s,
          "url" => taxonomy_family_href(current_output, id)
        }
      end,
      "url" => taxonomy_family_href(current_output, candidate["id"])
    }

    parents.each do |parent_id|
      links << { "source" => node_id, "target" => parent_id.to_s, "type" => "pending" }
    end
  end

  {
    "nodes" => nodes,
    "links" => links
  }
end

def taxonomy_constellation_html(normalization, proposed_review, current_output, data_id:)
  data = taxonomy_constellation_data(normalization, proposed_review, current_output)
  <<~HTML
    <div class="constellation-map" data-source="#{esc(data_id)}">
      <div class="constellation-toolbar">
        <input type="search" class="constellation-search" placeholder="Find a family">
        <select class="constellation-label-mode" aria-label="Label density">
          <option value="focus">Focus labels</option>
          <option value="top">Major labels</option>
          <option value="all">All labels</option>
        </select>
        <div class="constellation-legend" aria-label="Constellation legend">
          <span><i></i> canonical family</span>
          <span><i class="small"></i> node size = child motifs</span>
        </div>
      </div>
      <div class="constellation-stage">
        <svg class="constellation-svg" role="img" aria-label="Interactive constellation map of motif taxonomy families"></svg>
        <aside class="constellation-panel" aria-live="polite">
          <span class="row-kicker">Selected Family</span>
          <h3>Choose A Star</h3>
          <p>Search or click a node to inspect its children and related families.</p>
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
      <article class="list-row searchable" data-search="#{esc(search_text)}">
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
      <div class="stat"><strong>#{analyses.first.fetch(:tradition_count)}</strong><span>max traditions in one family</span></div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Richest Family Pages</h2>
        <a href="#{relative_url(index_output, "taxonomy/constellation.html")}">Open constellation</a>
      </div>
      <div class="card-grid">#{prototype_cards}</div>
    </section>

    <section class="toolbar">
      <input type="search" class="search-input" placeholder="Search families, motifs, or traditions" data-search-target=".searchable">
    </section>
    <section class="list-panel">#{family_rows}</section>
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
        count_link = count.positive? ? %(<a href="#{esc(extraction_search_url(current, child.fetch(:motif_id)))}">#{count}</a>) : %(<span class="muted">0</span>)
        <<~HTML
          <tr data-sort-item data-count="#{count}" data-label="#{esc(child.fetch(:label).downcase)}">
            <td>#{link_to_output(current, motif_output(child.fetch(:motif_id)), titleize(child.fetch(:label)))}</td>
            <td>#{esc(child.fetch(:relationship))}</td>
            <td>#{count_link}</td>
            <td>#{child.fetch(:tradition_count)}</td>
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
            <strong>#{count}</strong>
            <i style="width: #{width}%"></i>
          </a>
        HTML
      end.join

    tradition_sections = analysis.fetch(:occurrences)
      .group_by { |occurrence| occurrence["tradition"].to_s }
      .sort_by { |tradition, rows| [-rows.length, tradition_label(tradition)] }
      .map do |tradition, rows|
        passage_rows = rows
          .sort_by { |occurrence| [occurrence["source_title"].to_s, occurrence["passage_locator"].to_s, occurrence["family_motif_label"].to_s] }
          .map do |occurrence|
            source_output = output_for_repo_path(occurrence["source_text_path"])
            extraction_output = output_for_repo_path(occurrence["extraction_path"])
            <<~HTML
              <tr>
                <td>#{link_to_output(current, source_output, occurrence["source_title"].to_s.empty? ? occurrence["source_text_path"] : occurrence["source_title"])}</td>
                <td>#{esc(occurrence["passage_locator"])}</td>
                <td><span class="confidence #{esc(occurrence["confidence"])}">#{esc(occurrence["confidence"])}</span></td>
                <td>#{link_to_output(current, motif_output(occurrence["family_motif_id"]), titleize(occurrence["family_motif_label"]))}</td>
                <td>#{link_to_output(current, extraction_output, "record")}</td>
              </tr>
            HTML
          end.join

        <<~HTML
          <article id="tradition-#{esc(slugify(tradition))}" class="family-tradition-section searchable" data-search="#{esc([tradition, tradition_label(tradition), rows.map { |row| row["family_motif_label"] }].flatten.join(" "))}">
            <div class="family-tradition-head">
              <div>
                <span class="row-kicker">#{esc(tradition_label(tradition))}</span>
                <h3>How This Tradition Tells It</h3>
              </div>
              <strong>#{rows.length} occurrences</strong>
            </div>
            <p>#{esc(family_tradition_summary(tradition, rows))}</p>
            <div class="table-wrap">
              <table>
                <tr><th>Text</th><th>Line Range</th><th>Confidence</th><th>Child Motif</th><th>Extraction</th></tr>
                #{passage_rows}
              </table>
            </div>
          </article>
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

    body = <<~HTML
      <section class="family-hero-panel">
        <p>#{esc(compact_text(group["description"]))}</p>
        <div class="family-stats">
          <div class="stat"><strong>#{analysis.fetch(:occurrence_count)}</strong><span>total occurrences</span></div>
          <div class="stat"><strong>#{analysis.fetch(:child_motifs).length}</strong><span>child motifs</span></div>
          <div class="stat"><strong>#{analysis.fetch(:tradition_count)}</strong><span>traditions present</span></div>
          <div class="stat"><strong>#{esc(analysis.fetch(:date_range_label))}</strong><span>known era range</span></div>
        </div>
        #{prototype_ids.include?(group_id) ? "<span class=\"pending-badge\">research prototype</span>" : ""}
      </section>

      <section class="section">
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

      <section class="section">
        <div class="section-heading">
          <h2>Tradition Frequency</h2>
          <span class="muted">Relative bars compare traditions inside this family.</span>
        </div>
        <div class="family-tradition-bars">#{tradition_rows}</div>
      </section>

      <section class="section">
        <div class="section-heading">
          <h2>How Each Tradition Tells It</h2>
          <span class="muted">Grouped directly from extraction-record motif tags.</span>
        </div>
        <div class="family-tradition-list">#{tradition_sections}</div>
      </section>

      <section class="section family-comparison-grid">
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

      <section class="section">
        <div class="section-heading">
          <h2>Related Families</h2>
        </div>
        <div class="related-family-list">#{related_rows}</div>
      </section>

      <section class="section">
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
  end.sort_by { |analysis| [-analysis[:tradition_count], -analysis[:occurrence_count], analysis[:group]["label"].to_s] }
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
  Dir.glob(File.join(ROOT, "extractions", "**", "*.{yml,yaml}")).sort.map do |path|
    data = load_yaml(path)
    rel = relative(path)
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
        #{card("Constellation Map", "A visual star chart of how canonical families cluster and relate to each other.", href: relative_url(current, "taxonomy/constellation.html"), meta: "visual map")}
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
  group_lookup = groups.to_h { |group| [group["id"].to_s, group] }
  hierarchies = normalization.fetch("hierarchies", {})
  proposed_candidates = proposed_review.fetch("genuine_new_group_candidates", [])
  family_analyses = canonical_family_analyses(normalization, motif_index, timeline)
  build_taxonomy_family_pages(family_analyses)
  constellation = taxonomy_constellation_html(
    normalization,
    proposed_review,
    current,
    data_id: "taxonomy-constellation-data"
  )

  hierarchy_rows = hierarchies.map do |id, data|
    refs = [data["parent_refs"], data["child_refs"]].flatten.compact
    search_text = [id, data["label"], data["description"], refs].flatten.compact.join(" ")
    <<~HTML
      <article class="taxonomy-family searchable" data-search="#{esc(search_text)}">
        <div class="taxonomy-family-head">
          <span class="row-kicker">Hierarchy</span>
          <h3 id="#{esc(taxonomy_anchor(id))}">#{esc(data["label"] || titleize(id))}</h3>
        </div>
        <p>#{esc(compact_text(data["description"]))}</p>
        <div class="taxonomy-field">
          <strong>Parents</strong>
          <div class="chip-row">#{taxonomy_value_chips(data["parent_refs"], group_lookup, current)}</div>
        </div>
        <div class="taxonomy-field">
          <strong>Children</strong>
          <div class="chip-row">#{taxonomy_value_chips(data["child_refs"], group_lookup, current)}</div>
        </div>
      </article>
    HTML
  end.join

  family_rows = groups.reject { |group| group["id"].to_s.start_with?("_meta") }.map do |group|
    search_text = [
      group["id"],
      group["label"],
      group["description"],
      group["children"],
      group["aliases"],
      group["related"]
    ].flatten.compact.join(" ")
    <<~HTML
      <article class="taxonomy-family searchable" data-search="#{esc(search_text)}">
        <div class="taxonomy-family-head">
          <span class="row-kicker">#{esc(group["id"])}</span>
          <h3 id="#{esc(taxonomy_anchor(group["id"]))}"><a href="#{esc(relative_url(current, taxonomy_family_output(group["id"])))}">#{esc(group["label"])}</a></h3>
        </div>
        <p>#{esc(compact_text(group["description"]))}</p>
        <div class="taxonomy-fields">
          <div class="taxonomy-field">
            <strong>Children</strong>
            <div class="chip-row">#{taxonomy_value_chips(group["children"], group_lookup, current)}</div>
          </div>
          <div class="taxonomy-field">
            <strong>Aliases</strong>
            <div class="chip-row">#{taxonomy_value_chips(group["aliases"], group_lookup, current)}</div>
          </div>
          <div class="taxonomy-field">
            <strong>Related Families</strong>
            <div class="chip-row">#{taxonomy_value_chips(group["related"], group_lookup, current)}</div>
          </div>
        </div>
      </article>
    HTML
  end.join

  prototype_cards = family_analyses.first(5).map do |analysis|
    group = analysis.fetch(:group)
    body = "#{analysis.fetch(:occurrence_count)} occurrences across #{analysis.fetch(:tradition_count)} traditions; #{analysis.fetch(:child_motifs).length} mapped child motifs."
    card(group["label"], body, href: relative_url(current, taxonomy_family_output(group["id"])), meta: "research page")
  end.join

  proposed_rows = proposed_candidates.map do |candidate|
    parent_links = taxonomy_value_chips(candidate["suggested_parent_group_ids"], group_lookup, current)
    tradition_chips = Array(candidate["traditions"]).map do |tradition|
      %(<span class="chip">#{esc(tradition_label(tradition))}</span>)
    end.join
    source_ids = Array(candidate["source_candidate_ids"]).join(", ")
    search_text = [
      candidate["id"],
      candidate["label"],
      candidate["rationale"],
      candidate["traditions"],
      candidate["source_candidate_ids"]
    ].flatten.compact.join(" ")
    <<~HTML
      <article class="taxonomy-family proposed searchable" data-search="#{esc(search_text)}">
        <div class="taxonomy-family-head">
          <span class="row-kicker">Pending Review</span>
          <h3 id="#{esc(taxonomy_anchor(candidate["id"]))}">#{esc(candidate["label"])}</h3>
          <span class="pending-badge">#{esc(candidate["recommendation"].to_s.tr("_", " "))}</span>
        </div>
        <p>#{esc(candidate["rationale"])}</p>
        <div class="taxonomy-fields">
          <div class="taxonomy-field">
            <strong>Traditions</strong>
            <div class="chip-row">#{tradition_chips}</div>
          </div>
          <div class="taxonomy-field">
            <strong>Suggested Parents</strong>
            <div class="chip-row">#{parent_links}</div>
          </div>
          <div class="taxonomy-field">
            <strong>Draft Evidence</strong>
            <p class="muted">#{candidate["child_motif_count"]} child motifs, #{candidate["occurrence_count"]} occurrences. Consolidates: #{esc(source_ids)}</p>
          </div>
        </div>
      </article>
    HTML
  end.join

  body = <<~HTML
    <section class="stats-grid">
      <div class="stat"><strong>#{groups.count { |group| !group["id"].to_s.start_with?("_meta") }}</strong><span>approved families</span></div>
      <div class="stat"><strong>#{hierarchies.length}</strong><span>review hierarchies</span></div>
      <div class="stat"><strong>#{proposed_candidates.length}</strong><span>pending new groups</span></div>
      <div class="stat"><strong>#{proposed_review.dig("summary", "source_candidates_folded").to_i}</strong><span>draft groups folded</span></div>
    </section>

    <section class="toolbar">
      <input type="search" class="search-input" placeholder="Search taxonomy families, aliases, children, or proposed groups" data-search-target=".searchable">
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Constellation Map</h2>
        <a href="#{relative_url(current, "taxonomy/constellation.html")}">Open full chart</a>
      </div>
      #{constellation}
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Deep Family Prototypes</h2>
        <a href="#{relative_url(current, "taxonomy/families/index.html")}">View all family pages</a>
      </div>
      <div class="card-grid">#{prototype_cards}</div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Review Hierarchies</h2>
        <span class="muted">Broad parent structures used during normalization</span>
      </div>
      <div class="taxonomy-grid">#{hierarchy_rows}</div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Approved Canonical Families</h2>
        <span class="muted">Rendered from taxonomy/motif-normalization.yml</span>
      </div>
      <div class="taxonomy-grid">#{family_rows}</div>
    </section>

    <section class="section">
      <div class="section-heading">
        <h2>Proposed New Groups</h2>
        <span class="muted">Cross-tradition candidates from the normalization draft, pending review</span>
      </div>
      <div class="taxonomy-grid">#{proposed_rows}</div>
    </section>
  HTML

  write_page(current, layout(
    title: "Taxonomy",
    subtitle: "Approved canonical motif families, review hierarchies, and cross-tradition new group candidates.",
    current_output: current,
    body: body,
    page_class: "taxonomy-page"
  ))

  standalone_output = "taxonomy/constellation.html"
  standalone_body = <<~HTML
    <section class="section">
      <div class="section-heading">
        <h2>Motif Family Star Chart</h2>
        <a href="#{relative_url(standalone_output, "taxonomy/index.html")}">Back to taxonomy</a>
      </div>
      #{taxonomy_constellation_html(normalization, proposed_review, standalone_output, data_id: "taxonomy-constellation-data-full")}
    </section>
  HTML
  write_page(standalone_output, layout(
    title: "Taxonomy Constellation",
    subtitle: "A force-directed star chart of canonical motif families and pending new group candidates.",
    current_output: standalone_output,
    body: standalone_body,
    page_class: "taxonomy-page constellation-page"
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
    overflow: hidden;
    background:
      radial-gradient(circle at 20% 18%, rgba(186, 160, 79, 0.12), transparent 28%),
      radial-gradient(circle at 80% 30%, rgba(22, 124, 128, 0.08), transparent 26%),
      #0b0b09;
    border: 1px solid #242219;
    border-radius: 8px;
    box-shadow: 0 22px 60px rgba(11, 11, 9, 0.34);
  }

  .constellation-toolbar {
    display: grid;
    grid-template-columns: minmax(220px, 1fr) 160px auto;
    gap: 12px;
    align-items: center;
    padding: 12px;
    background: rgba(15, 15, 12, 0.96);
    border-bottom: 1px solid #242219;
  }

  .constellation-search,
  .constellation-label-mode {
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

  .constellation-label-mode option {
    color: #20231f;
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

  .constellation-stage {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 360px;
    min-height: 760px;
  }

  .constellation-svg {
    width: 100%;
    height: 760px;
    min-height: 620px;
    display: block;
    background:
      radial-gradient(circle at 50% 50%, rgba(186, 160, 79, 0.06), transparent 50%),
      linear-gradient(180deg, rgba(255,255,255,0.02), transparent);
    touch-action: manipulation;
  }

  .constellation-link {
    stroke: #2a2820;
    stroke-width: 1;
    opacity: 0.48;
  }

  .constellation-link.pending {
    stroke-dasharray: 5 6;
    opacity: 0.5;
  }

  .constellation-link.is-active {
    stroke: rgba(186, 160, 79, 0.74);
    stroke-width: 1.7;
    opacity: 1;
  }

  .constellation-link.is-dim,
  .constellation-node.is-dim,
  .constellation-label.is-dim,
  .constellation-count.is-dim {
    opacity: 0.16;
  }

  .constellation-node {
    cursor: pointer;
    fill: #baa04f;
    stroke: rgba(255, 241, 179, 0.78);
    stroke-width: 1;
    filter: drop-shadow(0 0 10px rgba(186, 160, 79, 0.72));
    transition: opacity 160ms ease, stroke-width 160ms ease, filter 160ms ease;
  }

  .constellation-node.pending {
    fill: rgba(186, 160, 79, 0.72);
    stroke: rgba(255, 241, 179, 0.52);
    filter: drop-shadow(0 0 6px rgba(186, 160, 79, 0.45));
  }

  .constellation-node.is-active {
    stroke-width: 2.4;
    filter: drop-shadow(0 0 16px rgba(255, 226, 143, 0.96));
  }

  .constellation-label {
    pointer-events: none;
    fill: #e9dbad;
    font-family: "Cormorant Garamond", Georgia, serif;
    font-size: 14px;
    letter-spacing: 0;
    text-anchor: middle;
    text-shadow: 0 1px 8px #0b0b09;
    opacity: 0;
    transition: opacity 140ms ease;
  }

  .constellation-label.is-key,
  .constellation-label.is-active,
  .constellation-map.show-all-labels .constellation-label {
    opacity: 0.92;
  }

  .constellation-map.focus-labels .constellation-label.is-key:not(.is-active) {
    opacity: 0.22;
  }

  .constellation-label.pending {
    fill: rgba(233, 219, 173, 0.74);
    font-size: 12px;
  }

  .constellation-count {
    pointer-events: none;
    fill: #0b0b09;
    font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 9px;
    font-weight: 800;
    text-anchor: middle;
    dominant-baseline: central;
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
    font-size: 34px;
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
    padding: 5px 8px;
    background: rgba(186, 160, 79, 0.12);
    border: 1px solid rgba(186, 160, 79, 0.28);
    border-radius: 999px;
    color: #f4ead0;
    font-size: 12px;
    text-decoration: none;
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
    font-size: 18px;
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

  .family-tradition-head {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    align-items: start;
    margin-bottom: 10px;
  }

  .family-tradition-head strong {
    color: var(--brick);
    white-space: nowrap;
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

    .stats-grid, .explorer-dashboard, .card-grid, .motif-cloud, .family-stats, .family-comparison-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .doc-shell, .motif-detail-grid, .timeline-row, .insight-band, .explorer-controls, .explorer-row, .taxonomy-grid, .constellation-stage, .family-timeline-row, .constellation-toolbar {
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
    .stats-grid, .explorer-dashboard, .card-grid, .motif-cloud, .family-stats, .family-comparison-grid {
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
      const labelMode = map.querySelector(".constellation-label-mode");
      if (!dataScript || !svg || !panel) return;

      const data = JSON.parse(dataScript.textContent);
      const nodes = data.nodes.map((node, index) => ({ ...node, index }));
      const nodeById = new Map(nodes.map((node) => [node.id, node]));
      const keyLabelIds = new Set(nodes
        .filter((node) => node.type === "approved")
        .slice()
        .sort((left, right) => Number(right.child_count || 0) - Number(left.child_count || 0))
        .slice(0, 10)
        .map((node) => node.id));
      const links = data.links
        .map((link) => ({ ...link, sourceNode: nodeById.get(link.source), targetNode: nodeById.get(link.target) }))
        .filter((link) => link.sourceNode && link.targetNode);
      const connected = new Map(nodes.map((node) => [node.id, new Set([node.id])]));
      links.forEach((link) => {
        connected.get(link.source).add(link.target);
        connected.get(link.target).add(link.source);
      });
      let selectedId = null;

      const radiusFor = (node) => {
        const base = node.type === "pending" ? 5 : 8;
        const scale = node.type === "pending" ? 1.5 : 2.45;
        const max = node.type === "pending" ? 12 : 25;
        return Math.min(max, base + Math.sqrt(Math.max(node.child_count, 1)) * scale);
      };

      const hashAngle = (id) => {
        let hash = 0;
        for (let i = 0; i < id.length; i += 1) hash = (hash * 31 + id.charCodeAt(i)) >>> 0;
        return (hash / 4294967295) * Math.PI * 2;
      };

      const clearSvg = () => {
        while (svg.firstChild) svg.removeChild(svg.firstChild);
      };

      const htmlEscape = (value) => String(value || "").replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;"
      })[char]);

      const svgEl = (name, attrs = {}) => {
        const el = document.createElementNS("http://www.w3.org/2000/svg", name);
        Object.entries(attrs).forEach(([key, value]) => el.setAttribute(key, value));
        return el;
      };

      const keepInside = (node, width, height) => {
        const r = radiusFor(node) + 34;
        node.x = Math.max(r, Math.min(width - r, node.x));
        node.y = Math.max(r, Math.min(height - r, node.y));
      };

      const initializePositions = (width, height) => {
        const cx = width / 2;
        const cy = height / 2;
        const inner = Math.min(width, height) * 0.30;
        const outer = Math.min(width, height) * 0.44;
        nodes.forEach((node) => {
          const angle = hashAngle(node.id);
          const distance = node.type === "pending" ? outer : inner + (node.index % 9) * 13;
          node.x = cx + Math.cos(angle) * distance;
          node.y = cy + Math.sin(angle) * distance;
          node.vx = 0;
          node.vy = 0;
          node.r = radiusFor(node);
        });
      };

      const simulate = (width, height) => {
        const cx = width / 2;
        const cy = height / 2;
        const edgeRadius = Math.min(width, height) * 0.43;
        for (let step = 0; step < 430; step += 1) {
          links.forEach((link) => {
            const source = link.sourceNode;
            const target = link.targetNode;
            const dx = target.x - source.x;
            const dy = target.y - source.y;
            const distance = Math.sqrt(dx * dx + dy * dy) || 1;
            const desired = link.type === "pending" ? 210 : 166;
            const strength = link.type === "pending" ? 0.009 : 0.014;
            const force = (distance - desired) * strength;
            const fx = (dx / distance) * force;
            const fy = (dy / distance) * force;
            source.vx += fx;
            source.vy += fy;
            target.vx -= fx;
            target.vy -= fy;
          });

          for (let i = 0; i < nodes.length; i += 1) {
            for (let j = i + 1; j < nodes.length; j += 1) {
              const a = nodes[i];
              const b = nodes[j];
              const dx = b.x - a.x;
              const dy = b.y - a.y;
              const distanceSq = Math.max(dx * dx + dy * dy, 36);
              const distance = Math.sqrt(distanceSq);
              const minDistance = a.r + b.r + 42;
              const push = distance < minDistance ? 0.11 : 430 / distanceSq;
              const fx = (dx / distance) * push;
              const fy = (dy / distance) * push;
              a.vx -= fx;
              a.vy -= fy;
              b.vx += fx;
              b.vy += fy;
            }
          }

          nodes.forEach((node) => {
            if (node.type === "pending") {
              const angle = hashAngle(node.id);
              const tx = cx + Math.cos(angle) * edgeRadius;
              const ty = cy + Math.sin(angle) * edgeRadius;
              node.vx += (tx - node.x) * 0.006;
              node.vy += (ty - node.y) * 0.006;
            } else {
              node.vx += (cx - node.x) * 0.0026;
              node.vy += (cy - node.y) * 0.0026;
            }
            node.vx *= 0.82;
            node.vy *= 0.82;
            node.x += node.vx;
            node.y += node.vy;
            keepInside(node, width, height);
          });
        }
      };

      const showPanel = (node) => {
        const childItems = node.children || [];
        const relatedItems = node.related || [];
        const visibleChildren = childItems.slice(0, 12);
        const hiddenChildCount = Math.max(0, childItems.length - visibleChildren.length);
        const children = visibleChildren.length
          ? visibleChildren.map((child) => `<a href="${htmlEscape(child.url)}">${htmlEscape(child.label)}</a>`).join("") +
            (hiddenChildCount ? `<span>+${hiddenChildCount} more</span>` : "")
          : "<span>None yet</span>";
        const related = relatedItems.length
          ? relatedItems.map((item) => `<a href="${htmlEscape(item.url)}">${htmlEscape(item.label)}</a>`).join("")
          : "<span>None yet</span>";
        const kicker = node.type === "pending" ? "Pending Proposed Group" : "Canonical Family";
        panel.innerHTML = `
          <span class="row-kicker">${htmlEscape(kicker)}</span>
          <h3>${htmlEscape(node.label)}</h3>
          <p>${htmlEscape(node.description || "")}</p>
          <div class="constellation-panel-metrics">
            <span><b>${Number(node.child_count || 0)}</b><small>child motifs</small></span>
            <span><b>${relatedItems.length}</b><small>${node.type === "pending" ? "suggested parents" : "related families"}</small></span>
          </div>
          ${node.url ? `<a class="constellation-panel-action" href="${htmlEscape(node.url)}">Open research page</a>` : ""}
          <div class="constellation-panel-section">
            <strong>Top Children <span>${node.child_count}</span></strong>
            <div class="constellation-panel-list">${children}</div>
          </div>
          <div class="constellation-panel-section">
            <strong>${node.type === "pending" ? "Suggested Parents" : "Related Families"}</strong>
            <div class="constellation-panel-list">${related}</div>
          </div>
        `;
      };

      const setLabelMode = (mode) => {
        map.classList.toggle("focus-labels", mode === "focus");
        map.classList.toggle("show-all-labels", mode === "all");
      };

      const render = () => {
        const bounds = map.querySelector(".constellation-stage").getBoundingClientRect();
        const panelWidth = panel.getBoundingClientRect().width || 360;
        const width = Math.max(620, Math.floor(bounds.width - (window.innerWidth > 900 ? panelWidth : 0)));
        const height = Math.max(620, Math.floor(svg.getBoundingClientRect().height || 760));
        svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
        clearSvg();
        initializePositions(width, height);
        simulate(width, height);

        const linkLayer = svgEl("g", { class: "constellation-links" });
        const nodeLayer = svgEl("g", { class: "constellation-nodes" });
        const labelLayer = svgEl("g", { class: "constellation-labels" });
        svg.append(linkLayer, nodeLayer, labelLayer);

        const linkEls = links.map((link) => {
          const el = svgEl("line", {
            class: `constellation-link ${link.type}`,
            x1: link.sourceNode.x.toFixed(1),
            y1: link.sourceNode.y.toFixed(1),
            x2: link.targetNode.x.toFixed(1),
            y2: link.targetNode.y.toFixed(1),
            "data-source": link.source,
            "data-target": link.target
          });
          linkLayer.appendChild(el);
          return el;
        });

        const nodeEls = nodes.map((node) => {
          const circle = svgEl("circle", {
            class: `constellation-node ${node.type}`,
            cx: node.x.toFixed(1),
            cy: node.y.toFixed(1),
            r: node.r.toFixed(1),
            "data-id": node.id,
            tabindex: "0",
            role: "button",
            "aria-label": node.label
          });
          const count = svgEl("text", {
            class: `constellation-count ${node.type}`,
            x: node.x.toFixed(1),
            y: node.y.toFixed(1),
            "data-id": node.id
          });
          count.textContent = node.child_count.toString();
          nodeLayer.append(circle, count);
          return circle;
        });

        const labelEls = nodes.map((node) => {
          const label = svgEl("text", {
            class: `constellation-label ${node.type}${keyLabelIds.has(node.id) ? " is-key" : ""}`,
            x: node.x.toFixed(1),
            y: (node.y + node.r + 15).toFixed(1),
            "data-id": node.id
          });
          label.textContent = node.label.length > 28 ? `${node.label.slice(0, 25)}...` : node.label;
          labelLayer.appendChild(label);
          return label;
        });

        const countEls = Array.from(svg.querySelectorAll(".constellation-count"));

        function highlight(id) {
          const activeSet = id ? connected.get(id) || new Set([id]) : null;
          nodeEls.forEach((el) => {
            const active = activeSet && activeSet.has(el.dataset.id);
            el.classList.toggle("is-active", Boolean(id && el.dataset.id === id));
            el.classList.toggle("is-dim", Boolean(id && !active));
          });
          [...labelEls, ...countEls].forEach((el) => {
            const active = activeSet && activeSet.has(el.dataset.id);
            el.classList.toggle("is-active", Boolean(id && active));
            el.classList.toggle("is-dim", Boolean(id && !active));
          });
          linkEls.forEach((el) => {
            const active = id && (el.dataset.source === id || el.dataset.target === id);
            el.classList.toggle("is-active", Boolean(active));
            el.classList.toggle("is-dim", Boolean(id && !active));
          });
        }

        const selectNode = (node) => {
          if (!node) return;
          selectedId = node.id;
          showPanel(node);
          highlight(node.id);
        };

        nodeEls.forEach((circle) => {
          const node = nodeById.get(circle.dataset.id);
          circle.addEventListener("mouseenter", () => highlight(circle.dataset.id));
          circle.addEventListener("mouseleave", () => highlight(selectedId));
          circle.addEventListener("focus", () => highlight(circle.dataset.id));
          circle.addEventListener("blur", () => highlight(selectedId));
          circle.addEventListener("click", () => selectNode(node));
          circle.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") {
              event.preventDefault();
              selectNode(node);
            }
          });
        });

        if (search) {
          search.oninput = () => {
            const query = search.value.trim().toLowerCase();
            if (!query) {
              highlight(selectedId);
              return;
            }
            const match = nodes.find((node) =>
              node.label.toLowerCase().includes(query) ||
              node.id.toLowerCase().includes(query)
            );
            if (match) selectNode(match);
          };
        }

        if (labelMode) {
          setLabelMode(labelMode.value || "focus");
          labelMode.onchange = () => setLabelMode(labelMode.value || "focus");
        } else {
          setLabelMode("focus");
        }

        const firstApproved = nodes.find((node) => node.id === "death_and_transformation") || nodes.find((node) => node.type === "approved");
        selectNode((selectedId && nodeById.get(selectedId)) || firstApproved);
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
build_step("explorer") { build_explorer(motif_index, patterns) }
build_step("texts") { build_texts(texts) }
build_step("patterns") { build_patterns(patterns) }
build_step("comparisons") { build_comparisons(comparisons) }
build_step("motifs") { build_motifs(motif_index, taxonomy_child_motif_ids(normalization, proposed_new_groups)) }
build_step("taxonomy") { build_taxonomy(normalization, proposed_new_groups, motif_index, timeline) }
build_step("timeline") { build_timeline(timeline, texts) }
build_step("extractions") { build_extractions(extractions) }

puts "wrote #{relative(SITE_DIR)}"
