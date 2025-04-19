# frozen_string_literal: true

require "simplecov"
require "simplecov-cobertura"
require "simplecov-html"

SimpleCov.formatters = [
  SimpleCov::Formatter::CoberturaFormatter,
  SimpleCov::Formatter::HTMLFormatter
]

SimpleCov.start do
  enable_coverage :branch

  track_files "lib/cattri/**/*.rb"

  add_filter "lib/cattri/version.rb"
  add_filter "/spec/"
end

SimpleCov.minimum_coverage 100
