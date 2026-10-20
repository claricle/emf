# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Emf::Emr::Parser EXTTEXTOUT span validation" do
  def header_bytes
    bytes = File.binread(Emf::SpecSupport::FixturePath.fixture("simple", "image1.emf"))
    bytes.byteslice(0, bytes.byteslice(4, 4).unpack1("V"))
  end

  def eof_bytes
    [14, 20, 0, 16, 20].pack("V5")
  end

  # Offsets are from record start; fixed fields end at 76 (60 with ETO_NO_RECT).
  def text_record(type, count:, off_string:, off_dx:, options: 0, body: "\x00".b * 40)
    rect = options.anybits?(0x100) ? "".b : ([0] * 4).pack("V4")
    fixed = ([0] * 4).pack("V4") + [1, 0, 0, 0, 0, count, off_string, options].pack("V8") + rect + [off_dx].pack("V")
    size = 8 + fixed.bytesize + body.bytesize
    [type, size].pack("V2") + fixed + body
  end

  def dx_values(count)
    ([1] * count).pack("V*")
  end

  def file(record)
    header_bytes + record + eof_bytes
  end

  def round_trip(bytes)
    first = Emf.serialize(Emf.parse(bytes))
    [first, Emf.serialize(Emf.parse(first))]
  end

  def text_class(type)
    type == 84 ? Emf::Emr::Binary::Records::ExtTextOutW : Emf::Emr::Binary::Records::ExtTextOutA
  end

  [[84, 2, "W"], [83, 1, "A"]].each do |type, width, name|
    describe "type #{type} (ExtTextOut#{name})" do
      cases = {
        "oversize nChars" => { count: 2_147_483_651, off_string: 76, off_dx: 84 },
        "offString beyond the record" => { count: 3, off_string: 2_919_235_660, off_dx: 0 },
        "offDx beyond the record" => { count: 3, off_string: 76, off_dx: 4_000_000 },
        "string span past nSize" => { count: 60, off_string: 84, off_dx: 0 },
        "Dx span past nSize" => { count: 5, off_string: 76, off_dx: 100 },
        "overlapping string and Dx spans" => { count: 4, off_string: 78, off_dx: 76 },
        "Dx span that fits at 4 bytes per char but not 8 with ETO_PDY" =>
          { count: 5, off_string: 76, off_dx: 88, options: 0x2000 }
      }
      cases["misaligned string offset"] = { count: 3, off_string: 77, off_dx: 0 } if width == 2
      cases.each do |label, args|
        it "keeps #{label} Raw with a ParseError and a byte-identical round trip" do
          bytes = file(text_record(type, **args))
          metafile = Emf.parse(bytes)

          expect(metafile.errors.size).to eq(1)
          expect(metafile.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
          expect(round_trip(bytes)).to eq([bytes, bytes])
        end
      end

      it "parses a normal record typed with no error" do
        body = ("a" * width * 3).b.ljust(12, "\x00") + dx_values(3)
        bytes = file(text_record(type, count: 3, off_string: 76, off_dx: 88, body: body))
        metafile = Emf.parse(bytes)

        expect(metafile.errors).to be_empty
        expect(metafile.records.first.wire).to be_a(text_class(type))
      end

      it "parses a Dx span that fits at 8 bytes per char with ETO_PDY typed with no error" do
        bytes = file(text_record(type, count: 3, off_string: 76, off_dx: 88, options: 0x2000))
        metafile = Emf.parse(bytes)

        expect(metafile.errors).to be_empty
        expect(metafile.records.first.wire).to be_a(text_class(type))
      end

      it "parses a record with non-overlapping adjacent spans typed with no error" do
        bytes = file(text_record(type, count: 4, off_string: 76, off_dx: 76 + (4 * width)))
        metafile = Emf.parse(bytes)

        expect(metafile.errors).to be_empty
        expect(metafile.records.first.wire).to be_a(text_class(type))
      end

      it "parses an ETO_NO_RECT record typed with no error" do
        body = "ab".b.ljust(4, "\x00") + dx_values(2)
        bytes = file(text_record(type, count: 2 / width, off_string: 60, off_dx: 64, options: 0x100, body: body))
        metafile = Emf.parse(bytes)

        expect(metafile.errors).to be_empty
        expect(metafile.records.first.wire).to be_a(text_class(type))
      end

      if width == 1
        it "parses an odd string offset typed with no error" do
          bytes = file(text_record(type, count: 3, off_string: 77, off_dx: 0))

          expect(Emf.parse(bytes).errors).to be_empty
        end
      end

      it "parses nChars 0 with zero offsets typed with no error" do
        bytes = file(text_record(type, count: 0, off_string: 0, off_dx: 0))

        expect(Emf.parse(bytes).errors).to be_empty
      end
    end
  end

  %w[bad_corrupted_2014-12-02-215358 bad_corrupted_2014-12-07-235709].each do |name|
    it "recovers #{name} idempotently" do
      bytes = File.binread(Emf::SpecSupport::FixturePath.fixture("emf-corrupted", "#{name}.emf"))

      expect(Emf.parse(bytes).errors).not_to be_empty
      expect(round_trip(bytes)).to eq([bytes, bytes])
    end
  end
end
