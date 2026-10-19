#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "support/parser_benchmark"

exit ParserBenchmark::CLI.new(ARGV).run
