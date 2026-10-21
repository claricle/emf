# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/mutation_parity"

RSpec.describe "Native mutation parity" do
  include_context "with native library"

  root = File.expand_path("../../..", __dir__)
  manifest = JSON.parse(File.read(File.join(root, "spec/fixtures/manifest.json")))
  sample = MutationParity.sample(root, manifest)
  tally = Hash.new(0)

  after(:all) { warn "mutation parity directions: #{tally.sort.to_h}" }

  it "samples fourteen small and medium valid fixtures under the size cap" do
    expect(sample.size).to eq(MutationParity::SAMPLE)
    expect(sample.map { |path| File.size(File.join(root, path)) }.max).to be <= MutationParity::SIZE_CAP
  end

  sample.each do |path|
    it "parses every seeded mutation of #{File.basename(path)} identically on both backends" do
      bytes = File.binread(File.join(root, path))
      rng = Random.new(MutationParity::SEED + path.sum)
      mismatches = MutationParity.cases(bytes, rng).filter_map do |label, mutated|
        ruby = MutationParity.run("ruby", library, mutated)
        native = MutationParity.run("native", library, mutated)
        direction = MutationParity.direction(ruby, native)
        tally[direction] += 1
        "#{label} (#{direction}): #{BackendParity.differences(ruby, native).first(3).join(', ')}" unless direction == :equal
      end

      expect(mismatches).to be_empty
    end
  end

  describe "native hydrating a record Ruby rejects" do
    let(:image) { File.binread(File.join(root, "spec/fixtures/emf/test-007.emf")) }

    # A SMALLTEXTOUT shorter than its fixed prefix: Ruby's reader raises EOFError and keeps Raw.
    it "reports Ruby's error for a SMALLTEXTOUT cut below its fixed prefix" do
      mutated = MutationParity.put(image, 2308 + 4, 92)
      ruby = MutationParity.run("ruby", library, mutated)
      native = MutationParity.run("native", library, mutated)

      expect(ruby.fetch("errors").first).to include("record_code" => 108, "message" => "EOFError: End of file reached")
      expect(native).to eq(ruby)
    end
  end
end
