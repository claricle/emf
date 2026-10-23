# frozen_string_literal: true

require "spec_helper"
require_relative "../support/diagnostic_contract"
require_relative "../support/native_library_context"

RSpec.describe "public parser diagnostics" do
  include DiagnosticContractSupport

  let(:bytes) { File.binread(Emf::SpecSupport::FixturePath.fixture("diagnostics", "recovery.emf")) }
  let(:header_size) { bytes.unpack1("V", offset: 4) }
  let(:expected) do
    [
      { record_index: 2, record_code: 3, record_type: "EMR_POLYGON", byte_offset: header_size + 12, disposition: :preserved_raw },
      { record_index: 3, record_code: 25, record_type: "EMR_SETBKCOLOR", byte_offset: header_size + 40, disposition: :preserved_raw },
      { record_index: 5, record_code: 0xBAADF00D, record_type: "UNKNOWN(0xBAADF00D)",
        byte_offset: header_size + 56, disposition: :skipped }
    ]
  end

  it "exposes complete ordered immutable values and preserves the input" do
    metafile = diagnostic_parse("ruby", bytes)

    expect(metafile.diagnostics.map(&:to_h)).to eq(expected)
    expect(metafile.diagnostics).to be_frozen
    expect(metafile.diagnostics).to all(be_a(Emf::Model::Diagnostic).and(be_frozen))
    expect(metafile.diagnostics.map(&:record_type)).to all(be_frozen)
    expect { metafile.diagnostics << metafile.diagnostics.first }.to raise_error(FrozenError)
    expect { metafile.diagnostics.first.instance_variable_set(:@disposition, :skipped) }.to raise_error(FrozenError)
    expect(metafile.errors.length).to eq(3)
    expect(metafile.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    expect(metafile.diagnostics.map(&:record_index)).not_to include(1)
    expect(Emf::Emr::Serializer.call(metafile)).to eq(bytes)
  end

  it "reports truncated records and short headers as explicitly skipped" do
    [[27, 20].pack("V2"), [27].pack("V"), "\x01".b].each do |trailing|
      metafile = diagnostic_parse("ruby", bytes.byteslice(0, header_size) + trailing)
      code = trailing.bytesize >= 4 ? 27 : 0
      name = code == 27 ? "EMR_MOVETOEX" : "UNKNOWN(0x00000000)"
      expect(metafile.diagnostics.map(&:to_h)).to eq([
                                                       { record_index: 1, record_code: code, record_type: name, byte_offset: header_size,
                                                         disposition: :skipped }
                                                     ])
    end
  end

  context "with installed native backend" do
    include_context "with native library"

    around do |example|
      previous = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
      ENV["EMF_NATIVE_LIBRARY"] = library
      example.run
    ensure
      ENV["EMF_NATIVE_LIBRARY"] = previous
    end

    it "matches complete Ruby diagnostics under actual native and native-selected auto" do
      results = %w[ruby native auto].map do |backend|
        metafile = diagnostic_parse(backend, bytes)
        expect(Emf::Emr::Serializer.call(metafile)).to eq(bytes)
        expect(metafile.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
        metafile.diagnostics.map(&:to_h)
      end
      expect(results).to eq([expected, expected, expected])
    end
  end
end
