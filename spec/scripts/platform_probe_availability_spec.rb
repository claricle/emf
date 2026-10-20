# frozen_string_literal: true

require "spec_helper"
require_relative "../../script/platform_probe/availability_matrix"

RSpec.describe AvailabilityMatrix::Fixtures do
  around do |example|
    Dir.mktmpdir("emf-corrupt-library-spec") do |directory|
      @directory = directory
      example.run
    end
  end

  ["\x7fELF".b, "\xcf\xfa\xed\xfe".b, "MZ\x90\x00".b].each do |magic|
    it "truncates #{magic.unpack1('H*')} before its object header can describe mapped segments" do
      bytes = magic + ("\x00".b * 4092)
      source = File.join(@directory, "original.so")
      File.binwrite(source, bytes)

      corrupt = described_class.new(@directory, source).truncated

      expect(File.binread(corrupt)).to eq(magic)
      expect(File.binread(source)).to eq(bytes)
      expect(File.extname(corrupt)).to eq(".so")
    end
  end

  it "produces a library the native loader rejects with a recoverable error" do
    source = File.join(@directory, "original.so")
    File.binwrite(source, "\x7fELF".b + ("\x00".b * 4092))
    corrupt = described_class.new(@directory, source).truncated
    child = <<~RUBY
      require "fiddle"
      begin
        Fiddle.dlopen(ARGV.fetch(0))
        abort "unexpectedly loaded corrupt library"
      rescue Fiddle::DLError
        puts "rejected corrupt library"
      end
    RUBY

    out, err, status = Open3.capture3(RbConfig.ruby, "-e", child, corrupt)

    expect([status.success?, out, err]).to eq([true, "rejected corrupt library\n", ""])
  end
end

RSpec.describe AvailabilityMatrix::Runner do
  let(:fixtures) do
    instance_double(AvailabilityMatrix::Fixtures, truncated: "corrupt.dll", foreign_architecture: "foreign.dll",
                                                  missing_dependency: nil, wrong_abi: nil)
  end
  let(:runner) { described_class.new(gem_home: "unused", library: "working.dll", fixture: __FILE__, directory: "unused") }

  before do
    allow(AvailabilityMatrix::Fixtures).to receive(:new).and_return(fixtures)
    allow(runner).to receive_messages(malformed_inputs: [], broken_installs: [])
  end

  it "accepts Windows loader causes without a filename while requiring an unavailable error and Ruby fallback" do
    allow(Gem).to receive(:win_platform?).and_return(true)

    names = %w[missing_library corrupt_library wrong_architecture]
    scenarios = runner.scenarios.select { |scenario| names.include?(scenario.name) }

    expect(scenarios.size).to eq(3)
    scenarios.each do |scenario|
      expect(scenario.auto).to eq(["ruby", nil, nil])
      expect(scenario.native.first(2)).to eq(["none", "Emf::Native::Unavailable"])
      expect("native backend could not load: No such file or directory").to match(scenario.native.last)
      expect("native backend could not load: Exec format error").to match(scenario.native.last)
      expect("native backend could not load: ").not_to match(scenario.native.last)
    end
  end

  it "still requires the failed library filename on POSIX" do
    allow(Gem).to receive(:win_platform?).and_return(false)

    scenario = runner.scenarios.find { |entry| entry.name == "corrupt_library" }

    expect("native backend could not load: corrupt.dll: file too short").to match(scenario.native.last)
    expect("native backend could not load: file too short").not_to match(scenario.native.last)
  end
end
