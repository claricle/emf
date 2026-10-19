# frozen_string_literal: true

require "bindata"
require "digest"
require "emf"
require "json"
require "tempfile"

# Canonical, backend-neutral observations of what the Ruby parser does with one
# input. This is a test artifact, not a public model. Binary strings are base64
# with a digest and floats keep their wire bytes, so nothing passes through a
# lossy JSON number or a UTF-8 conversion. Anything not understood is reported
# as an explicit "unsupported" node rather than omitted.
module BackendParity
  SCHEMA_VERSION = 1
  MAX_DEPTH = 12

  module_function

  def binary(string)
    bytes = string.to_s.b
    { "binary" => { "size" => bytes.bytesize, "sha256" => Digest::SHA256.hexdigest(bytes),
                    "base64" => [bytes].pack("m0") } }
  end

  def text(string)
    utf8 = string.to_s.dup.force_encoding(Encoding::UTF_8)
    utf8.valid_encoding? ? utf8 : binary(string)
  end

  def float(value, wire_bytes)
    { "float" => { "wire_hex" => wire_bytes.unpack1("H*"), "text" => value.to_s } }
  end

  def unsupported(object, reason)
    { "unsupported" => { "class" => object.class.name, "reason" => reason } }
  end

  def exception(error)
    { "class" => error.class.name, "message" => text(error.message) }
  end

  # Runs one stage; a raised error is an observation, never an abort.
  def capture
    { "status" => "ok", "value" => yield }
  rescue StandardError => e
    { "status" => "raised", "error" => exception(e) }
  end

  def digest(value)
    Digest::SHA256.hexdigest(JSON.generate(value))
  end

  # Walks a BinData object, keeping field order, class names and wire bytes.
  class WireWalker
    def call(node)
      case node
      when BinData::Struct then struct(node)
      when BinData::Array then { "array" => node.map { |element| call(element) } }
      when BinData::BasePrimitive then primitive(node)
      else BackendParity.unsupported(node, "not a BinData struct, array or primitive")
      end
    end

    private

    def struct(node)
      fields = node.field_names(true).to_h { |name| [name.to_s, call(node[name])] }
      { "struct" => node.class.name, "fields" => fields }
    end

    def primitive(node)
      value = node.value
      case value
      when Integer, true, false, nil then value
      when Float then BackendParity.float(value, node.to_binary_s)
      when String then BackendParity.binary(value)
      else BackendParity.unsupported(value, "primitive value type")
      end
    end
  end

  # Walks plain model objects (header, geometry) through their instance variables.
  # Header fields currently hold live BinData primitives; those are reported as
  # such (with their value) so the leak stays visible.
  class ModelWalker
    def initialize(wire_walker = WireWalker.new)
      @wire_walker = wire_walker
    end

    def call(node, depth = 0)
      return BackendParity.unsupported(node, "depth limit") if depth > MAX_DEPTH

      case node
      when Integer, true, false, nil then node
      when BinData::Base then { "bindata" => node.class.name, "value" => @wire_walker.call(node) }
      when Float then BackendParity.float(node, [node].pack("E"))
      when String then BackendParity.binary(node)
      when Symbol then { "symbol" => node.to_s }
      when Array then { "array" => node.map { |element| call(element, depth + 1) } }
      else object(node, depth)
      end
    end

    private

    def object(node, depth)
      return BackendParity.unsupported(node, "no instance state") if node.instance_variables.empty?

      fields = node.instance_variables.to_h do |name|
        [name.to_s.delete_prefix("@"), call(node.instance_variable_get(name), depth + 1)]
      end
      { "object" => node.class.name, "fields" => fields }
    end
  end

  # Records every visit_* dispatch, in order, with the record's identity.
  class VisitorTrace < Emf::Model::Visitor
    attr_reader :events

    def initialize
      super
      @events = []
      @model = ModelWalker.new
      Emf::Model::Visitor.visit_methods.each_key do |name|
        define_singleton_method(name) { |record| @events << event(name, record) }
      end
    end

    private

    def event(name, record)
      { "method" => name.to_s, "record_class" => record.class.name,
        "type_id" => @model.call(record.type_id),
        "offset" => (record.offset if record.respond_to?(:offset)) }
    end
  end

  # Observation of a parsed Metafile (the "parse" section).
  class ParseSection
    def initialize(source)
      @source = source
      @wire = WireWalker.new
      @model = ModelWalker.new(@wire)
    end

    def call(metafile)
      section = { "format" => metafile.format.to_s, "header" => header(metafile.header),
                  "records" => metafile.records.each_with_index.map { |record, index| record(record, index) },
                  "errors" => metafile.errors.map { |error| diagnostic(error) },
                  "emf_plus" => (BackendParity.binary(metafile.emf_plus) if metafile.emf_plus.is_a?(String)),
                  "trailing" => BackendParity.binary(metafile.trailing) }
      section["emf_plus_unsupported"] = BackendParity.unsupported(metafile.emf_plus, "nested emf_plus") \
        unless metafile.emf_plus.nil? || metafile.emf_plus.is_a?(String)
      section
    end

    private

    def header(header)
      { "model" => BackendParity.capture { @model.call(header) },
        "wire" => BackendParity.capture { @wire.call(header.to_wire) } }
    end

    def record(record, index)
      { "index" => index, "model_class" => record.class.name, "type_id" => @model.call(record.type_id),
        "offset" => (record.offset if record.respond_to?(:offset)) }.merge(wire(record))
    end

    def wire(record)
      return { "wire" => BackendParity.unsupported(record, "record has no wire") } unless record.respond_to?(:wire)

      bytes = record.wire.to_binary_s
      { "wire_class" => record.wire.class.name, "wire_size" => bytes.bytesize,
        "wire_sha256" => Digest::SHA256.hexdigest(bytes),
        "matches_source" => (@source.byteslice(record.offset, bytes.bytesize) == bytes),
        "wire" => BackendParity.capture { @wire.call(record.wire) } }
    end

    def diagnostic(error)
      { "class" => error.class.name, "message" => BackendParity.text(error.message),
        "offset" => (error.offset if error.respond_to?(:offset)),
        "record_code" => (error.record_code if error.respond_to?(:record_code)) }
    end
  end

  # Where two serialised byte strings first diverge.
  def first_difference(left, right)
    limit = [left.bytesize, right.bytesize].min
    index = (0...limit).find { |i| left.getbyte(i) != right.getbyte(i) }
    index || (limit if left.bytesize != right.bytesize)
  end

  # Paths (capped) at which two observation trees differ.
  def differences(left, right, path = "$", found = [])
    return found if found.size >= 50

    if left.is_a?(Hash) && right.is_a?(Hash)
      (left.keys | right.keys).each { |key| differences(left[key], right[key], "#{path}.#{key}", found) }
    elsif left.is_a?(Array) && right.is_a?(Array) && left.size == right.size
      left.each_index { |i| differences(left[i], right[i], "#{path}[#{i}]", found) }
    elsif left != right
      found << path
    end
    found
  end

  # Builds the full observation for one input.
  class Observation
    def self.call(bytes, metafile: nil)
      new(bytes, metafile).call
    end

    def initialize(bytes, metafile)
      @bytes = bytes.b
      @metafile = metafile
    end

    def call
      parse = BackendParity.capture { parse_section(metafile) }
      { "schema_version" => SCHEMA_VERSION, "backend" => { "name" => "ruby" },
        "input" => BackendParity.binary(@bytes).fetch("binary").slice("size", "sha256"),
        "detect_format" => BackendParity.capture { Emf.detect_format(@bytes)&.to_s },
        "parse" => parse, "visitor" => visitor, "serialize" => serialize, "reparse" => reparse(parse),
        "file_api" => file_api }
    end

    private

    def metafile
      @metafile ||= Emf.parse(@bytes)
    end

    def parse_section(target)
      ParseSection.new(@bytes).call(target)
    end

    def visitor
      BackendParity.capture do
        trace = VisitorTrace.new
        Emf::Model::Visitor.visit_all(trace, metafile)
        { "dispatch" => trace.events, "dump" => BackendParity.text(Emf::Visitors::Dump.new.visit_all(metafile).to_s),
          "stats" => Emf::Visitors::Stats.new.visit_all(metafile).histogram }
      end
    end

    def serialize
      BackendParity.capture do
        out = Emf.serialize(metafile)
        { "size" => out.bytesize, "sha256" => Digest::SHA256.hexdigest(out), "equals_input" => out == @bytes,
          "first_difference_offset" => BackendParity.first_difference(@bytes, out) }
      end
    end

    def reparse(parse)
      BackendParity.capture do
        out = Emf.serialize(metafile)
        again = parse_section_for(out)
        { "parse_sha256" => BackendParity.digest(again), "equals_parse" => parse["value"] == again,
          "differences" => parse["value"] ? BackendParity.differences(parse["value"], again) : nil }
      end
    end

    def parse_section_for(out)
      ParseSection.new(out.b).call(Emf.parse(out))
    end

    def file_api
      BackendParity.capture do
        out = Emf.serialize(metafile)
        Tempfile.create(["backend-parity", ".emf"]) do |file|
          written = Emf.serialize_file(metafile, file.path)
          { "serialize_file_return" => written, "file_equals_serialize" => File.binread(file.path) == out,
            "parse_file_equals_parse" => parse_file_digest(file.path) == BackendParity.digest(parse_section_for(out)) }
        end
      end
    end

    def parse_file_digest(path)
      BackendParity.digest(ParseSection.new(File.binread(path)).call(Emf.parse_file(path)))
    end
  end
end

if $PROGRAM_NAME == __FILE__ && ARGV.shift == "--observe"
  output = $stdout.dup
  $stdout.reopen(File::NULL, "w")
  $stderr.reopen(File::NULL, "w")
  output.write(JSON.generate(BackendParity::Observation.call(File.binread(ARGV.fetch(0)))))
  output.close
end
