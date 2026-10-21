# frozen_string_literal: true

require "spec_helper"
require "emf/native/bitmap_fields"

RSpec.describe "EMR bitmap records with a DIB header view" do
  records = Emf::Emr::Binary::Records
  minus_hundreds = [-333].pack("l<")

  # type => [class, fixed size, source pointer offset, mask pointer offset]
  # (MS-EMF 2.3.1.x; matches Emf::Native::BitmapFields::LAYOUTS)
  layouts = {
    78 => [records::MaskBlt, 128, 84, 112],
    79 => [records::PlgBlt, 140, 96, 124],
    80 => [records::SetDibitsToDevice, 76, 48, nil],
    114 => [records::AlphaBlend, 108, 84, nil],
    116 => [records::TransparentBlt, 108, 84, nil]
  }
  names = %i[off_bmi cb_bmi off_bits cb_bits]

  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }

  def bmi(width: 2, height: 2, bit_count: 8)
    [40, width, height, 1, bit_count, 0, 0, 0, 0, 0, 0].pack("Vl<2v2V2l<2V2") + ("\x00" * 1024)
  end

  # A record whose fixed part is zero except the given (offset => uint32) words.
  def record(type, fixed, words: {}, tail: "")
    raw = [type, fixed + tail.bytesize].pack("V2") + ("\x00" * (fixed - 8)) + tail.b
    words.each { |offset, value| raw[offset, 4] = [value].pack("V") }
    raw
  end

  def pointers(base, bmi_size, bits_offset, bits_size, bmi_offset)
    { base => bmi_offset, base + 4 => bmi_size, base + 8 => bits_offset, base + 12 => bits_size }
  end

  def parse(raw)
    Emf::Emr::Parser.call(header + raw + eof)
  end

  layouts.each do |type, (klass, fixed, source_at, _mask_at)|
    describe klass.name.split("::").last do
      it "reads the pointer fields at their MS-EMF offsets" do
        words = (source_at..).step(4).first(4).each_with_index.to_h { |offset, i| [offset, offset + i + 1] }
        wire = klass.read(record(type, fixed, words: words, tail: "TAIL"))
        expect(names.map { |name| wire.public_send(:"#{name}_src") }).to eq(words.values)
        expect(wire.body.to_s.bytesize).to eq(fixed - 24 + 4)
      end

      it "round-trips a record of exactly the fixed size" do
        raw = record(type, fixed)
        parsed = parse(raw)
        expect(parsed.errors).to be_empty
        expect(parsed.records.first.wire).to be_a(klass)
        expect(Emf::Emr::Serializer.call(parsed)).to eq(header + raw + eof)
      end

      it "reports an absent bitmap when cb_bmi is zero" do
        raw = record(type, fixed, tail: "opaque")
        parsed = parse(raw)
        expect(parsed.records.first.wire.dib_header_view.reason).to eq(:absent)
        expect(Emf::Emr::Serializer.call(parsed)).to eq(header + raw + eof)
      end

      it "exposes the DIB header and pixel array and round-trips BMI plus bits" do
        info = bmi
        bits = "\x07".b * 8
        words = pointers(source_at, info.bytesize, fixed + info.bytesize, bits.bytesize, fixed)
        raw = record(type, fixed, words: words, tail: "#{info}#{bits}xyz")
        parsed = parse(raw)
        wire = parsed.records.first.wire
        view = wire.dib_header_view
        expect(wire).to be_a(klass)
        expect(view.header).to have_attributes(kind: :info, width: 2, height: 2, bit_count: 8, color_table_entries: 256)
        expect(view).to be_bits_valid
        expect(Emf::Emr::Serializer.call(parsed)).to eq(header + raw + eof)
      end

      it "keeps an unusable BMI as a reason and the bytes intact" do
        raw = record(type, fixed, words: pointers(source_at, 40, fixed, 0, 4), tail: "short")
        parsed = parse(raw)
        expect(parsed.records.first.wire.dib_header_view.reason).to eq(:offset_in_fixed_part)
        expect(Emf::Emr::Serializer.call(parsed)).to eq(header + raw + eof)
      end

      it "still parses a record shorter than the fixed part, with a reason and no raise" do
        raw = record(type, fixed).byteslice(0, source_at - 4)
        raw[4, 4] = [raw.bytesize].pack("V")
        parsed = parse(raw)
        wire = parsed.records.first.wire
        expect(parsed.errors).to be_empty
        expect(wire).to be_a(klass)
        expect(wire.dib_header_view.reason).to eq(:absent)
        expect(Emf::Emr::Serializer.call(parsed)).to eq(header + raw + eof)
      end

      it "reports a BMI offset inside the fixed part instead of decoding it" do
        raw = record(type, fixed, words: pointers(source_at, 40, fixed, 0, source_at - 8), tail: bmi)
        expect(parse(raw).records.first.wire.dib_header_view.reason).to eq(:offset_in_fixed_part)
      end

      it "reports a bits offset inside the fixed part" do
        info = bmi
        words = pointers(source_at, info.bytesize, 30, 8, fixed)
        raw = record(type, fixed, words: words, tail: "#{info}#{"\x00".b * 8}")
        view = parse(raw).records.first.wire.dib_header_view
        expect(view).to be_valid
        expect(view.bits_reason).to eq(:bits_in_fixed_part)
      end

      it "reports a BMI pointing past a truncated record without raising" do
        raw = record(type, fixed, words: pointers(source_at, 40, fixed, 0, fixed), tail: "x")
        expect(parse(raw).records.first.wire.dib_header_view.reason).to eq(:past_record)
      end

      it "keeps bounds editable and the edit visible in the bytes" do
        raw = record(type, fixed, tail: "tail")
        parsed = parse(raw)
        parsed.records.first.wire.rcl_bounds.left = -333
        raw[8, 4] = minus_hundreds
        expect(Emf::Emr::Serializer.call(parsed)).to eq(header + raw + eof)
      end

      it "reproduces the raw bytes from the native-shaped field hash" do
        family = Emf::Native::BitmapFields::LAYOUTS.find { |_, entry| entry.first == type }.first
        raw = record(type, fixed, tail: "SUFFIX")
        _klass, fields = Emf::Native::BitmapFields.call(raw.byteslice(8..-7), family, raw)
        wire = klass.new(**fields, i_type: type, n_size: raw.bytesize)
        expect(wire.to_binary_s).to eq(raw)
      end
    end
  end

  [78, 79].each do |type|
    klass, fixed, _source_at, mask_at = layouts.fetch(type)
    describe "#{klass.name.split('::').last} mask bitmap" do
      it "reports mask offsets inside the fixed part" do
        info = bmi
        words = pointers(mask_at, info.bytesize, 30, 8, mask_at - 8)
        view = parse(record(type, fixed, words: words, tail: info)).records.first.wire.mask_dib_header_view
        expect(view.reason).to eq(:offset_in_fixed_part)
        words = pointers(mask_at, info.bytesize, 30, 8, fixed)
        view = parse(record(type, fixed, words: words, tail: info)).records.first.wire.mask_dib_header_view
        expect(view.bits_reason).to eq(:bits_in_fixed_part)
      end

      it "exposes the mask view independently of the source view" do
        info = bmi(width: 8, height: 1, bit_count: 1).byteslice(0, 48)
        bits = "\xFF".b * 4
        words = { mask_at => fixed, mask_at + 4 => info.bytesize, mask_at + 8 => fixed + info.bytesize, mask_at + 12 => bits.bytesize }
        raw = record(type, fixed, words: words, tail: info + bits)
        parsed = parse(raw)
        wire = parsed.records.first.wire
        expect(wire.mask_dib_header_view.header).to have_attributes(bit_count: 1, width: 8)
        expect(wire.mask_dib_header_view).to be_bits_valid
        expect(wire.dib_header_view.reason).to eq(:absent)
        expect([wire.off_bmi_mask, wire.cb_bmi_mask, wire.off_bits_mask, wire.cb_bits_mask])
          .to eq([fixed, info.bytesize, fixed + info.bytesize, bits.bytesize])
        expect(Emf::Emr::Serializer.call(parsed)).to eq(header + raw + eof)
      end
    end
  end
end
