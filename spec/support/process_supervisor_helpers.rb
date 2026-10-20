# frozen_string_literal: true

require "rbconfig"

# Child-process helpers for process_supervisor_spec.rb.
module ProcessSupervisorHelpers
  # A bare Ruby without Bundler's RUBYOPT: these children need no gems and must start fast on a loaded runner.
  def ruby(code)
    ["env", "-u", "RUBYOPT", RbConfig.ruby, "--disable-gems", "-e", code]
  end

  def with_path(path)
    original = ENV.fetch("PATH")
    ENV["PATH"] = path
    yield
  ensure
    ENV["PATH"] = original
  end

  # A killed orphan stays signalable as a zombie until init reaps it, so allow that brief window.
  def alive?(pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    loop do
      Process.kill(0, pid)
      return true if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end
  rescue Errno::ESRCH
    false
  end
end
