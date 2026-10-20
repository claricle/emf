# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe "EMF+ Image objects and image effects" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:version) { [0xDBC01002].pack("V") }
  let(:plus) { Emf::EmfPlus }

  def logical(type, data)
    padded = data + ("\0" * (-data.bytesize % 4))
    frame = plus::Parser.call(record(0x4008, padded, flags: type << 8, data_size: data.bytesize)).first
    plus::ObjectChain::LogicalObject.new([plus::Records.decode(frame)])
  end

  def image_body(data) = plus::Objects.decode(logical(5, data))

  def bitmap_header(pixel_format:, type:)
    [2, 1, 8, pixel_format, type].pack("l<l<l<VV")
  end

  shared_examples "a lossless image" do
    it "re-encodes to the original ObjectData" do
      expect(image_body(data).to_binary).to eq(data)
    end
  end

  describe "EmfPlusImage" do
    subject(:image) { image_body(data) }

    let(:argb_format) { 0x26200A }
    let(:indexed_format) { 0x30803 }

    context "with an EmfPlusBitmap of pixel data" do
      let(:pixels) { [1, 2, 3, 4, 5, 6, 7, 8].pack("C*") }
      let(:data) { version + [1].pack("V") + bitmap_header(pixel_format: argb_format, type: 0) + pixels }

      it "decodes the bitmap and its pixels" do
        expect(image).to be_a(plus::Objects::Image)
        expect([image.version, image.image_type, image.bitmap.width, image.bitmap.height, image.bitmap.stride,
                image.bitmap.pixel_format, image.bitmap.bitmap_type, image.bitmap.bitmap_data.pixel_data.to_s])
          .to eq([0xDBC01002, 1, 2, 1, 8, argb_format, 0, pixels])
        expect(image.metafile).to be_nil
      end

      it "has no palette entries" do
        expect(image.bitmap.bitmap_data.colors.palette_count).to eq(0)
      end

      it_behaves_like "a lossless image"
    end

    context "with an indexed bitmap" do
      let(:palette) { [1, 2].pack("VV") + [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88].pack("C*") }
      let(:data) { version + [1].pack("V") + bitmap_header(pixel_format: indexed_format, type: 0) + palette + "\x09\x0A".b }

      it "reads the palette before the pixels" do
        colors = image.bitmap.bitmap_data.colors
        expect([colors.palette_style_flags, colors.palette_count, colors.palette_entries[1].red,
                colors.palette_entries[1].alpha, image.bitmap.bitmap_data.pixel_data.to_s])
          .to eq([1, 2, 0x77, 0x88, "\x09\x0A".b])
      end

      it "rejects a palette count larger than the data without allocating it" do
        huge = version + [1].pack("V") + bitmap_header(pixel_format: indexed_format, type: 0) + [0, 0x7FFFFFFF].pack("VV") + ("\0" * 8)

        expect { image_body(huge) }.to raise_error(Emf::ParseError, /Palette of 2147483647 entries/)
      end

      it_behaves_like "a lossless image"
    end

    context "with a bitmap whose indexed flag is clear but data has a palette-like prefix" do
      let(:data) { version + [1].pack("V") + bitmap_header(pixel_format: argb_format, type: 0) + [1, 9].pack("VV") }

      it "treats those bytes as pixels, not a palette" do
        expect(image.bitmap.bitmap_data.pixel_data.to_s).to eq([1, 9].pack("VV"))
      end
    end

    context "with a compressed bitmap" do
      let(:png) { "#{"\x89PNG\r\n\x1A\n".b}payload" }
      let(:data) { version + [1].pack("V") + bitmap_header(pixel_format: indexed_format, type: 1) + png }

      it "reads the compressed bytes and ignores the indexed pixel format" do
        expect(image.bitmap.compressed_image.compressed_image_data.to_s).to eq(png)
      end

      it_behaves_like "a lossless image"
    end

    context "with an unknown bitmap data type" do
      let(:data) { "#{version}#{[1].pack('V')}#{bitmap_header(pixel_format: argb_format, type: 7)}xyz" }

      it "keeps the bytes" do
        expect(image.bitmap.unrecognized_data.to_s).to eq("xyz")
      end

      it_behaves_like "a lossless image"
    end

    context "with an EmfPlusMetafile" do
      let(:emf) { "EMFDATA!!".b }
      let(:data) { version + [2].pack("V") + [3, emf.bytesize].pack("VV") + emf + "\0\0\0".b }

      it "decodes the metafile and keeps the alignment padding" do
        expect([image.metafile.metafile_type, image.metafile.metafile_data_size, image.metafile.metafile_data.to_s,
                image.trailing]).to eq([3, 9, emf, "\0\0\0".b])
        expect(image.bitmap).to be_nil
      end

      it "rejects MetafileDataSize larger than the data" do
        huge = version + [2].pack("V") + [3, 0x7FFFFFFF].pack("VV") + emf

        expect { image_body(huge) }.to raise_error(Emf::ParseError, /MetafileData of 2147483647 bytes/)
      end

      it_behaves_like "a lossless image"
    end

    context "with an unknown ImageDataType" do
      let(:data) { "#{version}#{[0].pack('V')}abcd" }

      it "keeps the bytes" do
        expect([image.image_type, image.body.unrecognized_data.to_s]).to eq([0, "abcd"])
      end

      it_behaves_like "a lossless image"
    end

    it "raises ParseError on a truncated header" do
      expect { image_body(version + [1].pack("V") + [1, 1].pack("VV")) }.to raise_error(Emf::ParseError, /malformed Image/)
    end

    it "raises ParseError on a truncated metafile header" do
      expect { image_body(version + [2].pack("V") + [3].pack("V")) }.to raise_error(Emf::ParseError, /malformed Image/)
    end
  end

  describe "image effects" do
    def serializable(guid, buffer)
      raw = guid.delete("-").scan(/../).map { |b| b.to_i(16) }
      bytes = (raw[0, 4].reverse + raw[4, 2].reverse + raw[6, 2].reverse + raw[8, 8]).pack("C*")
      body = bytes + [buffer.bytesize].pack("V") + buffer
      frame = plus::Parser.call(record(0x4038, body + ("\0" * (-body.bytesize % 4)), data_size: body.bytesize)).first
      plus::Records.decode(frame)
    end

    def effect(guid, buffer) = serializable(guid, buffer).effect

    {
      "633c80a4-1843-482b-9ef2-be2834c5fdd4" => [:Blur, [2.5, 1].pack("eV"), { blur_radius: 2.5, expand_edge: 1 }],
      "d3a1dbe1-8ec4-4c17-9f4c-ea97ad1c343d" => [:BrightnessContrast, [-5, 7].pack("l<l<"),
                                                 { brightness_level: -5, contrast_level: 7 }],
      "537e597d-251e-48da-9664-29ca496b70f8" => [:ColorBalance, [1, -2, 3].pack("l<3"),
                                                 { cyan_red: 1, magenta_green: -2, yellow_blue: 3 }],
      "dd6a0022-58e4-4a67-9d9b-d48eb881a53d" => [:ColorCurve, [3, 2, -9].pack("VVl<"),
                                                 { curve_adjustment: 3, curve_channel: 2, adjustment_intensity: -9 }],
      "8b2dd6c3-eb07-4d87-a5f0-7108e26a9c5f" => [:HueSaturationLightness, [10, -20, 30].pack("l<3"),
                                                 { hue_level: 10, saturation_level: -20, lightness_level: 30 }],
      "99c354ec-2a31-4f3a-8c34-17a803b33a25" => [:Levels, [90, -10, 5].pack("l<3"),
                                                 { highlight: 90, mid_tone: -10, shadow: 5 }],
      "63cbf3ee-c526-402c-8f71-62c540bf5142" => [:Sharpen, [3.0, 50.0].pack("ee"), { radius: 3.0, amount: 50.0 }],
      "1077af00-2848-4441-9489-44ad4c2d7a2c" => [:Tint, [-40, 25].pack("l<l<"), { hue: -40, amount: 25 }]
    }.each do |guid, (name, buffer, fields)|
      context "with #{name}Effect" do
        subject(:parsed) { effect(guid, buffer) }

        it "decodes its fields" do
          expect(parsed).to be_a(plus::Effects.const_get(name)).and have_attributes(fields)
        end

        it "re-encodes the buffer" do
          expect(parsed.to_binary).to eq(buffer)
        end

        it "keeps bytes after the body" do
          expect(effect(guid, "#{buffer}ZZZZ").to_binary).to eq("#{buffer}ZZZZ")
        end

        if name == :ColorCurve
          it "falls back to the raw bytes for a short (Windows-corrupt) block" do
            short = effect(guid, buffer.byteslice(0, 5))

            expect(short).to be_a(plus::Effects::Opaque)
            expect(short.to_binary).to eq(buffer.byteslice(0, 5))
          end
        else
          it "raises ParseError for a short buffer" do
            expect { effect(guid, buffer.byteslice(0, 4 - 1)) }.to raise_error(Emf::ParseError, /malformed #{name} effect/)
          end
        end
      end
    end

    context "with ColorLookupTableEffect" do
      let(:guid) { "a7ce72a9-0f7f-40d7-b3cc-d0c02d5c3212" }
      let(:tables) { [0, 1, 2, 3].map { |n| (0..255).map { |i| (i + n) % 256 }.pack("C*") } }
      let(:buffer) { tables.join }

      it "decodes the four tables in spec order" do
        parsed = effect(guid, buffer)

        expect([parsed.blue_lookup_table, parsed.green_lookup_table, parsed.red_lookup_table, parsed.alpha_lookup_table])
          .to eq(tables)
        expect(parsed.to_binary).to eq(buffer)
      end

      it "raises ParseError when a table is cut short" do
        expect { effect(guid, buffer.byteslice(0, 1023)) }.to raise_error(Emf::ParseError, /malformed ColorLookupTable/)
      end
    end

    context "with ColorMatrixEffect" do
      let(:guid) { "718f2615-7933-40e3-a511-5f68fe14dd74" }
      let(:values) { (0...25).map(&:to_f) }
      let(:buffer) { values.pack("e25") }

      it "maps the column-ordered floats to Matrix[row][column]" do
        parsed = effect(guid, buffer)

        expect([parsed.matrix[1][0], parsed.matrix[0][1], parsed.matrix[4][4]]).to eq([1.0, 5.0, 24.0])
        expect(parsed.to_binary).to eq(buffer)
      end

      it "raises ParseError for a short buffer" do
        expect { effect(guid, buffer.byteslice(0, 99)) }.to raise_error(Emf::ParseError, /malformed ColorMatrix/)
      end
    end

    context "with RedEyeCorrectionEffect" do
      let(:guid) { "74d29d05-69a4-4266-9549-3cc52836b632" }
      let(:buffer) { [2, 1, 2, 3, 4, 5, 6, 7, 8].pack("l<9") }

      it "decodes the RectL areas" do
        parsed = effect(guid, buffer)

        expect([parsed.number_of_areas, parsed.areas]).to eq([2, [[1, 2, 3, 4], [5, 6, 7, 8]]])
        expect(parsed.to_binary).to eq(buffer)
      end

      it "accepts zero areas" do
        expect(effect(guid, [0].pack("l<")).areas).to eq([])
      end

      it "rejects a count larger than the buffer without allocating it" do
        expect { effect(guid, [0x7FFFFFFF, 1, 2, 3, 4].pack("l<5")) }
          .to raise_error(Emf::ParseError, /Areas of 2147483647 rectangles/)
      end

      it "rejects a negative count" do
        expect { effect(guid, [-1].pack("l<")) }.to raise_error(Emf::ParseError, /negative NumberOfAreas/)
      end
    end

    it "keeps the buffer of an unknown GUID" do
      parsed = effect("00000000-0000-0000-0000-000000000001", "abc")

      expect(parsed).to be_a(plus::Effects::Opaque)
      expect(parsed.to_binary).to eq("abc")
    end
  end

  describe "against the corpus" do
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      File.binread(path).include?("EMF+") && Emf.parse(File.binread(path)).emf_plus
    rescue Emf::Error
      false
    end
    decoded = fixtures.map do |path|
      Emf::EmfPlus::Records.decode_all(Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus))
    end.flatten

    it "decodes every Image object typed and byte-identical" do
      images = Emf::EmfPlus::ObjectChain.call(decoded).grep(Emf::EmfPlus::ObjectChain::LogicalObject)
                                        .select { |l| l.object_type == 5 }
      kinds = images.map { |l| l.body.image_type }.tally
      warn "corpus Image objects: #{images.size} #{kinds}"

      expect(images.map(&:body)).to all(be_a(Emf::EmfPlus::Objects::Image))
      expect(images.map { |l| l.body.to_binary }).to eq(images.map(&:data))
    end

    it "decodes every SerializableObject effect and re-encodes its buffer" do
      records = decoded.grep(Emf::EmfPlus::Records::SerializableObject)
      effects = records.map(&:effect)
      warn "corpus effects: #{records.size} #{effects.map { |e| e.class.name.split('::').last }.tally}"

      expect(effects.map(&:to_binary)).to eq(records.map(&:buffer))
    end
  end
end
