# frozen_string_literal: true

require_relative "lib/cattri/version"

Gem::Specification.new do |spec|
  spec.name          = "cattri"
  spec.version       = Cattri::VERSION
  spec.authors       = ["Nathan Lucas"]
  spec.email         = ["bnlucas@outlook.com"]

  spec.summary       = "Simple class and instance attribute DSL for Ruby."
  spec.description   = "Cattri provides a clean DSL for defining class-level and instance-level attributes " \
                       "with optional defaults, coercion, accessors, and inheritance support."
  spec.homepage      = "https://github.com/bnlucas/cattri"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"]     = spec.homepage
  spec.metadata["source_code_uri"]  = spec.homepage
  spec.metadata["changelog_uri"]    = "https://github.com/bnlucas/cattri/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://www.rubydoc.info/gems/cattri"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    (`git ls-files -z`.split("\x0") + %w[README.md LICENSE.txt]).uniq
  end

  # Runtime dependencies
  # spec.add_dependency "gem"

  # Development dependencies
  spec.add_development_dependency "debride"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-cobertura"
  spec.add_development_dependency "simplecov-html"
  spec.add_development_dependency "steep"
  spec.add_development_dependency "yard"
end
