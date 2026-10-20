# frozen_string_literal: true

require "json"

# Usage: ruby installed_workload.rb FIXTURE
# Runs against the emf gem installed in GEM_HOME (never the checkout), forcing
# the native backend: parse, dump, mutate, serialize, reparse.

# Flip to true once gem-relative library discovery has landed in lib/emf/native.
DISCOVERY_REQUIRED = false

ENV["EMF_BACKEND"] = "native"
spec = Gem::Specification.find_by_name("emf")
manifest = JSON.parse(File.read(File.join(spec.gem_dir, "lib/emf/native/platforms.json")))
library = File.join(spec.gem_dir, "lib/emf/native", manifest.fetch("platform"), manifest.fetch("library"))
abort "installed library missing: #{library}" unless File.file?(library)
abort "emf resolved outside GEM_HOME: #{spec.gem_dir}" unless spec.gem_dir.start_with?(File.expand_path(ENV.fetch("GEM_HOME")))
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
abort "gem-relative library discovery is required" if DISCOVERY_REQUIRED && !discovered

ENV["EMF_NATIVE_LIBRARY"] = library
abort "native backend NOT selected" unless Emf::Backend.send(:selected).instance_of?(Emf::Native::Adapter)

bytes = File.binread(ARGV.fetch(0))
meta = Emf.parse(bytes)
puts "parsed: format=#{meta.format} records=#{meta.records.size}"
abort "dump differs from input" unless Emf.serialize(meta) == bytes
puts "dump: roundtrip_identical=true"

record = meta.records.find { |r| r.wire.class.name.end_with?("SetTextColor") } or abort "no SetTextColor record"
original = record.wire.color.red.to_i
record.wire.color.red = original == 0xAB ? 0xAC : 0xAB
mutated = Emf.serialize(meta)
reparsed = Emf.parse(mutated)
unless mutated != bytes && mutated.bytesize == bytes.bytesize &&
       reparsed.records.size == meta.records.size && Emf.serialize(reparsed) == mutated
  abort "mutation not observed or not stable"
end
puts "mutate: SetTextColor color.red #{original} -> #{record.wire.color.red.to_i}, reparse+reserialize identical"
puts "ok"
