# frozen_string_literal: true

require "spec_helper"
require "emf/native"
require_relative "../../support/native_lifetime_acceptance"
require_relative "../../support/native_wmf"

RSpec.describe "Native Ruby ownership and lifetime acceptance" do
  include NativeLifetimeAcceptance
  include NativeWmfSupport

  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", "") }
  let(:backend) { Emf::Native.backend }
  let(:loader) { backend.instance_variable_get(:@loader) }
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520, n_version: 0x10000).to_binary_s }
  let(:mode) { [17, 12, 8].pack("V*") }
  let(:edited_mode) { [17, 12, 7].pack("V*") }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:bytes) { "#{header}#{mode}#{eof}tail" }
  let(:wmf_record) { native_wmf_record(0x0214, [2, 3].pack("s<2")) }
  let(:failure) { RuntimeError.new("injected Ruby construction failure") }

  around do |example|
    previous = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    ENV["EMF_NATIVE_LIBRARY"] = previous
  end

  before do
    skip "set EMF_TEST_NATIVE_LIBRARY to a built emf-ffi library" unless File.file?(library)
  end

  [false, true].each do |expose|
    it "keeps an EMF record usable after metafile GC (wire exposed: #{expose})" do
      events = observe_native_lifetimes(loader)
      input = bytes.dup
      record, wire, reference = retain_native_record(backend, input, expose: expose)
      input.replace("discarded input")
      collect_native_metafile(reference)
      expect_native_released(events, document: 1, buffer: 1)
      expect(record.type_id.to_i).to eq(17)
      expect(record.wire.to_binary_s).to eq(mode)
      expect(record.wire).to equal(wire) if expose
      record.wire.map_mode = 7
      expect(record.wire.to_binary_s).to eq(edited_mode)
    end
  end

  context "WMF retained records" do
    [false, true].each do |placeable|
      it "keeps a WMF record usable after metafile GC (placeable: #{placeable})" do
        events = observe_native_lifetimes(loader)
        input = native_wmf_bytes([wmf_record], placeable: placeable)
        record, _, reference = retain_native_record(backend, input)
        input.replace("discarded input")
        collect_native_metafile(reference)
        expect_native_released(events, wmf_document: 1, buffer: 1)
        expect(record).to be_a(Emf::Model::Wmf::Records::MoveTo)
        expect([record.x, record.y]).to eq([3, 2])
        record.x = 19
        model = Emf::Model::Metafile.new(format: :wmf, header: backend.parse(native_wmf_bytes([wmf_record])).header,
                                         records: [record, Emf::Model::Wmf::Records::Eof.new])
        expect(backend.parse(backend.serialize(model)).records.first.x).to eq(19)
        expect_native_released(events, wmf_document: 3, buffer: 3)
      end
    end
  end

  it "keeps a standalone materialized wire usable after both adapter and metafile GC" do
    events = observe_native_lifetimes(loader)
    wire, metafile_reference, record_reference = retain_native_wire(backend, bytes)
    collect_native_metafile(metafile_reference)
    collect_native_metafile(record_reference)
    expect_native_released(events, document: 1, buffer: 1)
    wire.map_mode = 7
    expect(wire.to_binary_s).to eq(edited_mode)
  end

  it "frees a document when model construction raises after creating a real lazy record" do
    events = observe_native_lifetimes(loader)
    retained = []
    allow(Emf::Model::Emr::Records::WireAdapter).to receive(:lazy).and_wrap_original do |original, **args|
      raise failure unless retained.empty?

      original.call(**args).tap { |record| retained << record }
    end
    expect { backend.parse(bytes) }.to raise_error(failure)
    expect_native_released(events, document: 1, buffer: 1)
    expect(retained.first.wire.to_binary_s).to eq(mode)
    allow(Emf::Model::Emr::Records::WireAdapter).to receive(:lazy).and_call_original
    expect(backend.serialize(backend.parse(bytes))).to eq(bytes)
    expect_native_released(events, document: 2, buffer: 2)
  end

  it "frees a WMF document when typed record construction raises midway" do
    events = observe_native_lifetimes(loader)
    allow(Emf::Model::Wmf::Records::Eof).to receive(:new).and_raise(failure)
    input = native_wmf_bytes([wmf_record])
    expect { backend.parse(input) }.to raise_error(failure)
    expect_native_released(events, wmf_document: 1, buffer: 1)
    allow(Emf::Model::Wmf::Records::Eof).to receive(:new).and_call_original
    expect(backend.serialize(backend.parse(input))).to eq(input)
    expect_native_released(events, wmf_document: 2, buffer: 2)
  end

  it "releases a temporary buffer and document if Ruby raises after native buffer view" do
    armed = true
    events = observe_native_lifetimes(loader, after_invoke: lambda { |name|
      if armed && name == :emf_buffer_view
        armed = false
        raise failure
      end
    })
    expect { backend.parse(bytes) }.to raise_error(failure)
    expect_native_released(events, document: 1, buffer: 1)
    expect(backend.serialize(backend.parse(bytes))).to eq(bytes)
    expect_native_released(events, document: 2, buffer: 2)
  end

  it "releases a native error even if copying its message raises, then recovers" do
    events = observe_native_lifetimes(loader)
    allow(loader).to receive(:error_message).and_raise(failure)
    expect { loader.document("invalid") { raise "unexpected successful parse" } }.to raise_error(failure)
    expect_native_released(events, error: 1)
    allow(loader).to receive(:error_message).and_call_original
    expect { loader.document("invalid") { raise "unexpected successful parse" } }.to raise_error(Emf::FormatError, /.+/)
    expect(backend.serialize(backend.parse(bytes))).to eq(bytes)
    expect_native_released(events, error: 2, document: 1, buffer: 1)
  end

  it "balances actual handles across repeated successful and failing EMF and WMF calls" do
    events = observe_native_lifetimes(loader)
    input = native_wmf_bytes([wmf_record], placeable: true)
    messages = []
    12.times do
      expect(backend.serialize(backend.parse(bytes))).to eq(bytes)
      expect(backend.serialize(backend.parse(input))).to eq(input)
      %i[document wmf_document].each do |operation|
        expect { loader.public_send(operation, "invalid") { raise "unexpected successful parse" } }
          .to raise_error(Emf::FormatError) { |error| messages << error.message }
      end
    end
    expect(messages).to all(be_a(String).and(satisfy { |message| !message.empty? }))
    expect(messages.each_slice(2).to_a.uniq.length).to eq(1)
    expect_native_released(events, document: 12, wmf_document: 12, buffer: 24, error: 24)
  end
end
