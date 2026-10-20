# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

module ParserBenchmark
  module WmfWorkloads
    FAMILIES = %w[geometry text bitmap unknown].freeze
    MAX_REPETITIONS = 10_000
    MANIFEST_FILENAME = "workload-manifest.json"

    module_function

    def build(family:, repetitions:, placeable: false)
      validate_repetitions(repetitions)
      family = family.to_s
      raise ArgumentError, "family must be one of #{FAMILIES.join(', ')}" unless FAMILIES.include?(family)

      unit = workload_records(family)
      eof = record(0, "".b)
      records = (unit.join * repetitions) + eof
      largest_record = unit.map { |bytes| bytes.bytesize / 2 }.max
      header = [2, 9, 0x0300, 9 + (records.bytesize / 2), 0, largest_record, 0].pack("v3VvVv")
      (placeable ? placeable_header : "".b) + header + records
    end

    def write(output_dir:, repetitions: 100)
      validate_repetitions(repetitions)
      FileUtils.mkdir_p(output_dir)
      containers = [false, true]
      workloads = FAMILIES.flat_map do |family|
        containers.map do |placeable|
          bytes = build(family: family, repetitions: repetitions, placeable: placeable)
          filename = "#{family}-#{placeable ? 'placeable' : 'standard'}.wmf"
          File.binwrite(File.join(output_dir, filename), bytes)
          { "path" => filename, "sha256" => Digest::SHA256.hexdigest(bytes), "size_bytes" => bytes.bytesize,
            "family" => family, "repetitions" => repetitions, "placeable" => placeable, "provenance" => "synthetic" }
        end
      end
      manifest = { "schema_version" => 1, "workloads" => workloads }
      File.write(File.join(output_dir, MANIFEST_FILENAME), "#{JSON.pretty_generate(manifest)}\n")
      manifest
    end

    def validate_repetitions(repetitions)
      return if repetitions.is_a?(Integer) && repetitions.between?(1, MAX_REPETITIONS)

      raise ArgumentError, "repetitions must be an integer between 1 and #{MAX_REPETITIONS}"
    end

    def workload_records(family)
      case family
      when "geometry"
        [record(0x0214, [-30, 20].pack("s<2")), record(0x0213, [40, -50].pack("s<2"))]
      when "text"
        text = "WMF text!".b
        [record(0x0521, "#{[text.bytesize].pack('s<')}#{text}\0#{[-20, 30].pack('s<2')}")]
      when "bitmap"
        # A 1x1, 24-bit BI_RGB DIB has one BGR pixel and a DWORD-aligned scanline.
        dib = [40, 1, 1, 1, 24, 0, 4, 0, 0, 0, 0].pack("Vl<2v2V6") + "\x33\x66\x99\0".b
        [record(0x0B41, [0x00CC0020].pack("V") + [1, 1, 0, 0, 1, 1, -10, 20].pack("s<8") + dib)]
      when "unknown"
        [record(0x80FE, "\x00\xFFopaque".b)]
      end
    end
    private_class_method :workload_records

    def record(function, payload)
      [3 + (payload.bytesize / 2), function].pack("Vv") + payload
    end
    private_class_method :record

    def placeable_header
      bytes = [0x9AC6CDD7, 0, -100, -100, 100, 100, 1440, 0].pack("Vvs<4vV")
      bytes + [bytes.unpack("v10").reduce(0, :^)].pack("v")
    end
    private_class_method :placeable_header
  end
end
