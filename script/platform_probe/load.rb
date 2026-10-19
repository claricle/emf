# frozen_string_literal: true

# Usage: ruby load.rb LIBRARY INTENDED_PLATFORM
# Prints exactly one JSON line; exits non-zero when loading or a call fails.

require "json"
require "rbconfig"

module PlatformProbe
  PAYLOAD = "emf-probe\x00\xFF\x01".b.freeze
  TOOLS = %w[cc gcc clang rustc].freeze

  module_function

  def on_path?(tool)
    exts = ENV.fetch("PATHEXT", "").split(";").push("")
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
      exts.any? { |ext| File.executable?(File.join(dir, tool + ext)) }
    end
  end

  def fiddle_available?
    require "fiddle"
    true
  rescue LoadError
    false
  end

  def call_library(path)
    require "fiddle"
    handle = Fiddle::Handle.new(path)
    version = abi_version(handle)
    [version, round_trip?(handle)]
  end

  def abi_version(handle)
    Fiddle::Function.new(handle["emf_probe_abi_version"], [], Fiddle::TYPE_INT).call
  end

  def round_trip?(handle)
    reverse = Fiddle::Function.new(
      handle["emf_probe_reverse"],
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
      Fiddle::TYPE_SIZE_T
    )
    output = Fiddle::Pointer.malloc(PAYLOAD.bytesize)
    written = reverse.call(Fiddle::Pointer[PAYLOAD], PAYLOAD.bytesize, output, PAYLOAD.bytesize)
    written == PAYLOAD.bytesize && output.to_s(written) == PAYLOAD.reverse
  end

  def report(library, intended)
    local = Gem::Platform.local.to_s
    {
      ruby_version: RUBY_VERSION,
      ruby_platform: RUBY_PLATFORM,
      gem_platform_local: local,
      intended_platform: intended,
      platform_match: Gem::Platform.new(intended) === Gem::Platform.local, # rubocop:disable Style/CaseEquality
      platform_exact: local == intended,
      fiddle_available: fiddle_available?,
      library: library,
      tools_on_path: TOOLS.to_h { |tool| [tool, on_path?(tool)] }
    }
  end

  def run(library, intended)
    result = report(library, intended)
    begin
      version, round_trip = call_library(library)
      result.merge!(abi_version: version, round_trip_ok: round_trip, error: nil)
    rescue LoadError, StandardError => e
      result.merge!(abi_version: nil, round_trip_ok: false, error: "#{e.class}: #{e.message}")
    end
    result
  end
end

if $PROGRAM_NAME == __FILE__
  library, intended = ARGV
  abort "usage: ruby load.rb LIBRARY INTENDED_PLATFORM" unless library && intended

  result = PlatformProbe.run(File.expand_path(library), intended)
  puts JSON.generate(result)
  exit(result[:round_trip_ok] && result[:abi_version] == 1 ? 0 : 1)
end
