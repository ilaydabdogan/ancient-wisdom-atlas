#!/usr/bin/env ruby
# frozen_string_literal: true

# Bespoke deterministic cleanup, OCR review pass 2 (`needs_cleanup` verdicts):
# the mechanical-noise family — running headers, standalone page numbers,
# soft-hyphen (¬) and line-end hyphen word breaks, doubled word spacing,
# library bookplate heads and card-pocket/date-due tails — plus the guarded
# interlinear-text zones of the two Boas Baffin-Land bulletins.
#
# Mechanical line selection / deletion / joining ONLY. No text is ever
# rewritten or paraphrased. Character-level OCR garble inside words (e.g.
# Spencer & Gillen's y -> "}'" substitution) is deliberately NOT touched here;
# log such systematic substitutions in transcription.corrections at promotion.
#
# Per-file operations (in application order):
#   head_cut_to:     delete lines between the "# ..." title line and the first
#                    line matching this regex (marker kept; searched in the
#                    first 1500 lines).
#   cut_between:     [start_re, end_re] delete from the line matching start_re
#                    through the line BEFORE the first subsequent end_re match
#                    (used for the Baffin part-1 OCR-shredded angakok-word
#                    vocabulary, section VII).
#   tail_cut_from:   delete from the first line matching this regex past
#                    `tail_frac` of the file (default 0.5) through EOF.
#   tail_cut_after:  same, but the marker line is kept. `tail_last: true`
#                    picks the last match instead of the first.
#   drop:            delete lines matching any of these file-verified regexes
#                    (running headers, photo credits, plate captions).
#   bracket_runner:  delete "Word] TITLE 123"-style BAE running headers
#                    ("RUSSELL] SPEECHES 341", incl. OCR-garbled surnames).
#   repeat_headers:  delete lines whose digit/punctuation-stripped normalized
#                    form repeats >= N times AND that carry a digit or are
#                    >=70% uppercase (page-top runners). Lines matching
#                    `protect`, or directly preceded by a CHAPTER/PART/BOOK
#                    line (i.e. real chapter titles), survive.
#   page_junk:       delete standalone page-number lines, including common
#                    OCR forms ("2O5", "38o", "i4g").
#   eskimo_zone:     [start_re, end_re] paragraph state machine for the
#                    "TEXTS FROM CUMBERLAND SOUND" sections: keeps tale
#                    headings, "(Recorded by ...)" credits, "Translation."
#                    markers and the continuous-English free-translation
#                    blocks; drops the interlinear Eskimo lines and their
#                    word-by-word gloss lines (which scramble English word
#                    order), including embedded interlinear song fragments.
#   not_dehyphen:    chain-join "word¬" soft-hyphen line breaks.
#   dehyphen:        join "word-" EOL with the next non-blank line when it
#                    starts lowercase, consuming intervening blank lines.
#   rejoin:          re-join paragraph splits created by removed page
#                    furniture (line ends mid-clause, next starts lowercase).
#   squeeze:         collapse runs of 2+ internal spaces (double-word-spaced
#                    scans only).
# Blank runs are always collapsed to at most 2; trailing blanks trimmed.

DIR = File.expand_path("../project-gutenberg", __dir__)

