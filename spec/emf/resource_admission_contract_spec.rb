# frozen_string_literal: true

require "spec_helper"
require_relative "../support/resource_contract"
require_relative "../support/native_library_context"

RSpec.shared_examples "EMF resource admission" do |backend|
  include Emf::SpecSupport::ResourceContract

  around do |example|
    with_resource_backend(backend) { example.run }
  end

  before { stub_const("Emf::Emr::Parser::MAX_SANE_ARRAY_LENGTH", 8) }

  [2, 3, 4, 5, 6, 85, 86, 87, 88, 89, 56, 92, 7, 8, 90, 91, 50, 95, 71, 72, 73, 74, 75].each do |type|
    it "admits the exact array limit and rejects complete type #{type} arrays beyond it" do
      expect(Emf.parse(minimal_resource_emf + resource_array_record(type, 8)).format).to eq(:emf)
      expect { Emf.parse(minimal_resource_emf + resource_array_record(type, 9)) }
        .to raise_error(Emf::ResourceLimitError) { |error|
          expect([error.resource, error.limit, error.actual]).to eq([:array_elements, 8, 9])
        }
    end

    it "preserves malformed type #{type} recovery ahead of its claimed array count" do
      raw = resource_array_record(type, 9, truncate: true)
      record = Emf.parse(minimal_resource_emf + raw).records.last
      expect(record.to_binary_s).to eq(raw)
    end
  end

  [7, 8, 90, 91].each do |type|
    it "limits the point count independently of the polygon count for type #{type}" do
      raw = resource_array_record(type, 9, poly_count: 1)
      expect { Emf.parse(minimal_resource_emf + raw) }.to raise_error(Emf::ResourceLimitError) { |error|
        expect([error.resource, error.limit, error.actual]).to eq([:array_elements, 8, 9])
      }
    end
  end

  it "preserves malformed complete pen and region layouts ahead of their claimed counts" do
    pen = resource_array_record(95, 9)
    pen[12, 8] = [12, 4].pack("V2")
    region = resource_array_record(75, 9)
    region[16, 4] = [28].pack("V")
    [pen, region].each do |raw|
      expect(Emf.parse(minimal_resource_emf + raw).records.last.to_binary_s).to eq(raw)
    end
  end

  it "counts the header and complete records, including unknown records" do
    stub_const("Emf::ResourceLimits::EmfRecords::MAX_RECORDS", 2)
    expect(Emf.parse(minimal_resource_emf + resource_record(0xFFFF, 8)).format).to eq(:emf)
    expect { Emf.parse(minimal_resource_emf + (resource_record(0xFFFF, 8) * 2)) }
      .to raise_error(Emf::ResourceLimitError) { |error|
        expect([error.resource, error.limit, error.actual]).to eq([:record_count, 2, 3])
      }
  end

  it "does not count incomplete spans or bytes following a complete EOF" do
    stub_const("Emf::ResourceLimits::EmfRecords::MAX_RECORDS", 2)
    expect(Emf.parse(minimal_resource_emf + resource_record(0xFFFF, 8) + [2, 100].pack("V2")).format).to eq(:emf)
    eof = resource_record(14, 20)
    expect(Emf.parse(minimal_resource_emf + eof + resource_array_record(2, 9)).format).to eq(:emf)
  end

  it "enforces record bytes at the accepted boundary" do
    stub_const("Emf::ResourceLimits::EmfRecords::MAX_RECORD_BYTES", 88)
    expect(Emf.parse(minimal_resource_emf).format).to eq(:emf)
    expect { Emf.parse(minimal_resource_emf + resource_record(0xFFFF, 92)) }
      .to raise_error(Emf::ResourceLimitError) { |error|
        expect([error.resource, error.limit, error.actual]).to eq([:record_bytes, 88, 92])
      }
  end
end

RSpec.describe "Ruby EMF resource admission" do
  include_examples "EMF resource admission", "ruby"
end

RSpec.describe "Native EMF resource admission" do
  include_context "with native library"

  around do |example|
    original = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    original ? ENV["EMF_NATIVE_LIBRARY"] = original : ENV.delete("EMF_NATIVE_LIBRARY")
  end

  before { expect(Emf::Emr::Parser).not_to receive(:call) }

  context "with native selection" do
    include_examples "EMF resource admission", "native"
  end

  context "with auto selection" do
    include_examples "EMF resource admission", "auto"
  end
end
