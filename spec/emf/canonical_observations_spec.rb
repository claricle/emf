# frozen_string_literal: true

require "spec_helper"
require "base64"
require "open3"
require "tmpdir"
require_relative "../support/backend_parity"

RSpec.describe BackendParity do
  let(:bytes) { Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf").b }
  let(:observation) { described_class::Observation.call(bytes) }
  let(:parse) { observation.dig("parse", "value") }
  let(:records) { parse.fetch("records") }

  def unpack_hex(hex)
    [hex].pack("H*")
  end

  def decode(node)
    Base64.strict_decode64(node.dig("binary", "base64"))
  end

  describe "a parsed fixture" do
    it "is deterministic across runs and survives a JSON round trip" do
      expect(described_class::Observation.call(bytes)).to eq(observation)
      expect(JSON.parse(JSON.generate(observation))).to eq(observation)
    end

    it "records detection, order, offsets, type ids and wire classes" do
      metafile = Emf.parse(bytes)
      expect(observation.fetch("detect_format")).to eq("status" => "ok", "value" => "emf")
      expect(parse.fetch("format")).to eq("emf_plus")
      expect(records.map { |r| r.fetch("offset") }).to eq(metafile.records.map(&:offset))
      expect(records.map { |r| r.dig("type_id", "value") }).to eq(metafile.records.map { |r| r.type_id.to_i })
      expect(records.map { |r| r.fetch("wire_class") }).to eq(metafile.records.map { |r| r.wire.class.name })
      expect(records.map { |r| r.fetch("index") }).to eq((0...records.size).to_a)
      expect(records).to all(include("matches_source" => true))
    end

    it "keeps every header wire field and the model header's BinData leak visible" do
      wire = parse.dig("header", "wire", "value")
      expect(wire.fetch("fields").keys).to eq(Emf.parse(bytes).header.to_wire.field_names(true).map(&:to_s))
      expect(wire.dig("fields", "d_signature")).to eq(0x464D4520)
      model = parse.dig("header", "model", "value")
      expect(model.dig("fields", "signature")).to include("bindata" => "BinData::Uint32le", "value" => 0x464D4520)
      expect(model.dig("fields", "bounds", "object")).to eq("Emf::Model::Geometry::Rect")
    end

    it "keeps opaque EMF+ bytes, trailing bytes and visitor dispatch" do
      expect(decode(parse.fetch("emf_plus"))).to eq(Emf.parse(bytes).emf_plus)
      expect(decode(parse.fetch("trailing"))).to eq("".b)
      dispatch = observation.dig("visitor", "value", "dispatch")
      expect(dispatch.map { |e| e.fetch("offset") }).to eq(records.map { |r| r.fetch("offset") })
      expect(observation.dig("visitor", "value", "dump")).to start_with("Metafile format=emf_plus records=#{records.size}")
    end

    it "records serialization and reparse outcomes without asserting them" do
      expect(observation.dig("serialize", "value")).to include("equals_input" => true, "first_difference_offset" => nil)
      expect(observation.dig("reparse", "value")).to include("equals_parse" => true, "differences" => [])
      expect(observation.dig("file_api", "value")).to include("serialize_file_return" => bytes.bytesize)
    end
  end

  describe "byte and field changes" do
    let(:target) { Emf.parse(bytes).records.find { |r| r.type_id.to_i == 98 } }

    it "localises a changed source byte to the record that owns it" do
      changed = bytes.dup
      changed.setbyte(target.offset + 8, changed.getbyte(target.offset + 8) ^ 0xFF)
      paths = described_class.differences(parse, described_class::Observation.call(changed).dig("parse", "value"))
      index = records.index { |r| r.fetch("offset") == target.offset }
      expect(paths).not_to be_empty
      expect(paths).to all(start_with("$.records[#{index}]"))
    end

    it "shows a mutated wire field in serialization and in the source-match flag" do
      metafile = Emf.parse(bytes)
      metafile.records.find { |r| r.offset == target.offset }.wire.mode = 2
      mutated = described_class::Observation.call(bytes, metafile: metafile)
      expect(mutated.dig("serialize", "value", "equals_input")).to be(false)
      expect(mutated.dig("serialize", "value", "first_difference_offset")).to eq(target.offset + 8)
      index = records.index { |r| r.fetch("offset") == target.offset }
      expect(mutated.dig("reparse", "value", "differences")).to eq(["$.records[#{index}].matches_source"])
    end
  end

  describe "diagnostics and failures" do
    it "reports ordered errors with class, message, offset and record code" do
      cut = described_class::Observation.call(bytes.byteslice(0, 299))
      errors = cut.dig("parse", "value", "errors")
      expect(errors).to eq([{ "class" => "Emf::ParseError", "offset" => 288, "record_code" => 98,
                              "message" => "truncated record at offset 288 (claimed 12, got 3)" }])
      expect(cut.dig("parse", "value", "records").size).to eq(3)
    end

    it "records a parser exception as data and carries it into dependent stages" do
      cut = described_class::Observation.call(bytes.byteslice(0, 292))
      expect(cut.dig("parse", "status")).to eq(cut.dig("serialize", "status"))
      expect(cut.dig("parse", "error", "class")).to be_a(String) if cut.dig("parse", "status") == "raised"
    end

    it "turns a failing stage into an explicit raised observation" do
      invalid = described_class::Observation.call("invalid metafile")
      expect(invalid.values_at("detect_format", "parse", "serialize", "file_api").map { |s| s.fetch("status") }).to all(eq("raised"))
      expect(invalid.dig("parse", "error", "class")).to eq("Emf::FormatError")
    end

    it "marks unobservable nodes as unsupported instead of dropping them" do
      expect(described_class::WireWalker.new.call(Object.new).dig("unsupported", "class")).to eq("Object")
      expect(described_class::ModelWalker.new.call(Object.new).dig("unsupported", "reason")).to eq("no instance state")
    end
  end

  describe "binary and floating-point fidelity" do
    def xform(*words)
      Emf::Binary::Types::XForm.read(words.pack("V*"))
    end

    def floats(xform)
      described_class::WireWalker.new.call(xform).fetch("fields").transform_values { |f| f.dig("float", "wire_hex") }
    end

    it "keeps signed zero and infinity as wire bytes through JSON" do
      words = [0x80000000, 0x00000000, 0x7F800000, 0xFF800000, 0x3F800000, 0x00000001]
      walked = described_class::WireWalker.new.call(xform(*words))
      expect(JSON.parse(JSON.generate(walked))).to eq(walked)
      expect(floats(xform(*words)).values).to eq(words.map { |w| [w].pack("V").unpack1("H*") })
    end

    it "keeps double NaN payloads apart at model level" do
      nans = [0x7FF8000000000001, 0x7FF8000000000002].map { |bits| [bits].pack("Q<").unpack1("E") }
      hexes = nans.map { |nan| described_class::ModelWalker.new.call(nan).dig("float", "wire_hex") }
      expect(hexes.uniq.size).to eq(2)
    end

    it "flags a float32 NaN payload that BinData re-emits canonicalised" do
      changed = bytes.dup
      target = Emf.parse(bytes).records.find { |r| r.wire.respond_to?(:xform) }
      changed[target.offset + 8, 4] = [0x7FC00001].pack("V")
      record = described_class::Observation.call(changed).dig("parse", "value", "records").find { |r| r["offset"] == target.offset }
      m11 = record.dig("wire", "value", "fields", "xform", "fields", "m11", "float", "wire_hex")
      expect([record.fetch("matches_source"), m11]).to eq([false, "0000c07f"])
    end

    it "keeps non-UTF-8 binary strings exactly" do
      raw = "\xFF\xFE\x00A\x80".b
      node = JSON.parse(JSON.generate(described_class.binary(raw)))
      expect(decode(node)).to eq(raw)
      expect(node.dig("binary", "sha256")).to eq(Digest::SHA256.hexdigest(raw))
      expect(described_class.text(raw)).to have_key("binary")
      expect(described_class.text("ok")).to eq("ok")
    end

    it "keeps model-level float bit patterns" do
      node = described_class::ModelWalker.new.call(-0.0)
      expect(unpack_hex(node.dig("float", "wire_hex")).unpack1("E")).to eql(-0.0)
    end
  end

  describe ".differences" do
    it "reports changed leaves, missing keys and length changes by path" do
      left = { "a" => [1, 2], "b" => { "c" => 1 }, "d" => 1 }
      right = { "a" => [1, 3], "b" => { "c" => 1 }, "e" => 1 }
      expect(described_class.differences(left, right)).to contain_exactly("$.a[1]", "$.d", "$.e")
      expect(described_class.differences([1], [1, 2])).to eq(["$"])
    end
  end

  describe "script/backend_observations" do
    let(:script) { File.expand_path("../../script/backend_observations", __dir__) }

    it "captures a marked subset to an explicit output and refuses to overwrite" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "out.json")
        _out, err, status = Open3.capture3(RbConfig.ruby, script, "--output", output, "--only", "fixtures/simple/")
        artifact = JSON.parse(File.read(output))
        expect([status.success?, err]).to eq([true, ""])
        expect(artifact).to include("subset" => true, "counts" => { "simple" => 1 })
        expect(artifact.dig("fixtures", 0, "observation", "parse", "status")).to eq("ok")
        expect(artifact.fetch("revision")).to include("git_sha")
        _out, _err, again = Open3.capture3(RbConfig.ruby, script, "--output", output)
        expect(again.success?).to be(false)
      end
    end
  end
end
