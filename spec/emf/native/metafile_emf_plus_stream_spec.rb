# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/emf_plus_native_snapshot"
require_relative "../../support/emf_plus_native_stream_support"

RSpec.describe "Metafile#emf_plus_stream backend selection" do
  include_context "with native library"

  let(:parity) { Emf::SpecSupport::EmfPlusSegmentParity }
  let(:support) { Emf::SpecSupport::EmfPlusNativeStreamSupport }
  let(:bytes) { File.binread(support.fixture_paths.find { |path| support.try_parse(File.binread(path))&.format == :emf_plus }) }
  let(:ruby_file) { parity.parse(bytes, "ruby", library) }
  let(:native_file) { parity.parse(bytes, "native", library) }

  it "returns the native stream, equal to Ruby's, for a native-backed metafile" do
    expect(native_file.emf_plus_stream).to be_a(Emf::Native::EmfPlusStream)
    expect(support.view(native_file.emf_plus_stream)).to eq(support.view(ruby_file.emf_plus_stream))
  end

  it "keeps the Ruby stream for a Ruby-backed metafile" do
    expect(ruby_file.emf_plus_stream.class).to eq(Emf::EmfPlus::Stream)
  end

  it "memoises and rebuilds with reload: true" do
    stream = native_file.emf_plus_stream
    expect(native_file.emf_plus_stream).to equal(stream)
    reloaded = native_file.emf_plus_stream(reload: true)
    expect(reloaded).not_to equal(stream)
    expect(reloaded).to be_a(Emf::Native::EmfPlusStream)
    expect(support.view(reloaded)).to eq(support.view(stream))
  end

  it "returns nil for a non-EMF+ native metafile" do
    plain = support.fixture_paths.map { |path| support.try_parse(File.binread(path)) }.find { |m| m&.format == :emf }
    expect(parity.parse(Emf.serialize(plain), "native", library).emf_plus_stream).to be_nil
  end
end
