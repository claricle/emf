# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_thread_acceptance"

RSpec.describe "Native independent-document thread acceptance" do
  # A child deadline contains native crashes/deadlocks; a configured library must load without fallback.
  let(:report) { NativeThreadAcceptance.run }

  before do
    skip "set EMF_TEST_NATIVE_LIBRARY to a built emf-ffi library" if ENV.fetch("EMF_TEST_NATIVE_LIBRARY", "").empty?
  end

  it "copies stable EMF and WMF results through synchronized independent document scopes" do
    expect(report.fetch("repetitions")).to eq(3)
    valid = report.fetch("valid")
    expect(valid.map { |worker| worker.fetch("path") }).to eq(NativeThreadAcceptance::FIXTURES)
    expect(valid.map { |worker| worker.fetch("baseline") }.uniq.size).to eq(3)
    valid.each do |worker|
      baseline = worker.fetch("baseline")
      expect(baseline.first).to match(/\A[0-9a-f]{64}\z/)
      expect(worker.fetch("observations")).to eq([baseline] * 3)
      expect(worker.fetch("gvl_released")).to be(true)
      if worker.fetch("path").end_with?(".emf")
        expect(baseline.last).to match(/\A[0-9a-f]{64}\z/)
        expect(worker.fetch("frees")).to eq("emf_document_free" => 4, "emf_buffer_free" => 8)
      else
        expect(baseline.last).to be_nil
        expect(worker.fetch("frees")).to eq("emf_wmf_document_free" => 4, "emf_buffer_free" => 4)
      end
    end
  end

  it "isolates malformed EMF and WMF calls while other documents remain open" do
    malformed = report.fetch("malformed")
    messages = malformed.fetch("messages")
    expect(messages.size).to eq(3)
    expect(messages.uniq.size).to eq(1)
    expect(messages.first.size).to eq(2)
    messages.first.each do |error|
      expect(error.first).to eq("Emf::FormatError")
      expect(error.last).not_to be_empty
    end
    expect(malformed.fetch("frees")).to eq("emf_error_free" => 6)
    expect(report.fetch("valid").map { |worker| worker.fetch("observations").size }).to eq([3, 3, 3])
  end
end
