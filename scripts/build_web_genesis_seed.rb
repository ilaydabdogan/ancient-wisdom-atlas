#!/usr/bin/env ruby
# frozen_string_literal: true

exec("ruby", File.expand_path("build_web_book_seed.rb", __dir__), "GEN")
