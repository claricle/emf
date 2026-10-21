# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require_relative "../support/process_supervisor"
require_relative "../support/windows_process_supervisor"

RSpec.describe WindowsProcessSupervisor do
  let(:limit) { 150 * 1024 * 1024 }
  let(:native) { instance_double(described_class::Native) }
  let(:supervisor) { described_class.new(wall_seconds: 2, rss_limit_bytes: limit, output_limit: 1024, native: native) }

  context "with a bounded native adapter double (not Windows runtime validation)" do
    before do
      allow(native).to receive(:start)
      allow(native).to receive(:read_output).and_return("")
      allow(native).to receive(:rss_bytes).and_return(1024)
      allow(native).to receive(:exit_code).and_return(0)
      allow(native).to receive(:cleanup)
    end

    it "selects Windows supervision through the public ProcessSupervisor API" do
      allow(Gem).to receive(:win_platform?).and_return(true)
      allow(described_class::Native).to receive(:new).and_return(native)
      result = ProcessSupervisor.new(wall_seconds: 2, rss_limit_bytes: limit).call(["ruby", "-e", "exit"])

      expect(result).to be_success
      expect(result).to be_a(ProcessSupervisor::Result)
      expect(result).to be_frozen
      expect(native).to have_received(:start).with(["ruby", "-e", "exit"], {})
      expect(native).to have_received(:cleanup)
    end

    it "preserves the POSIX process-group path" do
      allow(Gem).to receive(:win_platform?).and_return(false)
      posix = ProcessSupervisor.new(wall_seconds: 2, rss_limit_bytes: limit)
      allow(Process).to receive(:spawn).and_return(123)
      allow(ProcessGroup).to receive(:terminate)
      allow(posix).to receive(:supervise).and_return(:posix_result)
      allow(described_class::Native).to receive(:new)

      expect(posix.call(["child"], env: { "EMF_BACKEND" => "native" })).to eq(:posix_result)
      expect(Process).to have_received(:spawn).with({ "EMF_BACKEND" => "native" }, "child",
                                                    in: File::NULL, out: an_instance_of(IO), err: an_instance_of(IO), pgroup: true)
      expect(ProcessGroup).to have_received(:terminate).with(123, ProcessSupervisor::TERM_GRACE)
      expect(described_class::Native).not_to have_received(:new)
    end

    it "retains public limit validation on Windows" do
      allow(Gem).to receive(:win_platform?).and_return(true)
      expect { ProcessSupervisor.new(wall_seconds: 2) }.to raise_error(ArgumentError, /rss_limit_bytes/)
      expect { ProcessSupervisor.new(wall_seconds: 61, rss_limit_bytes: limit) }.to raise_error(ArgumentError, /wall_seconds/)
    end

    it "fails closed and cleans up when RSS monitoring fails" do
      allow(native).to receive(:rss_bytes).and_raise(described_class::NativeError, "sample failed")
      result = supervisor.call(["child"])

      expect(result.status).to eq(:monitor_failed)
      expect(result).not_to be_success
      expect(native).to have_received(:cleanup)
    end

    it "cleans up a partially initialized child when setup fails" do
      allow(native).to receive(:start).and_raise(described_class::NativeError, "assignment failed")
      result = supervisor.call(["child"])

      expect(result.status).to eq(:monitor_failed)
      expect(result.output).to include("assignment failed")
      expect(native).to have_received(:cleanup)
    end

    it "never launders cleanup failure into a successful exit" do
      allow(native).to receive(:cleanup).and_raise(described_class::NativeError, "job still active")
      result = supervisor.call(["child"])

      expect(result.status).to eq(:cleanup_failed)
      expect(result).not_to be_success
    end

    it "records an RSS breach even when the leader exits zero" do
      allow(native).to receive(:rss_bytes).and_return(limit + 1)
      result = supervisor.call(["child"])

      expect(result.status).to eq(:rss_exceeded)
      expect(result.peak_rss_bytes).to eq(limit + 1)
      expect(result).not_to be_success
    end

    it "bounds captured output and preserves an exit-time overflow" do
      allow(native).to receive(:read_output).and_return("x" * 1024, "y")
      result = supervisor.call(["child"])

      expect(result.status).to eq(:output_limit)
      expect(result.output).to eq("x" * 1024)
      expect(result).not_to be_success
    end

    it "preserves nonzero exit codes and environment overrides" do
      allow(native).to receive(:exit_code).and_return(3)
      result = supervisor.call(["child"], env: { "EMF_BACKEND" => "native" })

      expect(result.status).to eq(:exited)
      expect(result.exit_code).to eq(3)
      expect(result).not_to be_success
      expect(native).to have_received(:start).with(["child"], { "EMF_BACKEND" => "native" })
    end
  end

  context "on a real Windows runner", if: Gem.win_platform? do
    let(:supervisor) { ProcessSupervisor.new(wall_seconds: 2, rss_limit_bytes: limit, output_limit: 1024) }
    let(:ruby_command) { [RbConfig.ruby, "--disable-gems", "-e"] }

    it "kills a stalled child at the deadline" do
      result = supervisor.call(ruby_command + ["sleep 30"])

      expect(result.status).to eq(:timed_out)
      expect(result).not_to be_success
      expect(result.elapsed).to be_between(2, 6)
    end

    it "kills an excessive-memory helper and records working-set RSS" do
      # The RSS case must reach its memory bound before the separate wall-clock
      # control, including slower ARM runners. Production limits are unchanged.
      memory_supervisor = ProcessSupervisor.new(wall_seconds: 10, rss_limit_bytes: limit, output_limit: 1024)
      result = memory_supervisor.call(ruby_command + ['a = []; loop { a << ("x" * 4_000_000) }'])

      expect(result.status).to eq(:rss_exceeded)
      expect(result.peak_rss_bytes).to be > limit
      expect(result).not_to be_success
    end

    it "captures clean exit, stderr, Unicode environment and argv quoting" do
      code = 'print ENV.fetch("EMF_PROBE"); warn ARGV.fetch(0)'
      result = supervisor.call(ruby_command + [code, 'space "quote" tail\\'], env: { "EMF_PROBE" => "probe ☃" })

      expect(result).to be_success
      expect(result.output.force_encoding(Encoding::UTF_8)).to include("probe ☃", 'space "quote" tail\\')
      expect(result.peak_rss_bytes).to be_positive
    end

    it "contains and removes descendants after a clean leader exit" do
      code = 'require "rbconfig"; puts Process.spawn(RbConfig.ruby, "--disable-gems", "-e", "sleep 30")'
      result = supervisor.call(ruby_command + [code])
      api = described_class::API.new
      process = api.call("OpenProcess", 0x100000, 0, Integer(result.output.lines.first))
      begin
        expect(result).to be_success
        expect(process.to_i.zero? || api.call("WaitForSingleObject", process, 0).zero?).to be(true)
      ensure
        api.call("CloseHandle", process) unless process.to_i.zero?
      end
    end

    it "contains and removes descendants after a stalled leader" do
      code = 'require "rbconfig"; puts Process.spawn(RbConfig.ruby, "--disable-gems", "-e", "sleep 30"); $stdout.flush; sleep 30'
      result = supervisor.call(ruby_command + [code])
      api = described_class::API.new
      process = api.call("OpenProcess", 0x100000, 0, Integer(result.output.lines.first))
      begin
        expect(result.status).to eq(:timed_out)
        expect(process.to_i.zero? || api.call("WaitForSingleObject", process, 0).zero?).to be(true)
      ensure
        api.call("CloseHandle", process) unless process.to_i.zero?
      end
    end

    it "fails an output overflow even if the child exits zero" do
      result = supervisor.call(ruby_command + ['$stdout.write("x" * 1025)'])

      expect(result.status).to eq(:output_limit)
      expect(result.output.bytesize).to eq(1024)
      expect(result).not_to be_success
    end
  end
