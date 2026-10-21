# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "tmpdir"
require_relative "../support/process_supervisor"
require_relative "../support/process_supervisor_helpers"

RSpec.describe ProcessSupervisor do
  include ProcessSupervisorHelpers

  let(:root) { File.expand_path("../..", __dir__) }
  let(:limit) { 150 * 1024 * 1024 }
  # Generous wall for children that must finish, so a busy CI runner cannot turn them into timeouts.
  let(:supervisor) { described_class.new(wall_seconds: 10, rss_limit_bytes: limit) }
  let(:short_supervisor) { described_class.new(wall_seconds: 2, rss_limit_bytes: limit) }

  describe "benchmark series safety contract" do
    it "accepts the explicit series ceiling for a short child" do
      sup = described_class.new(wall_seconds: 1200, rss_limit_bytes: limit, benchmark_series: true)
      result = sup.call(ruby('print "series"'))

      expect(result).to be_success
      expect(result.output).to eq("series")
      expect(result.elapsed).to be < 60
    end

    it "retains the ordinary ceiling and requires a literal opt-in" do
      [false, nil, "true", 1].each do |opt_in|
        expect { described_class.new(wall_seconds: 61, rss_limit_bytes: limit, benchmark_series: opt_in) }
          .to raise_error(ArgumentError, /wall_seconds/)
      end
      expect { described_class.new(wall_seconds: 60, rss_limit_bytes: limit) }.not_to raise_error
    end

    it "rejects invalid and nonfinite wall limits in either mode" do
      [false, true].each do |opt_in|
        invalid = [nil, true, "60", Object.new, Complex(2, 0), Float::NAN, Float::INFINITY, -Float::INFINITY, 0, -1]
        invalid << (opt_in ? 1201 : 61)
        invalid.each do |wall|
          expect { described_class.new(wall_seconds: wall, rss_limit_bytes: limit, benchmark_series: opt_in) }
            .to raise_error(ArgumentError, /wall_seconds/)
        end
      end
    end

    it "keeps the RSS ceiling mandatory for series" do
      expect { described_class.new(wall_seconds: 1200, benchmark_series: true) }
        .to raise_error(ArgumentError, /rss_limit_bytes/)
    end

    it "enforces RSS and monitoring failures without allocating stress data" do
      { limit + 1 => :rss_exceeded, nil => :monitor_failed }.each do |sample, status|
        sup = described_class.new(wall_seconds: 1200, rss_limit_bytes: limit, benchmark_series: true)
        allow(sup).to receive(:group_rss_bytes).and_return(sample)
        result = sup.call(ruby("sleep 1"))

        expect(result.status).to eq(status)
        expect(result).not_to be_success
      end
    end

    it "still enforces a selected short deadline for series" do
      sup = described_class.new(wall_seconds: 1, rss_limit_bytes: limit, benchmark_series: true)
      result = sup.call(ruby("sleep 10"))

      expect(result.status).to eq(:timed_out)
      expect(result).not_to be_success
      expect(result.elapsed).to be_between(1, 5)
    end

    it "preserves finite fractional deadlines" do
      expect { described_class.new(wall_seconds: 1.5, rss_limit_bytes: limit) }.not_to raise_error
      expect { described_class.new(wall_seconds: Rational(3, 2), rss_limit_bytes: limit) }.not_to raise_error
    end

    it "preserves the output ceiling for series" do
      sup = described_class.new(wall_seconds: 1200, rss_limit_bytes: limit, output_limit: 16, benchmark_series: true)
      result = sup.call(ruby('print "x" * 17'))

      expect(result.status).to eq(:output_limit)
      expect(result.output.bytesize).to eq(16)
      expect(result).not_to be_success
    end

    it "cleans up descendants after a series child exits" do
      sup = described_class.new(wall_seconds: 1200, rss_limit_bytes: limit, benchmark_series: true)
      result = sup.call(ruby('pid = Process.spawn("sleep", "10"); puts pid'))

      expect(result).to be_success
      expect(alive?(Integer(result.output.lines.first))).to be(false)
    end

    it "forwards exact validated limits, command and environment to Windows" do
      require_relative "../support/windows_process_supervisor"
      windows = instance_double(WindowsProcessSupervisor)
      result = described_class::Result.new(status: :rss_exceeded, exit_code: nil)
      command = ["ruby", "probe.rb"]
      env = { "SERIES_PROBE" => "yes" }
      allow(Gem).to receive(:win_platform?).and_return(true)
      expect(WindowsProcessSupervisor).to receive(:new)
        .with(wall_seconds: 1200, rss_limit_bytes: limit, output_limit: 123).and_return(windows)
      expect(windows).to receive(:call).with(command, env: env).and_return(result)
      sup = described_class.new(wall_seconds: 1200, rss_limit_bytes: limit, output_limit: 123, benchmark_series: true)

      expect(sup.call(command, env: env)).to equal(result)
    end
  end

  it "kills a stalled child at the wall deadline" do
    result = short_supervisor.call(ruby("sleep"))

    expect(result.status).to eq(:timed_out)
    expect(result).not_to be_success
    expect(result.elapsed).to be >= 2
  end

  it "kills a memory hog and records a peak above the limit" do
    result = supervisor.call(ruby('a = []; loop { a << ("x" * 1_000_000) }'))

    expect(result.status).to eq(:rss_exceeded)
    expect(result).not_to be_success
    expect(result.peak_rss_bytes).to be > limit
  end

  it "leaves no live grandchild behind" do
    code = 'pid = Process.spawn("sleep", "60"); puts pid; $stdout.flush; sleep'
    result = short_supervisor.call(ruby(code))

    expect(result.status).to eq(:timed_out)
    expect(alive?(Integer(result.output.lines.first))).to be(false)
  end

  it "reaps a grandchild left by a child that exited cleanly" do
    code = 'pid = Process.spawn("sleep", "60"); puts pid'
    result = supervisor.call(ruby(code))

    expect(result).to be_success
    expect(alive?(Integer(result.output.lines.first))).to be(false)
  end

  it "kills a TERM-ignoring grandchild left by a child that exited cleanly" do
    # The grandchild reports only after its trap is installed; a fixed sleep races its startup.
    code = <<~RUBY
      require "rbconfig"
      r, w = IO.pipe
      pid = Process.spawn(RbConfig.ruby, "--disable-gems", "-e", "trap(%q(TERM)) {}; puts 1; $stdout.flush; sleep 60", out: w)
      w.close
      r.gets
      puts pid
    RUBY
    result = supervisor.call(ruby(code))

    expect(result).to be_success
    expect(alive?(Integer(result.output.lines.first))).to be(false)
  end

  it "reports a clean parse of a valid fixture as exited with plausible peak RSS" do
    fixture = File.join(root, "spec/fixtures/emf/test-000.emf")
    code = %(require "emf"; Emf.parse(File.binread(ARGV.fetch(0))))
    result = described_class.new(wall_seconds: 30, rss_limit_bytes: 1024 * 1024 * 1024)
                            .call([RbConfig.ruby, "-I", File.join(root, "lib"), "-e", code, fixture])

    expect(result).to be_success
    expect(result.status).to eq(:exited)
    expect(result.peak_rss_bytes).to be_between(5 * 1024 * 1024, 1024 * 1024 * 1024)
  end

  it "requires an RSS limit" do
    expect { described_class.new(wall_seconds: 2) }.to raise_error(ArgumentError, /rss_limit_bytes/)
  end

  it "rejects a wall limit above 60 seconds" do
    expect { described_class.new(wall_seconds: 61, rss_limit_bytes: limit) }.to raise_error(ArgumentError, /wall_seconds/)
  end

  it "stops a child that writes past the output limit" do
    sup = described_class.new(wall_seconds: 5, rss_limit_bytes: limit, output_limit: 1024)
    result = sup.call(ruby('loop { $stdout.write("x" * 4096) }'))

    expect(result.status).to eq(:output_limit)
    expect(result.output.bytesize).to be <= 1024
  end

  it "does not record a child that overflowed its output and then exited as a success" do
    sup = described_class.new(wall_seconds: 5, rss_limit_bytes: limit, output_limit: 1024)
    result = sup.call(ruby('$stdout.write("x" * 1025)'))

    expect(result.status).to eq(:output_limit)
    expect(result).not_to be_success
  end

  it "passes env through and reports a non-zero exit and a self-signal" do
    failed = supervisor.call(ruby("exit 3"))
    signaled = supervisor.call(ruby('Process.kill("KILL", $$)'))
    env = supervisor.call(ruby("print ENV.fetch('EMF_BACKEND')"), env: { "EMF_BACKEND" => "native" })

    expect([failed.status, failed.exit_code, failed]).to match([:exited, 3, satisfy { |r| !r.success? }])
    expect([signaled.status, signaled.signal, signaled.success?]).to eq([:signaled, 9, false])
    expect(env.output).to eq("native")
  end

  it "kills the group and fails closed when the RSS probe cannot be read" do
    Dir.mktmpdir("emf-failing-ps-") do |dir|
      File.write(File.join(dir, "ps"), "#!/bin/sh\nexit 1\n")
      File.chmod(0o700, File.join(dir, "ps"))
      result = with_path(dir) do
        short_supervisor.call([RbConfig.ruby, "--disable-gems", "-e", "a = %q(x) * 8_000_000; sleep 30"])
      end

      expect(result.status).to eq(:monitor_failed)
      expect(result).not_to be_success
      expect(result.elapsed).to be < 2
    end
  end

  it "returns frozen results" do
    expect(supervisor.call(ruby("exit 0"))).to be_frozen
  end
end
