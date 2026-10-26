# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"

# Two real-producer WMF shapes the parser used to reject and now keeps (Wmf::Recovery 903 and 1203):
# a META_POLYGON with NumberOfPoints 0 (PowerPoint, Apache POI empty-polygon-close.wmf) and a META_CREATEREGION
# whose ObjectCount is two bytes wide (libUEMF, the library Inkscape writes WMF with).
RSpec.describe "Emf::Conformance on empty polygons and libUEMF regions" do
  profiles = %i[strict tolerant].freeze
  def record(function, *words, body: "".b)
    payload = words.pack("v*") + body
    [3 + (payload.bytesize / 2), function].pack("Vv") + payload
  end

  def wmf(*records)
    stream = (records + [record(0)]).join
    total = 9 + (stream.bytesize / 2)
    largest = ([record(0)] + records).map { |item| item.bytesize / 2 }.max
    [1, 9, 0x0300, total & 0xFFFF, total >> 16, 1, largest & 0xFFFF, largest >> 16, 0].pack("v3vvvvvv").b + stream.b
  end

  def points(count) = [count].pack("s<") + [1, 2, 3, 4, 5, 6].pack("s<*").byteslice(0, [count, 0].max * 4).to_s

  def polygon(count) = [4 + ([count, 0].max * 2), 0x0324].pack("Vv") + points(count)

  # libUEMF layout: 2-byte ObjectCount, RegionSize = whole body, one scan of garbage counts.
  def uemf_region
    body = [0, 6, 0, 20 + 8, 1, 4, 0, 0, 1, 1, 2, 2, 2, 0, 0].pack("v*")[0, 28]
    [3 + (body.bytesize / 2), 0x06FF].pack("Vv") + body
  end

  def report(bytes, profile) = Emf::Conformance.check(bytes, profile: profile)
  def ids(findings) = findings.map(&:requirement_id)

  it "rejects a one-point polygon and a negative count on both profiles (preservation)" do
    [polygon(1), [4, 0x0324].pack("Vv") + [-1].pack("s<")].each do |raw|
      profiles.each do |profile|
        result = report(wmf(raw), profile)
        expect(result.valid?).to be(false)
        expect(ids(result.errors)).to include("wmf.reject.r0903")
      end
    end
  end

  it "keeps a zero-point polygon: strict error, tolerant warning" do
    bytes = wmf(polygon(0))
    expect(ids(report(bytes, :strict).errors)).to include("wmf.array.polygon_empty")
    tolerant = report(bytes, :tolerant)
    expect(tolerant.valid?).to be(true)
    expect(ids(tolerant.warnings)).to include("wmf.array.polygon_empty")
    expect(Emf.parse(bytes).errors.map { |e| e.evidence.check }).to eq([:point_count_invalid])
  end

  it "keeps a libUEMF region as an opaque record: strict error, tolerant warning" do
    bytes = wmf(uemf_region)
    expect(ids(report(bytes, :strict).errors)).to include("wmf.region.header")
    tolerant = report(bytes, :tolerant)
    expect(tolerant.valid?).to be(true)
    expect(ids(tolerant.warnings)).to include("wmf.region.header")
  end

  it "still rejects a region whose header is invalid under both layouts (preservation)" do
    bad = uemf_region.dup
    bad[6 + 2, 2] = [7].pack("v") # ObjectType is not 6
    profiles.each do |profile|
      expect(ids(report(wmf(bad), profile).errors)).to include("wmf.reject.r1203")
    end
  end

  it "gives identical reports on both backends" do
    library = ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil)
    skip "set EMF_TEST_NATIVE_LIBRARY to run native specs" if library.nil?
    inputs = [wmf(polygon(0)), wmf(uemf_region), wmf(polygon(1)), wmf(uemf_region.dup.tap { |r| r[8, 2] = [7].pack("v") })]
    reports = %w[ruby native].map do |backend|
      previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
      ENV["EMF_BACKEND"] = backend
      ENV["EMF_NATIVE_LIBRARY"] = library
      inputs.flat_map { |bytes| profiles.map { |p| Emf::Conformance.check(bytes, profile: p).to_h(timestamp: false) } }
    ensure
      previous.each { |key, value| ENV[key] = value }
    end
    expect(reports.first).to eq(reports.last)
  end
end
