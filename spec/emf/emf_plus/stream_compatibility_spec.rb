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
    load ARGV.shift
  RUBY

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

  def emf_plus_paths(paths)
    paths.select { |path| Emf.parse(File.binread(path)).format == :emf_plus }
  end

  it "keeps the fixture set non-empty" do
    expect(paths.size).to be >= 3
  end

  it "serializes identically whether or not the stream was built", :corpus do
    paths.each do |path|
      bytes = File.binread(path)
      baseline = Emf.serialize(Emf.parse(bytes))
      viewed = Emf.parse(bytes)
      stream = viewed.emf_plus_stream
      rebuilt = stream ? stream.to_metafile : viewed
      expect(Emf.serialize(rebuilt)).to eq(baseline), path
      expect(Emf.serialize(viewed)).to eq(baseline), path
    end
  end

  it "keeps EMF+ files that round-tripped byte-identically byte-identical", :corpus do
    paths.each do |path|
      bytes = File.binread(path)
      next unless Emf.serialize(Emf.parse(bytes)) == bytes

      viewed = Emf.parse(bytes)
      rebuilt = viewed.emf_plus_stream&.to_metafile || viewed
      expect(Emf.serialize(rebuilt)).to eq(bytes), path
    end
  end

  describe "exe/emf output" do
    pinned = %w[test-038 test-109]
    commands = %w[info dump stats]
    cli_paths = paths.select { |path| pinned.include?(File.basename(path, ".emf")) }
    cli_paths += [paths.find { |path| path.include?("EA-test-file") || path.include?("image1") }].compact

    cli_paths.each do |path|
      commands.each do |command|
        it "prints the same `#{command}` for #{File.basename(path)} after the stream is built" do
          plain, plain_err, plain_status = Open3.capture3("ruby", exe, command, path)
          touched, touched_err, touched_status = Open3.capture3("ruby", "-I", lib, "-r", "emf", "-e", touch_stream,
                                                                exe, command, path)
          expect(plain_status.exitstatus).to eq(0)
          expect(touched_status.exitstatus).to eq(0)
          expect(touched).to eq(plain)
          expect(touched_err).to eq(plain_err)
        end
      end
    end
  end

  describe "segmentation" do
    it "covers exactly the EMF+ comments and reproduces their bytes", :corpus do
      checked = 0
      emf_plus_paths(paths).each do |path|
        metafile = Emf.parse(File.binread(path))
        segments = metafile.emf_plus_stream.segments
        expect(segments.map(&:record_index)).to eq(emf_plus_comment_indexes(metafile)), path
        segments.each do |segment|
          expect(segment.payload).to eq(comment_payload(metafile, segment).byteslice(0, segment.payload.bytesize)), path
          expect(segment.payload + segment.tail).to eq(metafile.records[segment.record_index].wire.data.b.byteslice(4..)), path
          expect(segment.payload.bytesize).to eq(comment_payload(metafile, segment).bytesize), path
        end
        checked += 1
      end
      expect(checked).to be >= (ENV["EMF_STREAM_COMPAT_SUBSET"] ? 2 : 23)
    end
  end
end
