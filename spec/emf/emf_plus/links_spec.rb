# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::EmfPlus::Links do
  def frame(type, comment_index, offset, flags: 0)
    Emf::EmfPlus::Frame.new(type: type, flags: flags, size: 12, data_size: 0, data: "",
                            offset: offset, comment_index: comment_index)
  end

  def metafile(record_count) = Struct.new(:records).new(Array.new(record_count))

  let(:get_dc) { 0x4004 }
  let(:save) { 0x4025 }
  let(:serializable_object) { 0x4038 }
  let(:draw_image_points) { 0x401B }
  let(:effect_flag) { 0x2000 }

  describe ".get_dc_spans" do
    it "spans the EMF records after a GetDC that ends its comment, up to the next EMF+ comment" do
      frames = [frame(get_dc, 1, 0), frame(save, 4, 0)]

      spans = described_class.get_dc_spans(metafile(6), frames)

      expect(spans).to contain_exactly(have_attributes(comment_index: 1, offset: 0, emr_range: 2...4))
    end

    it "is empty when an EMF+ record follows the GetDC in the same comment" do
      frames = [frame(get_dc, 1, 0), frame(save, 1, 12)]

      span = described_class.get_dc_spans(metafile(6), frames).first

      expect(span.emr_range).to eq(2...2)
      expect(span).to be_empty
    end

    it "runs to the end of the metafile when no EMF+ record follows" do
      span = described_class.get_dc_spans(metafile(5), [frame(get_dc, 1, 0)]).first

      expect(span.emr_range).to eq(2...5)
    end

    it "returns frozen spans and ignores other records" do
      spans = described_class.get_dc_spans(metafile(5), [frame(save, 1, 0), frame(get_dc, 2, 0)])

      expect(spans.size).to eq(1)
      expect(spans.first).to be_frozen
    end

    context "with corpus files" do
      def spans_of(path)
        metafile = Emf.parse_file(File.join("spec/fixtures/emf", path))
        frames = Emf::EmfPlus::Parser.from_metafile(metafile)
        [metafile, frames, described_class.get_dc_spans(metafile, frames)]
      end

      it "finds one span per GetDC and bounds each by the next EMF+ comment" do
        metafile, frames, spans = spans_of("test-109.emf")
        plus_comments = frames.map(&:comment_index).uniq

        expect(spans.size).to eq(frames.count { |f| f.type == get_dc }).and eq(7)
        spans.reject(&:empty?).each do |span|
          expect(span.emr_range.to_a & plus_comments).to be_empty
          expect(plus_comments + [metafile.records.size]).to include(span.emr_range.end)
        end
        expect(spans.first).to have_attributes(comment_index: 1, emr_range: 2...3)
      end

      it "gives empty spans where EMF+ records follow the GetDC in the same comment" do
        _, _, spans = spans_of("test-150.emf")

        expect(spans.size).to eq(43)
        expect(spans).to all(be_empty)
      end
    end
  end

  describe ".effect_links" do
    it "links an E-flag DrawImagePoints to the immediately preceding SerializableObject, across comments" do
      effect = frame(serializable_object, 1, 0)
      draw = frame(draw_image_points, 2, 0, flags: effect_flag)

      links, errors = described_class.effect_links([effect, draw])

      expect(links).to contain_exactly(have_attributes(draw: draw, effect: effect))
      expect(errors).to be_empty
    end

    it "does not link when the E flag is clear" do
      links, errors = described_class.effect_links([frame(serializable_object, 1, 0), frame(draw_image_points, 2, 0)])

      expect([links, errors]).to eq([[], []])
    end

    it "reports a missing SerializableObject" do
      links, errors = described_class.effect_links([frame(save, 1, 0), frame(draw_image_points, 1, 12, flags: effect_flag)])

      expect(links).to be_empty
      expect(errors).to contain_exactly(have_attributes(reason: :missing_effect, comment_index: 1, offset: 12))
    end

    it "reports an E-flag draw at the very start of the stream" do
      _, errors = described_class.effect_links([frame(draw_image_points, 1, 0, flags: effect_flag)])

      expect(errors.map(&:reason)).to eq([:missing_effect])
    end

    it "reports a SerializableObject that is not immediately preceding" do
      frames = [frame(serializable_object, 1, 0), frame(save, 1, 12), frame(draw_image_points, 1, 24, flags: effect_flag)]

      links, errors = described_class.effect_links(frames)

      expect(links).to be_empty
      expect(errors).to contain_exactly(have_attributes(reason: :non_adjacent_effect, offset: 24))
    end

    it "links only the first of two E-flag draws sharing one SerializableObject" do
      first = frame(draw_image_points, 2, 0, flags: effect_flag)
      frames = [frame(serializable_object, 1, 0), first, frame(draw_image_points, 3, 0, flags: effect_flag)]

      links, errors = described_class.effect_links(frames)

      expect(links.map(&:draw)).to eq([first])
      expect(errors.map(&:reason)).to eq([:non_adjacent_effect])
    end

    it "links both corpus SerializableObject records without touching their bytes" do
      metafile = Emf.parse_file("spec/fixtures/emf/test-038.emf")
      frames = Emf::EmfPlus::Parser.from_metafile(metafile)
      before = frames.map(&:to_binary)

      links, errors = described_class.effect_links(frames)

      expect(errors).to be_empty
      expect(links.size).to eq(2)
      expect(links).to all(satisfy { |l| l.effect.type == serializable_object && frames.index(l.effect) + 1 == frames.index(l.draw) })
      expect(frames.map(&:to_binary)).to eq(before)
    end
  end
end