end

RSpec.describe WindowsProcessSupervisor::Native do
  let(:api) { instance_double(WindowsProcessSupervisor::API) }
  let(:native) { described_class.new(api: api) }
  let(:calls) { [] }
  let(:pointer_pack) { described_class::POINTER_PACK }
  let(:pointer_bytes) { described_class::POINTER_BYTES }

  before do
    # Exercise the real Native buffer/ordering/cleanup contract; this cannot certify the Win32 ABI.
    allow(api).to receive(:call) do |name, *args|
      calls << [name, args]
      case name
      when "CreateJobObjectW" then 10
      when "CreatePipe"
        args[0].replace([11].pack(pointer_pack))
        args[1].replace([12].pack(pointer_pack))
        1
      when "CreateFileW" then 13
      when "CreateProcessW"
        args.last[0, pointer_bytes * 2] = [14, 15].pack("#{pointer_pack}2")
        1
      when "QueryInformationJobObject"
        args[2][0, 8 + pointer_bytes] = [1, 1].pack("L<2") + [101].pack(pointer_pack) if args[1] == 3
        1
      when "OpenProcess" then 16
      when "K32GetProcessMemoryInfo"
        args[1][8 + pointer_bytes, pointer_bytes] = [2048].pack(pointer_pack)
        1
      when "WaitForSingleObject" then 0
      else 1
      end
    end
  end

  it "assigns a suspended child to a kill-on-close job before resume and closes every handle" do
    native.start(["ruby", "-e", "sleep"], {})
    native.cleanup
    names = calls.map(&:first)
    create = calls.find { |name, _| name == "CreateProcessW" }.last
    limits = calls.find { |name, _| name == "SetInformationJobObject" }.last

    expect(create[5]).to eq(0x404)
    expect(limits[1]).to eq(9)
    expect(limits[2].byteslice(16, 4).unpack1("L<")).to eq(0x2000)
    expect(names.index("AssignProcessToJobObject")).to be < names.index("ResumeThread")
    expect(names.index("TerminateJobObject")).to be < names.rindex("WaitForSingleObject")
    expect(calls.filter_map { |name, args| args.first if name == "CloseHandle" }).to contain_exactly(10, 11, 12, 13, 14, 15, 16, 16)
  end

  it "waits for captured descendants even after the job accounting is empty" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("WaitForSingleObject", 16, anything).and_return(258)

    expect { native.cleanup }.to raise_error(WindowsProcessSupervisor::NativeError, /descendant/)
    expect(calls.last).to eq(["CloseHandle", [10]])
  end

  it "still terminates the job if opening a descendant handle fails" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("OpenProcess", 0x100000, 0, 101).and_return(0)

    expect { native.cleanup }.to raise_error(WindowsProcessSupervisor::NativeError, /OpenProcess/)
    expect(calls.map(&:first)).to include("TerminateJobObject")
    expect(calls.last).to eq(["CloseHandle", [10]])
  end

  it "terminates and waits for the suspended process if job assignment fails" do
    allow(api).to receive(:call).with("AssignProcessToJobObject", 10, 14).and_return(0)
    expect { native.start(["ruby"], {}) }.to raise_error(WindowsProcessSupervisor::NativeError, /Assign/)
    native.cleanup

    expect(calls.map(&:first)).to include("TerminateProcess", "WaitForSingleObject")
    expect(calls.map(&:first)).not_to include("ResumeThread")
  end

  it "closes the job as fallback and reports explicit termination failure" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("TerminateJobObject", 10, 1).and_return(0)

    expect { native.cleanup }.to raise_error(WindowsProcessSupervisor::NativeError, /TerminateJob/)
    expect(calls.last).to eq(["CloseHandle", [10]])
  end

  it "fails closed on an incomplete job process enumeration" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("QueryInformationJobObject", 10, 3, anything, anything, 0) do |_, _, _, bytes, *_|
      bytes[0, 8] = [2, 1].pack("L<2")
      1
    end

    expect { native.rss_bytes }.to raise_error(WindowsProcessSupervisor::NativeError, /incomplete/)
  ensure
    expect { native.cleanup }.to raise_error(WindowsProcessSupervisor::NativeError, /incomplete/)
  end

  it "sums working-set bytes for every enumerated job process and closes probe handles" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("QueryInformationJobObject", 10, 3, anything, anything, 0) do |_, _, _, bytes, *_|
      bytes[0, 8 + (pointer_bytes * 2)] = [2, 2].pack("L<2") + [101, 102].pack("#{pointer_pack}2")
      1
    end

    expect(native.rss_bytes).to eq(4096)
    expect(calls.count { |name, args| name == "CloseHandle" && args == [16] }).to eq(3)
  ensure
    native.cleanup
  end

  it "closes the probe handle when GetProcessMemoryInfo fails" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("QueryInformationJobObject", 10, 3, anything, anything, 0) do |_, _, _, bytes, *_|
      bytes[0, 8 + pointer_bytes] = [1, 1].pack("L<2") + [101].pack(pointer_pack)
      1
    end
    allow(api).to receive(:call).with("K32GetProcessMemoryInfo", 16, anything, anything).and_return(0)

    expect { native.rss_bytes }.to raise_error(WindowsProcessSupervisor::NativeError, /MemoryInfo/)
    expect(calls).to include(["CloseHandle", [16]])
  ensure
    native.cleanup
  end
  it "does not resume a child unless its initial RSS sample was observed" do
    allow(api).to receive(:call).with("QueryInformationJobObject", 10, 3, anything, anything, 0).and_return(1)

    expect { native.start(["ruby"], {}) }.to raise_error(WindowsProcessSupervisor::NativeError, /initial/)
    expect(calls.map(&:first)).not_to include("ResumeThread")
  ensure
    native.cleanup
  end

  it "bounds pipe reads even when more output is already available" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("PeekNamedPipe", 11, 0, 0, 0, anything, 0) do |_, _, _, _, _, bytes, _|
      bytes.replace([100_000].pack("L<"))
      1
    end
    allow(api).to receive(:call).with("ReadFile", 11, anything, 1025, anything, 0) do |_, _, bytes, count, read, _|
      bytes.replace("x" * count)
      read.replace([count].pack("L<"))
      1
    end

    expect(native.read_output(1025)).to eq("x" * 1025)
    expect(native.read_output(0)).to eq("")
  ensure
    native.cleanup
  end

  it "distinguishes pipe EOF from a monitoring error" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("PeekNamedPipe", 11, 0, 0, 0, anything, 0).and_return(0)
    allow(api).to receive(:call).with("GetLastError").and_return(109)
    expect(native.read_output(1025)).to eq("")

    allow(api).to receive(:call).with("GetLastError").and_return(5)
    expect { native.read_output(1025) }.to raise_error(WindowsProcessSupervisor::NativeError, /Peek/)
  ensure
    native.cleanup
  end

  it "reports wait failure while still closing every owned handle" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("WaitForSingleObject", 14, 2000).and_return(-1)

    expect { native.cleanup }.to raise_error(WindowsProcessSupervisor::NativeError, /did not finish/)
    expect(calls.last).to eq(["CloseHandle", [10]])
  end

  it "reports CloseHandle failure and still attempts all remaining handles" do
    native.start(["ruby"], {})
    allow(api).to receive(:call).with("CloseHandle", 15).and_return(0)

    expect { native.cleanup }.to raise_error(WindowsProcessSupervisor::NativeError, /CloseHandle/)
    expect(calls.last).to eq(["CloseHandle", [10]])
  end
