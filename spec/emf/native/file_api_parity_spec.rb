# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require "tmpdir"

RSpec.describe "File API backend parity" do
  include_context "with native library"

  let(:following) { [17, 12, 7].pack("V3") }
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:bytes) do
    header = Emf::Emr::Binary::Header.new(
      i_type: 1, n_size: 88, d_signature: 0x464D4520, n_version: 0x10000,
      n_bytes: 88 + following.bytesize + eof.bytesize, n_records: 3
    ).to_binary_s
    header + following + eof
  end
  let(:backends) { %w[ruby native] }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  it "keeps file reads, writes, and filesystem errors consistent across backends" do
    Dir.mktmpdir("emf-file-api") do |directory|
      input_path = File.join(directory, "input.emf")
      output_path = File.join(directory, "output.emf")
      missing_path = File.join(directory, "missing", "file.emf")
      File.binwrite(input_path, bytes)

      backends.each do |backend|
        ENV["EMF_BACKEND"] = backend
        parsed = Emf.parse(bytes)
        parsed_from_file = Emf.parse_file(input_path)
        expect(parsed_from_file.format).to eq(parsed.format)
        expect(parsed_from_file.errors).to eq(parsed.errors)
        expect(Emf.serialize(parsed_from_file)).to eq(Emf.serialize(parsed))
        expect(Emf.serialize(parsed_from_file)).to eq(bytes)

        expect(Emf.serialize_file(parsed, output_path)).to eq(bytes.bytesize)
        expect(File.binread(output_path)).to eq(bytes)

        expect { Emf.parse_file(missing_path) }.to raise_error(Errno::ENOENT)
        expect { Emf.serialize_file(parsed, missing_path) }.to raise_error(Errno::ENOENT)

        preserved = "existing output\x00\xFF".b
        File.binwrite(output_path, preserved)
        unsupported = double("unsupported metafile", format: :unsupported)
        expect { Emf.serialize_file(unsupported, output_path) }
          .to raise_error(Emf::SerializeError)
        expect(File.binread(output_path)).to eq(preserved)
      end
    end
  end
end