SPECS = {
  # --- Boas, Eskimo of Baffin Land and Hudson Bay, part 1 (Bulletin AMNH XV) -
  "bulletin-american-museum-natural-history-15-001-370-eskimo-baffin-hudson-boas-part1.md" => {
    head_cut_to: /\AI\.—THE ESKIMO OF BAFFIN LAND AND HUDSON\z/,
    cut_between: [/\AVII\. LIST OF ANGAKOK WORDS/,
                  /\AThe preceding description of the Eskimo of Cumberland\z/],
    tail_cut_from: /\AERRATA\.\z/, tail_frac: 0.9,
    drop: [
      /Bulletin\s+American\s+Museum\s+o.\s+Natural\s+History\s*[.,]?\s*.{0,12}\z/,
      /Boas\s*,\s+Eskimo\s+of\s+Baffin\s+Land\s+and\s+H\S{0,6}dson\s+Bay/
    ],
    eskimo_zone: [/\AVI\.\s+TEXTS\s+FROM\s+CUMBERLAND\s+SOUND\.\z/,
                  /\AThe preceding description of the Eskimo of Cumberland\z/],
    page_junk: true, not_dehyphen: true, dehyphen: true, rejoin: true
  },
  # --- part 2 (double-word-spaced) --------------------------------------------
  "bulletin-american-museum-natural-history-15-371-570-eskimo-baffin-hudson-boas-part2.md" => {
    head_cut_to: /\AII\.—\s*SECOND\s+REPORT\s+ON\s+THE\s+ESKIMO\s+OF\s+BAFFIN\z/,
    tail_cut_from: /\ALIST\s+OF\s+THE\s+ANTHROPOLOGICAL\s+PUBLICATIONS\z/, tail_frac: 0.9,
    drop: [
      /Bulletin\s+American\s+Museum\s+o.\s+Natural\s+History\s*[.,]?\s*.{0,12}\z/,
      /Boas\s*,\s+Eskimo\s+of\s+Baffin\s+Land\s+and\s+H\S{0,6}dson\s+Bay/
    ],
    eskimo_zone: [/\AVI\.\s+TEXTS\s+FROM\s+CUMBERLAND\s+SOUND\.\z/, /\ACONCLUSION\.\z/],
    page_junk: true, not_dehyphen: true, dehyphen: true, rejoin: true, squeeze: true
  },
  # --- Dorsey, Traditions of the Skidi Pawnee ---------------------------------
  "traditionsofskid0000dors-traditions-skidi-pawnee-dorsey.md" => {
    head_cut_to: /\AINTRODUCTION\.\z/,
    tail_cut_from: /\AINDEX\.\z/, tail_frac: 0.9,
    drop: [/\A[\dioIl]{0,4}\s*Traditions\s+of\s+the\s+Skidi\s+Pawnee\.?\s*[\dioIl]{0,4}\z/],
    repeat_headers: 12,
    page_junk: true, not_dehyphen: true, dehyphen: true, rejoin: true, squeeze: true,
    tail_pop_junk: true
  },
  # --- Russell, The Pima Indians (BAE 26th Annual Report extract) -------------
  # NOTE: the Linguistics section (Songs, Speeches) is interlinear Pima/English
  # and remains noisy; myth narratives (Sophiology) and ethnography are clean.
  "pimaindians01russgoog-pima-indians-russell.md" => {
    head_cut_to: /\ABy Frank Russell\z/,
    tail_cut_from: /\ABUREAU OF AMERICAN ETHNOLOGY\z/, tail_frac: 0.95,
    drop: [/\A[\dOoIl]{0,4}\s*THE PIMA INDIANS\s*.{0,18}\z/],
    bracket_runner: true,
    protect: [/\ATRANSLATION\z/, /\AREPEAT\z/],
    repeat_headers: 18,
    page_junk: true, dehyphen: true, rejoin: true, tail_pop_junk: true
  },
  # --- Junod, Life of a South African Tribe, vols 1-2 -------------------------
  "lifeofsouthafric01junouoft-life-south-african-tribe-junod-vol1.md" => {
    head_cut_to: /\AINTRODUCTION\z/,
    tail_cut_after: /\Aof\s+all\s+the\s+subjects\s+treated\s+in\s+both\s+volumes\.\z/,
    drop: [/\APhot[.,]?\s+[A-Z]/, /\A(THE\s+)?THONGA\s+TRIBE\b.{0,12}\z/],
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true
  },
  "lifeofsouthafric02junouoft-life-south-african-tribe-junod-vol2.md" => {
    head_cut_to: /\AFOURTH\s+PART\z/,
    tail_cut_from: /\ATABLE\s+OF\s+CONTENTS\z/, tail_frac: 0.85,
    drop: [/\APhot[.,]?\s+[A-Z]/, /\A(THE\s+)?THONGA\s+TRIBE\b.{0,12}\z/],
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true
  },
  # --- Smith & Dale, Ila-Speaking Peoples, vols 1-2 ---------------------------
  "ilaspeakingpeopl01smituoft-ila-speaking-peoples-vol1-smith-dale.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_after: /\AEND\s+OF\s+VOL\.\s*1\z/,
    drop: [
      /\A[xvil\dOo]{0,6}\s*THE\s+ILA-SPEAKING\s+PEOPLES\b.{0,14}\z/i,
      /\ACH\.?\s*[XVIxvinml]{1,8}\s+[A-Z].{0,45}\z/
    ],
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true
  },
  "ilaspeakingpeopl02smituoft-ila-speaking-peoples-vol2-smith-dale.md" => {
    head_cut_to: /\APART\s+III\s*—/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.85,
    drop: [
      /\A[xvil\dOo]{0,6}\s*THE\s+ILA-SPEAKING\s+PEOPLES\b.{0,14}\z/i,
      /\ACH\.?\s*[XVIxvinml]{1,8}\s+[A-Z].{0,45}\z/
    ],
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true, tail_pop_junk: true
  },
  # --- Spencer & Gillen, Native / Northern Tribes of Central Australia --------
  # NOTE (vol 1): systematic y -> "}'" / "}-" glyph substitution left in place;
  # record in transcription.corrections at promotion.
  "nativetribesofce00spenuoft-native-tribes-central-australia-spencer-gillen.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    drop: [/\A[\dOoIl]{0,4}\s*NATIVE\s+TRIBES\s+OF\s+CENTRAL\s+AUSTRALIA\b.{0,16}\z/],
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true, tail_pop_junk: true
  },
  "northerntribesof00spen-northern-tribes-central-australia-spencer-gillen.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    drop: [/\A[\dOoIl]{0,4}\s*NORTHERN\s+TRIBES\s+OF\s+CENTRAL\s+AUSTRALIA\b.{0,16}\z/i],
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true
  },
  # --- Man, Aboriginal Inhabitants of the Andaman Islands ---------------------
  # Tail cut removes Man's index AND the appended Ellis "Report of Researches
  # into the Language of the South Andaman Island" (interlinear linguistics).
  "b24764413-aboriginal-inhabitants-andaman-man.md" => {
    head_cut_to: /\APREFACE\.\z/,
    tail_cut_from: /\AINDEX\.\z/, tail_frac: 0.75,
    drop: [
      /Man\.?\s*[—-]+\s*On\s+t[hk]e\s+Aboriginal\s+Inhabitants/,
      /\AOF\s+THE\s+ANDAMAN\s+ISLANDS\.?\s*[\dOoIl]{0,4}\z/,
      /\A[\dOoIl]{0,4}\s*On\s+the\s+Abor\S{1,10}\s+Inhabitants\s+of\s+the\s+Andaman\s+Islands\.?\s*[\dOoIl]{0,4}\z/
    ],
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true, tail_pop_junk: true
  },
  # --- Rasmussen, People of the Polar North -----------------------------------
  "peopleofpolarnor00rasmuoft-people-of-polar-north-rasmussen.md" => {
    head_cut_to: /\ACONTENTS\z/,
    tail_cut_from: /\APrinted\s+by\s+BALLANTTNE/, tail_frac: 0.9,
    drop: [/\A[\dOoIl]{0,4}\s*THE\s+(NEW\s+PEOPLE|EAST\s+GREENLANDERS|WEST\s+GREENLANDERS)\b.{0,8}\z/],
    repeat_headers: 12,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true
  },
  # --- Seligman, Melanesians of British New Guinea ----------------------------
  # NOTE: shredded comparative vocabulary tables (one word per line) remain in
  # the linguistics appendices; narrative/legend chapters are clean.
  "melanesiansofbri00seli-melanesians-british-new-guinea-seligman.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    repeat_headers: 12,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true
  },
  # --- Grubb, An Unknown People in an Unknown Land ----------------------------
  "unknownpeopleinu00grub-unknown-people-unknown-land-grubb.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    repeat_headers: 12,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true
  },
  # --- Rasmussen, Across Arctic America ---------------------------------------
  # Chapter-level triage (per review: "promote only chapters verified clean").
  # Suspicious-token rates per 1000 words: chapters I-XIII run 1.0-5.6,
  # XXVI-XXVIII run 3.0-6.8, while chapters XIV-XXV run 8.0-21.8 (a badly
  # scanned region OCR'd blind: "evideaotly, tie 'creature'", "dhiMim").
  # CUT WHOLESALE: chapters XIV through XXV (the Great Fish River /
  # Netsilik / Mackenzie coastal journey stretch, orig lines ~8022-14003).
  # KEPT: Introduction, chapters I-XIII (Hudson Bay, Caribou Eskimos,
  # shamans, songs) and XXVI-XXVIII (Alaska, Chukotsk, conclusion) - the
  # last two carry light residual garble, flagged for review. The internal
  # CONTENTS/illustrations block between the Introduction and Chapter I is
  # also cut.
  "acrossarcticamer006641mbp-across-arctic-america-rasmussen.md" => {
    head_cut_to: /\AINTRODUCTION\z/,
    cut_between: [
      [/\ACHAPTER\z/, /\ACHAPTER\s+I\z/],
      [/\ACHAPTER\s+XIV\z/, /\ACHAPTER\s+XXVI\z/]
    ],
    drop: [/\A[\dOoIl]{0,4}\s*A\s?CROSS\s+ARCTIC\s+AMERICA\s*[\dOoIl]{0,4}\z/],
    repeat_headers: 10,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true
  },
  # --- Boas & Tate, Tsimshian Mythology (31st BAE Annual Report) --------------
  # Structural decision (per review): keep only the narrative half - section
  # "I. TSIMSHIAN MYTHS" (the Tate texts in English translation). CUT: all
  # front matter incl. the ~1200-line table of contents and Boas's
  # introductory ethnographic sketch, and everything from section
  # "II. DESCRIPTION OF THE TSIMSHIAN, BASED ON THEIR MYTHOLOGY" through the
  # end (III. Tsimshian Society, IV. Comparative Study of Tsimshian
  # Mythology, appendices, index) - Boas's derived/comparative apparatus,
  # out of project scope for canonical narrative texts.
  "tsimshianmytholo00boas-tsimshian-mythology-boas-tate.md" => {
    head_cut_to: /\AI\.\s+TSIMSHIAN\s+MYTHS\z/, head_search: 4000,
    tail_cut_from: /\AII\.\s+DESCRIPTION\s+OF\s+THE\s+TS\S{0,10}\s+BASED\s+ON\s+THEIR\z/,
    tail_frac: 0.25,
    drop: [/\A[\dOoIl]{0,4}\s*TSIMSHIAN\s+MYTHOLOGY\b.{0,16}\z/i],
    bracket_runner: true,
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, squeeze: true, tail_pop_junk: true
  },
  # --- im Thurn, Among the Indians of Guiana ----------------------------------
  "amongindiansgui00thurgoog-among-indians-guiana-im-thurn.md" => {
    head_cut_to: /\APREFACE\.\z/,
    tail_cut_from: /\AINDEX\.\z/, tail_frac: 0.85,
    drop: [
      /\A[\dOoIl]{0,4}\s*AMONG THE INDIANS OF GUIANA\.?\s*[\dOoIl]{0,4}\z/,
      /\A\S{3,6}\s+Weller\.?\s+ditto\z/ # map-engraver credit fragment
    ],
    repeat_headers: 15,
    page_junk: true, dehyphen: true, rejoin: true, tail_pop_junk: true
  },
  # ===========================================================================
  # Lower-priority pass-2 files (mechanical noise only). Character-level OCR
  # garble noted per file in the review (Russian name vowels in Hapgood,
  # Pali/Sanskrit diacritics in SBE volumes, body garble in Grey) is NOT
  # touched - log in transcription.corrections at promotion.
  # ===========================================================================
  "epicsongsofrussi00hapguoft-epic-songs-of-russia-hapgood.md" => {
    head_cut_to: /\APREFACE\.\z/,
    drop: [/\A[\dOoIl]{0,4}\s*(THE\s+)?EPI\S{0,2}\s+SONGS\s+OF\s+\S{0,2}USSIA\.?\s*[\dOoIl]{0,4}\z/],
    repeat_headers: 10, page_junk: true, dehyphen: true, rejoin: true
  },
  "polynesianmythol00greyuoft-polynesian-mythology-grey.md" => {
    head_cut_to: /\APREFACE\.\z/,
    repeat_headers: 10, page_junk: true, dehyphen: true, rejoin: true
  },
  "queenofshebahero00budgrich-kebra-nagast-budge.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.85,
    drop: [/\A[\dOoIl]{0,4}\s*THE\s+QUEEN\s+OF\s+SHEBA\b.{0,34}\z/i],
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    squeeze: true, tail_pop_junk: true
  },
  "dirr-1925-caucasian-folk-tales-caucasian-folk-tales-dirr.md" => {
    head_cut_to: /\AINTRODUCTION\z/,
    tail_cut_after: /\AFINIS\z/, tail_frac: 0.9,
    repeat_headers: 12, page_junk: true, dehyphen: true, rejoin: true,
    tail_pop_junk: true
  },
  # Mahavamsa: standalone digit lines are NOT removed here - many are
  # marginal verse numbers (citation structure, per review "reattach, don't
  # delete"); reattachment needs a manual pass.
  "mahavamsaorgreat00mahciala-mahavamsa-geiger.md" => {
    head_cut_to: /\AINTRODUCTION\z/,
    tail_cut_from: /\AINDEXES\z/, tail_frac: 0.9,
    repeat_headers: 12, dehyphen: true, rejoin: true, squeeze: true
  },
  "sikhreligionitsg01unse-sikh-religion-macauliffe-vol1.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\APRINTED\s+AT\s+THE\s+CLARENDON\s+PRESS\z/, tail_frac: 0.9,
    drop: [/\A[\dOoIl]{0,4}\s*THE\s+SIKH\s+RELIGION\b.{0,10}\z/],
    repeat_headers: 15, page_junk: true, not_dehyphen: true, dehyphen: true,
    rejoin: true, squeeze: true, tail_pop_junk: true
  },
  "sacredbooksofch03conf-shu-king-shih-king-legge.md" => {
    head_cut_to: /\ACONTENTS\.\z/,
    tail_cut_from: /\ATRANSLITERATION\s+OF\s+ORIENTAL\s+ALPHABETS\.?\z/, tail_frac: 0.85,
    drop: [/\A[\dIlOo, .]{0,8}THE\s+SH[UIH]{1,2}\s+KING\b.{0,16}\z/],
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    squeeze: true, tail_pop_junk: true
  },
  "sacredbooksofchi0027unse-li-ki-part1-legge.md" => {
    head_cut_to: /\AINTRODUCTION\.\z/,
    tail_cut_from: /\ATRANSLITERATION OF ORIENTAL ALPHABETS\z/, tail_frac: 0.9,
    drop: [/\A[\dOoIl]{0,4}\s*THE\s+L[IJ1]\s+[KX][IJ1]\b.{0,14}\z/i],
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    tail_pop_junk: true
  },
  "mlbd.sacredbooksofeas0000fmax.vol.28-li-ki-part2-legge.md" => {
    head_cut_to: /\ABOOK XI\./,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.8,
    drop: [/\A[\dOoIl]{0,4}\s*THE\s+L[IJ1]\s+[KX][IJ1]\b.{0,14}\z/i],
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    tail_pop_junk: true
  },
  "questionsofkingm01davi-questions-of-king-milinda-part1.md" => {
    head_cut_to: /\AINTRODUCTION\.\z/,
    tail_cut_from: /\AINDEX\s+OF\s+PROPER\s+NAMES[.,]?\z/, tail_frac: 0.7,
    phrase_runners: [/THE\s+QUESTIONS\s+OF\s+KING\s+MILINDA/],
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    squeeze: true, tail_pop_junk: true
  },
  "questionsofkingm02davi-questions-of-king-milinda-part2.md" => {
    head_cut_to: /\AINTRODUCTION\.\z/,
    tail_cut_from: /\AINDEX\s+OF\s+PROPER\s+NAMES[.,]?\z/, tail_frac: 0.8,
    phrase_runners: [
      /(THE\s+)?QUESTIONS\s+AND\s+PUZZLES(\s+OF\s+MILINDA\s+THE\s+KING)?/,
      /OF\s+MILINDA\s+THE\s+KING/
    ],
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    squeeze: true, tail_pop_junk: true
  },
  # Vinaya part 1: words split across line breaks WITHOUT hyphens ("Maga
  # dha") cannot be repaired mechanically without rewriting text - left as
  # is (flagged in review).
  "sacredbookseast13mulluoft-vinaya-texts-part1.md" => {
    head_cut_to: /\ACONTENTS\.\z/,
    tail_cut_from: /\ATRANSLITERATION\s+OF\s+ORIENTAL\s+ALPHABETS\.?\z/, tail_frac: 0.8,
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    squeeze: true, tail_pop_junk: true
  },
  "vinayatexts02davi-vinaya-texts-part2.md" => {
    head_cut_to: /\ACONTENTS\.\z/,
    tail_cut_from: /\ATRANSLITERATION\s+OF\s+ORIENTAL\s+ALPHABETS\.?\z/, tail_frac: 0.85,
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    squeeze: true, tail_pop_junk: true
  },
  "in.ernet.dli.2015.189082-vinaya-texts-part3.md" => {
    head_cut_to: /\ACONTENTS\.\z/,
    tail_cut_from: /\AINDEX TO VINAYA TEXTS,?\z/, tail_frac: 0.75,
    drop: [/\A[IVXL]{1,5},\s*\d{1,2}(,\s*\d{1,3})?\.?\z/], # split marginal refs
    repeat_headers: 15, page_junk: true, dehyphen: true, rejoin: true,
    tail_pop_junk: true
  },
  "shansathomewitht00milnrich-shans-at-home-milne.md" => {
    head_cut_to: /\ACONTENTS\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.85,
    drop: [/\A[\dOoIl]{0,4}\s*SHANS\s+AT\s+HOME\b.{0,10}\z/],
    repeat_headers: 12, page_junk: true, dehyphen: true, rejoin: true,
    squeeze: true, tail_pop_junk: true
  },
  "cu31924028622284-madagascar-before-conquest-sibree.md" => {
    head_cut_to: /\APREFACE\.\z/,
    tail_cut_from: /Bresbam/, tail_frac: 0.95,
    drop: [/\A[\dOoIl]{0,4}\s*MADAGASCAR\s+BEFORE\s+THE\s+CONQUEST\.?\s*[\dOoIl]{0,4}\z/],
    repeat_headers: 12, page_junk: true, dehyphen: true, rejoin: true
  },
  "carolineislands00chri-caroline-islands-christian.md" => {
    head_cut_to: /\ACONTENTS\z/,
    # content ends with the appendix specimen notes; an OCR-shredded
    # sideways fold-out table sits between them and the INDEX.
    tail_cut_after: /\AScale\s+of\s+measurement\s+in\z/, tail_frac: 0.6,
    drop: [/\A[\dOoIl]{0,4}\s*THE\s+CAROLINE\s+ISLANDS\.?\s*[\dOoIl]{0,4}\z/],
    repeat_headers: 12, page_junk: true, dehyphen: true, rejoin: true,
    squeeze: true, tail_pop_junk: true
  },
  "cu31924023500543-island-of-stone-money-furness.md" => {
    head_cut_to: /\ACONTENTS\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    drop: [/\A[\dOoIl]{0,4}\s*THE\s+ISLAND\s+O[FP]\s+STO\S{0,4}\s+MONEY\.?\s*[\dOoIl]{0,4}\z/],
    repeat_headers: 12, page_junk: true, dehyphen: true, rejoin: true,
    tail_pop_junk: true
  },
  "ashanti0000ratt-ashanti-rattray.md" => {
    head_cut_to: /\APREFACE\z/,
    tail_cut_from: /\AINDEX\z/, tail_frac: 0.9,
    # standalone symbol shreds from OCR'd genealogy diagrams ("<", "<3", "£")
    drop: [/\A[^A-Za-z\s]{1,3}\z/],
    repeat_headers: 12, page_junk: true, not_dehyphen: true, dehyphen: true,
    rejoin: true, squeeze: true, tail_pop_junk: true
  }
}.freeze

