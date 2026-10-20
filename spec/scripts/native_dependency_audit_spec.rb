# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

require "spec_helper"

RSpec.describe "script/native_dependency_audit" do
  root = File.expand_path("../..", __dir__)
  script = File.join(root, "script/native_dependency_audit")
  allow_list = File.join(root, "script/native_licenses.json")
  cargo = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "cargo")) }

  before { skip "cargo is not on PATH" unless cargo }

  def write_workspace(dir, ffi_license: '"BSD-2-Clause"', ffi_version: "0.0.0")
    FileUtils.mkdir_p(File.join(dir, "crates/emf-ffi/src"))
    FileUtils.mkdir_p(File.join(dir, "crates/dep/src"))
    File.write(File.join(dir, "Cargo.toml"), "[workspace]\nresolver = \"2\"\nmembers = [\"crates/*\"]\n")
    File.write(File.join(dir, "crates/dep/Cargo.toml"), <<~TOML)
      [package]
      name = "dep"
      version = "0.0.0"
      edition = "2021"
      license = "MIT OR GPL-3.0-only"
    TOML
    File.write(File.join(dir, "crates/dep/src/lib.rs"), "")
    File.write(File.join(dir, "crates/emf-ffi/src/lib.rs"), "")
    File.write(File.join(dir, "crates/emf-ffi/Cargo.toml"), <<~TOML)
      [package]
      name = "emf-ffi"
      version = "#{ffi_version}"
      edition = "2021"
      #{"license = #{ffi_license}" if ffi_license}

      [dependencies]
      dep = { path = "../dep" }
    TOML
  end

  def generate_lock(dir)
    _o, e, s = Open3.capture3("cargo", "generate-lockfile", "--offline", chdir: dir)
    raise "lock generation failed: #{e}" unless s.success?
  end

  def audit(script, dir, allow_list, path: ENV.fetch("PATH"))
    Open3.capture3({ "PATH" => path }, RbConfig.ruby, script, "--manifest-dir", dir, "--allow-list", allow_list)
  end

  def allow_file(dir, *ids)
    File.join(dir, "allow.json").tap { |f| File.write(f, JSON.generate("allowed" => ids)) }
  end

  around do |example|
    Dir.mktmpdir("emf-dep-audit") do |dir|
      @dir = dir
      example.run
    end
  end

  it "passes the real workspace and reports the vulnerability check as NOT RUN" do
    stub = File.join(@dir, "bin")
    FileUtils.mkdir_p(stub)
    real = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |d| File.join(d, "cargo") }.find { |f| File.executable?(f) }
    shim = "#!/bin/sh\n[ \"$1\" = audit ] && { echo 'error: no such command: `audit`'; exit 101; }\nexec #{real} \"$@\"\n"
    File.write(File.join(stub, "cargo"), shim)
    FileUtils.chmod(0o755, File.join(stub, "cargo"))
    out, err, status = audit(script, File.join(root, "emf-rs"), allow_list, path: "#{stub}:#{ENV.fetch('PATH')}")
    report = JSON.parse(out)
    expect(status.success?).to be(true), err
    expect(report["crates"].map { |c| c["name"] }).to eq(%w[emf-core emf-ffi])
    expect(report["vulnerability_check"]["status"]).to eq("NOT RUN")
    expect(err).to include("vulnerability check: NOT RUN")
  end

  it "fails when the lock would be rewritten and leaves it untouched" do
    write_workspace(@dir)
    generate_lock(@dir)
    write_workspace(@dir, ffi_version: "0.0.1")
    before = File.binread(File.join(@dir, "Cargo.lock"))
    _out, err, status = audit(script, @dir, allow_list)
    expect(status.exitstatus).to eq(1)
    expect(err).to include("Cargo.lock: failed").and include("lock file")
    expect(File.binread(File.join(@dir, "Cargo.lock"))).to eq(before)
  end

  it "fails naming a crate whose license is not allowed" do
    write_workspace(@dir, ffi_license: '"GPL-3.0-only"')
    generate_lock(@dir)
    out, err, status = audit(script, @dir, allow_file(@dir, "BSD-2-Clause", "MIT"))
    expect(status.exitstatus).to eq(1)
    expect(JSON.parse(out)["license_findings"]).to eq(["emf-ffi 0.0.0: license GPL-3.0-only is not allowed"])
    expect(err).to include("FAIL emf-ffi 0.0.0")
  end

  it "accepts an OR expression when one alternative is allowed" do
    write_workspace(@dir)
    generate_lock(@dir)
    _out, err, status = audit(script, @dir, allow_file(@dir, "BSD-2-Clause", "MIT"))
    expect(status.success?).to be(true), err
  end

  it "fails an AND expression when one side is not allowed" do
    write_workspace(@dir, ffi_license: '"MIT AND GPL-3.0-only"')
    generate_lock(@dir)
    out, _err, status = audit(script, @dir, allow_file(@dir, "MIT"))
    expect(status.exitstatus).to eq(1)
    expect(JSON.parse(out)["license_findings"].join).to include("emf-ffi")
  end

  it "fails naming a crate with no license" do
    write_workspace(@dir, ffi_license: nil)
    generate_lock(@dir)
    out, _err, status = audit(script, @dir, allow_file(@dir, "MIT"))
    expect(status.exitstatus).to eq(1)
    expect(JSON.parse(out)["license_findings"]).to include("emf-ffi 0.0.0: no license expression")
  end

  def findings_for(script, license, *allowed)
    write_workspace(@dir, ffi_license: license.inspect)
    generate_lock(@dir)
    out, _err, status = audit(script, @dir, allow_file(@dir, *allowed))
    [status, JSON.parse(out)["license_findings"]]
  end

  it "fails a WITH exception that is not listed even when the base license is allowed" do
    status, findings = findings_for(script, "GPL-2.0-only WITH Classpath-exception-2.0", "GPL-2.0-only", "MIT")
    expect(status.exitstatus).to eq(1)
    expect(findings).to eq(["emf-ffi 0.0.0: license GPL-2.0-only WITH Classpath-exception-2.0 is not allowed"])
  end

  it "passes a WITH expression that is listed in full" do
    status, findings = findings_for(script, "GPL-2.0-only WITH Classpath-exception-2.0",
                                    "GPL-2.0-only WITH Classpath-exception-2.0", "MIT")
    expect(status.success?).to be(true)
    expect(findings).to eq([])
  end

  it "reports a malformed expression as a finding naming the crate" do
    status, findings = findings_for(script, "(MIT OR BSD-2-Clause", "MIT", "BSD-2-Clause")
    expect(status.exitstatus).to eq(1)
    expect(findings).to eq(["emf-ffi 0.0.0: malformed license expression \"(MIT OR BSD-2-Clause\" (missing close parenthesis)"])
  end
