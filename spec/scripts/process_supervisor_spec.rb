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
