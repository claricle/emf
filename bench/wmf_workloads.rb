#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "support/wmf_workloads"

module ParserBenchmark
  module WmfWorkloads
    class CLI
      def initialize(argv)
        @argv = argv
      end

      def run
        output_dir = nil
        repetitions = 100
        parser = OptionParser.new do |options|
          options.banner = "Usage: ruby bench/wmf_workloads.rb --output-dir DIR [--repetitions N]"
          options.on("--output-dir DIR", "Directory for synthetic WMF files and manifest") { |value| output_dir = value }
          options.on("--repetitions N", Integer, "Workload repetitions (1..10000; default: 100)") { |value| repetitions = value }
          options.on("-h", "--help", "Show this help") do
            puts options
            return 0
          end
        end
        parser.parse!(@argv)
        raise ArgumentError, "unexpected arguments: #{@argv.join(' ')}" unless @argv.empty?
        raise ArgumentError, "--output-dir is required" if output_dir.nil? || output_dir.empty?

        WmfWorkloads.write(output_dir: output_dir, repetitions: repetitions)
        puts File.expand_path(File.join(output_dir, MANIFEST_FILENAME))
        0
      rescue ArgumentError, OptionParser::ParseError => e
        warn e.message
        1
      end
    end
  end
end

exit ParserBenchmark::WmfWorkloads::CLI.new(ARGV).run if $PROGRAM_NAME == __FILE__
