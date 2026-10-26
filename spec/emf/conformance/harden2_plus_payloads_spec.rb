# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_payload_builder"

# Preservation pins: valid pen and brush payloads, with every optional-data flag, raise no EMF+ payload finding.
RSpec.describe "EMF+ payload rules accept valid optional-data objects" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:version) { [0xDBC01002].pack("V") }
  let(:matrix) { [1, 0, 0, 1, 0, 0].pack("e6") }
  let(:color) { [0xFF112233].pack("V") }
  let(:solid) { version + [0].pack("V") + color }

  def words(*values) = values.pack("V*")

  def floats(*values) = values.pack("e*")

  def path = version + words(3, 0) + floats(0, 1, 2, 3, 4, 5) + [0, 1, 1, 0].pack("C4")

  def cap
    head = version + words(0, 3, 0) + floats(1) + words(0, 0, 0) + floats(10, 1, 0, 0, 0, 0)
    head + words(path.bytesize) + path + words(path.bytesize) + path
  end

  def pen(flags)
    data = version + words(0, flags, 2) + floats(1)
    data += matrix if flags.anybits?(0x1)
    data += optional_scalars(flags)
    data + solid
  end

  def optional_scalars(flags)
    parts = {
      0x2 => words(0), 0x4 => words(0), 0x8 => words(0), 0x10 => floats(10), 0x20 => words(0), 0x40 => words(0),
      0x80 => floats(0), 0x100 => words(2) + floats(1, 1), 0x200 => words(0), 0x400 => words(2) + floats(0.2, 0.8),
      0x800 => words(cap.bytesize) + cap, 0x1000 => words(cap.bytesize) + cap
    }
    parts.select { |flag, _| flags.anybits?(flag) }.values.join.b
  end

  def gradient(flags, extra) = version + words(4, flags, 0) + floats(0, 0, 10, 10) + (color * 2) + words(0, 0) + extra

  def path_gradient(flags, boundary, extra)
    version + words(3, flags, 0) + color + floats(5, 5) + words(2) + (color * 2) + boundary + extra
  end

  def findings(type, data)
    report = Emf::Conformance.check(build.stream(build.object(type, 1, data)), profile: :strict)
    report.diagnostics.map(&:requirement_id).grep(/\Aemfplus\.(object|image)\./)
  end

  it "accepts a pen with each PenData flag alone and with all of them" do
    ([0] + (0..12).map { |bit| 1 << bit } + [0x1FFF]).each do |flags|
      expect(findings(2, pen(flags)) - ["emfplus.record.data_size_alignment"]).to be_empty, "PenDataFlags 0x#{flags.to_s(16)}"
    end
  end

  it "accepts linear gradient brushes with transform, preset colors and blend factors" do
    colors = words(2) + floats(0, 1) + (color * 2)
    factors = words(2) + floats(0, 1) + floats(0, 1)
    [gradient(0, ""), gradient(2, matrix), gradient(4, colors), gradient(8, factors), gradient(0x10, factors),
     gradient(0x18, factors + factors), gradient(0x86, matrix + colors)].each do |data|
      expect(findings(1, data.ljust(data.bytesize + (-data.bytesize % 4), "\0"))).to be_empty
    end
  end

  it "accepts path gradient brushes with point or path boundary and every optional field" do
    points = words(3) + floats(0, 0, 10, 0, 5, 10)
    boundary = words(path.bytesize) + path
    focus = words(2) + floats(0.5, 0.5)
    colors = words(2) + floats(0, 1) + (color * 2)
    [path_gradient(0, points, ""), path_gradient(1, boundary, ""), path_gradient(3, boundary, matrix),
     path_gradient(5, points, colors), path_gradient(0x40, points, focus),
     path_gradient(0x4F, boundary, matrix + colors + focus)].each do |data|
      expect(findings(1, data.ljust(data.bytesize + (-data.bytesize % 4), "\0"))).to be_empty
    end
  end

  it "still flags a path gradient whose FocusScaleData is cut short" do
    data = path_gradient(0x40, words(3) + floats(0, 0, 10, 0, 5, 10), floats(0.5, 0.5))
    expect(findings(1, data)).to include("emfplus.object.payload")
  end
end
