#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "date"
require "fileutils"
require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
SITE_DIR = File.join(ROOT, "site")

NAV = [
  ["Home", "index.html"],
  ["Texts", "texts/index.html"],
  ["Motifs", "motifs/index.html"],
  ["Comparisons", "comparisons/index.html"],
  ["Patterns", "patterns/index.html"],
  ["Extractions", "extractions/index.html"]
].freeze

TRADITION_LABELS = {
  "jewish_christian" => "Biblical",
  "buddhist" => "Buddhist",
  "daoist" => "Daoist",
  "egyptian" => "Egyptian",
  "greek" => "Greek",
  "hindu" => "Hindu",
  "mesopotamian" => "Mesopotamian",
  "norse" => "Norse"
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
  top_motifs = motif_index.fetch("motifs", []).first(8)

  body = <<~HTML
    <section class="stats-grid">
      <div class="stat"><strong>#{texts.length}</strong><span>complete texts</span></div>
      <div class="stat"><strong>#{traditions}</strong><span>traditions</span></div>
      <div class="stat"><strong>#{motif_count}</strong><span>motif groups</span></div>
      <div class="stat"><strong>#{occurrence_count}</strong><span>motif occurrences</span></div>
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
          %(<a href="#{relative_url(current, "motifs/index.html")}#motif-#{esc(motif["motif_id"])}"><strong>#{esc(motif["label"])}</strong><span>#{motif["occurrences"].length} appearances</span></a>)
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

def build_motifs(motif_index)
  current = "motifs/index.html"
  rows = motif_index.fetch("motifs", []).map do |motif|
    traditions = motif.fetch("traditions", {}).sort.map { |name, count| "#{tradition_label(name)} (#{count})" }.join(", ")
    <<~HTML
      <section id="motif-#{esc(motif["motif_id"])}" class="motif-section searchable" data-search="#{esc([motif["motif_id"], motif["label"], traditions].join(" "))}">
        <div class="motif-section-heading">
          <div>
            <span class="row-kicker">#{esc(motif["motif_id"])}</span>
            <h2>#{esc(motif["label"].to_s.split.map(&:capitalize).join(" "))}</h2>
          </div>
          <strong>#{motif["occurrences"].length} appearances</strong>
        </div>
        <p class="muted">#{esc(traditions)}</p>
        <div class="table-wrap">
          <table>
            <tr><th>Tradition</th><th>Source</th><th>Passage</th><th>Motif label</th><th>Record</th></tr>
            #{motif["occurrences"].map do |occ|
              source_output = output_for_repo_path(occ["source_text_path"])
              extraction_output = output_for_repo_path(occ["extraction_path"])
              "<tr><td>#{esc(tradition_label(occ["tradition"]))}</td><td><a href=\"#{esc(relative_url(current, source_output))}\">#{esc(occ["source_title"])}</a></td><td>#{esc(occ["passage_locator"])}</td><td>#{esc(occ["motif_label"])}</td><td><a href=\"#{esc(relative_url(current, extraction_output))}\">record</a></td></tr>"
            end.join}
          </table>
        </div>
      </section>
    HTML
  end.join

  body = <<~HTML
    <section class="toolbar">
      <input type="search" class="search-input" placeholder="Search motifs, traditions, or sources" data-search-target=".searchable">
    </section>
    #{rows}
  HTML

  write_page(current, layout(
    title: "Motif Index",
    subtitle: "#{motif_index["motif_count"]} motif groups and #{motif_index["occurrence_count"]} evidence-linked appearances.",
    current_output: current,
    body: body
  ))
end

def build_extractions(extractions)
  current = "extractions/index.html"
  rows = extractions.map do |item|
    data = item[:data]
    motifs = data.fetch("candidate_motifs", []).map { |motif| motif["label"] }.join(", ")
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
      <input type="search" class="search-input" placeholder="Search extraction records" data-search-target=".searchable">
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

STYLE_CSS = <<~CSS
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

  .search-input {
    width: 100%;
    min-height: 48px;
    padding: 12px 14px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 8px;
    color: var(--ink);
    font: inherit;
  }

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

    .stats-grid, .card-grid, .motif-cloud {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .doc-shell {
      grid-template-columns: 1fr;
    }

    .metadata-panel { position: static; }
  }

  @media (max-width: 560px) {
    main { width: min(100% - 24px, 1180px); padding-top: 20px; }
    h1 { font-size: 40px; }
    .stats-grid, .card-grid, .motif-cloud {
      grid-template-columns: 1fr;
    }
    .document { padding: 18px; }
  }
CSS

APP_JS = <<~JS
  (() => {
    document.querySelectorAll(".search-input").forEach((input) => {
      const selector = input.dataset.searchTarget;
      const items = Array.from(document.querySelectorAll(selector));
      input.addEventListener("input", () => {
        const query = input.value.trim().toLowerCase();
        items.forEach((item) => {
          const haystack = (item.dataset.search || item.textContent).toLowerCase();
          item.classList.toggle("is-hidden", query.length > 0 && !haystack.includes(query));
        });
      });
    });
  })();
JS

FileUtils.rm_rf(SITE_DIR)
FileUtils.mkdir_p(SITE_DIR)

texts = records_for_markdown("texts/public-domain/**/*.md")
patterns = records_for_markdown("patterns/**/*.md")
comparisons = records_for_markdown("comparisons/**/*.md")
extractions = extraction_records
motif_index = load_yaml(File.join(ROOT, "data", "indexes", "motif-occurrences.yml"))

build_assets
build_home(texts, comparisons, motif_index, extractions)
build_texts(texts)
build_patterns(patterns)
build_comparisons(comparisons)
build_motifs(motif_index)
build_extractions(extractions)

puts "wrote #{relative(SITE_DIR)}"
