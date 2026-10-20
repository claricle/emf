# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe "EMF+ state records" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:records) { Emf::EmfPlus::Records }

  def decode(bytes)
    records.decode(Emf::EmfPlus::Parser.call(bytes).first)
  end

  shared_examples "a lossless record" do
    it "decodes to its class and re-encodes identically" do
      expect(subject).to be_a(klass)
      expect(subject.to_binary).to eq(bytes)
    end
  end

  {
    SetTextRenderingHint: [0x401F, :text_rendering_hint],
    SetInterpolationMode: [0x4021, :interpolation_mode],
    SetPixelOffsetMode: [0x4022, :pixel_offset_mode],
    SetCompositingMode: [0x4023, :compositing_mode],
    SetCompositingQuality: [0x4024, :compositing_quality]
  }.each do |name, (type, reader)|
    describe name.to_s do
      let(:klass) { records.const_get(name) }
      let(:bytes) { record(type, "", flags: 0x7F05) }
      subject { decode(bytes) }

      it_behaves_like "a lossless record"

      it "reads the low flag byte as #{reader} and ignores the reserved byte" do
        expect(subject.public_send(reader)).to eq(5)
      end
    end
  end

  describe "SetAntiAliasMode" do
    let(:klass) { records::SetAntiAliasMode }
    let(:bytes) { record(0x401E, "", flags: 0x0005) }
    subject { decode(bytes) }

    it_behaves_like "a lossless record"

    it "splits the A bit from the 7-bit SmoothingMode" do
      expect(subject).to be_anti_alias.and have_attributes(smoothing_mode: 2)
    end

    it "reports anti-aliasing off when A is clear" do
      off = decode(record(0x401E, "", flags: 0x0004))

      expect(off).not_to be_anti_alias
      expect(off.smoothing_mode).to eq(2)
    end
  end

  describe "SetTextContrast" do
    let(:klass) { records::SetTextContrast }
    let(:bytes) { record(0x4020, "", flags: 0xF834) }
    subject { decode(bytes) }

    it_behaves_like "a lossless record"

    it "reads the 12-bit contrast and the gamma it encodes" do
      expect(subject).to have_attributes(text_contrast: 2100, gamma: 2.1)
    end
  end

  describe "SetRenderingOrigin" do
    let(:klass) { records::SetRenderingOrigin }
    let(:bytes) { record(0x401D, [-7, 300].pack("l<2")) }
    subject { decode(bytes) }

    it_behaves_like "a lossless record"

    it "reads signed x and y" do
      expect(subject).to have_attributes(x: -7, y: 300)
    end

    it "raises ParseError on a truncated body" do
      expect { decode(record(0x401D, [1].pack("l<"))) }.to raise_error(Emf::ParseError, /SetRenderingOrigin/)
    end
  end

  { Save: 0x4025, Restore: 0x4026, BeginContainerNoParams: 0x4028, EndContainer: 0x4029 }.each do |name, type|
    describe name.to_s do
      let(:klass) { records.const_get(name) }
      let(:bytes) { record(type, "*\x00\x00\x00".b) }
      subject { decode(bytes) }

      it_behaves_like "a lossless record"

      it "reads the stack index" do
        expect(subject.stack_index).to eq(42)
      end

      it "raises ParseError on an empty body" do
        expect { decode(record(type, "")) }.to raise_error(Emf::ParseError, /#{name}/)
      end
    end
  end

  describe "BeginContainer" do
    let(:klass) { records::BeginContainer }
    let(:bytes) { record(0x4027, (1..8).map(&:to_f).pack("e8") + [9].pack("V"), flags: 0x0002) }
    subject { decode(bytes) }

    it_behaves_like "a lossless record"

    it "reads page unit, both rectangles and the stack index" do
      expect(subject).to have_attributes(page_unit: 2, stack_index: 9)
      expect(subject.dest_rect).to have_attributes(x: 1.0, y: 2.0, width: 3.0, height: 4.0)
      expect(subject.src_rect).to have_attributes(x: 5.0, y: 6.0, width: 7.0, height: 8.0)
    end

    it "raises ParseError when the stack index is missing" do
      expect { decode(record(0x4027, [0.0].pack("e") * 8)) }.to raise_error(Emf::ParseError, /BeginContainer/)
    end
  end

  describe "SetTSGraphics" do
    let(:klass) { records::SetTSGraphics }
    let(:matrix) { [1.0, 0.0, 0.0, 1.0, 10.0, 20.0] }
    let(:fixed) { [1, 2, 3, 4, -5, 6, 7, 8, 9].pack("C4 s<2 S< C2") + matrix.pack("e6") }
    let(:bytes) { record(0x4039, fixed) }
    subject { decode(bytes) }

    it_behaves_like "a lossless record"

    it "reads every fixed field" do
      expect(subject).to have_attributes(
        anti_alias_mode: 1, text_render_hint: 2, compositing_mode: 3, compositing_quality: 4,
        render_origin_x: -5, render_origin_y: 6, text_contrast: 7, filter_type: 8, pixel_offset: 9,
        world_to_device: matrix, palette: "", palette_bytes: "", decoded_palette: nil
      )
      expect(subject).not_to be_palette
    end

    context "with a palette" do
      let(:palette) { [0, 2, 0xFF0000FF, 0xFF00FF00].pack("V4") }
      let(:with_palette) { record(0x4039, fixed + palette, flags: 0x0003) }
      subject(:typed) { decode(with_palette) }

      it "keeps #palette as the raw String it returned before the typed decode" do
        expect(typed.palette).to eq(palette)
        expect(typed.palette).to be_a(String)
        expect(typed.palette_bytes).to eq(palette)
        expect(typed.to_binary).to eq(with_palette)
      end

      it "decodes #decoded_palette as an EmfPlusPalette" do
        expect(typed).to be_palette.and be_vga_palette
        expect(typed.decoded_palette).to be_a(Emf::EmfPlus::Records::Primitives::Palette)
        expect(typed.decoded_palette.palette_count).to eq(2)
        expect(typed.decoded_palette.palette_entries.map { |c| [c.alpha, c.red, c.green, c.blue] })
          .to eq([[0xFF, 0, 0, 0xFF], [0xFF, 0, 0xFF, 0]])
      end

      it "keeps a short palette raw, with no decoded palette" do
        short = record(0x4039, fixed + palette.byteslice(0, 12), flags: 0x0001)
        rec = decode(short)

        expect(rec.decoded_palette).to be_nil
        expect(rec.palette).to eq(palette.byteslice(0, 12))
        expect(rec.to_binary).to eq(short)
      end

      it "keeps a palette whose bytes are not exactly one palette raw" do
        long = record(0x4039, fixed + palette + "\0\0\0\0".b, flags: 0x0001)

        expect(decode(long).decoded_palette).to be_nil
        expect(decode(long).palette).to eq(palette + "\0\0\0\0".b)
        expect(decode(long).to_binary).to eq(long)
      end

      it "has no decoded palette when T is clear" do
        expect(decode(record(0x4039, fixed, flags: 0x0002)).decoded_palette).to be_nil
      end

      it "still treats with(palette: true/false) as the T flag" do
        expect(typed.with(palette: false)).not_to be_palette
        expect(decode(bytes).with(palette: true)).to be_palette
        expect { typed.with(palette: "raw") }.to raise_error(ArgumentError, /palette must fit/)
      end

      it "replaces the palette through with(decoded_palette: {...}), recomputing Size and DataSize" do
        edited = decode(bytes).with(decoded_palette: { palette_style_flags: 0, palette_entries: [{ blue: 1, green: 2, red: 3, alpha: 4 }] })

        expect(edited).to be_palette
        expect(edited.decoded_palette.palette_entries.first).to have_attributes(blue: 1, green: 2, red: 3, alpha: 4)
        expect(edited).to have_attributes(data_size: 36 + 8 + 4, size: 12 + 36 + 8 + 4)
        expect(decode(edited.to_binary).decoded_palette.palette_count).to eq(1)
      end

      it "edits a decoded palette's colour and keeps the rest" do
        edited = typed.with(decoded_palette: { palette_style_flags: 0, palette_entries: [{ blue: 4, green: 3, red: 2, alpha: 1 }] })

        expect(edited).to be_vga_palette
        expect(edited.decoded_palette.palette_entries.first).to have_attributes(blue: 4, alpha: 1)
        expect(edited.data_size).to eq(36 + 12)
        expect(edited.world_to_device).to eq(matrix)
      end
    end

    it "raises ParseError on a truncated fixed part" do
      expect { decode(record(0x4039, fixed.byteslice(0, 32))) }.to raise_error(Emf::ParseError, /SetTSGraphics/)
    end
  end

  describe "against the corpus" do
    names = %i[SetRenderingOrigin SetAntiAliasMode SetTextRenderingHint SetTextContrast SetInterpolationMode
               SetPixelOffsetMode SetCompositingMode SetCompositingQuality Save Restore BeginContainer
               BeginContainerNoParams EndContainer SetTSGraphics]
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      File.binread(path).include?("EMF+") && Emf.parse(File.binread(path)).emf_plus
    rescue Emf::Error
      false
    end

    before(:context) do
      @pairs = fixtures.flat_map do |path|
        Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus).map do |frame|
          [frame, Emf::EmfPlus::Records.decode(frame)]
        end
      end
    end

    names.each do |name|
      it "decodes every #{name} record typed and re-encodes it identically" do
        klass = records.const_get(name)
        mine = @pairs.select { |frame, _| frame.type == klass::TYPE }
        warn "corpus #{name}: #{mine.size}" if ENV["STATE_COUNTS"]

        expect(mine.map { |_, rec| rec.class }).to all(eq(klass))
        expect(mine.map { |_, rec| rec.to_binary }).to eq(mine.map { |frame, _| frame.to_binary })
      end
    end
  end
end
