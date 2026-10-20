#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "support/native_components_benchmark"

exit NativeComponentsBenchmark::CLI.new(ARGV).run
