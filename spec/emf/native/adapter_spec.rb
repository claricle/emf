# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "open3"

RSpec.describe Emf::Native do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) do
    Emf::Emr::Binary::Header.new(
      i_type: 1, n_size: 108, d_signature: 0x464D4520, n_version: 0x10000,
      rcl_bounds: { left: -5, top: 2, right: 40, bottom: 60 },
      szl_device: { cx: 800, cy: 600 }, szl_micrometers: { cx: 20, cy: 30 }
    ).to_binary_s
  end
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:map_mode) { [17, 12, 8].pack("V*") }
  let(:polyline) { [4, 44].pack("V2") + [-5, 2, 40, 60].pack("l<4") + [2].pack("V") + [-1, 4, 9, -2].pack("l<4") }
  let(:comment) { "#{[70, 20, 5].pack('V3')}EMF+xPAD" }
  let(:unknown) { "#{[0xFFFF, 12].pack('V2')}raw!" }
  let(:bytes) { "#{header}#{map_mode}#{polyline}#{comment}#{unknown}#{eof}tail" }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before do
    skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library)
  end

  it "hydrates native fields without invoking Ruby wire readers and preserves editable models" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    [Emf::Emr::Binary::Header, Emf::Emr::Binary::Records::SetMapMode,
     Emf::Emr::Binary::Records::Polyline, Emf::Emr::Binary::Records::Comment,
     Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::Eof].each do |klass|
      expect(klass).not_to receive(:read)
    end
    parsed = Emf.parse(bytes)
    expect(parsed.header.bounds.left).to eq(-5)
    expect(parsed.header.szl_micrometers.cy).to eq(30)
    expect(parsed.records.map(&:offset)).to eq([108, 120, 164, 184, 196])
    expect(parsed.records[1].wire.aptl.map { |point| [point.x.to_i, point.y.to_i] }).to eq([[-1, 4], [9, -2]])
    expect(parsed.format).to eq(:emf_plus)
    expect(parsed.emf_plus).to eq("xPAD")
    expect(parsed.errors).to be_empty
    expect(Emf.serialize(parsed)).to eq(bytes)
    parsed.records.first.wire.map_mode = 7
    expect(Emf.serialize(parsed).byteslice(116, 4).unpack1("V")).to eq(7)
  end

  it "hydrates unsigned scalar state records directly and preserves editable serialization" do
    values = [0, 0x80000000, 0xFFFFFFFF]
    expect(Emf::Emr::Parser).not_to receive(:call)
    [
      [18, Emf::Emr::Binary::Records::SetBkMode, :bk_mode],
      [19, Emf::Emr::Binary::Records::SetPolyFillMode, :poly_fill_mode],
      [20, Emf::Emr::Binary::Records::SetRop2, :rop2],
      [21, Emf::Emr::Binary::Records::SetStretchBltMode, :stretch_mode]
    ].each do |type, klass, field|
      expect(klass).not_to receive(:read)
      values.each do |value|
        input = header + [type, 12, value].pack("V3") + eof
        parsed = Emf.parse(input)
        wire = parsed.records.first.wire
        expect(wire).to be_a(klass)
        expect(wire.public_send(field).to_i).to eq(value)
        expect(parsed.errors).to be_empty
        expect(Emf.serialize(parsed)).to eq(input)
        edited = value ^ 0xFFFFFFFF
        wire.public_send("#{field}=", edited)
        expected = header + [type, 12, edited].pack("V3") + eof
        expect(Emf.serialize(parsed)).to eq(expected)
        expect(Emf.parse(expected).records.first.wire.public_send(field).to_i).to eq(edited)
      end
    end
  end

  let(:coordinate_records) do
    [
      [9, Emf::Emr::Binary::Records::SetWindowExtEx, :extent, %i[cx cy]],
      [10, Emf::Emr::Binary::Records::SetWindowOrgEx, :origin, %i[x y]],
      [11, Emf::Emr::Binary::Records::SetViewportExtEx, :extent, %i[cx cy]],
      [12, Emf::Emr::Binary::Records::SetViewportOrgEx, :origin, %i[x y]],
      [13, Emf::Emr::Binary::Records::SetBrushOrgEx, :ptl_origin, %i[x y]],
      [26, Emf::Emr::Binary::Records::OffsetClipRgn, :ptl_offset, %i[x y]],
      [27, Emf::Emr::Binary::Records::MoveToEx, :origin, %i[x y]]
    ]
  end
  let(:coordinate_values) { [[0, -1], [-0x80000000, 0x7FFFFFFF], [0x7FFFFFFF, -0x80000000]] }

  it "hydrates signed coordinate pairs directly and preserves editable serialization" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    coordinate_records.each do |type, klass, field, axes|
      expect(klass).not_to receive(:read)
      coordinate_values.each do |values|
        input = header + [type, 16].pack("V2") + values.pack("l<2") + eof
        parsed = Emf.parse(input)
        wire = parsed.records.first.wire
        expect(wire).to be_a(klass)
        expect(axes.map { |axis| wire.public_send(field).public_send(axis).to_i }).to eq(values)
        expect(parsed.errors).to be_empty
        expect(Emf.serialize(parsed)).to eq(input)
        edited = values.map { |value| -value - 1 }
        wire.public_send("#{field}=", axes.zip(edited).to_h)
        expected = header + [type, 16].pack("V2") + edited.pack("l<2") + eof
        expect(Emf.serialize(parsed)).to eq(expected)
        reparsed = Emf.parse(expected).records.first.wire.public_send(field)
        expect(axes.map { |axis| reparsed.public_send(axis).to_i }).to eq(edited)
      end
    end
  end

  it "matches Ruby canonical coordinate models after wire traversal" do
    input = header + coordinate_records.flat_map do |type, *_fields|
      coordinate_values.map { |values| [type, 16].pack("V2") + values.pack("l<2") }
    end.join + eof
    native = Emf.parse(input)
    ENV["EMF_BACKEND"] = "ruby"
    ruby = Emf.parse(input)
    expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
    expect(native.records).to eq(ruby.records)
    expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
  end

  it "preserves short coordinate payloads as Raw with diagnostics and continued framing" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    coordinate_records.map(&:first).each do |type|
      (0..7).each do |length|
        short = [type, 8 + length].pack("V2") + ("x" * length)
        input = header + short + map_mode + eof
        parsed = Emf.parse(input)
        expect(parsed.records.map { |record| record.wire.class }).to eq(
          [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
        )
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  let(:color_shape_sizes) { { 24 => 12, 25 => 12, 42 => 24, 43 => 24, 44 => 32 } }

  let(:color_shape_records) do
    [
      [24, Emf::Emr::Binary::Records::SetTextColor, { color: { red: 0, green: 128, blue: 255, reserved: 219 } }],
      [25, Emf::Emr::Binary::Records::SetBkColor, { color: { red: 255, green: 0, blue: 127, reserved: 255 } }],
      [42, Emf::Emr::Binary::Records::Ellipse, { rcl_box: { left: -0x80000000, top: 0x7FFFFFFF, right: -1, bottom: 0 } }],
      [43, Emf::Emr::Binary::Records::Rectangle, { rcl_box: { left: 0x7FFFFFFF, top: -0x80000000, right: 0, bottom: -1 } }],
      [44, Emf::Emr::Binary::Records::RoundRect,
       { rcl_box: { left: -1, top: 0, right: -0x80000000, bottom: 0x7FFFFFFF }, szl_corner: { cx: -0x80000000, cy: 0x7FFFFFFF } }]
    ]
  end

  it "hydrates colors and rectangles directly, preserving reserved bytes and editable signed fields" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    color_shape_records.each do |type, klass, fields|
      expect(klass).not_to receive(:read)
      original = klass.new(i_type: type, n_size: color_shape_sizes.fetch(type), **fields).to_binary_s
      parsed = Emf.parse(header + original + eof)
      wire = parsed.records.first.wire
      expect(wire.class).to eq(klass)
      fields.each { |field, values| expect(wire.public_send(field).snapshot).to eq(values) }
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(header + original + eof)
      edited = fields.transform_values { |values| values.transform_values { |value| type < 26 ? 255 - value : -value - 1 } }
      edited.each { |field, values| wire.public_send("#{field}=", values) }
      expected = header + klass.new(i_type: type, n_size: color_shape_sizes.fetch(type), **edited).to_binary_s + eof
      expect(Emf.serialize(parsed)).to eq(expected)
      reparsed = Emf.parse(expected).records.first.wire
      edited.each { |field, values| expect(reparsed.public_send(field).snapshot).to eq(values) }
    end
  end

  it "matches Ruby canonical color and rectangle models including fixed-record suffix normalization" do
    color_shape_records.each do |type, klass, fields|
      original = klass.new(i_type: type, n_size: color_shape_sizes.fetch(type), **fields).to_binary_s
      ["".b, "tail".b].each do |suffix|
        record = [type, original.bytesize + suffix.bytesize].pack("V2") + original.byteslice(8..) + suffix
        input = header + record + eof
        ENV["EMF_BACKEND"] = "native"
        native = Emf.parse(input)
        ENV["EMF_BACKEND"] = "ruby"
        ruby = Emf.parse(input)
        expect(native.records.map { |entry| entry.wire.snapshot }).to eq(ruby.records.map { |entry| entry.wire.snapshot })
        expect(native.records).to eq(ruby.records)
        expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
      end
    end
  end

  it "preserves every short color and rectangle payload as Raw and continues framing" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    color_shape_records.each do |type, klass, fields|
      required = klass.new(i_type: type, n_size: color_shape_sizes.fetch(type), **fields).to_binary_s.bytesize - 8
      (0...required).each do |length|
        input = header + [type, length + 8].pack("V2") + ("x" * length) + map_mode + eof
        parsed = Emf.parse(input)
        expect(parsed.records.map { |record| record.wire.class }).to eq(
          [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
        )
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  it "validates exact typed field lengths for colors and rectangles" do
    [16, 17, 18, 19, 20].each do |family|
      expect { Emf::Native::Fields.call("".b, family) }.to raise_error(Emf::FormatError, "invalid native typed payload length")
    end
  end

  let(:fixed_state_records) do
    [
      [22, Emf::Emr::Binary::Records::SetTextAlign, { text_align_mode: 0xFFFFFFFF }],
      [33, Emf::Emr::Binary::Records::SaveDc, {}],
      [34, Emf::Emr::Binary::Records::RestoreDc, { saved_dc: -0x80000000 }],
      [37, Emf::Emr::Binary::Records::SelectObject, { ih_object: 0x80000000 }],
      [40, Emf::Emr::Binary::Records::DeleteObject, { ih_object: 0xFFFFFFFF }],
      [57, Emf::Emr::Binary::Records::SetArcDirection, { arc_direction: 0x80000000 }],
      [59, Emf::Emr::Binary::Records::BeginPath, {}],
      [60, Emf::Emr::Binary::Records::EndPath, {}],
      [61, Emf::Emr::Binary::Records::CloseFigure, {}],
      [62, Emf::Emr::Binary::Records::FillPath, { rcl_bounds: { left: -0x80000000, top: 0x7FFFFFFF, right: -1, bottom: 0 } }],
      [63, Emf::Emr::Binary::Records::StrokeAndFillPath, { rcl_bounds: { left: -1, top: 0, right: -0x80000000, bottom: 0x7FFFFFFF } }],
      [64, Emf::Emr::Binary::Records::StrokePath, { rcl_bounds: { left: 0x7FFFFFFF, top: -0x80000000, right: 0, bottom: -1 } }],
      [67, Emf::Emr::Binary::Records::SelectClipPath, { region_mode: 0xFFFFFFFF }],
      [68, Emf::Emr::Binary::Records::AbortPath, {}]
    ]
  end

  it "hydrates fixed state and path fields directly and preserves edits" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    fixed_state_records.each do |type, klass, fields|
      expect(klass).not_to receive(:read)
      length = 8 + fields.values.sum { |value| value.is_a?(Hash) ? 16 : 4 }
      wire_bytes = klass.new(i_type: type, n_size: length, **fields).to_binary_s
      parsed = Emf.parse(header + wire_bytes + eof)
      wire = parsed.records.first.wire
      expect(wire.class).to eq(klass)
      fields.each { |field, value| expect(wire.public_send(field).snapshot).to eq(value) }
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(header + wire_bytes + eof)
      edited = fields.transform_values do |value|
        if value.is_a?(Hash)
          value.transform_values { |number| -number - 1 }
        else
          type == 34 ? -value - 1 : 0
        end
      end
      edited.each { |field, value| wire.public_send("#{field}=", value) }
      expected = header + klass.new(i_type: type, n_size: length, **edited).to_binary_s + eof
      expect(Emf.serialize(parsed)).to eq(expected)
      reparsed = Emf.parse(expected).records.first.wire
      edited.each { |field, value| expect(reparsed.public_send(field).snapshot).to eq(value) }
    end
  end

  it "matches Ruby fixed state canonical models and preserves opaque SelectClipPath suffixes" do
    fixed_state_records.each do |type, klass, fields|
      length = 8 + fields.values.sum { |value| value.is_a?(Hash) ? 16 : 4 }
      original = klass.new(i_type: type, n_size: length, **fields).to_binary_s
      ["".b, "tail".b, ("opaque" * 3).b].each do |suffix|
        input = header + [type, length + suffix.bytesize].pack("V2") + original.byteslice(8..) + suffix + eof
        ENV["EMF_BACKEND"] = "native"
        native = Emf.parse(input)
        ENV["EMF_BACKEND"] = "ruby"
        ruby = Emf.parse(input)
        expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
        expect(native.records).to eq(ruby.records)
        expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
        next unless type == 67

        native.records.first.wire.region_mode = 1
        expect(native.records.first.wire.trailing.to_s).to eq(suffix)
        expect(Emf.serialize(native)).to eq(header + [67, length + suffix.bytesize, 1].pack("V3") + suffix + eof)
      end
    end
  end

  it "preserves every short fixed state payload as Raw with diagnostics and continued framing" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    fixed_state_records.each do |type, _, fields|
      required = fields.values.sum { |value| value.is_a?(Hash) ? 16 : 4 }
      (0...required).each do |length|
        input = header + [type, length + 8].pack("V2") + ("x" * length) + map_mode + eof
        parsed = Emf.parse(input)
        expect(parsed.records.map { |record| record.wire.class }).to eq(
          [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
        )
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  it "rejects invalid fixed state typed lengths including nonempty unit payloads" do
    (21..34).each do |family|
      expect { Emf::Native::Fields.call("x".b, family) }.to raise_error(Emf::FormatError, "invalid native typed payload length")
    end
  end

  let(:fixed_geometry_records) do
    point = { x: -0x80000000, y: 0x7FFFFFFF }
    bounds = { left: -0x80000000, top: 0x7FFFFFFF, right: -1, bottom: 0 }
    color = { red: 0, green: 128, blue: 255, reserved: 219 }
    arc = { rcl_box: bounds, ptl_start: point, ptl_end: { x: -1, y: 0 } }
    [
      [15, Emf::Emr::Binary::Records::SetPixelV, 12, { ptl_pixel: point, cr_color: color }],
      [29, Emf::Emr::Binary::Records::ExcludeClipRect, 16, { rcl_clip: bounds }],
      [30, Emf::Emr::Binary::Records::IntersectClipRect, 16, { rcl_clip: bounds }],
      [38, Emf::Emr::Binary::Records::CreatePen, 20, { ih_pen: 0xFFFFFFFF, pen_style: 0x80000000, width: point, color: color }],
      [39, Emf::Emr::Binary::Records::CreateBrushIndirect, 16,
       { ih_brush: 0x80000000, brush_style: 0xFFFFFFFF, color: color, brush_hatch: 0 }],
      [45, Emf::Emr::Binary::Records::Arc, 32, arc],
      [46, Emf::Emr::Binary::Records::Chord, 32, arc],
      [47, Emf::Emr::Binary::Records::Pie, 32, arc],
      [54, Emf::Emr::Binary::Records::LineTo, 8, { origin: point }],
      [55, Emf::Emr::Binary::Records::ArcTo, 32, arc]
    ]
  end

  it "hydrates fixed geometry fields directly and preserves signed and color edits" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    fixed_geometry_records.each do |type, klass, length, fields|
      expect(klass).not_to receive(:read)
      original = klass.new(i_type: type, n_size: length + 8, **fields).to_binary_s
      parsed = Emf.parse(header + original + eof)
      wire = parsed.records.first.wire
      expect(wire.class).to eq(klass)
      fields.each { |field, value| expect(wire.public_send(field).snapshot).to eq(value) }
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(header + original + eof)
      edited = fields.transform_values do |value|
        if value.is_a?(Hash)
          value.transform_values { |number| value.key?(:reserved) ? 255 - number : -number - 1 }
        else
          value ^ 0xFFFFFFFF
        end
      end
      edited.each { |field, value| wire.public_send("#{field}=", value) }
      expected = header + klass.new(i_type: type, n_size: length + 8, **edited).to_binary_s + eof
      expect(Emf.serialize(parsed)).to eq(expected)
      reparsed = Emf.parse(expected).records.first.wire
      edited.each { |field, value| expect(reparsed.public_send(field).snapshot).to eq(value) }
    end
  end

  it "matches Ruby fixed geometry canonical models with opaque suffixes and unknown siblings" do
    unknown = [0x12345678, 12, 0xFFFFFFFF].pack("V3")
    fixed_geometry_records.each do |type, klass, length, fields|
      original = klass.new(i_type: type, n_size: length + 8, **fields).to_binary_s
      ["".b, "tail".b, ("opaque" * 3).b].each do |suffix|
        input = header + [type, length + suffix.bytesize + 8].pack("V2") + original.byteslice(8..) + suffix + unknown + eof
        ENV["EMF_BACKEND"] = "native"
        native = Emf.parse(input)
        ENV["EMF_BACKEND"] = "ruby"
        ruby = Emf.parse(input)
        expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
        expect(native.records).to eq(ruby.records)
        expect(native.errors).to be_empty
        expect(native.records[1].wire.class).to eq(Emf::Emr::Binary::Records::Raw)
        expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
      end
    end
  end

  it "preserves every short fixed geometry payload as Raw and continues framing" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    fixed_geometry_records.each do |type, _, required, _|
      (0...required).each do |length|
        input = header + [type, length + 8].pack("V2") + ("x" * length) + map_mode + eof
        parsed = Emf.parse(input)
        expect(parsed.records.map { |record| record.wire.class }).to eq(
          [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
        )
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  it "rejects short and excess fixed geometry typed snapshot payloads" do
    fixed_geometry_records.each_with_index do |(_, _, required, _), index|
      [required - 1, required + 1].each do |length|
        expect { Emf::Native::Fields.call("x" * length, 35 + index) }
          .to raise_error(Emf::FormatError, "invalid native typed payload length")
      end
    end
  end

  let(:point_array_records) do
    [
      [2, Emf::Emr::Binary::Records::PolyBezier, 45, 8],
      [3, Emf::Emr::Binary::Records::Polygon, 46, 8],
      [5, Emf::Emr::Binary::Records::PolyBezierTo, 47, 8],
      [6, Emf::Emr::Binary::Records::PolylineTo, 48, 8],
      [85, Emf::Emr::Binary::Records::PolyBezier16, 49, 4],
      [86, Emf::Emr::Binary::Records::Polygon16, 50, 4],
      [87, Emf::Emr::Binary::Records::Polyline16, 51, 4],
      [88, Emf::Emr::Binary::Records::PolyBezierTo16, 52, 4],
      [89, Emf::Emr::Binary::Records::PolylineTo16, 53, 4]
    ]
  end

  it "hydrates point arrays directly with signed extrema and serializable edits" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    point_array_records.each do |type, klass, _, width|
      expect(klass).not_to receive(:read)
      maximum = width == 8 ? 0x7FFFFFFF : 0x7FFF
      points = [{ x: -maximum - 1, y: maximum }, { x: -1, y: 0 }]
      count_field, points_field = width == 8 ? %i[cptl aptl] : %i[cpts apts]
      fields = { rcl_bounds: { left: -0x80000000, top: 0x7FFFFFFF, right: -1, bottom: 0 },
                 count_field => 2, points_field => points }
      length = 28 + (2 * width)
      original = klass.new(i_type: type, n_size: length, **fields).to_binary_s
      parsed = Emf.parse(header + original + eof)
      wire = parsed.records.first.wire
      expect(wire.class).to eq(klass)
      fields.each { |field, value| expect(wire.public_send(field).snapshot).to eq(value) }
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(header + original + eof)
      edited = points.map { |point| point.transform_values { |value| -value - 1 } }
      wire.public_send("#{points_field}=", edited)
      expected = header + klass.new(i_type: type, n_size: length, **fields.merge(points_field => edited)).to_binary_s + eof
      expect(Emf.serialize(parsed)).to eq(expected)
      expect(Emf.parse(expected).records.first.wire.public_send(points_field).snapshot).to eq(edited)
    end
  end

  it "matches Ruby point array models for zero counts and suffixes with unknown siblings" do
    counts = [0, 2]
    bounds = [-5, 2, 40, 60].pack("l<4")
    coordinates = [-1, 0, 1, -2]
    point_array_records.each do |type, _, _, width|
      counts.each do |count|
        ["".b, "opaque".b].each do |suffix|
          format = width == 8 ? "l<4" : "s<4"
          payload = bounds + [count].pack("V")
          payload += coordinates.pack(format) unless count.zero?
          input = header + [type, payload.bytesize + suffix.bytesize + 8].pack("V2") + payload + suffix + unknown + eof
          ENV["EMF_BACKEND"] = "native"
          native = Emf.parse(input)
          ENV["EMF_BACKEND"] = "ruby"
          ruby = Emf.parse(input)
          expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
          expect(native.records).to eq(ruby.records)
          expect(native.errors).to be_empty
          expect(native.records[1].wire.class).to eq(Emf::Emr::Binary::Records::Raw)
          expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
        end
      end
    end
  end

  it "preserves truncated and oversized-count point arrays as Raw with continued framing" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    prefix = [-5, 2, 40, 60, 2].pack("l<4V")
    oversized_count = [0xFFFFFFFF].pack("V")
    point_array_records.each do |type, _, _, width|
      payload = prefix + ("x" * (2 * width))
      payloads = (0...payload.bytesize).map { |length| payload.byteslice(0, length) }
      payloads << (payload.byteslice(0, 16) + oversized_count)
      payloads.each do |short|
        input = header + [type, short.bytesize + 8].pack("V2") + short + map_mode + eof
        parsed = Emf.parse(input)
        expect(parsed.records.map { |record| record.wire.class }).to eq(
          [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
        )
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  it "rejects point array snapshot length and count mismatches before hydration" do
    hydrator = Emf::Native::Hydrator.new(nil, "".b)
    prefix = [0, 0, 0, 0, 2].pack("l<4Q<")
    oversized_count = [0xFFFFFFFFFFFFFFFF].pack("Q<")
    point_array_records.each do |_, _, family, width|
      payload = prefix + ("x" * (2 * width))
      invalid = [payload.byteslice(0, 23), payload.byteslice(0...-1), "#{payload}x",
                 payload.byteslice(0, 16) + oversized_count]
      invalid.each do |bytes|
        record = { family: family, payload: bytes }
        expect { hydrator.send(:wire_fields, record, "".b) }.to raise_error(Emf::FormatError)
      end
    end
  end

  let(:multi_array_records) do
    [
      [7, Emf::Emr::Binary::Records::PolyPolyline, 54, 8],
      [8, Emf::Emr::Binary::Records::PolyPolygon, 55, 8],
      [90, Emf::Emr::Binary::Records::PolyPolyline16, 56, 4],
      [91, Emf::Emr::Binary::Records::PolyPolygon16, 57, 4]
    ]
  end

  it "hydrates independent multi arrays directly with signed extrema and editable counts" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    multi_array_records.each do |type, klass, _, width|
      expect(klass).not_to receive(:read)
      maximum = width == 8 ? 0x7FFFFFFF : 0x7FFF
      total_field, points_field = width == 8 ? %i[c_ptl_total aptl] : %i[c_pts_total apts]
      points = [{ x: -maximum - 1, y: maximum }, { x: -1, y: 0 }]
      fields = { rcl_bounds: { left: -0x80000000, top: 0x7FFFFFFF, right: -1, bottom: 0 },
                 n_polys: 2, a_poly_counts: [0, 0xFFFFFFFF], total_field => 2, points_field => points }
      length = 40 + (2 * width)
      original = klass.new(i_type: type, n_size: length, **fields).to_binary_s
      parsed = Emf.parse(header + original + eof)
      wire = parsed.records.first.wire
      expect(wire.class).to eq(klass)
      fields.each { |field, value| expect(wire.public_send(field).snapshot).to eq(value) }
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(header + original + eof)
      edited_points = points + [{ x: 1, y: -2 }]
      edited = fields.merge(n_polys: 1, a_poly_counts: [7], total_field => 3, points_field => edited_points)
      edited[:rcl_bounds] = { left: 1, top: -2, right: 3, bottom: -4 }
      edited.each { |field, value| wire.public_send("#{field}=", value) }
      wire.n_size = 36 + (3 * width)
      expected = header + klass.new(i_type: type, n_size: wire.n_size.to_i, **edited).to_binary_s + eof
      expect(Emf.serialize(parsed)).to eq(expected)
      reparsed = Emf.parse(expected).records.first.wire
      edited.each { |field, value| expect(reparsed.public_send(field).snapshot).to eq(value) }
    end
  end

  it "matches Ruby independent empty multi arrays and suffixes with unknown siblings" do
    bounds = [-5, 2, 40, 60].pack("l<4")
    counts = [0, 0xFFFFFFFF]
    coordinates = [-1, 0, 1, -2]
    array_lengths = [[0, 0], [2, 0], [0, 2], [2, 2]]
    multi_array_records.each do |type, _, _, width|
      array_lengths.each do |poly_count, point_count|
        ["".b, "opaque".b].each do |suffix|
          format = width == 8 ? "l<4" : "s<4"
          payload = bounds + [poly_count, point_count].pack("V2")
          payload += counts.pack("V2") unless poly_count.zero?
          payload += coordinates.pack(format) unless point_count.zero?
          input = header + [type, payload.bytesize + suffix.bytesize + 8].pack("V2") + payload + suffix + unknown + eof
          ENV["EMF_BACKEND"] = "native"
          native = Emf.parse(input)
          ENV["EMF_BACKEND"] = "ruby"
          ruby = Emf.parse(input)
          expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
          expect(native.records).to eq(ruby.records)
          expect(native.errors).to be_empty
          expect(native.records[1].wire.class).to eq(Emf::Emr::Binary::Records::Raw)
          expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
        end
      end
    end
  end

  it "preserves malformed multi arrays as Raw and continues record framing" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    prefix = [-5, 2, 40, 60, 2, 2, 0, 0xFFFFFFFF].pack("l<4V4")
    overruns = [[0xFFFFFFFF, 0], [0, 0xFFFFFFFF], [2, 0], [0, 2]]
    multi_array_records.each do |type, _, _, width|
      payload = prefix + ("x" * (2 * width))
      payloads = (0...payload.bytesize).map { |length| payload.byteslice(0, length) }
      payloads.concat(overruns.map { |counts| prefix.byteslice(0, 16) + counts.pack("V2") })
      payloads.each do |short|
        input = header + [type, short.bytesize + 8].pack("V2") + short + map_mode + eof
        parsed = Emf.parse(input)
        expect(parsed.records.map { |record| record.wire.class }).to eq(
          [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
        )
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  it "rejects inconsistent multi array snapshot lengths and both excessive array counts before allocation" do
    bounds = "\x00".b * 16
    counts = [2, 2].pack("Q<2")
    extreme_counts = [[0xFFFFFFFFFFFFFFFF, 0], [0, 0xFFFFFFFFFFFFFFFF]]
    limit_counts = [[1_000_001, 0], [0, 1_000_001]]
    multi_array_records.each do |_, _, family, width|
      payload = bounds + counts + ("x" * (8 + (2 * width)))
      invalid = [payload.byteslice(0, 31), payload.byteslice(0...-1), "#{payload}x"]
      invalid.concat(extreme_counts.map { |lengths| bounds + lengths.pack("Q<2") })
      invalid.each do |bytes|
        expect { Emf::Native::Fields.multi_point_array(bytes, family) }.to raise_error(Emf::FormatError)
      end
      limit_counts.each do |poly_count, point_count|
        bytes = bounds + [poly_count, point_count].pack("Q<2") + ("x" * ((poly_count * 4) + (point_count * width)))
        expect { Emf::Native::Fields.multi_point_array(bytes, family) }
          .to raise_error(Emf::FormatError, "native multi array exceeds Ruby model array limit")
      end
    end
  end

  let(:poly_draw_records) do
    [[56, Emf::Emr::Binary::Records::PolyDraw, 58, 8],
     [92, Emf::Emr::Binary::Records::PolyDraw16, 59, 4]]
  end

  it "hydrates PolyDraw points and opaque type bytes directly with editable shared counts" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    poly_draw_records.each do |type, klass, _, width|
      expect(klass).not_to receive(:read)
      maximum = width == 8 ? 0x7FFFFFFF : 0x7FFF
      count_field, points_field = width == 8 ? %i[cptl aptl] : %i[cpts apts]
      points = [{ x: -maximum - 1, y: maximum }, { x: -1, y: 0 }]
      fields = { rcl_bounds: { left: -0x80000000, top: 0x7FFFFFFF, right: -1, bottom: 0 },
                 count_field => 2, points_field => points, ab_types: [128, 255] }
      original = klass.new(i_type: type, n_size: 28 + (2 * (width + 1)), **fields).to_binary_s
      parsed = Emf.parse(header + original + eof)
      wire = parsed.records.first.wire
      expect(wire.class).to eq(klass)
      fields.each { |field, value| expect(wire.public_send(field).snapshot).to eq(value) }
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(header + original + eof)
      edited = fields.merge(count_field => 3, points_field => points + [{ x: 1, y: -2 }], ab_types: [255, 0, 129])
      edited[:rcl_bounds] = { left: 1, top: -2, right: 3, bottom: -4 }
      edited.each { |field, value| wire.public_send("#{field}=", value) }
      wire.n_size = 28 + (3 * (width + 1))
      expected = header + klass.new(i_type: type, n_size: wire.n_size.to_i, **edited).to_binary_s + eof
      expect(Emf.serialize(parsed)).to eq(expected)
      reparsed = Emf.parse(expected).records.first.wire
      edited.each { |field, value| expect(reparsed.public_send(field).snapshot).to eq(value) }
    end
  end

  it "matches Ruby empty and nonempty PolyDraw models with opaque suffix and unknown siblings" do
    bounds = [-5, 2, 40, 60].pack("l<4")
    coordinates = [-1, 0, 1, -2]
    types = [128, 255].pack("C2")
    counts = [0, 2]
    suffixes = ["".b, "opaque".b]
    poly_draw_records.each do |type, _, _, width|
      counts.each do |count|
        suffixes.each do |suffix|
          payload = bounds + [count].pack("V")
          payload += coordinates.pack(width == 8 ? "l<4" : "s<4") + types unless count.zero?
          input = header + [type, payload.bytesize + suffix.bytesize + 8].pack("V2") + payload + suffix + unknown + eof
          ENV["EMF_BACKEND"] = "native"
          native = Emf.parse(input)
          ENV["EMF_BACKEND"] = "ruby"
          ruby = Emf.parse(input)
          expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
          expect(native.records).to eq(ruby.records)
          expect(native.errors).to be_empty
          expect(native.records[1].wire.class).to eq(Emf::Emr::Binary::Records::Raw)
          expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
        end
      end
    end
  end

  it "preserves truncated PolyDraw points or types as Raw with continued framing" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    prefix = [-5, 2, 40, 60, 2].pack("l<4V")
    excessive_count = [0xFFFFFFFF].pack("V")
    poly_draw_records.each do |type, _, _, width|
      payload = prefix + ("x" * (2 * (width + 1)))
      payloads = (0...payload.bytesize).map { |length| payload.byteslice(0, length) }
      payloads << (prefix.byteslice(0, 16) + excessive_count)
      payloads.each do |short|
        input = header + [type, short.bytesize + 8].pack("V2") + short + map_mode + eof
        parsed = Emf.parse(input)
        expect(parsed.records.map { |record| record.wire.class }).to eq(
          [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
        )
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  it "rejects PolyDraw snapshot lengths and excessive shared counts before allocation" do
    bounds = "\x00".b * 16
    count = [2].pack("Q<")
    excessive_count = [0xFFFFFFFFFFFFFFFF].pack("Q<")
    over_limit_count = [1_000_001].pack("Q<")
    poly_draw_records.each do |_, _, family, width|
      payload = bounds + count + ("x" * (2 * (width + 1)))
      invalid = [payload.byteslice(0, 23), payload.byteslice(0...-1), "#{payload}x",
                 bounds + excessive_count]
      invalid.each do |bytes|
        expect { Emf::Native::Fields.poly_draw(bytes, family) }.to raise_error(Emf::FormatError)
      end
      bytes = bounds + over_limit_count + ("x" * (1_000_001 * (width + 1)))
      expect { Emf::Native::Fields.poly_draw(bytes, family) }
        .to raise_error(Emf::FormatError, "native PolyDraw exceeds Ruby model array limit")
    end
  end

  it "matches Ruby canonical models after every wire is traversed" do
    native = Emf.parse(bytes)
    ENV["EMF_BACKEND"] = "ruby"
    ruby = Emf.parse(bytes)
    expect(native.header.to_wire.to_binary_s).to eq(ruby.header.to_wire.to_binary_s)
    expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
    expect(native.records).to eq(ruby.records)
    expect(native.emf_plus).to eq(ruby.emf_plus)
    expect(native.trailing).to eq(ruby.trailing)
  end

  it "matches Ruby canonical scalar state models after wire traversal" do
    values = [0, 0x80000000, 0xFFFFFFFF]
    input = header + (18..21).flat_map { |type| values.map { |value| [type, 12, value].pack("V3") } }.join + eof
    native = Emf.parse(input)
    ENV["EMF_BACKEND"] = "ruby"
    ruby = Emf.parse(input)
    expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
    expect(native.records).to eq(ruby.records)
    expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
  end

  it "loads and parses through the public API in a fresh native process" do
    script = <<~SCRIPT
      require "emf"
      bytes = ARGV.fetch(0).unpack1("m0")
      parsed = Emf.parse(bytes)
      abort "wrong native result" unless parsed.records.size == 5 && Emf.serialize(parsed) == bytes
      puts parsed.format
    SCRIPT
    stdout, stderr, status = Open3.capture3(
      { "EMF_BACKEND" => "native", "EMF_NATIVE_LIBRARY" => library },
      RbConfig.ruby, "-Ilib", "-e", script, [bytes].pack("m0")
    )
    expect(status.success?).to be(true), stderr
    expect(stdout.strip).to eq("emf_plus")
  end

  it "keeps malformed short EOF raw and continues framing" do
    short = [14, 8].pack("V2")
    parsed = Emf.parse(header + short + map_mode + eof)
    expect(parsed.records.map { |record| record.wire.class }).to eq(
      [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
    )
    expect(parsed.errors.first.record_code).to eq(14)
  end

  it "preserves malformed scalar state payloads as Raw with diagnostics and continued framing" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    (18..21).each do |type|
      (0..3).each do |length|
        short = [type, 8 + length].pack("V2") + ("x" * length)
        input = header + short + map_mode + eof
        parsed = Emf.parse(input)
        expect(parsed.records.map { |record| record.wire.class }).to eq(
          [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
        )
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  it "rejects an ABI mismatch during setup" do
    described_class.backend
    allow_any_instance_of(Emf::Native::Loader).to receive(:invoke).with(:emf_abi_version).and_return(9)
    expect { described_class.backend }.to raise_error(Emf::Native::Unavailable, /ABI version mismatch/)
  end

  it "treats missing ABI symbols as setup unavailability" do
    described_class.backend
    handle = double("library")
    allow(handle).to receive(:[]).and_raise(Fiddle::DLError, "missing symbol")
    allow(Fiddle).to receive(:dlopen).with(library).and_return(handle)
    expect { described_class.backend }.to raise_error(Emf::Native::Unavailable, /missing symbol/)
  end

  it "bounds checks and validates the snapshot transport" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    snapshot = loader.document(header + eof) { |document| loader.snapshot(document) }
    expect { Emf::Native::Snapshot.new(snapshot.byteslice(0, 20)) }.to raise_error(Emf::FormatError)
    expect(snapshot.byteslice(4, 4).unpack1("V")).to eq(2)
    [1, 9].each do |schema|
      snapshot[4, 4] = [schema].pack("V")
      expect { Emf::Native::Snapshot.new(snapshot) }.to raise_error(Emf::FormatError, /schema/)
    end
  end

  it "copies input spans without per-record C buffers and frees the native document before returning the model" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    calls = []
    allow(loader).to receive(:invoke).and_wrap_original do |original, name, *arguments|
      calls << name
      original.call(name, *arguments)
    end
    input = bytes.dup.force_encoding(Encoding::UTF_8)
    parsed = backend.parse(input)
    input.replace("changed after parsing")
    expect(calls.count(:emf_document_free)).to eq(1)
    expect(calls.count(:emf_record_bytes)).to eq(0)
    expect(calls.count(:emf_buffer_free)).to eq(1)
    GC.start
    expect(backend.serialize(parsed)).to eq(bytes)
  end

  it "rejects snapshot record spans outside the input and frees the native document" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    allow(loader).to receive(:invoke).and_call_original
    [[-1, 12], [108, -1], [108, 7], [bytes.bytesize, 12], [108, bytes.bytesize]].each do |offset, length|
      allow(Emf::Native::Snapshot).to receive(:new).and_wrap_original do |original, transport|
        snapshot = original.call(transport)
        snapshot.records.first.merge!(offset: offset, length: length)
        snapshot
      end
      expect(loader).to receive(:invoke).with(:emf_document_free, anything).and_call_original
      expect { backend.parse(bytes) }.to raise_error(Emf::FormatError, /record span/)
    end
  end

  it "frees the native document when an unsupported typed family raises" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    allow(loader).to receive(:invoke).and_call_original
    expect(loader).to receive(:invoke).with(:emf_document_free, anything).and_call_original
    expect(Emf::Emr::Parser).not_to receive(:call)
    expect { backend.parse(header + [41, 12, 1].pack("V3") + eof) }
      .to raise_error(Emf::FormatError, /does not support typed EMR record 41/)
  end

  it "preserves malformed supported records as Raw with native diagnostics and unframed bytes" do
    malformed = [4, 28].pack("V2") + [0, 0, 1, 1, 20].pack("V5")
    parsed = Emf.parse("#{header}#{malformed}abc")
    expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    expect(parsed.errors.map(&:offset)).to eq([108, 136])
    expect(parsed.errors.first.record_code).to eq(4)
    expect(parsed.trailing).to eq("abc")
    expect(Emf.serialize(parsed)).to eq("#{header}#{malformed}abc")
  end

  it "propagates native parse errors without Ruby retry and frees the error handle" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    allow(loader).to receive(:invoke).and_call_original
    expect(loader).to receive(:invoke).with(:emf_error_free, anything).and_call_original
    expect(Emf::Emr::Parser).not_to receive(:call)
    expect { backend.parse("broken") }.to raise_error(Emf::FormatError)
  end

  it "rejects extended EOF honestly rather than changing its palette layout" do
    expect { Emf.parse(header + [14, 24, 1, 16, 0, 24].pack("V6")) }
      .to raise_error(Emf::FormatError, /extended or paletted EOF/)
  end

  it "falls back only when loading fails during selection" do
    ENV["EMF_NATIVE_LIBRARY"] = "/missing/emf-native-library"
    ENV["EMF_BACKEND"] = "auto"
    expect(Emf.parse(header + eof).records.last.type_id).to eq(14)
    ENV["EMF_BACKEND"] = "native"
    expect { Emf.parse(header + eof) }.to raise_error(Emf::Native::Unavailable, /could not load/)
  end
end