end

RSpec.describe "NativeDependencyAudit::LicensePolicy" do
  before(:all) { load File.expand_path("../../script/native_dependency_audit", __dir__) }

  let(:policy) do
    NativeDependencyAudit::LicensePolicy.new(["MIT", "BSD-2-Clause", "GPL-2.0-only WITH Classpath-exception-2.0"])
  end

  {
    "MIT" => true,
    "MIT OR GPL-3.0-only" => true,
    "MIT AND GPL-3.0-only" => false,
    "MIT/BSD-2-Clause" => true,
    "(MIT OR GPL-3.0-only) AND BSD-2-Clause" => true,
    "GPL-2.0-only WITH Classpath-exception-2.0" => true,
    "GPL-2.0-only WITH Other-exception" => false,
    "GPL-2.0-only" => false,
    "MIT AND GPL-2.0-only WITH Classpath-exception-2.0" => true
  }.each do |expression, allowed|
    it "judges #{expression.inspect} as #{allowed ? 'allowed' : 'not allowed'}" do
      verdict = policy.verdict(expression)
      expect([verdict.allowed, verdict.malformed]).to eq([allowed, false])
    end
  end

  {
    "a missing close parenthesis" => "(MIT OR BSD-2-Clause",
    "an extra close parenthesis" => "MIT)",
    "a trailing license id" => "MIT BSD-2-Clause",
    "a dangling AND" => "MIT AND",
    "a leading OR" => "OR MIT",
    "a WITH without an exception" => "MIT WITH",
    "an empty group" => "()",
    "an empty expression" => " ",
    "unexpected characters" => "MIT; GPL-3.0-only"
  }.each do |name, expression|
    it "fails closed on #{name}" do
      verdict = policy.verdict(expression)
      expect(verdict.allowed).to be(false)
      expect(verdict.malformed).to be_a(String)
    end
  end
end
