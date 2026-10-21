# frozen_string_literal: true

require "fiddle"

# Windows Job Objects contain descendants, including those surviving a clean leader exit.
# No breakaway flag is enabled. Native handles, rather than Ruby's POSIX wait/group API,
# own the process lifetime. Loading this file does not load a Windows DLL on POSIX.
class WindowsProcessSupervisor
  class NativeError < StandardError; end

  def initialize(wall_seconds:, rss_limit_bytes:, output_limit:, native: nil)
    @wall_seconds = wall_seconds
    @rss_limit_bytes = rss_limit_bytes
    @output_limit = output_limit
    @native = native
  end

  def call(command, env: {})
    started = now
    output = +"".b
    peak = 0
    status = :monitor_failed
    exit_code = nil
    begin
      @native ||= Native.new
      @native.start(command, env)
      loop do
        output << @native.read_output(@output_limit + 1 - output.bytesize)
        peak = [peak, @native.rss_bytes].max
        exit_code = @native.exit_code
        status = breach(started, peak, output)
        break if status

        if exit_code
          # Capture bytes written between the previous drain and process exit.
          output << @native.read_output(@output_limit + 1 - output.bytesize)
          status = breach(started, peak, output) || :exited
          break
        end
        sleep ProcessSupervisor::SAMPLE_INTERVAL
      end
    rescue NativeError, Fiddle::DLError => e
      status = :monitor_failed
      output << "\n#{e.message}".b.byteslice(0, [@output_limit + 1 - output.bytesize, 0].max)
    ensure
      begin
        @native&.cleanup
      rescue NativeError
        status = :cleanup_failed
      end
    end
    ProcessSupervisor::Result.new(status: status, exit_code: exit_code, signal: nil, elapsed: now - started,
                                  peak_rss_bytes: peak, output: output.byteslice(0, @output_limit)).freeze
  end

  private

  def breach(started, peak, output)
    return :output_limit if output.bytesize > @output_limit
    return :rss_exceeded if peak > @rss_limit_bytes

    :timed_out if now - started >= @wall_seconds
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Explicit Win32 widths: DWORD is an unsigned 32-bit value even on Win64 (unlike
  # Unix unsigned long), so flags such as GENERIC_READ (0x80000000) fit; BOOL is a
  # signed 32-bit int.
  class API
    PTR = Fiddle::TYPE_VOIDP
    DWORD = Fiddle.const_defined?(:TYPE_UINT32_T) ? Fiddle::TYPE_UINT32_T : -Fiddle::TYPE_INT32_T
    BOOL = Fiddle::TYPE_INT32_T
    # ResumeThread returns (DWORD)-1 on failure.
    RESUME_FAILED = 0xFFFFFFFF
    SIGNATURES = {
      "CreateJobObjectW" => [[PTR, PTR], PTR],
      "SetInformationJobObject" => [[PTR, DWORD, PTR, DWORD], BOOL],
      "CreatePipe" => [[PTR, PTR, PTR, DWORD], BOOL],
      "SetHandleInformation" => [[PTR, DWORD, DWORD], BOOL],
      "CreateFileW" => [[PTR, DWORD, DWORD, PTR, DWORD, DWORD, PTR], PTR],
      "CreateProcessW" => [[PTR, PTR, PTR, PTR, BOOL, DWORD, PTR, PTR, PTR, PTR], BOOL],
      "AssignProcessToJobObject" => [[PTR, PTR], BOOL],
      "ResumeThread" => [[PTR], DWORD],
      "PeekNamedPipe" => [[PTR, PTR, DWORD, PTR, PTR, PTR], BOOL],
      "ReadFile" => [[PTR, PTR, DWORD, PTR, PTR], BOOL],
      "QueryInformationJobObject" => [[PTR, DWORD, PTR, DWORD, PTR], BOOL],
      "OpenProcess" => [[DWORD, BOOL, DWORD], PTR],
      "K32GetProcessMemoryInfo" => [[PTR, PTR, DWORD], BOOL],
      "WaitForSingleObject" => [[PTR, DWORD], DWORD],
      "GetExitCodeProcess" => [[PTR, PTR], BOOL],
      "TerminateJobObject" => [[PTR, DWORD], BOOL],
      "TerminateProcess" => [[PTR, DWORD], BOOL],
      "CloseHandle" => [[PTR], BOOL],
      "GetLastError" => [[], DWORD]
    }.freeze

    def initialize
      @library = Fiddle.dlopen("kernel32.dll")
      abi = Fiddle::Function.const_defined?(:STDCALL) ? Fiddle::Function::STDCALL : Fiddle::Function::DEFAULT
      @functions = SIGNATURES.to_h do |name, (args, result)|
        [name, Fiddle::Function.new(@library[name], args, result, abi)]
      end
    end

    def call(name, *args)
      # Fiddle saves the native thread's error before returning to Ruby. A second
      # DLL call can observe an error overwritten by Ruby's GVL/thread machinery.
      return Fiddle.win32_last_error if name == "GetLastError"

      @functions.fetch(name).call(*args)
    end
  end

  # Buffer layouts and process creation are kept together to make the Win32 ABI auditable.
  module NativeSupport
    POINTER_BYTES = Fiddle::SIZEOF_VOIDP
    POINTER_PACK = POINTER_BYTES == 8 ? "Q<" : "L<"
    CLEANUP_SECONDS = 2

    private

    def pipe
      security = buffer(POINTER_BYTES == 8 ? 24 : 12)
      security[0, 4] = [security.bytesize].pack("L<")
      security[POINTER_BYTES == 8 ? 16 : 8, 4] = [1].pack("L<")
      reader = buffer(POINTER_BYTES)
      writer = buffer(POINTER_BYTES)
      check("CreatePipe", reader, writer, security, 0)
      @reader, @writer = [reader, writer].map { |value| track(value.unpack1(POINTER_PACK)) }
      check("SetHandleInformation", @reader, 1, 0)
      @input = handle("CreateFileW", wide("NUL"), 0x80000000, 3, security, 3, 0, 0)
    end

    def spawn(command, env)
      raise ArgumentError, "command must be a nonempty argv array" unless command.is_a?(Array) && !command.empty?

      startup = buffer(POINTER_BYTES == 8 ? 104 : 68)
      startup[0, 4] = [startup.bytesize].pack("L<")
      startup[POINTER_BYTES == 8 ? 60 : 44, 4] = [0x100].pack("L<") # STARTF_USESTDHANDLES
      startup[POINTER_BYTES == 8 ? 80 : 56, POINTER_BYTES * 3] = [@input, @writer, @writer].pack("#{POINTER_PACK}3")
      info = buffer((POINTER_BYTES * 2) + 8)
      environment = environment_block(env)
      check("CreateProcessW", 0, wide(command.map { |arg| quote(arg) }.join(" ")), 0, 0, 1,
            0x404, environment, 0, startup, info) # CREATE_SUSPENDED | CREATE_UNICODE_ENVIRONMENT
      @process, @thread = info.unpack("#{POINTER_PACK}2").map { |value| track(value) }
      close(@writer)
      close(@input)
    end

    # MS C runtime argv quoting: double backslashes before quotes and the closing quote.
    def quote(argument)
      value = String(argument)
      raise ArgumentError, "NUL in command argument" if value.include?("\0")

      escaped = value.gsub(/(\\*)"/) { "#{Regexp.last_match(1) * 2}\\\"" }.sub(/(\\+)\z/) { Regexp.last_match(1) * 2 }
      %("#{escaped}")
    end

    def environment_block(env)
      values = ENV.to_h
      env.each do |key, value|
        values.delete_if { |existing, _| existing.casecmp?(key) }
        values[key] = value unless value.nil?
      end
      entries = values.sort_by { |key, _| key.upcase }.map { |key, value| "#{key}=#{value}" }
      wide("#{entries.join("\0")}\0")
    end

    def job_pids
      # A fixed cap bounds enumeration. ERROR_MORE_DATA fails closed.
      list = buffer(8 + (POINTER_BYTES * Native::MAX_PROCESSES))
      check("QueryInformationJobObject", @job, 3, list, list.bytesize, 0)
      assigned, count = list.unpack("L<2")
      raise NativeError, "incomplete job process list" if assigned != count || count > Native::MAX_PROCESSES

      list.byteslice(8, count * POINTER_BYTES).unpack("#{POINTER_PACK}*")
    end

    def terminate_job
      # ActiveProcesses == 0 is job accounting, not a process-signaling barrier.
      # Retain current members before termination so cleanup also waits for them.
      members = []
      begin
        job_pids.each { |pid| members << handle("OpenProcess", 0x100000, 0, pid) }
      ensure
        # Even a failed snapshot must not leave the live job running.
        check("TerminateJobObject", @job, 1)
        wait_empty
      end
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + CLEANUP_SECONDS
      members.each do |process|
        remaining = [(deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)) * 1000, 0].max.to_i
        raise NativeError, "terminated descendant did not finish" unless @api.call("WaitForSingleObject", process, remaining).zero?
      end
    end

    def check_wait
      return if @api.call("WaitForSingleObject", @process, CLEANUP_SECONDS * 1000).zero?

      raise NativeError, "terminated process did not finish"
    end

    def check(name, *args)
      return if @api.call(name, *args).positive?

      raise NativeError, "#{name} failed (Win32 #{@api.call('GetLastError')})"
    end

    def handle(name, *args)
      value = @api.call(name, *args).to_i
      raise NativeError, "#{name} failed" if [0, -1, (1 << (POINTER_BYTES * 8)) - 1].include?(value)

      track(value)
    end

    def track(value)
      @handles << value
      value
    end

    def close(value)
      check("CloseHandle", value)
      @handles.delete(value)
    end

    def buffer(size)
      "\0".b * size
    end

    def wide(value)
      "#{value}\0".encode(Encoding::UTF_16LE).b
    end
  end

  class Native
    include NativeSupport

    MAX_PROCESSES = 4096

    def initialize(api: API.new)
      @api = api
      @handles = []
    end

    def start(command, env)
      @job = handle("CreateJobObjectW", 0, 0)
      limits = buffer(POINTER_BYTES == 8 ? 144 : 112)
      limits[16, 4] = [0x2000].pack("L<") # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
      check("SetInformationJobObject", @job, 9, limits, limits.bytesize)
      pipe
      spawn(command, env)
      check("AssignProcessToJobObject", @job, @process)
      @assigned = true
      @initial_rss = rss_bytes
      raise NativeError, "ResumeThread failed" if @api.call("ResumeThread", @thread) == API::RESUME_FAILED
    end

    def read_output(maximum)
      return "".b if maximum <= 0

      output = +"".b
      while output.bytesize < maximum
        available = buffer(4)
        unless @api.call("PeekNamedPipe", @reader, 0, 0, 0, available, 0).positive?
          return output if @api.call("GetLastError") == 109 # ERROR_BROKEN_PIPE: all writers exited

          raise NativeError, "PeekNamedPipe failed"
        end
        count = [available.unpack1("L<"), maximum - output.bytesize, 4096].min
        break if count.zero?

        bytes = buffer(count)
        read = buffer(4)
        check("ReadFile", @reader, bytes, count, read, 0)
        length = read.unpack1("L<")
        raise NativeError, "ReadFile made no progress" if length.zero?

        output << bytes.byteslice(0, length)
      end
      output
    end

    def rss_bytes
      pids = job_pids
      raise NativeError, "empty initial job RSS sample" if pids.empty? && @initial_rss.nil?

      sample = pids.sum { |pid| process_rss(pid) }
      [sample, @initial_rss.to_i].max
    end

    def exit_code
      case @api.call("WaitForSingleObject", @process, 0)
      when 258 then nil # WAIT_TIMEOUT
      when 0
        code = buffer(4)
        check("GetExitCodeProcess", @process, code)
        code.unpack1("L<")
      else raise NativeError, "process wait failed"
      end
    end

    def cleanup
      failure = nil
      begin
        if @assigned
          terminate_job
        elsif @process
          check("TerminateProcess", @process, 1)
        end
        check_wait if @process
      rescue NativeError => e
        failure = e
      ensure
        # Close the job last: kill-on-close remains a fallback if explicit termination fails.
        @handles.reverse_each do |value|
          failure ||= NativeError.new("CloseHandle failed") unless @api.call("CloseHandle", value).positive?
        end
        @handles.clear
      end
      raise failure if failure
    end

    private

    def process_rss(pid)
      process = handle("OpenProcess", 0x410, 0, pid) # QUERY_INFORMATION | VM_READ
      begin
        counters = buffer(POINTER_BYTES == 8 ? 72 : 40)
        counters[0, 4] = [counters.bytesize].pack("L<")
        check("K32GetProcessMemoryInfo", process, counters, counters.bytesize)
        counters.byteslice(8 + POINTER_BYTES, POINTER_BYTES).unpack1(POINTER_PACK)
      ensure
        close(process)
      end
    end

    def wait_empty
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + CLEANUP_SECONDS
      loop do
        accounting = buffer(48)
        check("QueryInformationJobObject", @job, 1, accounting, accounting.bytesize, 0)
        return if accounting.byteslice(40, 4).unpack1("L<").zero?
        raise NativeError, "job did not empty after termination" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end
    end
  end
end
