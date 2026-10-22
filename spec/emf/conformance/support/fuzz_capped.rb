# frozen_string_literal: true

module Emf
  module SpecSupport
    # Runs a block in a forked child that the parent kills past a memory or CPU budget. macOS ignores
    # RLIMIT_AS, so the parent polls `ps`. Returns :ok, :raised or :over_budget.
    module FuzzCapped
      MAX_RSS_KB = 400_000
      MAX_CPU_SECONDS = 4.0

      module_function

      def run
        pid = fork do
          yield
          exit!(0)
        rescue StandardError, NoMemoryError
          exit!(3)
        end
        watch(pid)
      end

      def watch(pid)
        loop do
          finished, status = Process.waitpid2(pid, Process::WNOHANG)
          return status.exitstatus.zero? ? :ok : :raised if finished
          return kill(pid) if over_budget?(pid)

          sleep 0.02
        end
      end

      def over_budget?(pid)
        `ps -o rss= -p #{pid}`.to_i > MAX_RSS_KB || cpu_seconds(pid) > MAX_CPU_SECONDS
      end

      def cpu_seconds(pid)
        minutes, seconds = `ps -o time= -p #{pid}`.strip.split(":")
        (minutes.to_i * 60) + seconds.to_f
      end

      def kill(pid)
        Process.kill("KILL", pid)
        Process.wait(pid)
        :over_budget
      end
    end
  end
end
