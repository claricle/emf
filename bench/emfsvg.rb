#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "support/emfsvg_benchmark"

exit EmfsvgBenchmark::CLI.new(ARGV).run
