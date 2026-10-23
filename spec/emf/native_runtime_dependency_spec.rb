# frozen_string_literal: true

require "open3"
require "rbconfig"
require "spec_helper"
require_relative "../support/native_library_context"

RSpec.describe "Native runtime dependencies" do
  include_context "with native library"

  it "starts the actual native Loader silently under Bundler" do
    output, errors, status = Open3.capture3(
      RbConfig.ruby, "-rbundler/setup", "-Ilib", "-remf", "-remf/native/loader",
      "-e", "Emf::Native::Loader.new(ARGV.fetch(0))", library
    )
    expect(status.success?).to be(true), errors
    expect(output).to be_empty
    expect(errors).to be_empty
  end
end
