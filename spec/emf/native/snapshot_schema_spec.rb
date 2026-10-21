# frozen_string_literal: true

require "spec_helper"
require "emf/native"
require "emf/native/loader"
require "emf/native/snapshot"
require_relative "../../support/native_library_context"

RSpec.describe Emf::Native::Snapshot do
  include_context "with native library"

  let(:loader) { Emf::Native::Loader.new(library) }
  let(:root) { File.expand_path("../../..", __dir__) }

  def snapshots(bytes)
    loader.document(bytes) do |document|
      %i[emf_document_snapshot emf_document_snapshot_v3].map { |name| loader.send(:buffer, name, document) }
    end
  end

  def view(snapshot)
    [snapshot.header, snapshot.raw_header, snapshot.records, snapshot.diagnostics, snapshot.trailing, snapshot.unframed]
  end

  %w[emf/test-000.emf emf/test-031.emf emf/test-178.emf emf-ea/EA-test-file-012.emf].each do |path|
    it "decodes the schema 2 and schema 3 snapshots of #{File.basename(path)} to the same records" do
      v2, v3 = snapshots(File.binread(File.join(root, "spec/fixtures", path)))

      expect([v2.byteslice(4, 4).unpack1("V"), v3.byteslice(4, 4).unpack1("V")]).to eq([2, 3])
      expect(view(described_class.new(v3))).to eq(view(described_class.new(v2)))
    end
  end

  it "rejects a schema 3 snapshot whose payloads run past the buffer" do
    _v2, v3 = snapshots(File.binread(File.join(root, "spec/fixtures/emf/test-000.emf")))
    header_length, count = v3.unpack("Q<2", offset: 16)
    cut = v3.byteslice(0, 56 + 112 + header_length + (count * 40) + 10)
    cut[8, 8] = [cut.bytesize].pack("Q<")

    expect { described_class.new(cut) }.to raise_error(Emf::FormatError, "truncated native snapshot")
  end

  it "parses with the schema 3 snapshot when the library has it" do
    expect(loader.instance_variable_get(:@snapshot_function)).to eq(:emf_document_snapshot_v3)
  end
end
