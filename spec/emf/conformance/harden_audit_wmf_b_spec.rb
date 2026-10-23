# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Emf::Conformance WMF buffer/object hardening" do
  let(:records) { Emf::Model::Wmf::Records }

  def header
    Emf::Model::Wmf::Header.new(type: 1, version: 0x300, size_words: 12, number_of_objects: 16, max_record_words: 3,
                                number_of_members: 0, placeable: nil)
  end

  def model(*list)
    Emf::Model::Metafile.new(format: :wmf, header: header, records: list + [records::Eof.new(offset: 200)])
  end

  def found(metafile, profile)
    Emf::Conformance.check(metafile, profile: profile).diagnostics.map { |d| [d.requirement_id, d.severity] }
  end

  # Micrografx Flowcharter (emfio TestRoundRect.wmf) writes a free-text comment under Escape 0x000F, not a WMFC segment.
  let(:foreign_comment) do
    data = "Exported by ABC Flowcharter 3.0 - Micrografx, Inc".b
    data += "\x00".b if data.bytesize.odd?
    records::Escape.new(escape_function: 0x000F, data: data, padding: nil, offset: 18, type_id: 0x0626)
  end

  it "keeps a foreign Escape 0x000F payload an error in strict" do
    expect(found(model(foreign_comment), :strict)).to eq([["wmf.escape.embedded_emf.segment", :error]])
  end

  it "accepts a foreign Escape 0x000F payload in tolerant as a warning" do
    expect(found(model(foreign_comment), :tolerant)).to eq([["wmf.escape.embedded_emf.segment", :warning]])
  end

  it "still reports a checksum mismatch as a warning only in tolerant (preservation)" do
    expect(Emf::Conformance::Registry.default["wmf.escape.embedded_emf.checksum"].tolerant_reason).not_to be_nil
  end
end
