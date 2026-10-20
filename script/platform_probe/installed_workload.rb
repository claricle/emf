# frozen_string_literal: true

require "json"

# Usage: ruby installed_workload.rb EMF_FIXTURE
# Runs against the emf gem installed in GEM_HOME (never the checkout), forcing
# native discovery, then parse/dump/edit/reparse for EMF and self-contained WMF.
module InstalledWorkload
  module_function

  def discover!
    ENV["EMF_BACKEND"] = "native"
    spec = Gem::Specification.find_by_name("emf")
    manifest = JSON.parse(File.read(File.join(spec.gem_dir, "lib/emf/native/platforms.json")))
    library = File.join(spec.gem_dir, "lib/emf/native", manifest.fetch("platform"), manifest.fetch("library"))
    abort "installed library missing: #{library}" unless File.file?(library)
    gem_home = "#{File.expand_path(ENV.fetch('GEM_HOME'))}#{File::SEPARATOR}"
    abort "emf resolved outside GEM_HOME: #{spec.gem_dir}" unless spec.gem_dir.start_with?(gem_home)
    puts "installed gem: #{spec.full_name} #{spec.gem_dir}"

    ENV.delete("EMF_NATIVE_LIBRARY")
    require "emf"
    discovered =
      begin
        Emf::Native.backend.instance_of?(Emf::Native::Adapter)
      rescue Emf::Native::Unavailable => e
        puts "discovery without EMF_NATIVE_LIBRARY: #{e.message}"
        false
      end
    puts "discovery_without_env=#{discovered ? 'works' : 'unavailable'}"
    abort "gem-relative library discovery is required" unless discovered
    abort "native backend NOT selected" unless Emf::Backend.send(:selected).instance_of?(Emf::Native::Adapter)
  end

  def run(fixture)
    check_emf(File.binread(fixture))
    [false, true].each { |placeable| check_wmf(wmf_bytes(placeable: placeable), placeable: placeable) }
    puts "ok"
  end

  def check_emf(bytes)
    meta = Emf.parse(bytes)
    puts "parsed: format=#{meta.format} records=#{meta.records.size}"
    abort "emf: dump differs from input" unless Emf.serialize(meta) == bytes
    puts "dump: roundtrip_identical=true"

    record = text_color_record(meta) or abort "emf: no SetTextColor record"
    original = record.wire.color.red.to_i
    expected = original == 0xAB ? 0xAC : 0xAB
    record.wire.color.red = expected
    mutated = Emf.serialize(meta)
    reparsed = Emf.parse(mutated)
    edited = text_color_record(reparsed)
    unless stable_mutation?(bytes, mutated, meta, reparsed) && edited && edited.wire.color.red.to_i == expected
      abort "emf: mutation not observed or not stable"
    end
    puts "mutate: SetTextColor color.red #{original} -> #{expected}, reparse+reserialize identical"
  rescue Emf::Error => e
    abort "emf: #{e.class}: #{e.message}"
  end

  def check_wmf(bytes, placeable:)
    label = "wmf #{placeable ? 'placeable' : 'standard'}"
    meta = Emf.parse(bytes)
    abort "#{label}: unexpected format #{meta.format}" unless meta.format == :wmf
    puts "parsed: format=wmf kind=#{placeable ? 'placeable' : 'standard'} records=#{meta.records.size}"
    abort "#{label}: dump differs from input" unless Emf.serialize(meta) == bytes
    puts "dump: #{label} roundtrip_identical=true"

    record = move_record(meta) or abort "#{label}: no MoveTo record"
    original = record.x
    record.x = -123
    mutated = Emf.serialize(meta)
    reparsed = Emf.parse(mutated)
    edited = move_record(reparsed)
    abort "#{label}: mutation not observed or not stable" unless stable_mutation?(bytes, mutated, meta, reparsed) && edited&.x == -123
    puts "mutate: #{label} MoveTo x #{original} -> -123, reparse+reserialize identical"
  rescue Emf::Error => e
    abort "#{label}: #{e.class}: #{e.message}"
  end

  def text_color_record(meta)
    meta.records.find { |record| record.wire.class.name.end_with?("SetTextColor") }
  end

  def move_record(meta)
    meta.records.find { |record| record.is_a?(Emf::Model::Wmf::Records::MoveTo) }
  end

  def stable_mutation?(bytes, mutated, meta, reparsed)
    mutated != bytes && mutated.bytesize == bytes.bytesize && reparsed.format == meta.format &&
      reparsed.records.size == meta.records.size && Emf.serialize(reparsed) == mutated
  end

  def wmf_bytes(placeable:)
    move = [5, 0x0214, -3, 7].pack("Vvs<2")
    eof = [3, 0].pack("Vv")
    standard = [1, 9, 0x300, 17, 0, 5, 0].pack("v3VvVv") + move + eof
    return standard unless placeable

    prefix = [0x9AC6CDD7, 0, -5, -6, 50, 60, 1440, 0].pack("Vvs<4vV")
    prefix + [prefix.unpack("v*").reduce(0, :^)].pack("v") + standard
  end
end

if $PROGRAM_NAME == __FILE__
  InstalledWorkload.discover!
  InstalledWorkload.run(ARGV.fetch(0))
end
