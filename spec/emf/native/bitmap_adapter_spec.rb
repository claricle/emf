# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "emf/native/bitmap_fields"
require_relative "../../support/bitmap_records"

RSpec.describe "native bitmap hydration" do
  include BitmapRecords

  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:unknown) { "#{[0xFFFF, 12].pack('V2')}RAW!" }
  let(:bad_offset) { [4].pack("V") }
  let(:edited_scalar) { [-333].pack("l<") }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before { skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library) }

  body_starts = { 76 => 100, 77 => 108, 81 => 80, 93 => 32, 94 => 32 }
  layouts = %i[reversed empty absent]
  [76, 77, 78, 79, 80, 81, 93, 94, 114, 116].each do |type|
    layouts.each do |layout|
      it "hydrates EMR#{type} #{layout} buffers directly with parity and editable bytes" do
        record = bitmap_record(type, layout: layout)
        klass = Emf::Emr::Binary::Records.lookup(type)
        expected = klass.read(record).snapshot
        expect(klass).not_to receive(:read)
        expect(Emf::Emr::Parser).not_to receive(:call)
        input = "#{header}#{record}#{unknown}#{eof}tail"
        parsed = Emf.parse(input)
        wire = parsed.records.first.wire
        expect(wire).to be_a(klass)
        expect(wire.snapshot).to eq(expected)
        expect(Emf.serialize(parsed)).to eq(input)
        edited = record.dup
        case type
        when 93, 94
          wire.ih_brush = 0xFFFFFEB3
          edited[8, 4] = edited_scalar
        when 76, 77, 81
          wire.x_dest = -333
          edited[24, 4] = edited_scalar
        else
          wire.rcl_bounds.left = -333
          edited[8, 4] = edited_scalar
        end
        body = type == 81 ? :trailing : :body
        value = wire.public_send(body).to_s.dup
        if layout == :reversed
          source = BitmapRecords::POINTER_LAYOUTS.fetch(type)[1]
          offset = record.byteslice(source, 4).unpack1("V")
          body_start = body_starts.fetch(type, 24)
          value.setbyte(offset - body_start, 0xAB)
          edited.setbyte(offset, 0xAB)
        end
        value[-1] = "!"
        wire.public_send("#{body}=", value)
        edited[-1] = "!"
        expect(Emf.serialize(parsed)).to eq("#{header}#{edited}#{unknown}#{eof}tail")
      end
    end

    it "keeps bad EMR#{type} buffer ranges opaque like Ruby and continues through EOF" do
      record = bitmap_record(type)
      source = BitmapRecords::POINTER_LAYOUTS.fetch(type)[1]
      record[source, 4] = bad_offset
      input = header + record + eof
      parsed = Emf.parse(input)
      expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records.lookup(type))
      expect(parsed.records.first.wire.snapshot).to eq(Emf::Emr::Binary::Records.lookup(type).read(record).snapshot)
      expect(parsed.records.last.wire).to be_a(Emf::Emr::Binary::Records::Eof)
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(input)
    end
  end

  it "rejects truncated exported payloads but not impossible buffer ranges" do
    expect { Emf::Native::BitmapFields.call("".b, 100, "".b) }.to raise_error(Emf::FormatError)
    payload = [1, 2, 32, 0xFFFFFFFF, 0, 0].pack("V*")
    expect { Emf::Native::BitmapFields.call(payload, 100, "x" * 32) }.not_to raise_error
  end
end
