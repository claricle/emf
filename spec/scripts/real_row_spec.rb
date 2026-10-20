# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"

# Runs real_row.sh with stub rustup/cargo on PATH and HOME pointed away from
# ~/.cargo/bin, so the build step records its command instead of compiling.
RSpec.describe "script/platform_probe/real_row.sh" do
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

  # A ruby shim records the packaging script calls and runs everything else for
  # real; the row then stops at staging because no gem was written.
  def package_commands(env_extra = {})
    Dir.mktmpdir do |dir|
      bin = File.join(dir, "bin")
      Dir.mkdir(bin)
      log = File.join(dir, "ruby.log")
      File.write(File.join(bin, "ruby"), <<~SH)
        #!/bin/sh
        case "$1" in
          */build_native_gem|*/build_source_release_gem|*/check_native_package) echo "$*" >> #{log}; exit 0 ;;
        esac
        exec #{RbConfig.ruby} "$@"
      SH
      File.chmod(0o755, File.join(bin, "ruby"))
      library = File.join(dir, "libemf_ffi.dylib")
      File.write(library, "")
      env = { "HOME" => dir, "PATH" => "#{bin}:#{ENV.fetch('PATH')}", "EMF_REAL_LIBRARY" => library,
              "EMF_RELEASE_REVISION" => nil, "GITHUB_SHA" => nil }.merge(env_extra)
      Open3.capture3(env, "bash", script, "aarch64-apple-darwin", "arm64-darwin", File.join(dir, "out"))
      return File.read(log).lines(chomp: true)
    end
  end

  it "binds the platform gem, the source release gem and the package check to one revision" do
    revision = "0123456789abcdef0123456789abcdef01234567"
    platform, source, check = package_commands("EMF_RELEASE_REVISION" => revision)

    expect(platform).to match(%r{/build_native_gem --platform arm64-darwin .* --revision #{revision} --output })
    expect(source).to match(%r{/build_source_release_gem --revision #{revision} --output })
    expect(check).to match(%r{/check_native_package --directory \S+ --revision #{revision}\z})
  end

  it "uses the checkout HEAD when no release revision is given" do
    head = `git -C #{File.expand_path("../..", __dir__)} rev-parse HEAD`.strip
    commands = package_commands

    expect(commands.size).to eq(3)
    expect(commands).to all(include("--revision #{head}"))
  end

  it "reports a blocker when the build produces no library" do
    _log, summary, status = build_command("aarch64-pc-windows-gnullvm")

    expect(summary).to include("build_cdylib=ok")
    expect(summary).to include("BLOCKER no emf-ffi library under emf-rs/target/aarch64-pc-windows-gnullvm/release")
    expect(status.exitstatus).to eq(1)
  end
end
