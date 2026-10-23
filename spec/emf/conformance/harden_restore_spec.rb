# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

# A Restore naming a StackIndex no EmfPlusSave ever assigned is a tolerant warning (LibreOffice's TestEmfPlusSave.emf
# has one). A restore of a state that was saved and already popped, or skipped over, stays an error in both profiles.
RSpec.describe "EMF+ Restore of a never-saved state" do
  plus = Emf::SpecSupport::EmfPlusBuilder
  unknown = "emfplus.state.restore_unknown_state"
  stale = "emfplus.state.restore_unmatched"
  corpus_file = "/private/tmp/emf-harden-extcorpus/files/lo2-emfio_qa_cppunit_emf_data_TestEmfPlusSave.emf"

  def save(index) = Emf::SpecSupport::EmfPlusBuilder.record(0x4025, body: [index].pack("V"))

  def restore(index) = Emf::SpecSupport::EmfPlusBuilder.record(0x4026, body: [index].pack("V"))

  def severities(bytes, id, profile)
    Emf::Conformance.check(bytes, profile: profile).diagnostics.select { |d| d.requirement_id == id }.map(&:severity)
  end

  it "is a strict error and a tolerant warning, reported once, for a restore before any save" do
    stream = plus.stream(restore(0), save(0), restore(0))
    expect(severities(stream, unknown, :strict)).to eq([:error])
    expect(severities(stream, unknown, :tolerant)).to eq([:warning])
    expect(severities(stream, stale, :strict)).to be_empty
    expect(severities(stream, stale, :tolerant)).to be_empty
  end

  it "keeps a restore of an already-popped state an error in both profiles" do
    stream = plus.stream(save(0), restore(0), restore(0))
    expect(severities(stream, stale, :tolerant)).to eq([:error])
    expect(severities(stream, unknown, :tolerant)).to be_empty
  end

  it "keeps a restore skipped over by an earlier pop an error in both profiles" do
    stream = plus.stream(save(0), save(1), restore(0), restore(1))
    expect(severities(stream, stale, :strict)).to eq([:error])
    expect(severities(stream, stale, :tolerant)).to eq([:error])
  end

  it "keeps an unmatched EndContainer an error in the tolerant profile" do
    stream = plus.stream(plus.record(0x4029, body: [7].pack("V")))
    expect(severities(stream, "emfplus.state.end_container_unmatched", :tolerant)).to eq([:error])
  end

  it "makes LibreOffice's TestEmfPlusSave.emf tolerant-valid", skip: (File.exist?(corpus_file) ? false : "corpus file missing") do
    bytes = File.binread(corpus_file)
    expect(Emf::Conformance.check(bytes, profile: :tolerant).diagnostics.select { |d| d.severity == :error }).to be_empty
    expect(severities(bytes, unknown, :tolerant)).to eq([:warning])
    expect(severities(bytes, unknown, :strict)).to eq([:error])
  end
end
