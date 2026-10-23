# frozen_string_literal: true

require "spec_helper"
require "emf/native/loader"
require_relative "../support/resource_contract"
require_relative "../support/native_library_context"

RSpec.describe Emf::ResourceLimitError do
  include Emf::SpecSupport::ResourceContract

  let(:bytes) { Emf::SpecSupport::FixturePath.read_fixture("wmf", "standard-line.wmf") }

  it "exposes stable structured values without borrowing parse error semantics" do
    error = described_class.new(resource: :record_count, limit: 4, actual: 5)
    expect([error.resource, error.limit, error.actual]).to eq([:record_count, 4, 5])
    expect(error).to be_a(Emf::Error)
    expect(error).not_to be_a(Emf::FormatError)
    expect(error).not_to be_a(Emf::ParseError)
  end

  it "accepts the exact Ruby input limit and rejects the same fixture one byte below" do
    with_resource_backend("ruby") do
      stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", bytes.bytesize)
      expect(Emf.parse(bytes).format).to eq(:wmf)
      stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", bytes.bytesize - 1)
      expect { Emf.parse(bytes) }.to raise_error(described_class) { |error|
        expect([error.resource, error.limit, error.actual]).to eq([:input_bytes, bytes.bytesize - 1, bytes.bytesize])
      }
    end
  end

  { 1 => :input_bytes, 2 => :record_bytes, 3 => :record_count,
    4 => :allocated_bytes, 5 => :work_units, 6 => :output_bytes }.each do |code, resource|
    it "preserves native #{resource} metadata without reading the error message" do
      loader = resource_loader(3, code: code)
      expect(loader.instance_variable_get(:@functions).fetch(:emf_error_free)).to receive(:call).with(456)
      expect { loader.document("bad") { raise "must not yield" } }.to raise_error(described_class) { |error|
        expect([error.resource, error.limit, error.actual]).to eq([resource, 9, 10])
      }
    end
  end

  it "keeps unreadable native resource detail unclassified" do
    loader = resource_loader(3, view_status: 5)
    expect { loader.document("bad") { raise "must not yield" } }.to raise_error(Emf::Error) { |error|
      expect(error).not_to be_a(described_class)
      expect(error.message).to eq("native resource failure detail is unreadable")
    }
  end

  it "does not classify unrelated native errors by their text" do
    loader = resource_loader(2)
    expect { loader.document("bad") { raise "must not yield" } }.to raise_error(Emf::FormatError)
  end
end

RSpec.describe "Native resource limit ABI" do
  include_context "with native library"
  include Emf::SpecSupport::ResourceContract

  let(:loader) { Emf::Native::Loader.new(library) }
  let(:bytes) { minimal_resource_emf }
  let(:ceilings) { [200 * 1024 * 1024, 128 * 1024 * 1024, 4 * 1024 * 1024, 640 * 1024 * 1024, 64 * 1024 * 1024] }

  { input_bytes: [0, 87, 88], record_bytes: [1, 87, 88], record_count: [2, 0, 1],
    allocated_bytes: [3, 0, 88], work_units: [4, 0, 7] }.each do |resource, (index, limit, actual)|
    it "reports actual native #{resource} metadata at the boundary" do
      expect(native_resource_parse(loader, bytes, ceilings)).to be(true)
      ceilings[index] = limit
      expect { native_resource_parse(loader, bytes, ceilings) }.to raise_error(Emf::ResourceLimitError) { |error|
        expect([error.resource, error.limit, error.actual]).to eq([resource, limit, actual])
      }
    end
  end

  %w[native auto].each do |backend|
    it "selects the actual native adapter under #{backend}" do
      original = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
      ENV["EMF_NATIVE_LIBRARY"] = library
      expect(Emf::Emr::Parser).not_to receive(:call)
      with_resource_backend(backend) { expect(Emf.parse(bytes).format).to eq(:emf) }
    ensure
      original ? ENV["EMF_NATIVE_LIBRARY"] = original : ENV.delete("EMF_NATIVE_LIBRARY")
    end
  end
end
