# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_rejection_cases"
require_relative "../../support/native_library_context"
require_relative "../../support/conformance_parity"

RSpec.describe "Emf::Conformance WMF rejection and declared-size rules" do
  records = Emf::Model::Wmf::Records
  profiles = %i[strict tolerant].freeze
  shadowed = [301, 302, 303].freeze
  seeds = File.expand_path("../../../emf-rs/fuzz/seeds/wmf-resilience", __dir__)

  def check(input, profile = :strict) = Emf::Conformance.check(input, profile: profile)

  def ids(input, profile = :strict) = check(input, profile).diagnostics.map(&:requirement_id)

  def named(reason) = format("wmf.reject.r%04d", reason)

  describe "rejected input" do
    WmfRejectionCases.cases.except(*shadowed).each do |reason, bytes|
      it "reason #{reason} gives exactly #{format('wmf.reject.r%04d', reason)} as an error in both profiles" do
        profiles.each do |profile|
          report = check(bytes, profile)
          expect(report.diagnostics.map(&:requirement_id)).to eq([named(reason)])
          expect([report.valid?, report.diagnostics.first.severity, report.diagnostics.first.format]).to eq([false, :error, :wmf])
        end
      end
    end

    it "takes the offset from the evidence and states declared and actual in the message" do
      diagnostic = check(WmfRejectionCases.cases.fetch(203)).diagnostics.first
      expect(diagnostic.offset).to eq(20)
      expect(diagnostic.message).to eq("WMF placeable checksum mismatch at offset 20 (declared 65535, actual 22385)")
      expect(diagnostic.spec_citation).to start_with("MS-WMF 2.3.2.3")
    end

    it "names the failing record's function for a record-level reason, and none for a header reason" do
      expect(check(WmfRejectionCases.cases.fetch(1203)).diagnostics.first.record_type).to eq(0xFF)
      expect(check(WmfRejectionCases.cases.fetch(306)).diagnostics.first.record_type).to be_nil
    end

    it "keeps emf.parse.unparseable for reasons the format detector shadows (301-303)" do
      shadowed.each do |reason|
        expect(ids(WmfRejectionCases.cases.fetch(reason))).to eq(["emf.parse.unparseable"])
      end
    end

    it "keeps emf.parse.unparseable for a failure without a named reason" do
      expect(ids("this is not a metafile at all, not even close".b)).to eq(["emf.parse.unparseable"])
    end

    it "reports reasons 101 and 401 (not producible here) as emf.parse.unparseable only" do
      failure = Emf::FormatError.new("WMF input too large").with_evidence(Emf::ParseEvidence.new(check: :input_too_large, offset: 0))
      context = Emf::Conformance::Context.new(bytes: "".b, parse_failure: failure)
      expect(Emf::Conformance::ParseRecoveryRules.unparseable(context).size).to eq(1)
      expect(Emf::Conformance::WmfRejectionRules::CHECKS.values & [101, 401, *shadowed]).to be_empty
    end

    it "covers every reachable reason: 56 minus 101, 401, the shadowed three, and 305, 404 and 1801 (recovered or retired)" do
      expect(Emf::Conformance::WmfRejectionRules::CHECKS.size).to eq(48)
      expect(WmfRejectionCases.cases.keys - shadowed).to match_array(Emf::Conformance::WmfRejectionRules::CHECKS.values)
    end

    {
      "bitmap-short-record" => "wmf.reject.r1401", "missing-eof" => "wmf.reject.r0405", "negative-text-count" => "wmf.reject.r1003",
      "placeable-checksum" => "wmf.reject.r0203", "zero-record" => "wmf.reject.r0403",
      "header-size" => "emf.parse.unparseable"
    }.each do |name, id|
      it "seed #{name}.wmf gives #{id}" do
        profiles.each { |profile| expect(ids(File.join(seeds, "#{name}.wmf"), profile)).to eq([id]) }
      end
    end
  end

  describe "declared size on accepted models" do
    let(:header) do
      Emf::Model::Wmf::Header.new(type: 1, version: 0x300, size_words: 17, number_of_objects: 0, max_record_words: 5,
                                  number_of_members: 0, placeable: nil)
    end

    def model(list, header)
      Emf::Model::Metafile.new(format: :wmf, header: header, records: list)
    end

    def eof(words = 3) = records::Eof.new(offset: 100).declare_size(words)

    def move(words) = records::MoveTo.new(type_id: 0x14, x: 1, y: 2, offset: 18).declare_size(words)

    let(:records) { Emf::Model::Wmf::Records }

    it "reports nothing for records built in memory or sized as their layout requires" do
      expect(ids(model([records::MoveTo.new(type_id: 0x14, x: 1, y: 2, offset: 18), records::Eof.new(offset: 30)], header))).to eq([])
      expect(ids(model([move(5), eof], header))).to eq([])
    end

    it "flags an exact layout whose RecordSize differs (wmf.record.declared_size)" do
      diagnostics = check(model([move(6), eof], header)).diagnostics
      expect(diagnostics.map(&:requirement_id)).to include("wmf.record.declared_size")
      expect(diagnostics.find { |d| d.requirement_id == "wmf.record.declared_size" }.message).to include("MoveTo layout is 5 words")
    end

    it "flags a RecordSize under the 3-word minimum and an EOF that is not 3 words" do
      expect(ids(model([move(2), eof], header))).to include("wmf.record.declared_size")
      expect(ids(model([move(5), eof(4)], header))).to include("wmf.record.declared_size")
    end

    it "flags a state record shorter than its payload but not a longer one" do
      state = ->(words) { records::SetBkMode.new(type_id: 0x0102, mode: 1, suffix: "".b, offset: 18).declare_size(words) }
      expect(ids(model([state.call(3), eof], header))).to include("wmf.record.declared_size")
      expect(ids(model([state.call(5), eof], header))).not_to include("wmf.record.declared_size")
    end

    it "flags a buffer record whose RecordSize differs from the bytes it occupies (wmf.buffer.declared_size)" do
      text = ->(words) { records::TextOut.new(text: "ab".b, padding: "".b, x: 0, y: 0, offset: 18).declare_size(words) }
      expect(ids(model([text.call(8), eof], header))).to include("wmf.buffer.declared_size")
      expect(ids(model([text.call(7), eof], header))).not_to include("wmf.buffer.declared_size")
    end

    it "flags a header MaxRecord that is not the largest RecordSize (wmf.header.max_record)" do
      wrong = Emf::Model::Wmf::Header.new(type: 1, version: 0x300, size_words: 17, number_of_objects: 0, max_record_words: 4,
                                          number_of_members: 0, placeable: nil)
      expect(ids(model([move(5), eof], wrong))).to eq(["wmf.header.max_record"])
      expect(ids(model([move(5), eof], header))).to eq([])
    end

    it "flags a header Size that is not 9 plus the RecordSizes (wmf.header.size_matches_records)" do
      wrong = Emf::Model::Wmf::Header.new(type: 1, version: 0x300, size_words: 20, number_of_objects: 0, max_record_words: 5,
                                          number_of_members: 0, placeable: nil)
      expect(ids(model([move(5), eof], wrong))).to eq(["wmf.header.size_matches_records"])
    end

    it "stays silent on every accepted seed and fixture" do
      accepted = Dir[File.join(seeds, "valid-*.wmf")] + Dir[File.expand_path("../../fixtures/wmf/*.wmf", __dir__)]
      expect(accepted).not_to be_empty
      accepted.each do |path|
        found = ids(path) & %w[wmf.record.declared_size wmf.buffer.declared_size wmf.header.max_record wmf.header.size_matches_records]
        expect(found).to eq([]), path
      end
    end
  end

  describe "backend parity" do
    include_context "with native library"

    inputs = WmfRejectionCases.cases.transform_keys { |reason| "reason #{reason}" }
    inputs = inputs.merge(Dir[File.join(seeds, "*.wmf")].to_h { |path| [File.basename(path), File.binread(path)] })

    it "gives byte-identical reports on both backends for every rejection case and seed, in both profiles" do
      expect(inputs.size).to eq(51 + 16)
      differences = profiles.flat_map do |profile|
        inputs.filter_map do |label, bytes|
          run = ->(backend) { ConformanceParity.with_backend(backend, library) { check(bytes, profile).to_h.merge("timestamp" => nil) } }
          difference = ConformanceParity.first_difference(run.call("ruby"), run.call("native"))
          "#{label} [#{profile}] #{difference}" if difference
        end
      end
      expect(differences).to eq([])
    end
  end
end
