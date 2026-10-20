# frozen_string_literal: true

require "spec_helper"
require "timeout"
require_relative "../../support/emf_plus_records"

RSpec.describe "EMF+ Pen and CustomLineCap objects" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:version) { [0xDBC01002].pack("V") }
  let(:matrix) { [1.0, 0.0, 0.0, 1.0, 5.0, 6.0].pack("e6") }
  let(:solid_brush) { version + [0].pack("V") + [1, 2, 3, 4].pack("C4") }

  def decode(type, data)
    padded = data + ("\0" * (-data.bytesize % 4))
    frame = Emf::EmfPlus::Parser.call(record(0x4008, padded, flags: type << 8, data_size: data.bytesize)).first
    Emf::EmfPlus::Objects.decode(Emf::EmfPlus::ObjectChain::LogicalObject.new([Emf::EmfPlus::Records.decode(frame)]))
  end

  def pen(flags, optional = "".b, brush: solid_brush)
    version + [0, flags, 2, 1.5].pack("VVVe") + optional + brush
  end

  def fast_failure(type, data)
    Timeout.timeout(5) { decode(type, data) }
  end

  def path_bytes = version + [1, 0].pack("VV") + [1.0, 2.0].pack("e2") + [0].pack("C")

  def cap_bytes(flags: 0, optional: "".b)
    version + [0].pack("V") + [flags, 1, 0.5, 2, 3, 4, 8.0, 1.0].pack("VVeVVVee") + ("\0" * 16) + optional
  end

  shared_examples "a lossless object" do
    it "re-encodes to the original ObjectData" do
      expect(subject.to_binary).to eq(data)
    end
  end

  describe Emf::EmfPlus::Objects::Pen do
    subject(:body) { decode(2, data) }

    context "without optional data" do
      let(:data) { pen(0) }

      it "decodes the header and the brush" do
        expect(body).to be_a(described_class).and have_attributes(
          version: 0xDBC01002, pen_type: 0, pen_unit: 2, pen_width: 1.5, transform: nil, start_cap: nil
        )
        expect(body.brush).to be_a(Emf::EmfPlus::Objects::Brush)
      end

      it_behaves_like "a lossless object"
    end

    context "with every flag" do
      let(:cap) { cap_bytes }
      let(:optional) do
        matrix + [0, 1, 2].pack("l<3") + [7.5].pack("e") + [1, 2].pack("l<2") + [0.5].pack("e") +
          [2, 3.0, 4.0].pack("Ve2") + [1].pack("l<") + [2, 0.25, 0.75].pack("Ve2") +
          [cap.bytesize].pack("V") + cap + [cap.bytesize].pack("V") + cap
      end
      let(:data) { pen(0x1FFF, optional) + "\0\0".b }

      it "decodes each branch" do
        expect([body.transform.dx, body.start_cap, body.end_cap, body.join, body.miter_limit, body.line_style,
                body.dashed_line_cap, body.dash_offset, body.dashed_line, body.pen_alignment, body.compound_line])
          .to eq([5.0, 0, 1, 2, 7.5, 1, 2, 0.5, [3.0, 4.0], 1, [0.25, 0.75]])
        expect([body.custom_start_cap, body.custom_end_cap]).to all(be_a(Emf::EmfPlus::Objects::CustomLineCap))
      end

      it "keeps the padding with the brush" do
        expect(body.brush.trailing).to eq("\0\0".b)
      end

      it_behaves_like "a lossless object"
    end

    {
      0x002 => [:start_cap, 5, [5].pack("l<")],
      0x004 => [:end_cap, 6, [6].pack("l<")],
      0x008 => [:join, 1, [1].pack("l<")],
      0x010 => [:miter_limit, 10.0, [10.0].pack("e")],
      0x020 => [:line_style, 4, [4].pack("l<")],
      0x040 => [:dashed_line_cap, 2, [2].pack("l<")],
      0x080 => [:dash_offset, 2.0, [2.0].pack("e")],
      0x200 => [:pen_alignment, 3, [3].pack("l<")]
    }.each do |flag, (reader, value, bytes)|
      context "with only flag 0x#{flag.to_s(16)}" do
        let(:data) { pen(flag, bytes) }

        it "decodes #{reader}" do
          expect(body.public_send(reader)).to eq(value)
        end

        it_behaves_like "a lossless object"
      end
    end

    context "with only a transform" do
      let(:data) { pen(1, matrix) }

      it "decodes it" do
        expect(body.transform).to have_attributes(dx: 5.0, dy: 6.0)
      end

      it_behaves_like "a lossless object"
    end

    context "with only a dashed line" do
      let(:data) { pen(0x100, [2, 1.0, 2.0].pack("Ve2")) }

      it "decodes the dashes" do
        expect(body.dashed_line).to eq([1.0, 2.0])
      end

      it_behaves_like "a lossless object"
    end

    context "with only a compound line" do
      let(:data) { pen(0x400, [1, 0.5].pack("Ve")) }

      it "decodes the entries" do
        expect(body.compound_line).to eq([0.5])
      end

      it_behaves_like "a lossless object"
    end

    context "with only a custom start cap" do
      let(:data) { pen(0x800, [cap_bytes.bytesize].pack("V") + cap_bytes) }

      it "decodes the nested cap and leaves the end cap empty" do
        expect(body.custom_start_cap.data.base_cap).to eq(1)
        expect(body.custom_end_cap).to be_nil
      end

      it_behaves_like "a lossless object"
    end

    context "with only a custom end cap" do
      let(:data) { pen(0x1000, [cap_bytes.bytesize].pack("V") + cap_bytes) }

      it "decodes the nested cap" do
        expect(body.custom_end_cap.data.stroke_join).to eq(4)
      end

      it_behaves_like "a lossless object"
    end

    context "with a non-solid trailing brush" do
      let(:data) { pen(0x20, [1].pack("l<"), brush: version + [1].pack("V") + [7].pack("V") + ("\0" * 8)) }

      it "reuses the Brush object" do
        expect(body.brush).to have_attributes(brush_type: 1)
      end

      it_behaves_like "a lossless object"
    end

    describe "hostile counts" do
      it "rejects an oversized dash count quickly" do
        data = pen(0x100, [0xFFFFFFFF].pack("V"))
        expect { fast_failure(2, data) }.to raise_error(Emf::ParseError, /dashed_line of 4294967295 entries/)
      end

      it "rejects an oversized compound count quickly" do
        expect { fast_failure(2, pen(0x400, [0x40000000].pack("V"))) }
          .to raise_error(Emf::ParseError, /compound_line of/)
      end

      it "rejects a custom cap size past the object" do
        expect { fast_failure(2, pen(0x800, [0xFFFFFFFF].pack("V"))) }
          .to raise_error(Emf::ParseError, /custom_start_cap length/)
      end

      it "rejects a missing count" do
        expect { fast_failure(2, version + [0, 0x100, 2, 1.5].pack("VVVe")) }
          .to raise_error(Emf::ParseError, /dashed_line count needs 4 bytes/)
      end

      it "rejects a truncated fixed field" do
        expect { fast_failure(2, pen(0x10, "".b, brush: "".b)) }.to raise_error(Emf::ParseError)
      end

      it "rejects a truncated header" do
        expect { fast_failure(2, version) }.to raise_error(Emf::ParseError, /header needs/)
      end
    end
  end

  describe Emf::EmfPlus::Objects::CustomLineCap do
    subject(:body) { decode(9, data) }

    context "with default data and no optional data" do
      let(:data) { cap_bytes }

      it "decodes the fields" do
        expect(body).to have_attributes(version: 0xDBC01002, cap_type: 0, fill_path: nil, line_path: nil)
        expect(body.data).to have_attributes(base_cap: 1, base_inset: 0.5, stroke_miter_limit: 8.0)
      end

      it_behaves_like "a lossless object"
    end

    context "with a fill path" do
      let(:data) { cap_bytes(flags: 1, optional: [path_bytes.bytesize].pack("V") + path_bytes) }

      it "decodes the path" do
        expect([body.fill_path.points.points.first.x, body.line_path]).to eq([1.0, nil])
      end

      it_behaves_like "a lossless object"
    end

    context "with a line path" do
      let(:data) { cap_bytes(flags: 2, optional: [path_bytes.bytesize].pack("V") + path_bytes) }

      it "decodes the path" do
        expect([body.fill_path, body.line_path.point_count]).to eq([nil, 1])
      end

      it_behaves_like "a lossless object"
    end

    context "with both paths and slack inside the length" do
      let(:fill) { path_bytes + "\0\0\0\0".b }
      let(:optional) { [fill.bytesize].pack("V") + fill + [path_bytes.bytesize].pack("V") + path_bytes }
      let(:data) { cap_bytes(flags: 3, optional: optional) + "\0\0".b }

      it "decodes both and round-trips the slack and padding" do
        expect([body.fill_path.point_count, body.line_path.point_count, body.trailing]).to eq([1, 1, "\0\0".b])
      end

      it_behaves_like "a lossless object"
    end

    context "with adjustable arrow data" do
      let(:data) do
        version + [1].pack("V") + [2.0, 3.0, 0.5].pack("e3") + [1, 2, 3, 4].pack("V4") + [8.0, 1.0].pack("e2") + ("\0" * 16)
      end

      it "decodes the fields" do
        expect(body.cap_type).to eq(1)
        expect(body.data).to have_attributes(width: 2.0, height: 3.0, fill_state: 1, line_join: 4)
      end

      it_behaves_like "a lossless object"
    end

    context "with an unknown type" do
      let(:data) { version + [9].pack("V") + "RAW!".b }

      it "keeps the bytes" do
        expect(body.unknown_data).to eq("RAW!".b)
      end

      it_behaves_like "a lossless object"
    end

    describe "hostile lengths" do
      it "rejects a fill path length past the object" do
        expect { fast_failure(9, cap_bytes(flags: 1, optional: [0x7FFFFFFF].pack("V"))) }
          .to raise_error(Emf::ParseError, /fill_path length/)
      end

      it "rejects a negative-looking length" do
        expect { fast_failure(9, cap_bytes(flags: 2, optional: [0xFFFFFFFF].pack("V"))) }
          .to raise_error(Emf::ParseError, /line_path length/)
      end

      it "rejects an absurd path point count inside the length" do
        bad = version + [0x7FFFFFFF, 0].pack("VV")
        expect { fast_failure(9, cap_bytes(flags: 1, optional: [bad.bytesize].pack("V") + bad)) }
          .to raise_error(Emf::ParseError)
      end

      it "rejects a missing length" do
        expect { fast_failure(9, cap_bytes(flags: 1)) }.to raise_error(Emf::ParseError, /fill_path length needs 4 bytes/)
      end

      it "rejects truncated default data" do
        expect { fast_failure(9, cap_bytes.byteslice(0, 20)) }.to raise_error(Emf::ParseError, /data needs/)
      end
    end
  end

  describe "against the corpus" do
    # The byte check skips parsing the fixtures with no EMF+ comment; parsing them all costs minutes.
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      File.binread(path).include?("EMF+") && Emf.parse(File.binread(path)).emf_plus
    rescue Emf::Error
      false
    end
    wanted = [2, 9]
    objects = fixtures.flat_map do |path|
      records = Emf::EmfPlus::Records.decode_all(Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus))
      Emf::EmfPlus::ObjectChain.call(records).grep(Emf::EmfPlus::ObjectChain::LogicalObject)
                               .select { |l| wanted.include?(l.object_type) }
    end

    it "decodes every Pen and CustomLineCap typed and byte-identical" do
      pens = objects.select { |l| l.object_type == 2 }
      flags = pens.map { |l| l.body.pen_data_flags }
      branches = Emf::EmfPlus::Objects::Pen.constants.grep(/\ADATA_/).to_h do |name|
        [name, flags.count { |f| f.anybits?(Emf::EmfPlus::Objects::Pen.const_get(name)) }]
      end
      warn "corpus Pen: #{pens.size} objects; flag branches #{branches.reject { |_, n| n.zero? }}; " \
           "CustomLineCap: #{objects.size - pens.size}"

      expect(objects.map(&:body)).to all(be_a(Emf::EmfPlus::Objects::Typed))
      expect(objects.map { |l| l.body.to_binary }).to eq(objects.map(&:data))
    end
  end
end
