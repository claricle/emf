# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "process_supervisor"

module EmfPlusCliCompatibility
  # Capture the two channels separately while the existing supervisor bounds the
  # whole process group. File sizes also bound dump output without pipe deadlocks.
  class Capture < ProcessSupervisor
    def initialize(paths)
      super(wall_seconds: 60, rss_limit_bytes: 512 * 1024 * 1024, output_limit: 16 * 1024 * 1024)
      @paths = paths
    end

    private

    def breach(started, peak, output, monitored)
      super || (:output_limit if @paths.sum { |path| File.size?(path).to_i } > @output_limit)
    end
  end

  module_function

  def reference_cli(root, directory)
    # Exact exe/emf from 97c5885d58b4c366df317f9af4accbe3cdde0ec5.
    # Keep the oracle available in shallow checkouts and source archives.
    source = File.binread(File.join(root, "spec/fixtures/cli/emf-97c5885.txt"))
    expected = "fd311333701e16fe848419495982153e6bc60921d014775ffbcddfd9e04150fa"
    raise "historical CLI fixture digest mismatch" unless Digest::SHA256.hexdigest(source) == expected

    path = File.join(directory, "previous-emf.rb")
    File.write(path, source)
    path
  end

  def capture_cli(root, executable, command, fixture, prefix)
    paths = %w[stdout stderr].map { |channel| "#{prefix}.#{channel}" }
    # exec preserves the actual entrypoint, ARGV and exit status, including errors.
    launcher = '$stdout.reopen(ARGV.shift, "wb"); $stderr.reopen(ARGV.shift, "wb"); exec(*ARGV)'
    invocation = [RbConfig.ruby, "-I#{root}/lib", executable, command, fixture]
    result = Capture.new(paths).call([RbConfig.ruby, "-e", launcher, *paths, *invocation], env: { "EMF_BACKEND" => "ruby" })
    observation = {
      status: result.status.to_s, exit_code: result.exit_code, signal: result.signal, elapsed: result.elapsed,
      peak_rss_bytes: result.peak_rss_bytes, stdout: File.binread(paths.first), stderr: File.binread(paths.last)
    }
    File.write("#{prefix}.json", JSON.pretty_generate(observation.except(:stdout, :stderr).merge(
                                                        stdout_sha256: Digest::SHA256.hexdigest(observation.fetch(:stdout)),
                                                        stderr_sha256: Digest::SHA256.hexdigest(observation.fetch(:stderr))
                                                      )))
    observation
  end
end
