# frozen_string_literal: true

require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF resource limits" do
  include_context "native WMF bridge"

  let(:bytes) { File.binread(File.expand_path("../fixtures/wmf/standard-line.wmf", __dir__)) }

  %w[ruby native auto].each do |backend|
    context "with #{backend} selected" do
      before do
        ENV["EMF_BACKEND"] = backend
        unless backend == "ruby"
          expect(Emf::Native).to receive(:backend).at_least(:once).and_call_original
          expect(Emf::Wmf::Parser).not_to receive(:call)
        end
      end

      it "accepts the exact byte limit and reports the same rejected input size" do
        stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", bytes.bytesize)
        expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)

        stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", bytes.bytesize - 1)
        expect { Emf.parse(bytes) }.to raise_error(Emf::ResourceLimitError) { |error|
          expect([error.resource, error.limit, error.actual]).to eq([:input_bytes, bytes.bytesize - 1, bytes.bytesize])
        }
      end

      it "counts EOF and reports the first refused record rather than the final total" do
        records = Emf.parse(bytes).records.length
        expect(records).to be > 2
        stub_const("Emf::Wmf::Binary::MAX_RECORDS", records)
        parsed = Emf.parse(bytes)
        expect(parsed.records.length).to eq(records)
        expect(parsed.records.last).to be_a(Emf::Model::Wmf::Records::Eof)
        expect(Emf.serialize(parsed)).to eq(bytes)

        stub_const("Emf::Wmf::Binary::MAX_RECORDS", records - 2)
        expect { Emf.parse(bytes) }.to raise_error(Emf::ResourceLimitError) { |error|
          expect([error.resource, error.limit, error.actual]).to eq([:record_count, records - 2, records - 1])
        }
      end

      it "does not count records after a recovered EOF against the record limit" do
        records = Emf.parse(bytes).records.length
        eof = "\x04\x00\x00\x00\x00\x00\x00\x00".b
        trailing = "\x03\x00\x00\x00\x00\x00".b * records
        recovered = bytes.byteslice(0, bytes.bytesize - 6) + eof + trailing
        stub_const("Emf::Wmf::Binary::MAX_RECORDS", records)

        parsed = Emf.parse(recovered)
        expect(parsed.records.length).to eq(records)
        expect(parsed.trailing).to eq(trailing)
        expect(parsed.errors.map { |error| error.evidence.check }).to include(:eof_length_invalid)
      end

      it "preserves unrelated malformed header failures" do
        malformed = bytes.dup
        malformed[4, 2] = "\x00\x00"
        expect { Emf.parse(malformed) }.to raise_error(Emf::FormatError, /Version/)
      end
    end
  end

  it "maps actual native input rejection independently of public admission checks" do
    require "emf/native/loader"
    require "emf/native/wmf_hydrator"
    loader = Emf::Native::Loader.new(library)
    stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", bytes.bytesize - 1)

    expect { Emf::Native::WmfHydrator.parse(loader, bytes) }.to raise_error(Emf::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq([:input_bytes, bytes.bytesize - 1, bytes.bytesize])
    }
  end

  it "reports the first refused record in the hydrator guard" do
    require "emf/native/wmf_hydrator"
    loader = Emf::Native::Loader.new(library)
    stub_const("Emf::Wmf::Binary::MAX_RECORDS", 1)

    expect { Emf::Native::WmfHydrator.parse(loader, bytes) }
      .to raise_error(Emf::ResourceLimitError) { |error|
        expect([error.resource, error.limit, error.actual]).to eq([:record_count, 1, 2])
      }
  end
end
