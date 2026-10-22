# frozen_string_literal: true

require_relative "../support/native_library_context"

# WireAdapter#values against BinData: for every record of every fixture the
# values are the ones a BinData read of the record's own bytes holds.
RSpec.describe "WireAdapter#values" do
  fixtures = %w[emf emf-ea emf-corrupted].flat_map do |directory|
    Dir[File.join(__dir__, "..", "fixtures", directory, "*.emf")].map { |path| [directory, File.basename(path)] }
  end

  # Plain nested Hash/Array of what BinData or a value object holds; floats as
  # their double bits so that NaN payloads and -0.0 compare exactly.
  def normalize(node)
    case node
    when Emf::Emr::Binary::ValueView::Value then node.to_h.transform_values { |child| normalize(child) }
    when Hash then node.transform_values { |child| normalize(child) }
    when Array then node.map { |child| normalize(child) }
    when Float then [:float, [node].pack("G")]
    else node
    end
  end

  def parse_with(backend, bytes)
    ENV["EMF_BACKEND"] = backend
    Emf.parse(bytes)
  ensure
    ENV.delete("EMF_BACKEND")
  end

  def equivalence(backend, directory, name)
    bytes = Emf::SpecSupport::FixturePath.read_fixture(directory, name)
    begin
      parsed = parse_with(backend, bytes)
    rescue Emf::FormatError
      # A header that does not parse leaves no records to read values from.
      return { rejected: 1 }
    end
    values = parsed.records.map(&:values)
    oracle = parse_with(backend, bytes).records
    counts = Hash.new(0)
    oracle.each_with_index do |record, index|
      klass = record.wire.class
      if Emf::Emr::Binary::ValueView.for_class(klass)
        reference = klass.read(record.to_binary_s).snapshot
        expect(normalize(values.fetch(index))).to eq(normalize(reference)), "#{name} record #{index} #{klass}"
        counts[:supported] += 1
      else
        expect(values.fetch(index)).to be_nil, "#{name} record #{index} #{klass}"
        counts[:unsupported] += 1
      end
    end
    counts
  end

  shared_examples "equivalent to the BinData wire" do |backend|
    fixtures.each do |directory, name|
      it "#{backend}: #{directory}/#{name}" do
        counts = equivalence(backend, directory, name)
        expect(counts.values.sum).to be_positive # a rejected file counts once
      end
    end
  end

  context "with the Ruby backend" do
    include_examples "equivalent to the BinData wire", "ruby"
  end

  context "with the native backend" do
    include_context "with native library"

    include_examples "equivalent to the BinData wire", "native"
  end

  it "supports the 37 fixed-layout and 10 point-array record classes and not the text-out records" do
    supported = Emf::Emr::Binary::Records.constants.map { |name| Emf::Emr::Binary::Records.const_get(name) }
                                         .grep(Class).select { |klass| Emf::Emr::Binary::ValueView.for_class(klass) }
    expect(supported.size).to eq(47)
    expect(Emf::Emr::Binary::ValueView.for_class(Emf::Emr::Binary::Records::ExtTextOutW)).to be_nil
    expect(Emf::Emr::Binary::ValueView.for_class(Emf::Emr::Binary::Records::Raw)).to be_nil
  end

  describe "after a wire edit" do
    edits = {
      scalar: [98, ->(wire) { wire.mode = 2 }, lambda(&:mode), 2],
      nested: [36, ->(wire) { wire.xform.dx = 12.5 }, ->(values) { values.xform.dx }, 12.5],
      array: [86, ->(wire) { wire.apts[0].x = 241 }, ->(values) { values.apts.first.x }, 241]
    }
    backends = { "ruby" => nil, "native" => "with native library" }

    backends.each_key do |backend|
      context "with the #{backend} backend" do
        include_context "with native library" if backend == "native"

        let(:bytes) { Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf") }
        let(:metafile) { parse_with(backend, bytes) }

        edits.each do |shape, (type_id, edit, read, expected)|
          it "reflects a #{shape} edit made through the wire" do
            record = metafile.records.find { |candidate| candidate.type_id == type_id }
            before = record.values
            expect(read.call(before)).not_to eq(expected)
            expect(record.values).to eq(before)

            edit.call(record.wire)

            expect(read.call(record.values)).to eq(expected)
            expect(read.call(before)).not_to eq(expected)
            expect(normalize(record.values)).to eq(normalize(record.wire.snapshot))
          end

          it "reflects a #{shape} edit through a retained wire reference" do
            record = metafile.records.find { |candidate| candidate.type_id == type_id }
            wire = record.wire
            expect(read.call(record.values)).not_to eq(expected)

            edit.call(wire)

            expect(read.call(record.values)).to eq(expected)
          end
        end

        it "returns the same values before and after the wire is only read" do
          record = metafile.records.find { |candidate| candidate.type_id == 86 }
          before = record.values
          record.wire.apts.to_a
          expect(record.values).to eq(before)
        end
      end
    end

    it "gives equal values on both backends" do
      skip "set EMF_TEST_NATIVE_LIBRARY to run native specs" if ENV["EMF_TEST_NATIVE_LIBRARY"].nil?
      bytes = Emf::SpecSupport::FixturePath.read_fixture("emf", "test-031.emf")
      ruby = parse_with("ruby", bytes).records.map(&:values)
      native = parse_with("native", bytes).records.map(&:values)
      expect(native.map { |values| normalize(values) }).to eq(ruby.map { |values| normalize(values) })
    end
  end

  it "keeps float32 NaN payloads and signed and unsigned integer ranges" do
    wire = Emf::Emr::Binary::Records::SetWorldTransform.new
    wire.xform.m11.assign_bits(0x7FC0_1234)
    wire.xform.dx = -2.5
    bytes = wire.to_binary_s
    values = Emf::Emr::Binary::ValueView.for_class(wire.class).from_bytes(bytes, 0)
    expect([values.xform.m11].pack("G")).to eq([wire.xform.m11.value].pack("G"))
    expect(values.xform.m11).to be_nan
    expect(values.xform.dx).to eq(-2.5)
    expect(values).to be_frozen
    expect(values.xform).to be_frozen
  end
end
