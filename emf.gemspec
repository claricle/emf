# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "emf/version"

Gem::Specification.new do |spec|
  spec.name = "emf"
  spec.version = Emf::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Parser for WMF, EMF, and EMF+ metafiles, with an optional native backend."
  spec.description = "Parser for Windows Metafile (WMF), Enhanced Metafile (EMF), " \
                     "and EMF+ binary formats, in Ruby with an optional native backend. Produces an OOP domain model that downstream " \
                     "gems (such as emfsvg) consume."
  spec.homepage = "https://github.com/claricle/emf"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.adoc"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("lib/**/*.rb") + Dir.glob("lib/emf/conformance/manifest/*.yml") + %w[README.adoc LICENSE.txt]
  spec.bindir = "exe"
  spec.executables = %w[emf]
  spec.require_paths = %w[lib]

  spec.add_dependency "bindata", "~> 2.4"
end
