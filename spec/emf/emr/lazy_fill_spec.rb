# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Lazily filled records" do
  records = Emf::Emr::Binary::Records
  codes = Emf::Emr::Binary::TypeCodes
  fill = Emf::Emr::Binary::FastFill
  bindata_writer = BinData::Base.instance_method(:to_binary_s)

  def made_fields(wire)
    wire.instance_variable_get(:@field_objs).map { |field| !field.nil? }
  end

  let(:select_bytes) { [codes::SELECTOBJECT, 12, 0x8000_0005].pack("V3") }
  let(:polygon_bytes) do
    body = [codes::POLYGON16, 0, 1, 2, 3, 4, 3].pack("VVl<4V") + [10, -20, 30, -40, 50, 60].pack("s<*")
    body[4, 4] = [body.bytesize].pack("V")
    body
  end

  describe "a fixed-layout record" do
    let(:filler) { fill.for(codes::SELECTOBJECT) }

    it "makes only the fields that are read" do
      wire, = filler.call(select_bytes)

      expect(made_fields(wire)).to eq([false, false, false])
      expect(wire.ih_object.value).to eq(0x8000_0005)
      expect(made_fields(wire)).to eq([false, false, true])
    end

    it "reads, snapshots and writes like BinData whatever the order of access" do
      wire, = filler.call(select_bytes)
      wire.n_size
      expected = records::SelectObject.read(select_bytes)

      expect(wire.snapshot).to eq(expected.snapshot)
      expect(bindata_writer.bind_call(wire)).to eq(select_bytes)
      expect(wire.num_bytes).to eq(expected.num_bytes)
    end

    it "is not clear while holding values, and starts over after clear" do
      wire, = filler.call(select_bytes)

      expect(wire.clear?).to be(false)
      wire.clear
      expect(wire.snapshot).to eq(records::SelectObject.new.snapshot)
    end

    it "takes assign over the unread fields" do
      wire, = filler.call(select_bytes)
      wire.assign(i_type: codes::SELECTOBJECT, n_size: 12, ih_object: 7)

      expect(wire.ih_object.value).to eq(7)
      expect(wire.i_type.value).to eq(codes::SELECTOBJECT)
    end

    it "does not share fields with the next record parsed" do
      first, = filler.call(select_bytes)
      first.ih_object.assign(1)
      second, = filler.call(select_bytes)

      expect(second.ih_object.value).to eq(0x8000_0005)
    end

    it "keeps its values when the caller changes the bytes afterwards" do
      bytes = select_bytes.dup
      wire, = filler.call(bytes)
      bytes.setbyte(8, 0)

      expect(wire.ih_object.value).to eq(0x8000_0005)
    end
  end

  describe "a record with a nested struct and a point array" do
    let(:filler) { fill.for_points(codes::POLYGON16) }

    it "makes the nested bounds only when asked" do
      wire, = filler.call(polygon_bytes)

      expect(wire.cpts.value).to eq(3)
      expect(made_fields(wire)).to eq([false, false, false, true, false])
      expect(wire.rcl_bounds.snapshot).to eq(left: 1, top: 2, right: 3, bottom: 4)
    end

    it "reads the same as BinData" do
      wire, suffix = filler.call(polygon_bytes + "ab".b)
      expected = records::Polygon16.read(polygon_bytes)

      expect(wire.snapshot).to eq(expected.snapshot)
      expect(suffix).to eq("ab".b)
    end

    it "holds the points flat until they are read, and packs them from there" do
      wire, = filler.call(polygon_bytes)
      array = wire.apts

      expect(array.instance_variable_get(:@flat_points)).to eq([10, -20, 30, -40, 50, 60])
      expect(filler.pack(wire)).to eq(polygon_bytes)
      expect(array.instance_variable_get(:@elements)).to be_nil
      expect(array.to_a.map(&:snapshot)).to eq(records::Polygon16.read(polygon_bytes).apts.map(&:snapshot))
    end

    it "returns nil when the count overruns the record" do
      expect(filler.call(polygon_bytes.byteslice(0, polygon_bytes.bytesize - 4))).to be_nil
    end
  end

  describe "verify_lazy" do
    [[:for, codes::SELECTOBJECT], [:for, codes::SETWORLDTRANSFORM], [:for, codes::RECTANGLE],
     [:for_points, codes::POLYGON16]].each do |finder, type|
      it "accepts the installed BinData for type #{type}" do
        filler = fill.public_send(finder, type)
        bytes = filler.send(:bindata_bytes, filler.send(:verification_record))

        expect(filler.send(:verify_lazy, bytes)).to be(true)
        expect(filler.instance_variable_get(:@lazy_ok)).to be(true)
      end
    end

    it "refuses when BinData::Struct has a method the shell was not written for" do
      filler = fill.for(codes::SELECTOBJECT)
      allow(BinData::Struct).to receive(:private_instance_methods).with(false).and_return([:brand_new_reader])

      expect(filler.send(:verify_lazy, select_bytes)).to be(false)
    end

    it "refuses when a lazy record reads differently from the read one" do
      filler = fill.for(codes::SELECTOBJECT)
      allow(filler).to receive(:lazy_field).and_wrap_original do |original, *args|
        field = original.call(*args)
        field.assign(1)
        field
      end

      expect(filler.send(:verify_lazy, select_bytes)).to be(false)
    end

    it "fills every field at once when the check has failed" do
      filler = fill.for_points(codes::POLYGON16)
      filler.instance_variable_set(:@lazy_ok, false)
      wire, suffix = filler.call(polygon_bytes + "z".b)

      expect(made_fields(wire)).to all(be(true))
      expect(wire.instance_variable_get(:@lazy_filler)).to be_nil
      expect(wire.snapshot).to eq(records::Polygon16.read(polygon_bytes).snapshot)
      expect(bindata_writer.bind_call(wire)).to eq(polygon_bytes)
      expect(suffix).to eq("z".b)
    ensure
      filler.instance_variable_set(:@lazy_ok, true)
    end

    it "parses a file identically with the eager fallback" do
      bytes = File.binread(File.expand_path("../../fixtures/emf/test-000.emf", __dir__))
      lazy = Emf.parse(bytes).records.map { |record| record.wire.snapshot }
      fillers = ObjectSpace.each_object(fill).to_a
      fillers.each { |filler| filler.instance_variable_set(:@lazy_ok, false) }
      eager = Emf.parse(bytes).records.map { |record| record.wire.snapshot }

      expect(eager).to eq(lazy)
    ensure
      fillers.each { |filler| filler.instance_variable_set(:@lazy_ok, true) }
    end
  end

  describe "verify_flat_points" do
    let(:filler) { fill.for_points(codes::POLYGON16) }

    it "accepts the installed BinData::Array" do
      expect(filler.send(:verify_flat_points)).to be(true)
    end

    it "refuses when BinData::Array has a method the holder was not written for" do
      allow(BinData::Array).to receive(:instance_methods).with(false).and_return([:brand_new_reader])

      expect(filler.send(:verify_flat_points)).to be(false)
    end

    it "refuses when a held array reads differently from BinData's" do
      allow(filler).to receive(:points_from).and_return([])

      expect(filler.send(:verify_flat_points)).to be(false)
    end

    it "builds eager points when the check fails" do
      filler.instance_variable_set(:@hold_flat, false)
      wire, = filler.call(polygon_bytes)

      expect(wire.apts.instance_variable_get(:@flat_points)).to be_nil
      expect(wire.apts.to_a.size).to eq(3)
      expect(filler.pack(wire)).to eq(polygon_bytes)
    ensure
      filler.instance_variable_set(:@hold_flat, true)
    end
  end

  describe "parsing a whole file" do
    it "reads every wire like a BinData read of that record's bytes" do
      bytes = File.binread(File.expand_path("../../fixtures/emf/test-000.emf", __dir__))
      metafile = Emf.parse(bytes)

      metafile.records.each do |record|
        wire = record.wire
        raw = bytes.byteslice(record.offset, bytes.unpack1("V", offset: record.offset + 4))
        expect(wire.snapshot).to eq(wire.class.read(raw).snapshot)
      end
      expect(metafile.records.map { |record| record.wire.class }.uniq.size).to be > 3
    end

    it "keeps wires intact when the caller's bytes change after the parse" do
      bytes = File.binread(File.expand_path("../../fixtures/emf/test-000.emf", __dir__))
      metafile = Emf.parse(bytes)
      expected = metafile.records.map(&:to_binary_s)
      bytes.replace("\0".b * bytes.bytesize)

      expect(metafile.records.map { |record| record.wire.to_binary_s }).to eq(expected)
    end
  end
end
