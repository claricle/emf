# frozen_string_literal: true

require "spec_helper"

RSpec.describe "extended pen empty offsets" do
  backends = %w[ruby native].freeze
  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", "") }

  def record(styles)
    fixed = 52 + (styles.length * 4)
    [95, fixed, 2, fixed - 8, 0, fixed - 8, 0, 0x12200, 8, 0, 0xFFFFFF, 0, styles.length, *styles].pack("V*")
  end

  def input(bytes)
    header = Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
    "#{header}#{bytes}#{[0xFFFF, 12, 123, 14, 20, 0, 0, 20].pack('V*')}tail"
  end

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  [[], [20, 24, 20, 24]].each do |styles|
    it "matches Ruby source and scalar edits with #{styles.length} styles" do
      skip "set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library)
      source = input(record(styles))
      replacement = Array(17).pack("V")
      results = backends.map do |backend|
        ENV["EMF_BACKEND"] = backend
        ENV["EMF_NATIVE_LIBRARY"] = library
        parsed = Emf.parse(source)
        expect(parsed.errors).to be_empty
        wire = parsed.records.first.wire
        expect(wire).to be_a(Emf::Emr::Binary::Records::ExtCreatePen)
        expect(wire.off_bmi.to_i).to eq(44 + (styles.length * 4))
        expect(wire.off_bits.to_i).to eq(wire.off_bmi.to_i)
        expect(wire.bitmap_info.to_s).to eq("")
        expect(wire.bitmap_bits.to_s).to eq("")
        expect(Emf.serialize(parsed)).to eq(source)
        snapshot = wire.snapshot
        wire.width = 17
        edited = source.dup
        edited[108 + 32, 4] = replacement
        expect(Emf.serialize(parsed)).to eq(edited)
        expect(Emf.parse(edited).errors).to be_empty
        [snapshot, Emf.serialize(parsed)]
      end
      expect(results[1]).to eq(results[0])
    end
  end
end
