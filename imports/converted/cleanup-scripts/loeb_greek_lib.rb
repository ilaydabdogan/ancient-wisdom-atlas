#!/usr/bin/env ruby
# frozen_string_literal: true

# Shared deterministic Greek/English separator for two Loeb Classical Library
# volumes translated by Frazer/Jones (Apollodorus "The Library" vol. I and
# Pausanias "Description of Greece" vol. I). Both print the Greek text and the
# English translation on facing pages, which the OCR serialised as alternating
# blocks: [English translation] [English footnotes] [page header/number]
# [Greek block] [Greek apparatus criticus] ... This module DROPs the Greek
# blocks + apparatus + page furniture and KEEPs the English translation and the
# English (and Latin-citation) footnotes. It only SELECTS and DELETES lines; it
# never writes or invents text.
#
# The two volumes degrade differently, and one rule covers both:
#   * Pausanias: the Greek survived OCR as real polytonic Unicode (non-ASCII).
#   * Apollodorus: the Greek was mangled into Latin-lookalike glyph soup
#     (interior capitals "avT@ TocovTov", accented vowels "HéET@TOV", stray @).
# In BOTH, a Greek paragraph carries NO English stopwords, whereas every English
# translation/footnote paragraph is dense with them. So the classifier drops a
# paragraph only when it has zero English stopwords AND at least two Greek-
# signature tokens (non-ASCII char, interior capital, or '@'). A footnote that
# is a bare Latin citation (no stopword, no Greek signature) is therefore kept.
#
# Used by:
#   clean_apollodorus_library_frazer_vol1.rb
#   clean_pausanias_description_greece_frazer_vol1.rb

