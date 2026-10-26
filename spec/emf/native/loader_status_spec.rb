# frozen_string_literal: true

require "spec_helper"
require "emf/native/loader"

RSpec.describe Emf::Native::Loader do
  subject(:loader) { described_class.allocate }

  let(:parse) { instance_double(Fiddle::Function) }
  let(:document_free) { instance_double(Fiddle::Function) }
  let(:error_free) { instance_double(Fiddle::Function) }
  let(:functions) do
    { emf_parse: parse, emf_document_free: document_free,
      emf_error_free: error_free }
  end

  before do
    loader.instance_variable_set(:@functions, functions)
    allow(document_free).to receive(:call)
    allow(error_free).to receive(:call)
  end

  it "rejects an incompatible ABI before resolving its operation symbols" do
    library = double("library")
    version = instance_double(Fiddle::Function, call: 9)
    allow(Fiddle).to receive(:dlopen).with("wrong-abi").and_return(library)
    allow(library).to receive(:[]).with("emf_abi_version").and_return(123)
    allow(library).to receive(:[]).with("emf_parse").and_raise(Fiddle::DLError, "missing operation symbol")
    allow(Fiddle::Function).to receive(:new)
      .with(123, [], Fiddle::TYPE_INT).and_return(version)

    expect { described_class.new("wrong-abi") }
      .to raise_error(Emf::Native::Unavailable, "native backend ABI version mismatch (expected 1)")
    expect(library).not_to have_received(:[]).with("emf_parse")
  end

  # Numeric statuses are the public contract in emf-ffi/include/emf.h.
  { 1 => Emf::Error, 2 => Emf::FormatError,
    4 => Emf::SerializeError, 5 => Emf::Error, 6 => Emf::Error,
    99 => Emf::Error }.each do |status, error_class|
    it "maps ABI status #{status} to #{error_class}" do
      allow(parse).to receive(:call).and_return(status)

      expect { loader.document("bad") { raise "must not yield" } }
        .to(raise_error do |error|
          expect(error.class).to eq(error_class)
          expect(error.message).to eq("native operation failed (status #{status})")
        end)
      expect(document_free).not_to have_received(:call)
      expect(error_free).not_to have_received(:call)
    end
  end

  it "does not invent resource metadata for an absent native error" do
    functions[:emf_error_resource_view] = instance_double(Fiddle::Function)
    allow(parse).to receive(:call).and_return(3)

    expect { loader.document("bad") { raise "must not yield" } }
      .to raise_error(Emf::Error, "native resource failure has no error detail")
  end

  context "with an older ABI-1 library" do
    around do |example|
      previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
      example.run
    ensure
      %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
    end

    let(:legacy_functions) do
      { emf_abi_version: instance_double(Fiddle::Function, call: 1),
        emf_parse: parse, emf_document_free: document_free, emf_error_free: error_free,
        emf_error_view: instance_double(Fiddle::Function, call: 5),
        emf_document_snapshot: instance_double(Fiddle::Function),
        emf_record_bytes: instance_double(Fiddle::Function),
        emf_buffer_view: instance_double(Fiddle::Function),
        emf_buffer_free: instance_double(Fiddle::Function) }
    end

    before do
      library = double("ABI-1 library without optional extensions")
      allow(Fiddle).to receive(:dlopen).with("legacy-abi").and_return(library)
      allow(library).to receive(:[]).and_raise(Fiddle::DLError, "missing symbol")
      legacy_functions.each_with_index do |(name, function), address|
        allow(library).to receive(:[]).with(name.to_s).and_return(address)
        allow(Fiddle::Function).to receive(:new).with(address, anything, anything).and_return(function)
      end
    end

    %w[native auto].each do |backend|
      it "keeps #{backend} selected as native without the resource accessor" do
        ENV["EMF_BACKEND"] = backend
        ENV["EMF_NATIVE_LIBRARY"] = "legacy-abi"

        expect(Emf.backend).to eq(:native)
      end
    end

    it "parses successfully and releases the document without optional extensions" do
      allow(parse).to receive(:call) do |_bytes, _length, _limits, output, _error|
        output[0, 8] = [123].pack("J")
        0
      end

      expect { |block| described_class.new("legacy-abi").document("valid", &block) }.to yield_with_args(123)
      expect(document_free).to have_received(:call).with(123).once
    end

    it "preserves legacy limit failures and releases their error handles" do
      allow(parse).to receive(:call) do |_bytes, _length, _limits, _output, error|
        error[0, 8] = [456].pack("J")
        3
      end

      expect { described_class.new("legacy-abi").document("bad") { raise "must not yield" } }
        .to raise_error(Emf::FormatError, "native operation failed (status 3)")
      expect(error_free).to have_received(:call).with(456).once
    end
  end

  it "yields successful handles and frees them after the caller returns" do
    allow(parse).to receive(:call) do |_bytes, _length, _limits, output, _error|
      output[0, 8] = [123].pack("J")
      0
    end
    allow(document_free).to receive(:call)

    expect { |block| loader.document("valid", &block) }.to yield_with_args(123)
    expect(document_free).to have_received(:call).with(123).once
  end

  it "releases an error handle when reading its description fails" do
    error_view = instance_double(Fiddle::Function, call: 5)
    functions[:emf_error_view] = error_view
    allow(parse).to receive(:call) do |_bytes, _length, _limits, _output, error|
      error[0, 8] = [456].pack("J")
      6
    end
    allow(error_free).to receive(:call)

    expect { loader.document("bad") { raise "must not yield" } }
      .to raise_error(Emf::Error, "native operation failed (status 6)")
    expect(error_free).to have_received(:call).with(456).once
  end

  it "maps buffer-view failures and releases the returned buffer" do
    snapshot = instance_double(Fiddle::Function)
    buffer_view = instance_double(Fiddle::Function, call: 5)
    buffer_free = instance_double(Fiddle::Function, call: nil)
    functions.merge!(emf_document_snapshot: snapshot,
                     emf_buffer_view: buffer_view, emf_buffer_free: buffer_free)
    allow(snapshot).to receive(:call) do |_document, output, _error|
      output[0, 8] = [789].pack("J")
      0
    end
    loader.instance_variable_set(:@snapshot_function, :emf_document_snapshot)

    expect { loader.snapshot(123) }.to(raise_error do |error|
      expect(error.class).to eq(Emf::Error)
      expect(error.message).to eq("native buffer view failed (status 5)")
    end)
    expect(buffer_free).to have_received(:call).with(789).once
  end
end
