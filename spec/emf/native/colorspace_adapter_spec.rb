# frozen_string_literal: true

require "spec_helper"
require "emf/native"
require "emf/native/loader"
require "emf/native/snapshot"
require "rbconfig"

RSpec.describe "native color-space hydration" do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:following) { [17, 12, 7].pack("V3") }
  let(:unknown) { [0xFFFF, 12].pack("V2") + "raw!".b }
  let(:siblings) { following + unknown + eof + "tail".b }
  let(:edited_handle) { [123].pack("V") }
  let(:unsigned_handle) { [0x80000000].pack("V") }
  let(:body) { [0xFFFFFFFF].pack("V") + "opaque\x00\x80\xFF".b }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before { skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library) }

  [99, 100, 101, 122].each do |type|
    context "with type #{type}" do
      let(:klass) { Emf::Emr::Binary::Records.lookup(type) }
      let(:record) { [type, 8 + body.bytesize].pack("V2") + body }
      let(:input) { header + record + siblings }

      it "hydrates the existing opaque wire API and preserves bytes through exposure and edits" do
        expect(Emf::Emr::Parser).not_to receive(:call)
        expect(klass).not_to receive(:read)
        parsed = Emf.parse(input)
        expect(parsed.errors).to be_empty
        expect(Emf.serialize(parsed)).to eq(input)
        wire = parsed.records.first.wire
        expect(wire).to be_a(klass)
        expect(wire.snapshot).to eq(i_type: type, n_size: record.bytesize, body: body)
        expect(Emf.serialize(parsed)).to eq(input)

        edited = body.dup
        edited[0, 4] = edited_handle
        wire.body = edited
        expected_record = [type, record.bytesize].pack("V2") + edited
        expect(Emf.serialize(parsed)).to eq(header + expected_record + siblings)
        expect(parsed.records.drop(1).map(&:to_binary_s).join + parsed.trailing).to eq(siblings)
        reparsed = Emf.parse(Emf.serialize(parsed))
        expect(reparsed.records.first.wire.body.to_s).to eq(edited)
        expect(Emf.serialize(reparsed)).to eq(header + expected_record + siblings)
      end

      it "matches Ruby for empty and arbitrary bodies, including size-changing edits" do
        ["".b, unsigned_handle, body].each do |original|
          bytes = header + [type, original.bytesize + 8].pack("V2") + original + siblings
          ENV["EMF_BACKEND"] = "ruby"
          ruby = Emf.parse(bytes)
          ENV["EMF_BACKEND"] = "native"
          native = Emf.parse(bytes)
          expect(native.errors).to be_empty
          expect(native.records).to eq(ruby.records)
          expect(native.records.first.wire.snapshot).to eq(ruby.records.first.wire.snapshot)
          expect(Emf.serialize(native)).to eq(bytes)

          [body + "more".b, "".b].each do |edited|
            [ruby, native].each do |metafile|
              wire = metafile.records.first.wire
              wire.body = edited
              wire.n_size = edited.bytesize + 8
            end
            expected = header + [type, edited.bytesize + 8].pack("V2") + edited + siblings
            expect(Emf.serialize(native)).to eq(expected)
            expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
            expect(Emf.parse(expected).records.first.wire.body.to_s).to eq(edited)
          end
        end
      end

      it "uses the existing raw snapshot transport without adding typed payload fields" do
        loader = Emf::Native::Loader.new(library)
        snapshot = loader.document(input) { |document| Emf::Native::Snapshot.new(loader.snapshot(document)) }
        expect(snapshot.records.first).to include(type: type, family: 0, payload: "".b, offset: header.bytesize, length: record.bytesize)
      end
    end
  end
end
