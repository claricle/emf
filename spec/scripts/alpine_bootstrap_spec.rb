# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "open3"

RSpec.describe "script/platform_probe/alpine.sh" do
  it "provides Git to both source-gem probes without dropping bootstrap dependencies" do
    Dir.mktmpdir do |dir|
      bin = File.join(dir, "bin")
      Dir.mkdir(bin)
      scripts = File.join(dir, "script/platform_probe")
      FileUtils.mkdir_p(scripts)
      script = File.join(scripts, "alpine.sh")
      FileUtils.cp(File.expand_path("../../script/platform_probe/alpine.sh", __dir__), script)
      git = File.join(dir, "fake-git")
      File.write(git, <<~SH)
        #!/bin/sh
        if [ "$1" = config ]; then
          [ "$*" = "config --global --add safe.directory $EXPECTED_CHECKOUT" ] || exit 1
          printf '%s\n' "$*" >> "$BOOTSTRAP_BIN/trust"
        else
          [ -f "$BOOTSTRAP_BIN/trust" ] || exit 1
          printf '%s\n' "$EXPECTED_REVISION"
        fi
      SH
      File.chmod(0o755, git)
      File.write(File.join(bin, "apk"), <<~SH)
        #!/bin/sh
        printf '%s\n' "$*" > "$BOOTSTRAP_BIN/packages"
        for package in "$@"; do
          if [ "$package" = git ]; then
            cp "$BOOTSTRAP_GIT" "$BOOTSTRAP_BIN/git"
          fi
        done
      SH
      # No package installation, Ruby load, download or toolchain setup occurs.
      %w[ruby curl sh].each do |command|
        File.write(File.join(bin, command), "#!/bin/sh\nexit 0\n")
      end
      Dir.children(bin).each { |command| File.chmod(0o755, File.join(bin, command)) }
      %w[run_row real_row].each do |row|
        File.write(File.join(scripts, "#{row}.sh"), <<~SH)
          #!/bin/sh
          revision=$("$BOOTSTRAP_BIN/git" rev-parse HEAD) || exit 1
          [ "$revision" = "$EXPECTED_REVISION" ] || exit 1
          printf '%s %s\n' '#{row}' "$revision" >> "$BOOTSTRAP_BIN/revisions"
        SH
      end
      revision = "0123456789abcdef0123456789abcdef01234567"
      env = { "HOME" => dir, "PATH" => "#{bin}:#{ENV.fetch('PATH')}",
              "BOOTSTRAP_BIN" => bin, "BOOTSTRAP_GIT" => git,
              "EXPECTED_CHECKOUT" => File.realpath(dir), "EXPECTED_REVISION" => revision }
      stdout, stderr, status = Open3.capture3(env, "/bin/sh", script,
                                              "x86_64-unknown-linux-musl", "x86_64-linux-musl", File.join(dir, "out"))

      expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
      expect(File.read(File.join(bin, "packages")).split).to include("bash", "curl", "file", "build-base", "ruby", "git")
      expect(File.read(File.join(bin, "trust"))).to eq("config --global --add safe.directory #{File.realpath(dir)}\n")
      expect(File.read(File.join(bin, "revisions")).lines(chomp: true)).to eq(["run_row #{revision}", "real_row #{revision}"])
      expect(File.read(File.join(dir, "out/bootstrap-failures.txt"))).to eq("")
    end
  end
end
