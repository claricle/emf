# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Native EOF wire parity" do
  backends = %w[ruby native].freeze
  layouts = [[0, 0, 20, "".b], [1, 16, 0, [24].pack("V")], [0, 0, 123, "tail".b]].freeze
  let(:sibling) { [0xFFFF, 12, 42].pack("V*") }
  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", "") }
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  layouts.each do |entries, offset, last, body|
    it "preserves #{entries} palette entries and #{body.bytesize} opaque bytes through edits" do
      skip "set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library)
      eof = [14, 20 + body.bytesize, entries, offset, last].pack("V*") + body
      source = "#{header}#{sibling}#{eof}suffix"
      replacement = Array(17).pack("V")
      results = backends.map do |backend|
        ENV["EMF_BACKEND"] = backend
        ENV["EMF_NATIVE_LIBRARY"] = library
        parsed = Emf.parse(source)
        expect(parsed.errors).to be_empty
        expect(Emf.serialize(parsed)).to eq(source)
        wire = parsed.records.last.wire
        expect(wire).to be_a(Emf::Emr::Binary::Records::Eof)
        expect(wire.snapshot).to include(n_pal_entries: entries, off_pal_entries: offset, n_size_last: last, body: body)
        expect(Emf.serialize(parsed)).to eq(source)
        snapshot = wire.snapshot
        wire.n_size_last = 17
        edited = source.dup
        edited[header.bytesize + sibling.bytesize + 16, 4] = replacement
        expect(Emf.serialize(parsed)).to eq(edited)
        expect(Emf.parse(edited).records.last.wire.snapshot[:n_size_last]).to eq(17)
        unless body.empty?
          wire.body = "edit"
          edited[header.bytesize + sibling.bytesize + 20, 4] = "edit"
          expect(Emf.serialize(parsed)).to eq(edited)
          expect(Emf.parse(edited).records.last.wire.body.to_s).to eq("edit")
        end
        [snapshot, Emf.serialize(parsed)]
      end
      expect(results[1]).to eq(results[0])
    end
  end
  it "retains short EOF as Raw with diagnostics and exact bytes" do
    skip "set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library)
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    source = header + [14, 16, 0, 0].pack("V*")
    parsed = Emf.parse(source)
    expect(parsed.records.last.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    expect(parsed.errors.map(&:record_code)).to include(14)
    expect(Emf.serialize(parsed)).to eq(source)
  end
end
