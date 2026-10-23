# frozen_string_literal: true

require_relative "../../bench/support/wmf_workloads"

module WmfResilienceSeeds
  MANIFEST_FILENAME = "seeds-manifest.json"

  module_function

  # expected_outcome describes the Ruby parser; other parsers may report diagnostics.
  def build
    valid_seeds + malformed_seeds
  end

  def valid_seeds
    containers = [false, true]
    ParserBenchmark::WmfWorkloads::FAMILIES.flat_map do |family|
      containers.map do |placeable|
        { "name" => "valid-#{family}-#{placeable ? 'placeable' : 'standard'}",
          "family" => family, "placeable" => placeable, "expected_outcome" => "parsed",
          "recipe" => "workload-repetitions-1",
          "bytes" => ParserBenchmark::WmfWorkloads.build(family: family, repetitions: 1, placeable: placeable) }
      end
    end
  end

  def malformed_seeds
    [
      malformed_seed("header-size", recipe: "set standard header size at byte 2 to 8 words") do |bytes|
        bytes[2, 2] = [8].pack("v")
      end,
      malformed_seed("file-size", expected_outcome: "recovered", recipe: "set standard file size at byte 6 to 8 words") do |bytes|
        bytes[6, 4] = [8].pack("V")
      end,
      malformed_seed("max-record", expected_outcome: "recovered", recipe: "set maximum record size at byte 12 to zero") do |bytes|
        bytes[12, 4] = [0].pack("V")
      end,
      malformed_seed("zero-record", recipe: "set first record size at byte 18 to zero") do |bytes|
        bytes[18, 4] = [0].pack("V")
      end,
      malformed_seed("missing-eof", recipe: "remove final 6-byte EOF record and repair standard file size") do |bytes|
        bytes.slice!(-6, 6)
        bytes[6, 4] = [bytes.bytesize / 2].pack("V")
      end,
      malformed_seed("negative-text-count", family: "text", recipe: "set text count at byte 24 to signed -1") do |bytes|
        bytes[24, 2] = [65_535].pack("v")
      end,
      malformed_seed("placeable-checksum", placeable: true, recipe: "XOR placeable checksum byte 20 with 1") do |bytes|
        bytes.setbyte(20, bytes.getbyte(20) ^ 1)
      end,
      malformed_seed("bitmap-short-record", family: "bitmap", recipe: "set first bitmap record size at byte 18 to 3 words") do |bytes|
        bytes[18, 4] = [3].pack("V")
      end
    ]
  end
  private_class_method :valid_seeds, :malformed_seeds

  def malformed_seed(name, recipe:, expected_outcome: "rejected", family: "geometry", placeable: false)
    bytes = ParserBenchmark::WmfWorkloads.build(family: family, repetitions: 1, placeable: placeable)
    yield bytes
    { "name" => name, "family" => family, "placeable" => placeable, "expected_outcome" => expected_outcome,
      "recipe" => recipe, "bytes" => bytes }
  end
  private_class_method :malformed_seed

  def write(output_dir:)
    FileUtils.mkdir_p(output_dir)
    seeds = build.map do |seed|
      filename = "#{seed.fetch('name')}.wmf"
      bytes = seed.fetch("bytes")
      File.binwrite(File.join(output_dir, filename), bytes)
      seed.except("bytes").merge(
        "path" => filename, "sha256" => Digest::SHA256.hexdigest(bytes), "size_bytes" => bytes.bytesize,
        "provenance" => "synthetic"
      )
    end
    manifest = { "schema_version" => 1, "seeds" => seeds }
    File.write(File.join(output_dir, MANIFEST_FILENAME), "#{JSON.pretty_generate(manifest)}\n")
    manifest
  end
end