PAGE_JUNK = /\A[\dOoIlSg()\[\]]{1,5}\z/.freeze
CHAPTERISH = /\A(CHAPTER|PART|BOOK)\b/i.freeze

def normalized(line)
  line.gsub(/[\d\[\]().:;,'"*^—–-]+/, " ").squeeze(" ").strip.downcase
end

def caps_ratio(str)
  letters = str.scan(/[A-Za-z]/)
  return 0.0 if letters.length < 4
  letters.count { |c| c =~ /[A-Z]/ }.to_f / letters.length
end

def bracket_runner?(str)
  return false unless str =~ /\A[A-Za-z]{3,12}[\]\)]\s+\S/
  rest = str.sub(/\A[A-Za-z]{3,12}[\]\)]\s+/, "")
  rest.length <= 50 && (rest =~ /\d\s*\z/ || caps_ratio(rest) >= 0.6)
end

# --- Eskimo interlinear zone helpers -----------------------------------------
def eskimo_word?(raw)
  w = raw.gsub(/["'“”‘’()\[\],.!?;:—–]/, "")
  return false if w.empty?
  return true if w =~ /q(?![uU])/i
  return true if w =~ /ng[mn]/
  false
end

ENGLISH_STOPWORDS = %w[the a an and of to in on at by he she it they we you i
                       is was were said thus that this all one there from get
                       them her his had who].freeze

def eskimo_line?(line)
  words = line.split.reject { |t| t.gsub(/[[:punct:]]/, "") =~ /\A\d*\z/ }
  return false if words.empty?
  flags = words.count { |w| eskimo_word?(w) }
  return true if flags >= 2 && flags.to_f / words.size >= 0.34
  return true if words.size <= 2 && flags == words.size && flags >= 1
  # Eskimo lines without q/ngm signatures: no common English words, and most
  # words carry the agglutinative -Vt/-Vk endings ("Ikungat pekit").
  if words.size >= 2 && words.none? { |w| ENGLISH_STOPWORDS.include?(w.downcase.gsub(/[^a-z]/, "")) }
    endings = words.count { |w| w.gsub(/[[:punct:]]/, "") =~ /[aiu][tkq]\z/i }
    return true if endings.to_f / words.size >= 0.6
  end
  false
end

def eskimo_para?(para)
  esk = para.count { |l| eskimo_line?(l) }
  esk >= 1 && esk >= (para.length / 2.0).ceil
end

TALE_HEADING = /\A[\divxIVXl]{1,4}\.\s*\S[^a-z]{2,45}\z/.freeze
TRANSLATION_MARKER = /\AT\s{0,3}ranslation\s*\.?\s*[.*\d]{0,4}\z/.freeze
RECORDED_BY = /\A\(Recorded by/.freeze

# Processes the zone lines paragraph-wise; returns kept lines.
def filter_eskimo_zone(lines, stats)
  paras = []
  current = []
  lines.each do |line|
    if line.strip.empty?
      paras << current unless current.empty?
      current = []
    else
      current << line
    end
  end
  paras << current unless current.empty?

  kept = []
  mode = :scan            # :scan | :interlinear | :song_drop
  seen_translation = false
  paras.each do |para|
    stripped = para.map(&:strip)
    first = stripped.first
    if para.length == 1 && first =~ TALE_HEADING && caps_ratio(first) >= 0.5
      kept << para
      mode = :scan
      seen_translation = false
      next
    end
    if para.length == 1 && first =~ TRANSLATION_MARKER
      kept << para
      mode = :scan
      seen_translation = true
      stats[:translation_blocks] += 1
      next
    end
    if para.length == 1 && first =~ RECORDED_BY
      kept << para
      next
    end
    if mode == :song_drop
      short = stripped.all? { |l| l.length < 40 }
      if short && (eskimo_para?(stripped) || first =~ /\A[a-z(]/ || stripped.all? { |l| l.split.length <= 5 })
        stats[:song_gloss_dropped] += 1
        next
      end
      mode = :scan
    end
    esk_lines = stripped.count { |l| eskimo_line?(l) }
    # Before the tale's free translation, OCR often runs Eskimo lines and
    # their glosses together into one mixed paragraph: two flagged lines
    # (or one in a short paragraph) are enough to mark it interlinear.
    trigger = eskimo_para?(stripped) ||
              (!seen_translation && (esk_lines >= 2 || (esk_lines >= 1 && stripped.length <= 3)))
    if trigger
      stats[:eskimo_paras] += 1
      mode = seen_translation ? :song_drop : :interlinear
      next
    end
    if mode == :interlinear
      stats[:interlinear_gloss_dropped] += 1
      next
    end
    kept << para
  end
  kept.flat_map { |para| para + [""] }
end

selected = ARGV.empty? ? SPECS : SPECS.select { |n, _| ARGV.any? { |a| n.include?(a) } }

selected.each do |name, spec|
  path = File.join(DIR, name)
  abort "missing #{name}" unless File.file?(path)
  lines = File.readlines(path, chomp: true)
  before = lines.length
  stats = Hash.new(0)

  # --- head cut ---------------------------------------------------------------
  if spec[:head_cut_to]
    idx = (1...[lines.length, spec[:head_search] || 1500].min).find { |i| lines[i].strip =~ spec[:head_cut_to] }
    raise "#{name}: head marker not found" unless idx
    stats[:head_trim] = idx - 1
    lines = [lines[0], ""] + lines[idx..]
  end

  # --- internal cuts ----------------------------------------------------------
  if spec[:cut_between]
    pairs = spec[:cut_between].first.is_a?(Regexp) ? [spec[:cut_between]] : spec[:cut_between]
    pairs.each do |s_re, e_re|
      s = lines.index { |l| l.strip =~ s_re }
      raise "#{name}: cut_between start #{s_re.inspect} not found" unless s
      e = (s + 1...lines.length).find { |i| lines[i].strip =~ e_re }
      raise "#{name}: cut_between end #{e_re.inspect} not found" unless e
      stats[:internal_cut] += e - s
      lines = lines[0...s] + lines[e..]
    end
  end

  # --- tail cut ---------------------------------------------------------------
  if spec[:tail_cut_from] || spec[:tail_cut_after]
    re = spec[:tail_cut_from] || spec[:tail_cut_after]
    from = (lines.length * (spec[:tail_frac] || 0.5)).to_i
    range = (from...lines.length)
    idx = spec[:tail_last] ? range.to_a.reverse.find { |i| lines[i].strip =~ re } : range.find { |i| lines[i].strip =~ re }
    raise "#{name}: tail marker not found" unless idx
    keep_to = spec[:tail_cut_after] ? idx : idx - 1
    stats[:tail_trim] = lines.length - keep_to - 1
    lines = lines[0..keep_to]
  end

  # --- line drops: explicit, bracket runners, repeated headers, page junk -----
  drops = spec[:drop] || []
  protect = spec[:protect] || []
  norm_counts = Hash.new(0)
  if spec[:repeat_headers]
    lines.each do |l|
      s = l.strip
      next if s.empty? || s.length > 70
      k = normalized(s)
      norm_counts[k] += 1 if k.length >= 4
    end
  end

  kept = []
  prev_nonblank = ""
  lines.each do |line|
    s = line.strip
    if s.empty?
      kept << line
      next
    end
    if protect.any? { |re| s =~ re }
      kept << line
      prev_nonblank = s
      next
    end
    if drops.any? { |re| s =~ re }
      stats[:dropped] += 1
      next
    end
    if spec[:phrase_runners] &&
       spec[:phrase_runners].any? { |re| s =~ re && s.sub(re, "").gsub(/\s+/, " ").strip.length <= 24 }
      stats[:phrase_runners] += 1
      next
    end
    if spec[:bracket_runner] && bracket_runner?(s)
      stats[:bracket_runners] += 1
      next
    end
    if spec[:page_junk] && s.length <= 5 && s =~ PAGE_JUNK && s =~ /\d/
      stats[:page_junk] += 1
      next
    end
    if spec[:repeat_headers] && s.length <= 70 &&
       norm_counts[normalized(s)] >= spec[:repeat_headers] &&
       (s =~ /\d/ || caps_ratio(s) >= 0.7) &&
       prev_nonblank !~ CHAPTERISH
      stats[:repeat_headers] += 1
      next
    end
    kept << line
    prev_nonblank = s
  end
  lines = kept

  # --- Eskimo interlinear zone ------------------------------------------------
  if spec[:eskimo_zone]
    s_re, e_re = spec[:eskimo_zone]
    s = lines.index { |l| l.strip =~ s_re }
    raise "#{name}: eskimo_zone start not found" unless s
    e = (s + 1...lines.length).find { |i| lines[i].strip =~ e_re }
    raise "#{name}: eskimo_zone end not found" unless e
    zone = filter_eskimo_zone(lines[(s + 1)...e], stats)
    lines = lines[0..s] + [""] + zone + lines[e..]
  end

  # --- soft-hyphen (¬) chain join ---------------------------------------------
  if spec[:not_dehyphen]
    joined = []
    i = 0
    while i < lines.length
      line = lines[i]
      while line.rstrip.end_with?("¬")
        j = i + 1
        j += 1 while j < lines.length && lines[j].strip.empty?
        break unless j < lines.length
        line = line.rstrip.sub(/¬\z/, "") + lines[j].lstrip
        stats[:not_dehyphenated] += 1
        i = j
      end
      joined << line
      i += 1
    end
    lines = joined
  end

  # --- line-end hyphen join ---------------------------------------------------
  if spec[:dehyphen]
    joined = []
    i = 0
    while i < lines.length
      line = lines[i]
      if line.rstrip =~ /[a-z]-\z/
        j = i + 1
        j += 1 while j < lines.length && lines[j].strip.empty?
        if j < lines.length && lines[j].lstrip =~ /\A[a-z]/
          joined << line.rstrip.sub(/-\z/, "") + lines[j].lstrip
          stats[:dehyphenated] += 1
          i = j + 1
          next
        end
      end
      joined << line
      i += 1
    end
    lines = joined
  end

  # --- re-join paragraph splits left by removed furniture ---------------------
  if spec[:rejoin]
    merged = []
    lines.each do |line|
      if line.strip.empty?
        merged << line
      else
        k = merged.length - 1
        k -= 1 while k >= 0 && merged[k].strip.empty?
        if k >= 0 && k < merged.length - 1 && merged[k] =~ /[a-z,;]\z/ && line.lstrip =~ /\A[a-z]/
          merged.slice!(k + 1..)
          stats[:paragraphs_rejoined] += 1
        end
        merged << line
      end
    end
    lines = merged
  end

  # --- squeeze + blank collapse ------------------------------------------------
  final = []
  blank_run = 0
  lines.each do |line|
    out = line.rstrip
    out = out.gsub(/(?<=\S) {2,}(?=\S)/, " ").sub(/\A\s+/, "") if spec[:squeeze]
    if out.empty?
      blank_run += 1
      final << "" if blank_run <= 2
    else
      blank_run = 0
      final << out
    end
  end
  final.pop while final.last == ""
  if spec[:tail_pop_junk]
    # pop trailing sideways-plate OCR shreds ("z", "<", "CO", "ssuiddTiiiijj")
    while final.last && (final.last.strip.length <= 8 || final.last !~ /[a-z]{3}/ ||
                         (final.last.strip !~ /\s/ && final.last =~ /[a-z][A-Z]/))
      final.pop
      stats[:tail_junk_popped] += 1
      final.pop while final.last == ""
    end
  end

  File.write(path, final.join("\n") + "\n")
  puts "#{name}: #{before} -> #{final.length} (#{stats.map { |k, v| "#{k}=#{v}" }.join(' ')})"
end
