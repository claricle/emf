# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/malformed_parity"

RSpec.describe "Native malformed-EMF parity" do
  include_context "with native library"

  root = File.expand_path("../../..", __dir__)
  manifest = JSON.parse(File.read(File.join(root, "spec/fixtures/manifest.json")))
  fixtures = MalformedParity.entries(manifest)

  let(:runner) { MalformedParity::Runner.new(root: root, library: library) }
  let(:image) { File.binread(File.join(root, "spec/fixtures/simple/image1.emf")) }

  def parse_with(backend, bytes)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library
    Emf.parse(bytes)
  rescue StandardError => e
    e
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  def messages(result)
    result.is_a?(Exception) ? result.message : result.errors.map { |error| [error.offset, error.record_code, error.message] }
  end

  it "covers the 21 corrupt fixtures: 9 parsed, 10 recovered, 2 format errors" do
    expect(fixtures.size).to eq(21)
    expect(fixtures.map { |entry| entry.fetch("outcome") }.tally).to eq("parsed" => 9, "recovered" => 10, "format_error" => 2)
  end

  fixtures.each do |entry|
    it "matches Ruby outcome, records, diagnostics, trailing bytes and serialization for #{File.basename(entry.fetch('path'))}" do
      path = File.join(root, entry.fetch("path"))
      ruby = runner.call(path, "ruby")
      native = runner.call(path, "native")

      expect(ruby.fetch("outcome")).to eq(entry.fetch("outcome"))
      expect(native).to eq(ruby), BackendParity.differences(ruby, native).join(", ")
      expect(native.fetch("serialized").fetch("equals_input")).to be(true) unless native.fetch("outcome") == "format_error"
    end
  end

  describe "header rejection wording" do
    it "names the header nSize when the header is truncated, as Ruby does" do
      cut = image.byteslice(0, 100)
      huge = image.dup.tap { |bytes| bytes[4, 4] = [image.bytesize + 500].pack("V") }
      small = image.dup.tap { |bytes| bytes[4, 4] = [4].pack("V") }

      [cut, huge, small].each do |bytes|
        expect(messages(parse_with("native", bytes))).to eq(messages(parse_with("ruby", bytes)))
      end
      expect(messages(parse_with("native", cut))).to eq("truncated EMF header (claimed 108, got 100)")
    end

    it "words an nSize too small for the header fields the way Ruby does" do
      bytes = image.dup.tap { |data| data[4, 4] = [80].pack("V") }

      expect(parse_with("ruby", bytes)).to be_a(Emf::FormatError)
      expect(messages(parse_with("native", bytes))).to eq(messages(parse_with("ruby", bytes)))
      expect(messages(parse_with("native", bytes))).to eq("EMF header nSize 80 cannot hold its fields")
    end
  end

  describe "framing diagnostics" do
    {
      "an nSize below eight" => ->(image) { image.byteslice(0, 108) + [14, 0].pack("V*") + ("\0" * 8) },
      "a truncated record head" => ->(image) { image.byteslice(0, 108) + "abc".b },
      "a truncated record" => ->(image) { image.byteslice(0, image.bytesize - 5) }
    }.each do |label, build|
      it "reports #{label} with Ruby's message, offset and record code" do
        bytes = build.call(image)
        ruby = parse_with("ruby", bytes)
        native = parse_with("native", bytes)

        expect(messages(native)).to eq(messages(ruby))
        expect(native).to be_a(Emf::Model::Metafile)
        expect(messages(native)).not_to be_empty
        expect(native.trailing).to eq(ruby.trailing)
      end
    end
  end
end
