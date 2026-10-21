# frozen_string_literal: true

require "emf"
require "json"
require "digest"
require_relative "malformed_parity"

$stdout.reopen(File::NULL, "w")
$stderr.reopen(File::NULL, "w")
ENV["EMF_BACKEND"] = ARGV.fetch(1)
bytes = File.binread(ARGV.fetch(0))
File.write(ARGV.fetch(2), JSON.generate(MalformedParity.observe(bytes)))
