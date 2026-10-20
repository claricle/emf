# frozen_string_literal: true

require "io/wait"

# Signals and reaps a whole process group, tolerating darwin's zombie-leader EPERM.
module ProcessGroup
  module_function

  # TERM, a short grace, then KILL; always reaps. KILL also reaches grandchildren left behind by a clean exit.
  # The leader is reaped before KILL because darwin answers EPERM when signalling a group whose leader is a zombie.
  def terminate(pid, grace)
    signal_group("TERM", pid)
    deadline = now + grace
    reaped = reaped_by?(pid, deadline)
    signal_group("KILL", pid)
    Process.wait(pid) unless reaped
  rescue Errno::ECHILD
    nil
  end

  # ECHILD means the leader was already reaped; the group KILL must still be sent.
  def reaped_by?(pid, deadline)
    until Process.wait2(pid, Process::WNOHANG)
      return false if now >= deadline

      sleep 0.01
    end
    true
  rescue Errno::ECHILD
    true
  end

  # darwin refuses a group signal (EPERM) while the group holds a zombie or orphan in transition:
  # reap the leader and retry, then fall back to signalling each member of the group.
  def signal_group(name, pid, retried: false)
    Process.kill(name, -pid)
  rescue Errno::ESRCH
    nil
  rescue Errno::EPERM
    return signal_members(name, pid) if retried

    reaped_by?(pid, now + 1)
    signal_group(name, pid, retried: true)
  end

  def signal_members(name, pgid)
    members(pgid).each do |member|
      Process.kill(name, member)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end
  end

  # `ps -g` means different things on Linux and darwin; filtering `-A` output by pgid is the portable form.
  def members(pgid)
    IO.popen(%w[ps -A -o pid=,pgid=], err: File::NULL, &:read).each_line.filter_map do |line|
      member, group = line.split.map(&:to_i)
      member if group == pgid
    end
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

# Runs a command in its own process group under wall-clock, RSS and output limits.
class ProcessSupervisor
  MAX_WALL_SECONDS = 60
  SAMPLE_INTERVAL = 0.05
  TERM_GRACE = 0.2

  Result = Struct.new(:status, :exit_code, :signal, :elapsed, :peak_rss_bytes, :output, keyword_init: true) do
    def success?
      status == :exited && exit_code.zero?
    end
  end

  def initialize(wall_seconds:, rss_limit_bytes: nil, output_limit: 16_384)
    raise NotImplementedError, "ProcessSupervisor needs POSIX process groups" if Gem.win_platform?
    raise ArgumentError, "rss_limit_bytes is required" unless rss_limit_bytes
    raise ArgumentError, "wall_seconds must be in 1..#{MAX_WALL_SECONDS}" unless (1..MAX_WALL_SECONDS).cover?(wall_seconds)

    @wall_seconds = wall_seconds
    @rss_limit_bytes = rss_limit_bytes
    @output_limit = output_limit
  end

  def call(command, env: {})
    reader, writer = IO.pipe
    started = now
    pid = Process.spawn(env, *command, in: File::NULL, out: writer, err: writer, pgroup: true)
    writer.close
    supervise(pid, reader, started)
  ensure
    writer&.close unless writer&.closed?
    reader&.close
    ProcessGroup.terminate(pid, TERM_GRACE) if pid
  end

  private

  def supervise(pid, reader, started)
    output = +""
    peak = 0
    loop do
      drain(reader, output)
      peak = [peak, group_rss_bytes(pid)].max
      reaped = Process.wait2(pid, Process::WNOHANG)
      return finish(reaped.last, started, peak, drain(reader, output)) if reaped

      breach = breach(started, peak, output)
      return killed(pid, breach, started, peak, output) if breach

      reader.wait_readable(SAMPLE_INTERVAL)
    end
  end

  def breach(started, peak, output)
    return :output_limit if output.bytesize > @output_limit
    return :rss_exceeded if peak > @rss_limit_bytes

    :timed_out if now - started >= @wall_seconds
  end

  def drain(reader, output)
    while (chunk = reader.read_nonblock(4096, exception: false)).is_a?(String)
      output << chunk
      break if output.bytesize > @output_limit
    end
    output
  end

  # A limit breached before the exit was noticed still wins: an exit never launders a breach into success.
  def finish(process_status, started, peak, output)
    status = breach(started, peak, output) || (process_status.signaled? ? :signaled : :exited)
    build(status, started, peak, output, exit_code: process_status.exitstatus, signal: process_status.termsig)
  end

  def killed(pid, status, started, peak, output)
    ProcessGroup.terminate(pid, TERM_GRACE)
    build(status, started, peak, output, exit_code: nil, signal: nil)
  end

  def build(status, started, peak, output, exit_code:, signal:)
    Result.new(status: status, exit_code: exit_code, signal: signal, elapsed: now - started,
               peak_rss_bytes: peak, output: output.byteslice(0, @output_limit)).freeze
  end

  # `ps -g` means different things on Linux and darwin; filtering `-A` output by pgid is the portable form.
  def group_rss_bytes(pgid)
    rows = IO.popen(%w[ps -A -o pid=,pgid=,rss=], err: File::NULL, &:read)
    rows.each_line.sum do |line|
      _pid, group, rss_kib = line.split
      group.to_i == pgid ? rss_kib.to_i * 1024 : 0
    end
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
