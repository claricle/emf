# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "release checkout provenance" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:lock_path) { "emf-rs/Cargo.lock" }
  let(:lock_bytes) { File.binread(File.join(root, lock_path)) }
  let(:binary_bytes) { "\x00\x01\r\n\xFF\n".b }

  it "preserves lockfile hashes and binary bytes with Windows automatic line endings" do
    Dir.mktmpdir("emf-checkout-provenance") do |directory|
      FileUtils.mkdir_p(File.join(directory, "emf-rs"))
      File.binwrite(File.join(directory, lock_path), lock_bytes)
      File.binwrite(File.join(directory, "fixture.emf"), binary_bytes)
      attributes = File.join(root, ".gitattributes")
      FileUtils.cp(attributes, directory) if File.file?(attributes)
      checkout = File.join(directory, "windows")
      commands = [
        ["init", "--quiet"],
        ["-c", "core.autocrlf=false", "add", "--all"],
        ["-c", "core.autocrlf=true", "checkout-index", "--all", "--force", "--prefix=#{checkout}/"]
      ]
      commands.each do |arguments|
        _, err, status = Open3.capture3(
          { "GIT_CONFIG_NOSYSTEM" => "1", "GIT_CONFIG_GLOBAL" => File::NULL },
          "git", *arguments, chdir: directory
        )
        expect(status.success?).to be(true), "git #{arguments.join(' ')} failed: #{err}"
      end

      checked_out_lock = File.binread(File.join(checkout, lock_path))
      expect(checked_out_lock).to eq(lock_bytes)
      expect(Digest::SHA256.hexdigest(checked_out_lock)).to eq(Digest::SHA256.hexdigest(lock_bytes))
      expect(File.binread(File.join(checkout, "fixture.emf"))).to eq(binary_bytes)
    end
  end
end
