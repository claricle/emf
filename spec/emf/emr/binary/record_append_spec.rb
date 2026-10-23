# frozen_string_literal: true

# A record appends its own bytes to a buffer: a built shell that is still its
# bytes appends them as they are, anything else is packed.
RSpec.describe Emf::Emr::Binary::Record, "#append_to" do
  let(:klass) { Emf::Emr::Binary::Records::SelectObject }
  let(:out) { +"".b }

  it "appends an untouched built shell's bytes, without building a copy" do
    wire = klass.new(i_type: 37, ih_object: 5)
    allow(wire).to receive(:built_binary_s).and_call_original
    allow(wire).to receive(:to_binary_s).and_call_original
    expect(wire.append_to(out)).to equal(out)
    expect(out.unpack("V*")).to eq([37, 0, 5])
    expect(wire).not_to have_received(:built_binary_s)
    expect(wire).not_to have_received(:to_binary_s)
  end

  it "patches an assigned n_size into the appended bytes" do
    wire = klass.new(i_type: 37, ih_object: 5)
    wire.n_size = 12
    wire.append_to(out)
    expect(out.unpack("V*")).to eq([37, 12, 5])
  end

  it "appends a shell whose n_size field was made, still from its bytes" do
    wire = klass.new(i_type: 37, ih_object: 5)
    wire.n_size = 12
    expect(wire.n_size.value).to eq(12)
    allow(wire).to receive(:to_binary_s).and_call_original
    wire.append_to(out)
    expect(out.unpack("V*")).to eq([37, 12, 5])
    expect(wire).not_to have_received(:to_binary_s)
  end

  it "packs a shell once another field was edited" do
    wire = klass.new(i_type: 37, ih_object: 5)
    wire.ih_object = 9
    wire.append_to(out)
    expect(out.unpack("V*")).to eq([37, 0, 9])
    expect(wire.append_built_to?(+"".b)).to be(false)
  end

  it "packs a shell whose n_size is not an Integer exactly as BinData does" do
    wire = klass.new(i_type: 37, ih_object: 5)
    wire.n_size = 4.5
    expect(wire.append_built_to?(+"".b)).to be(false)
  end
end

require "emf/native/lazy_wire"

RSpec.describe "byte sources append themselves" do
  it "appends a filled record's bytes" do
    bytes = [37, 12, 5].pack("V*").freeze
    source = Emf::Emr::FilledRecord.for(37, 4, 12, "\x00\x00\x00\x00".b + bytes)
    expect(source.append_to("a".b)).to eq("a".b + bytes)
  end

  it "appends a lazy native wire's bytes" do
    bytes = [37, 12, 5].pack("V*").b
    wire = Emf::Native::LazyWire.new(Emf::Emr::Binary::Records::SelectObject, { ih_object: 5 }, bytes, { type: 37 })
    expect(wire.append_to("a".b)).to eq("a".b + bytes)
  end
end
