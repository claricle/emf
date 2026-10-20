# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "BinData font_body registration" do
  let(:lib) { File.expand_path("../../lib", __dir__) }

  def run_ruby(script, env = {})
    Open3.capture2e(env, RbConfig.ruby, "-W", "-I", lib, "-e", script)
  end

  [
    ["EMF+ font before EMR font", "Emf::EmfPlus::Objects::Font; Emf::Emr::Binary::Records::CreateFontIndirectW"],
    ["EMR font before EMF+ font", "Emf::Emr::Binary::Records::CreateFontIndirectW; Emf::EmfPlus::Objects::Font"],
    ["EMR font file only, then EMF+ font, then record definition",
     "require 'emf/emr/binary/font'; Emf::EmfPlus::Objects::Font; Emf::Emr::Binary::Records::CreateFontIndirectW"]
  ].each do |label, loader|
    it "binds the EMR record to the EMR body without a registry warning: #{label}" do
      script = "require 'emf'; #{loader}; " \
               "puts Emf::Emr::Binary::Records::CreateFontIndirectW.new.body.class; " \
               "puts BinData::RegisteredClasses.lookup('font_body')"
      output, status = run_ruby(script)
      expect(status).to be_success
      expect(output).not_to include("replacing registered class")
      expect(output.lines.map(&:strip).last(2)).to eq(%w[Emf::Emr::Binary::FontBody Emf::Emr::Binary::FontBody])
    end
  end

  it "keeps the EMF+ body constants pointing at the EMF+ class" do
    script = "require 'emf'; font = Emf::EmfPlus::Objects::Font; " \
             "puts font::BODY.name, font::FontBody.name, font::FontBody.superclass"
    output, status = run_ruby(script)
    expect(status).to be_success
    expect(output.lines.map(&:strip)).to eq(%w[Emf::EmfPlus::Objects::Font::FontBody
                                               Emf::EmfPlus::Objects::Font::FontBody BinData::Record])
  end

  it "loads every lib file with no registered-class replacement warning" do
    script = "require 'emf'; Dir[File.join(ARGV[0], '**/*.rb')].sort.each { |f| require f }"
    output, status = Open3.capture2e(RbConfig.ruby, "-W", "-I", lib, "-e", script, lib)
    expect(status).to be_success
    expect(output).not_to include("replacing registered class")
  end

  context "with the native backend" do
    let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", "") }

    it "hydrates a font record after the EMF+ font class has loaded" do
      skip "set EMF_TEST_NATIVE_LIBRARY to test native" unless File.file?(library)
      script = "require 'emf'; require 'emf/native/font_fields'; Emf::EmfPlus::Objects::Font; " \
               "m = Emf.parse(File.binread(ARGV[0])); puts Emf.serialize(m).bytesize"
      fixture = File.expand_path("../fixtures/emf/test-000.emf", __dir__)
      output, status = Open3.capture2e({ "EMF_BACKEND" => "native", "EMF_NATIVE_LIBRARY" => library },
                                       RbConfig.ruby, "-I", lib, "-e", script, fixture)
      expect(status).to be_success, output
      expect(output.lines.last.strip).to eq(File.size(fixture).to_s)
    end
  end
end
