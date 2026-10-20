#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "support/emfsvg_comparison"

exit EmfsvgComparison::CLI.new(ARGV).run
