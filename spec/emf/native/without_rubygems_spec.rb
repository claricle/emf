# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Backend selection without RubyGems" do
  let(:bindata_paths) { Gem.loaded_specs.fetch("bindata").full_require_paths }

  it "falls back to Ruby under automatic selection instead of failing to load" do
    script = 'p Emf.parse(File.binread("spec/fixtures/simple/image1.emf")).format'
    load_paths = (["lib"] + bindata_paths).flat_map { |path| ["-I", path] }
    stdout, stderr, status = Open3.capture3(
      { "EMF_BACKEND" => nil, "EMF_NATIVE_LIBRARY" => nil, "RUBYOPT" => nil, "RUBYLIB" => nil },
      RbConfig.ruby, "--disable-gems", *load_paths, "-remf", "-e", script
    )
    expect(status.success?).to be(true), stderr
    expect(stdout).to eq(":emf_plus\n")
  end
end
