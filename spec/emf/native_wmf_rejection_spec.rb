# frozen_string_literal: true

require "spec_helper"
require "emf/native/loader"
require "emf/native/wmf_rejection"
require "emf/native/wmf_hydrator"
require_relative "../support/wmf_mutation"
require_relative "../support/wmf_rejection_cases"

RSpec.describe "Native WMF rejection detail" do
  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil) }
  let(:loader) { Emf::Native::Loader.new(library) }
  let(:cases) { WmfRejectionCases.cases }

  before { skip "set EMF_TEST_NATIVE_LIBRARY for native WMF rejection detail" if library.to_s.empty? }

  def reason_of(bytes)
    Emf::Native::WmfRejection.read(loader.wmf_rejection(bytes, Emf::Wmf::Binary::MAX_INPUT_BYTES, Emf::Wmf::Binary::MAX_RECORDS))&.reason
  end

  it "covers every reason the table maps, except the two that need a huge input" do
    mapped = Emf::Native::WmfRejection::INPUT.keys + Emf::Native::WmfRejection::RECORD.keys
    expect(cases.keys).to match_array(mapped - [101, 401])
  end

  WmfRejectionCases.cases.each do |reason, bytes|
    it "reports reason #{reason} and raises the contract's own error through the native backend" do
      expect(reason_of(bytes)).to eq(reason)
      ruby = WmfMutation.observe(bytes, "ruby", library)
      expect(%i[parse_error error]).to include(ruby.first)
      expect(WmfMutation.observe(bytes, "native", library)).to eq(ruby)
    end
  end

  it "reports no rejection for input the contract accepts" do
    expect(reason_of(WmfRejectionCases.wmf([WmfRejectionCases.rec(0x14, [1, 2].pack("s<2")), WmfRejectionCases.eof]))).to be_nil
  end

  it "keeps a native rejection when the contract accepts the input" do
    accepted = WmfRejectionCases.wmf([WmfRejectionCases.eof])
    allow(Emf::Native::WmfRejection).to receive(:read).and_return(nil)
    hydrator = Emf::Native::WmfHydrator
    allow(hydrator).to receive(:new).and_raise(Emf::FormatError, "native-only failure")
    expect { hydrator.parse(loader, accepted) }.to raise_error(Emf::FormatError, "native-only failure")
  end

  it "refuses a malformed WMFR answer" do
    expect { Emf::Native::WmfRejection.read("WMFX".b + ("\0".b * 44)) }.to raise_error(Emf::FormatError, /rejection/)
    expect { Emf::Native::WmfRejection.read("WMFR".b) }.to raise_error(Emf::FormatError, /rejection/)
  end
end