module LoebGreek
  module_function

  ENGLISH_STOPWORDS = %w[
    the a an and of to in on he she it they we you i is are was were be been
    said say that this these those all one two his her him them there here
    with for from by at as not but or which who what when where how had have
    has would could their your our then see compare according into out
    upon their its also who whom
  ].freeze

  def greek_sig?(w)
    w.match?(/[^\x00-\x7F]/) ||        # non-ASCII (real Greek Unicode / accents)
      w.match?(/[[:lower:]][[:upper:]]/) || # interior capital (OCR glyph soup)
      w.include?("@")
  end

  def word_tokens(line)
    line.split.reject { |t| t.gsub(/["'“”‘’()\[\],.!?;:*—–·]/, "").match?(/\A\d*\z/) }
  end

  def stopword_count(toks)
    # Only stopwords of length >= 3 count as an English signal. One- and
    # two-letter tokens (a, an, of, to, is, A, R, H ...) collide with the
    # manuscript sigla and elided particles that fill the Greek apparatus
    # criticus; genuine English prose always carries longer stopwords too
    # (the, and, that, was, with), so this loses no English while stopping the
    # apparatus lines ("... uecov A: pecov Heyne ...") from reading as English.
    toks.count do |t|
      c = t.downcase.gsub(/[^a-z]/, "")
      c.length >= 3 && ENGLISH_STOPWORDS.include?(c)
    end
  end

  def has_english_stopword?(line)
    stopword_count(word_tokens(line)) > 0
  end

  # A paragraph is Greek when it carries no English stopword yet has real Greek
  # signature. This keeps English translation + English/Latin footnotes.
  def greek_para?(para)
    toks = para.flat_map { |l| word_tokens(l) }
    return false if toks.empty?
    return false if stopword_count(toks) > 0

    sig = toks.count { |t| greek_sig?(t) }
    return true if sig >= 2
    # short, entirely-Greek fragment (e.g. a one-line clausula)
    return true if toks.size <= 4 && sig >= 1 && sig == toks.count { |t| !t.match?(/\A[A-Za-z.,;:]+\z/) || greek_sig?(t) }
    false
  end

  # Running headers repeated on every page (all-caps furniture).
  HEADER = /\A(PAUSANIAS|APOLLODORUS|INTRODUCTION|PREFACE|CONTENTS)\b/.freeze
  LIBRARY_HEADER = /\ATHE\s+LIBRARY\b/.freeze
  DESC_HEADER = /DESCRIPTION\s+OF\s+GREECE/.freeze
  # bare page numbers, roman numerals, printer signatures ("B 2"), symbol runs.
  PAGE_JUNK = /\A[\dIVXLlivxoO.,;:()\[\]\s'"*—–·§|~`^]{1,10}\z/.freeze
  SIGNATURE = /\A[A-Z]\s?\d{1,3}\z/.freeze
  DATE_MARGIN = /\A\d{2,4}\s*B\.?\s?[cC]\b/.freeze

  # Per-page running heads that lead with an ALL-CAPS region/section word and
  # a chapter reference: "ATTICA, xvi. 6-9", "CORINTH, iv. 4-v. 1", "BOOK I".
  # A translation sentence never opens with a 4+ letter all-caps word, so a
  # short stopword-free line that does is furniture.
  RUNNING_HEAD = /\A[A-Z]{4,}[,:.]?(\s|\z)/.freeze

  def header_line?(s)
    return true if s == s.upcase && (s.match?(HEADER) || s.match?(LIBRARY_HEADER) || s.match?(DESC_HEADER))
    toks = word_tokens(s)
    return true if !toks.empty? && toks.size <= 8 && stopword_count(toks).zero? && s.match?(RUNNING_HEAD)
    false
  end

  # OCR scan-bleed garble: no English stopword and mostly non-alphabetic or
  # non-ASCII soup (used for stray plate-bleed lines inside the body).
  def garble?(line)
    return false if has_english_stopword?(line)
    nonspace = line.gsub(/\s/, "")
    return false if nonspace.empty?
    letters = line.count("A-Za-z")
    ascii_alpha_ratio = letters.to_f / nonspace.length
    toks = line.split
    avg = toks.empty? ? 0 : toks.sum(&:length).to_f / toks.size
    (ascii_alpha_ratio < 0.5) || (toks.size >= 4 && avg <= 2.2)
  end

  def clean(body)
    stats = Hash.new(0)

    paras = []
    current = []
    body.each do |line|
      if line.strip.empty?
        paras << current unless current.empty?
        current = []
      else
        current << line
      end
    end
    paras << current unless current.empty?

    kept_paras = []
    paras.each do |para|
      stripped = para.map(&:strip)

      if para.length == 1
        s = stripped[0]
        if header_line?(s)
          stats[:headers] += 1
          next
        end
        if s.match?(PAGE_JUNK) || s.match?(SIGNATURE) || s.match?(DATE_MARGIN)
          stats[:page_junk] += 1
          next
        end
      end

      if greek_para?(stripped)
        stats[:greek_paras] += 1
        next
      end

      # Mixed paragraph: drop interior Greek lines, page headers, and garble;
      # keep the English lines.
      filtered = para.reject do |l|
        s = l.strip
        drop = header_line?(s) || s.match?(PAGE_JUNK) || s.match?(DATE_MARGIN)
        drop ||= greek_para?([s])
        drop ||= garble?(s)
        stats[:inline_dropped] += 1 if drop
        drop
      end
      kept_paras << filtered unless filtered.empty?
    end

    kept = kept_paras.flat_map { |para| para + [""] }

    # Re-join paragraph splits left by removed furniture (English line ending
    # mid-clause followed by a lowercase-starting line).
    merged = []
    kept.each do |line|
      if line.strip.empty?
        merged << line
      else
        k = merged.length - 1
        k -= 1 while k >= 0 && merged[k].strip.empty?
        if k >= 0 && k < merged.length - 1 &&
           merged[k].match?(/[a-z,;]\z/) && line.lstrip.match?(/\A[a-z]/)
          merged.slice!(k + 1..)
          stats[:paragraphs_rejoined] += 1
        end
        merged << line
      end
    end

    # Neutralize stray angle brackets, squeeze double spaces, collapse blanks.
    final = []
    blank_run = 0
    merged.each do |line|
      out = line.tr("<>", "()").rstrip.gsub(/(?<=\S) {2,}(?=\S)/, " ").sub(/\A\s+/, "")
      if out.empty?
        blank_run += 1
        final << "" if blank_run <= 2
      else
        blank_run = 0
        final << out
      end
    end
    final.pop while final.last == ""

    [final, stats]
  end

  def sample(final)
    n = final.length
    [["HEAD", 0], ["Q1", n / 4], ["MID", n / 2], ["Q3", 3 * n / 4], ["TAIL", n - 16]].each do |label, start|
      puts "\n----- #{label} (line #{start}) -----"
      puts final[[start, 0].max, 16].join("\n")
    end
  end
end
