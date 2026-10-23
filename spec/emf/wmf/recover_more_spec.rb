# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_recovery"

RSpec.describe "WMF record shapes recovered instead of rejected (Ruby backend)" do
  extend WmfRecovery
  include WmfRecovery

  around do |example|
    previous = ENV.fetch("EMF_BACKEND", nil)
    ENV["EMF_BACKEND"] = "ruby"
    example.run
  ensure
    ENV["EMF_BACKEND"] = previous
  end

  cases.each do |name, expected|
    context "with #{name}" do
      let(:metafile) { Emf.parse(expected[:bytes]) }

      it "keeps every record and records one ParseError with evidence" do
        expect(metafile.records.map(&:type_id)).to eq(expected[:types])
        expect(metafile.errors.size).to eq(1)
        error = metafile.errors.first
        evidence = Emf::ParseEvidence.new(check: expected[:check], offset: expected[:offset], declared: expected[:declared],
                                          actual: expected[:actual])
        expect([error.class, error.evidence]).to eq([Emf::ParseError, evidence])
        expect(error.offset).to eq(expected[:offset])
      end

      it "serializes, and the reserialized file reparses with the same records" do
        reparsed = Emf.parse(Emf.serialize(metafile))
        expect(reparsed.records.map(&:type_id)).to eq(expected[:types])
      end
    end
  end

  it "ignores the surplus bytes of an object record and reads its payload" do
    pen = Emf.parse(cases.fetch("object record with surplus bytes")[:bytes]).records.first
    expect([pen.pen_style, pen.width_x, pen.width_y]).to eq([1, 2, 3])
  end

  it "zero-pads the face name of a short font record" do
    font = Emf.parse(cases.fetch("font shorter than its face name")[:bytes]).records.first
    expect(font.face_name).to start_with("Arial")
  end

  it "keeps a negative-length text record verbatim" do
    record = Emf.parse(cases.fetch("TextOut with a negative length")[:bytes]).records.first
    expect([record.class, record.raw_bytes.bytesize]).to eq([Emf::Model::Wmf::Records::UnknownRecord, 12])
  end

  it "ends the stream at an oversized EOF record and keeps the bytes after it as trailing data" do
    bytes = cases.fetch("EOF longer than three words")[:bytes] + "tail".b
    expect(Emf.parse(bytes).trailing).to eq("tail".b)
  end

  it "lists several recovered departures in input order" do
    bytes = stream([native_wmf_record(0x01F0, [5].pack("v")), eof_words(5)], objects: 1, placeable: true).tap do |file|
      file[20, 2] = [0xFFFF].pack("v")
    end
    checks = Emf.parse(bytes).errors.map { |error| error.evidence.check }
    expect(checks).to eq(%i[placeable_checksum_mismatch object_reference_invalid eof_length_invalid])
  end

  rejected.each do |name, (bytes, message)|
    it "still rejects #{name}" do
      expect { Emf.parse(bytes) }.to raise_error(Emf::ParseError, message)
    end
  end
end
