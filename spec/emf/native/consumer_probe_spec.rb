# frozen_string_literal: true

require "spec_helper"
require "open3"
require_relative "../../support/native_consumer_parity"

RSpec.describe "Native consumer dispatch probe" do
  it "forwards Ruby parser admission keywords while recording the actual dispatch" do
    Dir.mktmpdir("emf-consumer-probe-") do |directory|
      report = File.join(directory, "report.json")
      output, errors, status = Open3.capture3(
        { "EMF_BACKEND" => "ruby", "EMF_NATIVE_LIBRARY" => "" },
        RbConfig.ruby, "-Ilib", "-e", NativeConsumerParity::CHILD, report, "visitors",
        NativeConsumerParity.fixture("emf/test-007.emf")
      )

      expect(status.success?).to be(true), errors
      evidence = JSON.parse(File.read(report))
      expect(evidence).to include(
        "backend" => "Emf::Backend::Ruby", "ruby_calls" => 1, "native_calls" => 0
      )
      expect(evidence).not_to have_key("error")
      observed = JSON.parse(output)
      expect(observed.fetch("records")).to be > 1
      expect(observed.fetch("total")).to eq(observed.fetch("records"))
      expect(observed.fetch("errors")).to be_empty
    end
  end
end
