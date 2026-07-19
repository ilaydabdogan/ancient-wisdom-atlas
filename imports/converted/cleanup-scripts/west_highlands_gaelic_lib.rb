#!/usr/bin/env ruby
# frozen_string_literal: true

# Shared deterministic Gaelic/English separator for the two Campbell
# "Popular Tales of the West Highlands" volumes. Both volumes interleave a
# clean continuous ENGLISH translation with the full GAELIC original; this
# module DROPs the Gaelic paragraphs + page furniture and KEEPs the English.
# It only SELECTS and DELETES lines; it never writes or invents text.
#
# Used by:
#   clean_popular_tales_west_highlands_v1_campbell.rb
#   clean_popular_tales_west_highlands_v2_campbell.rb

module WestHighlandsGaelic
  module_function

  # Very common Gaelic function words that essentially never stand alone in
  # this book's English prose. (Ambiguous words shared with English -- an, na,
  # is, do, mi, air, gu -- are deliberately excluded to avoid flagging English.)
  GAELIC_LEXICON = %w[
    agus bha cha thu nan ann gun robh chaidh thainig thubhairt thuirt
    arsa ars mise iad sinn sibh sin ris rium riut dhomh dhuit dha dhe
    ghruagach nighean righ bheil gur mar gus ach mu bho fhein fein
    aige aice aca ann's gaol dubh dubh oidhche latha
  ].freeze

  ENGLISH_STOPWORDS = %w[
    the a an and of to in on he she it they we you i is was were be been
    said say that this these those all one two his her him them there here
    with for from by at as not but or which who what when where how
  ].freeze

  # Unambiguous English stopwords used to tell a WHOLE Gaelic block from a
  # mixed English sentence: the words a, an, is, o, i, na, mo, do, ann, in, on
  # are excluded because they are also very common Gaelic words (so counting
  # them would make a pure Gaelic block look partly English). What remains
  # occurs densely in English prose and essentially never in Gaelic.
  ENGLISH_ONLY_STOPWORDS = %w[
    the and of to he she it they we you was were been said say that this
    these those all one two his her him them there here with for from by
    at as not but which who what when where how had have has would could
    their your our then them
  ].freeze

  # Grave / circumflex accented vowels used by Gaelic orthography.
  GAELIC_ACCENT = /[àèìòùâêîôûÀÈÌÒÙ]/.freeze

  def gaelic_word?(raw)
    r = raw.strip
    # Gaelic elision apostrophes -- tested on the RAW token before any quote
    # stripping, since the elision apostrophe is often the first/last char:
    #   leading 's 'n 'g 'm ; short prefix + ' (dh' a' b' d' m' n' t' gu'n).
    # English contractions (don't, it's, I'm) have a longer stem before the
    # apostrophe or an 'i'/vowel prefix, so are not matched.
    return true if r.match?(/\A['’][sngm][^[:alpha:]']*\z/i) # 's 'n 'g 'm alone
    return true if r.match?(/\A(dh|gu|a|b|d|m|t|n)['’]/i)

    w = raw.gsub(/\A["'“”‘’(\[]+/, "")
           .gsub(/["'“”‘’)\],.!?;:]+\z/, "")
    return false if w.empty?

    # The digraphs bh/mh/dh/fh are pervasive in Gaelic and near-absent in the
    # book's English (rare exceptions: "adhere", "shepherd" -- tolerated).
    return true if w.match?(/bh|mh|dh|fh/i)
    # Vol. II OCR frequently misreads the 'h' of these digraphs as 'b', giving
    # tb/cb/db/gb/fb (Tba=Tha, cba=cha, gbabb=ghabh, feumaidb=feumaidh). These
    # bigrams essentially never occur inside an English word.
    return true if w.match?(/[cdfgt]b/i) && !w.downcase.match?(/\A(outb|footb|handb)/)
    return true if w.match?(GAELIC_ACCENT)
    # Characteristic Gaelic verb/noun endings.
    return true if w.downcase.match?(/(idh|adh|aidh|eadh)\z/)
    return true if GAELIC_LEXICON.include?(w.downcase.delete("'’"))

    false
  end

  def word_tokens(line)
    line.split.reject { |t| t.gsub(/["'“”‘’()\[\],.!?;:*—–-]/, "").match?(/\A\d*\z/) }
  end

  def has_english_stopword?(line)
    word_tokens(line).any? { |w| ENGLISH_STOPWORDS.include?(w.downcase.gsub(/[^a-z]/, "")) }
  end

  def gaelic_para?(para)
    # All-caps lines are headings/titles; assessed separately.
    assessable = para.reject { |l| l == l.upcase }
    words = assessable.flat_map { |l| word_tokens(l) }
    return false if words.empty?

    flags = words.count { |w| gaelic_word?(w) }
    stopwords = words.count { |w| ENGLISH_ONLY_STOPWORDS.include?(w.downcase.gsub(/[^a-z]/, "")) }
    stop_frac = stopwords.to_f / words.size

    # Drop a WHOLE paragraph only when it is overwhelmingly Gaelic: dense Gaelic
    # signature AND almost devoid of English stopwords. English prose is
    # ~25-40% stopwords; a genuine Gaelic block is ~0-4% (its few English-shared
    # words -- a, an, o -- were kept out of the flag lexicon). This guard is
    # what protects mixed sentences that merely trail off into a Gaelic clause
    # (e.g. "...found his two companions agus bha iad uile...") -- those are left
    # for line-level filtering so their English survives.
    if flags >= 3 && stop_frac < 0.06 && (flags.to_f / words.size >= 0.18 || words.size >= 12)
      return true
    end

    # A short line/stanza/heading that is entirely non-English (no stopword).
    if words.size <= 8 && flags >= 2
      return assessable.none? { |l| has_english_stopword?(l) }
    end
    false
  end

  # Page furniture: bare page numbers, roman numerals, tiny symbol runs.
  PAGE_JUNK = /\A[\dIVXLlivxoO°()\[\].,;:\s'"*—–-]{1,8}\z/.freeze
  RUNNING_HEADER = /WEST\s+HIGHLAND\s+TALES/i.freeze

  def garble?(line)
    # A single OCR-garble line: has no English stopword and is mostly
    # non-alphabetic (symbols/punctuation soup like "J* tyy**, h.V >Xt (Jt").
    return false if has_english_stopword?(line)
    letters = line.count("A-Za-z")
    nonspace = line.gsub(/\s/, "").length
    return false if nonspace.zero?
    alpha_ratio = letters.to_f / nonspace
    toks = line.split
    avg_len = toks.empty? ? 0 : toks.sum(&:length).to_f / toks.size
    # low alphabetic fraction, or a scatter of tiny non-word fragments
    (alpha_ratio < 0.55) || (toks.size >= 3 && avg_len <= 2.4 && alpha_ratio < 0.8 && !gaelic_para?([line]))
  end

  def gaelic_heading?(line)
    # An all-caps single-line heading that is a Gaelic tale title: carries a
    # Gaelic-signature word and no English stopword (English titles such as
    # "THE YOUNG KING OF EASAIDH RUADH" keep their THE/OF and survive).
    return false unless line == line.upcase
    toks = word_tokens(line)
    return false if toks.empty?
    return false if has_english_stopword?(line)
    toks.any? { |w| gaelic_word?(w) }
  end

  def clean(body)
    stats = Hash.new(0)

    # --- split into blank-line-delimited paragraphs ---
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

    # --- classify + delete ---
    kept_paras = []
    paras.each do |para|
      stripped = para.map(&:strip)

      if para.length == 1
        s = stripped[0]
        if s.match?(PAGE_JUNK)
          stats[:page_junk] += 1
          next
        end
        if s.match?(RUNNING_HEADER)
          stats[:running_headers] += 1
          next
        end
        if gaelic_heading?(s)
          stats[:gaelic_headings] += 1
          next
        end
        if garble?(s)
          stats[:garble] += 1
          next
        end
      end

      if gaelic_para?(stripped)
        stats[:gaelic_paras] += 1
        next
      end

      # Mixed paragraph: drop interior Gaelic lines and running headers/garble.
      filtered = para.reject do |l|
        s = l.strip
        next false if s == s.upcase && !gaelic_heading?(s) # keep English caps headings
        drop = s.match?(RUNNING_HEADER) || gaelic_heading?(s)
        unless drop
          toks = word_tokens(s)
          flags = toks.count { |w| gaelic_word?(w) }
          frac = toks.empty? ? 0 : flags.to_f / toks.size
          # Strong inline Gaelic line, or a short embedded Gaelic verse line
          # (e.g. a quoted song stanza) with no English stopword to anchor it.
          drop = (flags >= 3 && frac >= 0.5) ||
                 (flags >= 2 && frac >= 0.4 && !has_english_stopword?(s))
        end
        stats[:inline_gaelic_lines] += 1 if drop
        drop
      end
      kept_paras << filtered unless filtered.empty?
    end

    kept = kept_paras.flat_map { |para| para + [""] }

    # --- re-join paragraph splits left by removed furniture ---
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

    # --- squeeze double spaces, collapse blank runs ---
    final = []
    blank_run = 0
    merged.each do |line|
      # Neutralize stray OCR angle brackets so no HTML-like tags survive; in
      # these volumes '<' and '>' occur only inside OCR garble, never English.
      out = line.tr("<>", "()")
      out = out.rstrip.gsub(/(?<=\S) {2,}(?=\S)/, " ").sub(/\A\s+/, "")
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
    [["HEAD", 0], ["Q1", n / 4], ["MID", n / 2], ["Q3", 3 * n / 4], ["TAIL", n - 18]].each do |label, start|
      puts "\n----- #{label} (line #{start}) -----"
      puts final[[start, 0].max, 18].join("\n")
    end
  end
end
