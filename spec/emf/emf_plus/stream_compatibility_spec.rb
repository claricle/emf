# frozen_string_literal: true

require "spec_helper"
require "open3"

# The EMF+ stream is a read-only view: building it must not change what the
# Metafile serializes to, what the CLI prints, or the comment bytes it frames.
#
# Full run:   bundle exec rspec spec/emf/emf_plus/stream_compatibility_spec.rb
# Subset run: EMF_STREAM_COMPAT_SUBSET=1 bundle exec rspec spec/emf/emf_plus/stream_compatibility_spec.rb
RSpec.describe "EMF+ stream compatibility" do
  fixtures_root = Emf::SpecSupport::FixturePath.fixtures_root
  subset = %w[emf/test-038.emf emf/test-109.emf simple/image1.emf].map { |name| File.join(fixtures_root, name) }
  valid = %w[emf emf-ea simple].flat_map { |dir| Dir[File.join(fixtures_root, dir, "*.emf")] }.sort
  paths = ENV["EMF_STREAM_COMPAT_SUBSET"] ? subset : valid

  exe = File.expand_path("../../../exe/emf", __dir__)
  lib = File.expand_path("../../../lib", __dir__)
  touch_stream = <<~RUBY
    module TouchStream
      def parse_file(*) = super.tap { |metafile| metafile.emf_plus_stream&.entries }
    end
    Emf.singleton_class.prepend(TouchStream)
  RUBY

  def with_backend(name)
    previous = ENV.fetch("EMF_BACKEND", nil)
    ENV["EMF_BACKEND"] = name
    yield
  ensure
    previous.nil? ? ENV.delete("EMF_BACKEND") : ENV["EMF_BACKEND"] = previous
  end

  def comment_payload(metafile, segment)
    wire = metafile.records[segment.record_index].wire
    wire.data.b.byteslice(4, wire.cb_data - 4)
  end

  def emf_plus_comment_indexes(metafile)
    metafile.records.each_index.select do |index|
      wire = metafile.records[index].wire
      wire.is_a?(Emf::Emr::Binary::Records::Comment) && wire.cb_data >= 4 && wire.data.b.start_with?("EMF+")
    end
  end

  def expect_viewing_is_additive(path)
    bytes = File.binread(path)
    baseline = Emf.serialize(Emf.parse(bytes))
    viewed = Emf.parse(bytes)
    rebuilt = viewed.emf_plus_stream.to_metafile
    expect(Emf.serialize(rebuilt)).to eq(baseline), path
    expect(Emf.serialize(viewed)).to eq(baseline), path
    expect(Emf.serialize(rebuilt)).to eq(bytes), path if baseline == bytes
  end

  # Parsing is backend-dependent and the first examples must hold for the Ruby
  # view whatever backend is configured; the native example below covers that one.
  around { |example| with_backend("ruby") { example.run } }

  before(:context) do
    @emf_plus_paths = paths.select { |path| with_backend("ruby") { Emf.parse(File.binread(path)).format == :emf_plus } }
  end

  it "keeps the fixture set non-empty" do
    expect(paths.size).to be >= 3
  end

  it "builds no stream for fixtures without EMF+", :corpus do
    (paths - @emf_plus_paths).each do |path|
      expect(Emf.parse(File.binread(path)).emf_plus_stream).to be_nil, path
    end
  end

  it "serializes identically whether or not the stream was built, and keeps byte-identical files byte-identical", :corpus do
    @emf_plus_paths.each { |path| expect_viewing_is_additive(path) }
  end

  it "stays additive when the native backend parses the fixture", :corpus do
    with_backend("native") do
      begin
        Emf::Native.backend
      rescue Emf::Native::Unavailable => e
        skip e.message
      end

      rejected = []
      checked = @emf_plus_paths.count do |path|
        expect_viewing_is_additive(path)
        true
      rescue Emf::FormatError => e
        rejected << "#{File.basename(path)}: #{e.message}"
        false
      end
      RSpec.configuration.reporter.message("native rejected #{rejected.size} EMF+ fixtures:\n  #{rejected.join("\n  ")}") if rejected.any?
      expect(checked).to be >= 1
    end
  end

  describe "exe/emf output" do
    commands = %w[info dump stats]
    pinned = %w[test-038 test-109]
    cli_paths = paths.select { |path| pinned.include?(File.basename(path, ".emf")) }
    cli_paths += [paths.find { |path| path.include?("EA-test-file") || path.include?("image1") }].compact

    run_commands = lambda do |preamble, path|
      script = <<~RUBY
        #{preamble}
        results = #{commands.inspect}.map do |command|
          out, err = StringIO.new, StringIO.new
          $stdout, $stderr = out, err
          status = begin
            ARGV.replace([command, #{path.dump}])
            load #{exe.dump}
            0
          rescue SystemExit => e
            e.status
          ensure
            $stdout, $stderr = STDOUT, STDERR
          end
          [command, status, out.string, err.string]
        end
        STDOUT.write(Marshal.dump(results))
      RUBY
      stdout, stderr, status = Open3.capture3({ "EMF_BACKEND" => "ruby" }, "ruby", "-I", lib, "-r", "emf", "-r", "stringio",
                                              "-e", script)
      raise "child failed: #{stderr}" unless status.success?

      Marshal.load(stdout) # rubocop:disable Security/MarshalLoad -- our own child's output
    end

    cli_paths.each do |path|
      it "prints the same info, dump and stats for #{File.basename(path)} after the stream is built" do
        plain = run_commands.call("", path)
        touched = run_commands.call(touch_stream, path)
        expect(plain.map { |_, status, _, _| status }).to eq([0, 0, 0])
        expect(touched).to eq(plain)
      end
    end
  end

  describe "segmentation" do
    it "covers exactly the EMF+ comments and reproduces their bytes", :corpus do
      @emf_plus_paths.each do |path|
        metafile = Emf.parse(File.binread(path))
        segments = metafile.emf_plus_stream.segments
        expect(segments.map(&:record_index)).to eq(emf_plus_comment_indexes(metafile)), path
        segments.each do |segment|
          expect(segment.payload).to eq(comment_payload(metafile, segment).byteslice(0, segment.payload.bytesize)), path
          expect(segment.payload + segment.tail).to eq(metafile.records[segment.record_index].wire.data.b.byteslice(4..)), path
          expect(segment.payload.bytesize).to eq(comment_payload(metafile, segment).bytesize), path
        end
      end
      expect(@emf_plus_paths.size).to be >= (ENV["EMF_STREAM_COMPAT_SUBSET"] ? 2 : 23)
    end
  end
end
