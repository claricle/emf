# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"

RSpec.describe "Backend selection" do
  describe "in a fresh process" do
    let(:script) do
      <<~SCRIPT
        require "json"
        require "emf"
        before = $LOADED_FEATURES.grep(%r{(?:fiddle|emf/native)})
        bytes = File.binread("spec/fixtures/simple/image1.emf")
        begin
          parsed = Emf.parse(bytes)
          result = { format: parsed.format, round_trip: Emf.serialize(parsed) == bytes, backend: Emf.backend }
        rescue StandardError => e
          result = { error: e.class.name, message: e.message }
        end
        result[:before] = before
        result[:after] = $LOADED_FEATURES.grep(%r{(?:fiddle|emf/native)})
        puts JSON.generate(result)
      SCRIPT
    end

    [nil, "auto", "ruby"].each do |override|
      context "with #{override.inspect}" do
        let(:result) do
          env = { "EMF_BACKEND" => override, "EMF_NATIVE_LIBRARY" => "" }
          stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, "-Ilib", "-e", script)
          expect(status.success?).to be(true), stderr
          JSON.parse(stdout)
        end

        it "keeps the Ruby backend usable without native assets" do
          expect(result).to include("format" => "emf_plus", "round_trip" => true, "backend" => "ruby", "before" => [])
          expect(result.fetch("after").grep(%r{fiddle|emf/native/loader})).to eq([])
          expect(result.fetch("after")).to eq([]) if override == "ruby"
        end
      end
    end

    context "with a native library" do
      let(:library) do
        ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
          extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
          File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
        end
      end

      before { skip "native library not built" unless File.file?(library) }

      %w[auto native].each do |override|
        it "reports native and preserves a real round trip with #{override}" do
          env = { "EMF_BACKEND" => override, "EMF_NATIVE_LIBRARY" => library }
          stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, "-Ilib", "-e", script)
          expect(status.success?).to be(true), stderr
          expect(JSON.parse(stdout)).to include("backend" => "native", "format" => "emf_plus", "round_trip" => true)
        end
      end
    end

    { "native" => ["Emf::Native::Unavailable", /native backend.*not installed/],
      "invalid" => ["ArgumentError", /EMF_BACKEND.*invalid/],
      "" => ["ArgumentError", /EMF_BACKEND/] }.each do |override, (error_class, message)|
      it "rejects #{override.inspect} clearly" do
        env = { "EMF_BACKEND" => override, "EMF_NATIVE_LIBRARY" => "" }
        stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, "-Ilib", "-e", script)
        expect(status.success?).to be(true), stderr
        result = JSON.parse(stdout)
        expect(result.fetch("error")).to eq(error_class)
        expect(result.fetch("message")).to match(message)
      end
    end
  end

  describe ".backend" do
    let(:override) { "auto" }
    let(:native) { double("native backend") }

    before do
      allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return(override)
    end

    context "when Ruby is forced" do
      let(:override) { "ruby" }

      it "reports Ruby without setting up native" do
        expect(Emf::Native).not_to receive(:backend)
        expect(Emf.backend).to eq(:ruby)
      end
    end

    %w[auto native].each do |setting|
      context "with #{setting}" do
        let(:override) { setting }

        it "reports an available native backend as a symbol" do
          allow(Emf::Native).to receive(:backend).and_return(native)
          expect(Emf.backend).to eq(:native)
        end
      end
    end

    it "reports Ruby when automatic native selection is unavailable" do
      allow(Emf::Native).to receive(:backend).and_raise(Emf::Native::Unavailable, "missing native")
      expect(Emf.backend).to eq(:ruby)
    end

    context "when native is forced but unavailable" do
      let(:override) { "native" }

      it "propagates unavailability" do
        error = Emf::Native::Unavailable.new("missing native")
        allow(Emf::Native).to receive(:backend).and_raise(error)
        expect { Emf.backend }.to(raise_error { |raised| expect(raised).to equal(error) })
      end
    end

    it "propagates unexpected native setup failures" do
      error = RuntimeError.new("binding defect")
      allow(Emf::Native).to receive(:backend).and_raise(error)
      expect { Emf.backend }.to(raise_error { |raised| expect(raised).to equal(error) })
    end

    context "with an invalid override" do
      let(:override) { "invalid" }

      it "retains the selection error" do
        expect { Emf.backend }.to raise_error(ArgumentError, /invalid EMF_BACKEND: "invalid"/)
      end
    end

    it "resolves the current setting on each call" do
      allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("ruby", "auto")
      allow(Emf::Native).to receive(:backend).and_return(native)
      expect(Emf.backend).to eq(:ruby)
      expect(Emf.backend).to eq(:native)
    end
  end

  describe "Ruby compatibility" do
    before do
      allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("ruby")
    end

    it "retains WMF routing and unsupported serialization errors" do
      bytes = [1, 9, 0x0300, 0, 0, 0, 3, 0].pack("v3VvVv2")
      expect(Emf.detect_format(bytes)).to eq(:wmf)
      expect(Emf::Wmf::Parser).to receive(:call).with(bytes).and_return(:wmf)
      expect(Emf.parse(bytes)).to eq(:wmf)
      metafile = double("WMF", format: :wmf)
      expect(Emf::Wmf::Serializer).to receive(:call).with(metafile).and_return("wmf".b)
      expect(Emf.serialize(metafile)).to eq("wmf".b)
      unknown = double("unsupported", format: :unknown)
      expect { Emf.serialize(unknown) }.to raise_error(Emf::SerializeError, "unknown format: :unknown")
    end

    it "keeps filesystem errors outside backend selection" do
      missing = File.join(__dir__, "missing-directory", "file.emf")
      expect { Emf.parse_file(missing) }.to raise_error(Errno::ENOENT)
      bytes = Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf")
      expect { Emf.serialize_file(Emf.parse(bytes), missing) }.to raise_error(Errno::ENOENT)
    end
  end

  describe "native execution" do
    let(:native) { double("native backend", parse: :parsed, serialize: :serialized) }
    let(:bytes) { "native input".b }
    let(:metafile) { double("metafile") }
    let(:override) { "auto" }

    before do
      allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return(override)
      allow(Emf::Native).to receive(:backend).and_return(native)
    end

    it "dispatches parse and serialize to a usable native backend" do
      expect(Emf::Emr::Parser).not_to receive(:call)
      expect(Emf::Emr::Serializer).not_to receive(:call)
      expect(native).to receive(:parse).with(bytes).and_return(:parsed)
      expect(native).to receive(:serialize).with(metafile).and_return(:serialized)
      expect(Emf.parse(bytes)).to eq(:parsed)
      expect(Emf.serialize(metafile)).to eq(:serialized)
    end

    context "when native is forced" do
      let(:override) { "native" }

      it "uses the native backend for parsing and serialization" do
        expect(native).to receive(:parse).with(bytes).and_return(:parsed)
        expect(native).to receive(:serialize).with(metafile).and_return(:serialized)
        expect(Emf.parse(bytes)).to eq(:parsed)
        expect(Emf.serialize(metafile)).to eq(:serialized)
      end
    end

    [Emf::FormatError, Emf::SerializeError, Emf::Error].each do |error_class|
      it "propagates #{error_class} without retrying in Ruby" do
        error = error_class.new("native operation failed")
        allow(native).to receive(:parse).and_raise(error)
        allow(native).to receive(:serialize).and_raise(error)
        expect(Emf::Emr::Parser).not_to receive(:call)
        expect(Emf::Emr::Serializer).not_to receive(:call)
        expect { Emf.parse(bytes) }.to(raise_error { |raised| expect(raised).to equal(error) })
        expect { Emf.serialize(metafile) }.to(raise_error { |raised| expect(raised).to equal(error) })
      end
    end

    it "only falls back on an availability error during selection" do
      error = Emf::Native::Unavailable.new("native operation failed")
      allow(native).to receive(:parse).and_raise(error)
      expect(Emf::Emr::Parser).not_to receive(:call)
      expect { Emf.parse(bytes) }.to(raise_error { |raised| expect(raised).to equal(error) })
    end

    it "does not treat an unexpected setup defect as unavailability" do
      error = RuntimeError.new("binding defect")
      allow(Emf::Native).to receive(:backend).and_raise(error)
      expect(Emf::Emr::Parser).not_to receive(:call)
      expect { Emf.parse(bytes) }.to(raise_error { |raised| expect(raised).to equal(error) })
    end
  end
end
