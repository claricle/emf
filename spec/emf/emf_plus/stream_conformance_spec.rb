# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe Emf::EmfPlus::Stream::Conformance do
  include Emf::SpecSupport::EmfPlusRecords

  let(:source) { Emf.parse(File.binread(File.join(__dir__, "../../fixtures/emf/test-000.emf"))) }

  def comment_wire(payload)
    data = "EMF+".b + payload
    Emf::Emr::Binary::Records::Comment.new(i_type: 70, n_size: 12 + data.bytesize + (-data.bytesize % 4),
                                           cb_data: data.bytesize, data: data + ("\0" * (-data.bytesize % 4)))
  end

  def metafile_with(*payloads)
    adapters = payloads.map { |payload| Emf::Model::Emr::Records::WireAdapter.new(wire: comment_wire(payload)) }
    Emf::Model::Metafile.new(format: :emf_plus, header: source.header, records: adapters + source.records.last(1),
                             emf_plus: payloads.join, trailing: source.trailing)
  end

  def conformance_errors(metafile) = metafile.emf_plus_stream.errors.grep(described_class::Diagnostic)

  {
    reserved_type: [0x4005, 0x4006, 0x4007],
    stroke_fill_path: [0x4037],
    unknown_type: [0x4000, 0x403B, 0x7FFF]
  }.each do |kind, types|
    types.each do |type|
      it "reports 0x#{type.to_s(16)} as #{kind}, keeping bytes, Metafile#errors and parsing intact" do
        payload = record(0x4002, "") + record(type, "abcd", flags: 0x0102)
        metafile = metafile_with(payload)

        expect(conformance_errors(metafile)).to match(
          [have_attributes(kind: kind, comment_index: 0, offset: 12, record_type: type, message: a_kind_of(String))]
        )
        expect(metafile.emf_plus_stream.records.last.record).to be_a(Emf::EmfPlus::Records::Unknown)
        expect(metafile.errors).to eq(source.errors)
        expect(Emf.parse(Emf.serialize(metafile)).emf_plus_stream.segments.first.payload).to eq(payload)
      end
    end
  end

  it "reports nothing for defined, registered record types" do
    expect(conformance_errors(metafile_with(record(0x4002, "") + record(0x4004, "")))).to be_empty
  end

  it "reports nothing on an EMF+ fixture" do
    expect(conformance_errors(source)).to be_empty
  end
end
