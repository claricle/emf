# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"

# Runs real_row.sh with stub rustup/cargo on PATH and HOME pointed away from
# ~/.cargo/bin, so the build step records its command instead of compiling.
RSpec.describe "script/platform_probe/real_row.sh build_cdylib" do
  let(:script) { File.expand_path("../../script/platform_probe/real_row.sh", __dir__) }

  def build_command(target, rustflags: nil)
    Dir.mktmpdir do |dir|
      bin = File.join(dir, "bin")
      Dir.mkdir(bin)
      log = File.join(dir, "cargo.log")
      File.write(File.join(bin, "rustup"), "#!/bin/sh\nexit 0\n")
      File.write(File.join(bin, "cargo"), "#!/bin/sh\nprintf 'RUSTFLAGS=%s\\nARGS=%s\\n' \"$RUSTFLAGS\" \"$*\" > #{log}\n")
      [File.join(bin, "rustup"), File.join(bin, "cargo")].each { |path| File.chmod(0o755, path) }
      env = { "HOME" => dir, "PATH" => "#{bin}:#{ENV.fetch('PATH')}", "RUSTFLAGS" => rustflags, "EMF_REAL_LIBRARY" => nil }
      _out, _err, status = Open3.capture3(env, "bash", script, target, "test-platform", File.join(dir, "out"))
      summary = File.read(File.join(dir, "out/real/summary.txt"))
      return [File.read(log), summary, status]
    end
  end

  it "links the Windows ARM64 gnullvm library statically and keeps the caller's flags" do
    log, = build_command("aarch64-pc-windows-gnullvm", rustflags: "-C debuginfo=0")

    expect(log).to include("RUSTFLAGS=-C debuginfo=0 -C link-arg=-static")
    expect(log).to include("ARGS=+stable build --locked --release -p emf-ffi --target aarch64-pc-windows-gnullvm")
  end

  it "keeps the musl crt-static override" do
    log, = build_command("x86_64-unknown-linux-musl")

    expect(log).to include("RUSTFLAGS= -C target-feature=-crt-static\n")
  end

  it "leaves other targets' flags untouched, including x86_64 Windows" do
    %w[x86_64-pc-windows-gnu x86_64-unknown-linux-gnu aarch64-apple-darwin].each do |target|
      log, = build_command(target, rustflags: "-C debuginfo=0")

      expect(log).to include("RUSTFLAGS=-C debuginfo=0\n"), target
    end
  end

  it "reports a blocker when the build produces no library" do
    _log, summary, status = build_command("aarch64-pc-windows-gnullvm")

    expect(summary).to include("build_cdylib=ok")
    expect(summary).to include("BLOCKER no emf-ffi library under emf-rs/target/aarch64-pc-windows-gnullvm/release")
    expect(status.exitstatus).to eq(1)
  end
end
