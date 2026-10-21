# frozen_string_literal: true

require "spec_helper"
require_relative "../../script/platform_probe/installed_workload"

RSpec.describe InstalledWorkload do
  let(:fixture) { Emf::SpecSupport::FixturePath.fixture("emf", "test-000.emf") }

  around do |example|
    previous = ENV.to_h.slice("GEM_HOME", "EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "ruby"
    example.run
  ensure
    %w[GEM_HOME EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  it "preserves the EMF markers and completes both self-contained WMF workloads before ok" do
    expect { described_class.run(fixture) }.to output(
      a_string_matching(/parsed: format=emf(?:_plus)? records=\d+\ndump: roundtrip_identical=true\n/)
        .and(include("mutate: SetTextColor color.red "))
        .and(include("parsed: format=wmf kind=standard records=2\n", "parsed: format=wmf kind=placeable records=2\n"))
        .and(include("dump: wmf standard roundtrip_identical=true\n", "dump: wmf placeable roundtrip_identical=true\n"))
        .and(include("mutate: wmf standard MoveTo x 7 -> -123, reparse+reserialize identical\n"))
        .and(include("mutate: wmf placeable MoveTo x 7 -> -123, reparse+reserialize identical\nok\n"))
    ).to_stdout
  end

  [false, true].each do |placeable|
    context "with #{placeable ? 'placeable' : 'standard'} WMF" do
      let(:bytes) { described_class.wmf_bytes(placeable: placeable) }
      let(:label) { "wmf #{placeable ? 'placeable' : 'standard'}" }

      it "provides valid tiny bytes with an editable typed field through the public API" do
        parsed = Emf.parse(bytes)
        expect(parsed.format).to eq(:wmf)
        expect(parsed.header.placeable.nil?).to eq(!placeable)
        expect(parsed.records.map(&:class)).to eq([Emf::Model::Wmf::Records::MoveTo, Emf::Model::Wmf::Records::Eof])
        expect([parsed.records.first.x, parsed.records.first.y]).to eq([7, -3])
        expect(Emf.serialize(parsed)).to eq(bytes)
        parsed.records.first.x = -123
        edited = Emf.serialize(parsed)
        reparsed = Emf.parse(edited)
        expect([reparsed.records.first.x, reparsed.records.first.y]).to eq([-123, -3])
        expect(edited).not_to eq(bytes)
        expect(Emf.serialize(reparsed)).to eq(edited)
      end

      it "fails with the format and kind when serialization loses the edit" do
        allow(Emf).to receive(:serialize).and_return(bytes)
        expect do
          expect { described_class.check_wmf(bytes, placeable: placeable) }.to raise_error(SystemExit)
        end.to output("#{label}: mutation not observed or not stable\n").to_stderr
      end

      it "rejects a stable byte change that does not preserve the requested field edit" do
        parsed = Emf.parse(bytes)
        allow(parsed.records.first).to receive(:x=) { parsed.records.first.y = -4 }
        allow(Emf).to receive(:parse).and_call_original
        allow(Emf).to receive(:parse).with(bytes).and_return(parsed)

        expect do
          expect { described_class.check_wmf(bytes, placeable: placeable) }.to raise_error(SystemExit)
        end.to output("#{label}: mutation not observed or not stable\n").to_stderr
      end

      it "identifies the format and kind when parsing fails" do
        expect do
          expect { described_class.check_wmf("".b, placeable: placeable) }.to raise_error(SystemExit)
        end.to output(a_string_starting_with("#{label}: Emf::")).to_stderr
      end
    end
  end

  context "with a retained native library" do
    before do
      library = ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil)
      skip "set EMF_TEST_NATIVE_LIBRARY to exercise the native workload" if library.nil? || library.empty?
      ENV["EMF_BACKEND"] = "native"
      ENV["EMF_NATIVE_LIBRARY"] = library
      Emf::Backend.send(:selected)
    end

    it "runs EMF and both WMF forms without falling back to the Ruby WMF parser" do
      expect(Emf::Wmf::Parser).not_to receive(:call)
      expect { described_class.run(fixture) }.to output(
        a_string_matching(/parsed: format=emf(?:_plus)? records=\d+\n/)
          .and(include("mutate: wmf standard MoveTo x 7 -> -123, reparse+reserialize identical\n"))
          .and(include("mutate: wmf placeable MoveTo x 7 -> -123, reparse+reserialize identical\nok\n"))
      ).to_stdout
    end
  end

  context "with installed-library discovery" do
    let(:gem_dir) { "/installed/gems/emf-0.0.0" }
    let(:manifest_path) { "#{gem_dir}/lib/emf/native/platforms.json" }
    let(:library_path) { "#{gem_dir}/lib/emf/native/test/libemf_ffi.so" }
    let(:specification) { instance_double(Gem::Specification, gem_dir: gem_dir, full_name: "emf-0.0.0") }
    let(:adapter) { Emf::Native::Adapter.allocate }

    before do
      ENV["GEM_HOME"] = "/installed/gems"
      ENV["EMF_NATIVE_LIBRARY"] = "/override/must-not-be-used.so"
      allow(Gem::Specification).to receive(:find_by_name).with("emf").and_return(specification)
      allow(File).to receive(:read).with(manifest_path).and_return('{"platform":"test","library":"libemf_ffi.so"}')
      allow(File).to receive(:file?).with(library_path).and_return(true)
    end

    it "clears the override and forces native before invoking installed discovery" do
      expect(Emf::Native).to receive(:backend) do
        expect(ENV.fetch("EMF_NATIVE_LIBRARY", nil)).to be_nil
        expect(ENV.fetch("EMF_BACKEND")).to eq("native")
        adapter
      end
      allow(Emf::Backend).to receive(:selected).and_return(adapter)
      expect { described_class.discover! }.to output(a_string_including("discovery_without_env=works\n")).to_stdout
    end

    it "keeps a native discovery failure visible and stops" do
      allow(Emf::Native).to receive(:backend).and_raise(Emf::Native::Unavailable, "loader failure")
      allow($stdout).to receive(:puts)
      expect($stdout).to receive(:puts).with("discovery without EMF_NATIVE_LIBRARY: loader failure")
      expect($stdout).to receive(:puts).with("discovery_without_env=unavailable")
      expect do
        expect { described_class.discover! }.to raise_error(SystemExit)
      end.to output("gem-relative library discovery is required\n").to_stderr
      expect(ENV.fetch("EMF_NATIVE_LIBRARY", nil)).to be_nil
      expect(ENV.fetch("EMF_BACKEND")).to eq("native")
    end

    it "rejects fallback after installed discovery succeeds" do
      allow(Emf::Native).to receive(:backend).and_return(adapter)
      allow(Emf::Backend).to receive(:selected).and_return(Object.new)
      allow($stdout).to receive(:puts)
      expect do
        expect { described_class.discover! }.to raise_error(SystemExit)
      end.to output("native backend NOT selected\n").to_stderr
    end

    it "rejects a similarly prefixed directory outside GEM_HOME" do
      ENV["GEM_HOME"] = "/installed/gem"
      expect do
        expect { described_class.discover! }.to raise_error(SystemExit)
      end.to output("emf resolved outside GEM_HOME: #{gem_dir}\n").to_stderr
    end
  end
end
