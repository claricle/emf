# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_consumer_parity"

RSpec.describe "Forced-backend public consumer parity" do
  before do
    expect(File.file?(NativeConsumerParity.library)).to be(true), "set EMF_TEST_NATIVE_LIBRARY to a usable native library"
  end

  shared_examples "proven backend dispatch" do
    it "uses the requested parsers without native fallback" do
      expect(ruby_result.fetch("evidence")).to include("backend" => "Emf::Backend::Ruby", "native_calls" => 0, "ruby_calls" => 1)
      expect(native_result.fetch("evidence")).to include("backend" => "Emf::Native::Adapter", "native_calls" => 1, "ruby_calls" => 0)
    end
  end

  NativeConsumerParity::FIXTURES.each do |fixture|
    context "with #{fixture}" do
      let(:path) { NativeConsumerParity.fixture(fixture) }

      NativeConsumerParity::COMMANDS.each do |command|
        context "CLI #{command}" do
          let(:ruby_result) { NativeConsumerParity.run("ruby", "cli", command, path) }
          let(:native_result) { NativeConsumerParity.run("native", "cli", command, path) }

          include_examples "proven backend dispatch"

          it "preserves successful output and exit status" do
            expect(ruby_result.fetch("exit")).to eq(0)
            expect(ruby_result.fetch("output")).not_to be_empty
            expect(native_result.slice("exit", "output")).to eq(ruby_result.slice("exit", "output"))
            expect(ruby_result.fetch("output")).to include("byte-identical") if command == "round-trip"
          end

          if command == "info" && fixture.start_with?("wmf/")
            it "prints standard WMF fields and optional placeable bounds" do
              NativeConsumerParity::BACKENDS.each do |backend|
                output = NativeConsumerParity.run(backend, "cli", command, path).fetch("output")
                expect(output).to include("Type:      2  Version: 768  Size: 27 words",
                                          "Objects:   0  MaxRecord: 5 words  Members: 7")
                if fixture == "wmf/placeable-line.wmf"
                  expect(output).to include("Bounds:    left=-100 top=-200 right=300 bottom=400", "Units:     1440 per inch")
                else
                  expect(output).not_to include("Bounds:", "Units:")
                end
                expect(output).not_to include("Frame:", "Device:", "nRecords:")
              end
            end
          end
        end
      end

      context "direct Stats and Dump visitors" do
        let(:ruby_result) { NativeConsumerParity.run("ruby", "visitors", path) }
        let(:native_result) { NativeConsumerParity.run("native", "visitors", path) }

        include_examples "proven backend dispatch"

        it "retains complete histograms and record dumps" do
          expect(ruby_result.fetch("exit")).to eq(0)
          expect(native_result.slice("exit", "output")).to eq(ruby_result.slice("exit", "output"))
          observed = JSON.parse(ruby_result.fetch("output"))
          expect(observed.fetch("records")).to be > 1
          expect(observed.fetch("total")).to eq(observed.fetch("records"))
          expect(observed.fetch("histogram").values.sum).to eq(observed.fetch("records"))
          expect(observed.fetch("lines").size).to eq(observed.fetch("records") + 2)
          expect(observed.fetch("errors")).to eq([])
        end
      end

      it "writes byte-identical round-trip files through both CLI backends" do
        Dir.mktmpdir("emf-consumer-output-") do |directory|
          output = File.join(directory, "round-trip.bin")
          results = NativeConsumerParity::BACKENDS.map do |backend|
            result = NativeConsumerParity.run(backend, "cli", "round-trip", path, output)
            expect(result.fetch("exit")).to eq(0), result.inspect
            expect(File.binread(output)).to eq(File.binread(path))
            File.unlink(output)
            result
          end
          expect(results.last.fetch("output")).to eq(results.first.fetch("output"))
          expect(results.last.fetch("evidence")).to include("native_calls" => 1, "ruby_calls" => 0)
        end
      end
    end
  end

  it "preserves deterministic corrupt-input errors and nonzero CLI exit status" do
    Dir.mktmpdir("emf-consumer-corrupt-") do |directory|
      path = File.join(directory, "truncated.emf")
      File.binwrite(path, "\x01\x00".b)
      results = NativeConsumerParity::BACKENDS.map { |backend| NativeConsumerParity.run(backend, "cli", "validate", path) }
      results.each do |result|
        expect(result.fetch("exit")).to eq(1)
        expect(result.fetch("evidence").fetch("error")).to eq(["Emf::FormatError", "input too short (2 bytes)"])
        expect(result.fetch("output")).to include("input too short (2 bytes)")
      end
      expect(results.last.fetch("evidence")).to include("native_calls" => 1, "ruby_calls" => 0)
    end
  end
end
