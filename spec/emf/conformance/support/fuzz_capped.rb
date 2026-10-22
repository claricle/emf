# frozen_string_literal: true

module Emf
  module SpecSupport
    # Runs a block in a forked child that the parent kills past a memory or CPU budget. macOS ignores
    # RLIMIT_AS, so the parent polls `ps`. Returns :ok, :raised or :over_budget.
    # The memory budget is growth over the child's first reading: on Linux a forked child's RSS already
    # counts the parent's shared pages, so a large test process would otherwise exceed it at once.
    module FuzzCapped
      MAX_GROWTH_KB = 400_000
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
        baseline = nil
        loop do
          finished, status = Process.waitpid2(pid, Process::WNOHANG)
          return status.exitstatus.zero? ? :ok : :raised if finished

          rss = rss_kb(pid)
          baseline ||= rss
          return kill(pid) if over_budget?(rss - baseline, cpu_seconds(`ps -o time= -p #{pid}`))

          sleep 0.02
        end
      end

      def over_budget?(growth_kb, cpu) = growth_kb > MAX_GROWTH_KB || cpu > MAX_CPU_SECONDS

      def rss_kb(pid) = `ps -o rss= -p #{pid}`.to_i

      # `ps -o time=` prints M:SS.ss on macOS and [DD-]HH:MM:SS on Linux.
      def cpu_seconds(text)
        days, clock = text.strip.include?("-") ? text.strip.split("-", 2) : [0, text.strip]
        seconds = clock.split(":").reduce(0.0) { |total, part| (total * 60) + part.to_f }
        (days.to_i * 86_400) + seconds
      end

      def kill(pid)
        Process.kill("KILL", pid)
        Process.wait(pid)
        :over_budget
      end
    end
  end
end
