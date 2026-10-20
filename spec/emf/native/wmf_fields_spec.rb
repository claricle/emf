# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/emf/native/wmf_fields"

RSpec.describe Emf::Native::WmfFields do
  let(:type) { 0x0102 }
  let(:offset) { 22 }
  let(:payload) { [2].pack("V") }
  let(:raw) { [4, type, 2].pack("Vvv") }
  let(:descriptor) { { type: type, offset: offset, payload: payload, family: 6 } }

  it "rejects a supported state with a non-state native family" do
    record = descriptor.merge(family: 4)

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a state payload whose LE-u32 field count is wrong" do
    record = descriptor.merge(payload: "".b)

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a u16 state value that exceeds its unsigned range" do
    record = descriptor.merge(payload: [0x10000].pack("V"))

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a raw state record shorter than its fixed prefix" do
    expect { described_class.new(descriptor, raw.byteslice(0, 6)).call }.to raise_error(Emf::Error)
  end
end
