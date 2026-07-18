#!/usr/bin/env ruby
# frozen_string_literal: true

# Mechanical quote verification across the extraction corpus: every quote
# in every record is checked verbatim (whitespace-normalized) against its
# source text file. Results are written to a verification index — records
# are NOT modified. The site reads the index to badge evidence as
# machine-verified. Deterministic; no model involved.

require_relative "batch_common"

options = {
  extraction_glob: "extractions/**/*.{yml,yaml}",
  output: "data/indexes/quote-verification.yml"
}

OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/verify_extraction_quotes.rb [options]"
  parser.on("--extraction-glob GLOB", "Extraction records glob") { |value| options[:extraction_glob] = value }
  parser.on("--output PATH", "Output index path") { |value| options[:output] = value }
end.parse!

ROOT = AtlasBatch::ROOT

def normalize_ws(text)
  text.to_s
      .tr("‘’‚", "'")
      .tr("“”„", '"')
      .tr("–—", "-")
      .gsub("…", "...")
      .gsub(/\s+/, " ")
      .strip
end

# A quote matches if every ellipsis-separated fragment (>= 12 chars)
# appears in the source; extractors legitimately elide with "...".
def quote_matches?(quote, haystack)
  fragments = normalize_ws(quote).split(/\.{3,}|\[\.\.\.\]/).map(&:strip).select { |fragment| fragment.length >= 12 }
  return haystack.include?(normalize_ws(quote)) if fragments.length <= 1

  fragments.all? { |fragment| haystack.include?(fragment) }
end

def collect_quotes(node, out = [])
  case node
  when Hash
    node.each { |key, value| key == "quote" && value.is_a?(String) && !value.strip.empty? ? out << value : collect_quotes(value, out) }
  when Array
    node.each { |item| collect_quotes(item, out) }
  end
  out
end

source_cache = {}
records = {}
totals = { "records" => 0, "records_with_quotes" => 0, "verified" => 0, "failed" => 0, "source_missing" => 0 }

Dir.glob(File.join(ROOT, options[:extraction_glob])).sort.each do |path|
  record = AtlasBatch.load_yaml(path)
  next if record.empty? || !record.is_a?(Hash)

  source = record["source_text_path"].to_s
  next if source.empty?

  totals["records"] += 1
  quotes = collect_quotes(record)
  next if quotes.empty?

  totals["records_with_quotes"] += 1
  source_full = File.join(ROOT, source)
  unless File.file?(source_full)
    totals["source_missing"] += 1
    next
  end
  source_cache[source] ||= normalize_ws(File.read(source_full))
  haystack = source_cache[source]
  failed = quotes.reject { |quote| quote_matches?(quote, haystack) }

  status = failed.empty? ? "verified" : "failed"
  totals[status == "verified" ? "verified" : "failed"] += 1
  records[record["record_id"].to_s] = {
    "status" => status,
    "quotes_total" => quotes.length,
    "quotes_failed" => failed.length,
    "failed_samples" => failed.first(2).map { |quote| quote[0, 120] }
  }
end

output = {
  "quote_verification_version" => "1",
  "generated_at" => AtlasBatch.utc_now,
  "summary" => totals.merge(
    "verified_rate" => totals["records_with_quotes"].positive? ? (totals["verified"].to_f / totals["records_with_quotes"]).round(4) : nil
  ),
  "records" => records
}

AtlasBatch.write_yaml(File.join(ROOT, options[:output]), output)
puts "records with quotes: #{totals["records_with_quotes"]}; verified: #{totals["verified"]}; failed: #{totals["failed"]}; rate: #{output["summary"]["verified_rate"]}"
puts "wrote #{options[:output]}"