end

# Marshals values through a Fiddle closure declared with the supervisor's own
# Win32 types, so the width/signedness contract is checked on every platform
# (CI job 119157190834 failed CreateFileW on GENERIC_READ with a signed DWORD).
RSpec.describe WindowsProcessSupervisor::API do
  def round_trip(type, value)
    closure = Fiddle::Closure::BlockCaller.new(type, [type]) { |given| given }
    Fiddle::Function.new(closure, [type], type).call(value)
  end

  it "passes DWORD flags with the top bit set, such as GENERIC_READ" do
    expect(round_trip(described_class::DWORD, 0x80000000)).to eq(0x80000000)
    expect(round_trip(described_class::DWORD, 0xFFFFFFFF)).to eq(described_class::RESUME_FAILED)
  end

  it "keeps BOOL results signed" do
    expect(round_trip(described_class::BOOL, -1)).to eq(-1)
  end

  it "reads Fiddle's saved Win32 error without another native call" do
    api = described_class.allocate
    function = double("native function")
    api.instance_variable_set(:@functions, { "PeekNamedPipe" => function })
    allow(function).to receive(:call).and_return(0)
    without_partial_double_verification do
      allow(Fiddle).to receive(:win32_last_error).and_return(109)
    end

    expect(api.call("PeekNamedPipe")).to eq(0)
    expect(api.call("GetLastError")).to eq(109)
  end

  it "declares CreateFileW's access mask as a DWORD" do
    args, = described_class::SIGNATURES.fetch("CreateFileW")
    expect(args[1]).to eq(described_class::DWORD)
  end
end
