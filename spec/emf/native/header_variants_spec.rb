# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/header_variant_wire"

RSpec.describe "EMF header layout variants across backends" do
  include_context "with native library"

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  let(:wire) { HeaderVariantWire }
  let(:backends) { %w[ruby native] }
  let(:scalar_fields) do
    %i[n_size signature version n_bytes n_records n_handles s_reserved n_description off_description
       n_pal_entries cb_pixel_format off_pixel_format b_open_gl trailing description]
  end

  def observe(backend, input)
    ENV["EMF_BACKEND"] = backend
    parsed = Emf.parse(input)
    header = parsed.header
    {
      scalars: scalar_fields.to_h { |field| [field, header.public_send(field)] },
      geometry: geometry_of(header),
      errors: parsed.errors.map { |e| [e.offset, e.record_code] }, # wording is backend-specific
      records: parsed.records.map { |r| r.wire.to_binary_s },
      trailing: parsed.trailing,
      serialized: Emf.serialize(parsed)
    }
  end

  def geometry_of(header)
    rects = { bounds: header.bounds, frame: header.frame }.transform_values do |r|
      %i[left top right bottom].to_h { |k| [k, r.public_send(k)] }
    end
    sizes = { device_pixels: header.device_pixels, device_mm: header.device_mm,
              szl_micrometers: header.szl_micrometers }.transform_values { |z| { cx: z.cx, cy: z.cy } }
    rects.merge(sizes)
  end

  def expect_identical_and_exact(input)
    ruby = observe("ruby", input)
    native = observe("native", input)
    expect(native).to eq(ruby)
    expect(native.fetch(:serialized)).to eq(input)
    ENV["EMF_BACKEND"] = "native"
    expect(observe("native", native.fetch(:serialized))).to eq(native)
    native
  end

  describe "every permitted layout" do
    # 88 = base, 100 = + pixel format, 108 = + micrometers, larger = opaque extension tail.
    [88, 100, 108, 112, 124, 132, 252].each do |size|
      it "parses a #{size}-byte header identically and round-trips exactly" do
        seen = expect_identical_and_exact(wire.stream(size, cb_pixel_format: 40, off_pixel_format: 0x7FFF_FFFF, b_open_gl: 1))

        expect(seen[:scalars]).to include(n_size: size, n_records: 2)
        expect(seen[:errors]).to be_empty
        expect(seen[:records]).to eq([wire::FOLLOWING, wire::EOF_RECORD])
      end
    end

    it "reports optional fields as zero and the tail as empty when the header ends early" do
      seen = expect_identical_and_exact(wire.stream(88, cb_pixel_format: 40, off_pixel_format: 9, b_open_gl: 1))

      expect(seen[:scalars]).to include(cb_pixel_format: 0, off_pixel_format: 0, b_open_gl: 0, trailing: "".b)
      expect(seen[:geometry].fetch(:szl_micrometers)).to eq(cx: 0, cy: 0)
    end

    it "keeps signed geometry and the opaque tail of a 110-byte (non multiple of four) header" do
      seen = expect_identical_and_exact(wire.stream(110))

      expect(seen[:geometry].fetch(:bounds)).to eq(left: -5, top: 6, right: 70_000, bottom: -80_000)
      expect(seen[:geometry].fetch(:szl_micrometers)).to eq(cx: -1, cy: 2)
      expect(seen[:scalars].fetch(:trailing)).to eq("\xEE".b * 2)
    end
  end

  describe "field values the specification leaves unconstrained" do
    sizes = [88, 108, 124]
    {
      "description count zero with a wild offset" => { n_description: 0, off_description: 0xFFFF_FFFF },
      "odd description length" => { n_description: 3, off_description: 108 },
      "description offset inside the fixed fields" => { n_description: 4, off_description: 12 },
      "description running past the header" => { n_description: 0xFFFF_FFFF, off_description: 300 },
      "pixel format size without an offset" => { cb_pixel_format: 40, off_pixel_format: 0 },
      "pixel format offset without a size" => { cb_pixel_format: 0, off_pixel_format: 108 },
      "pixel format overlapping the description" => { n_description: 8, off_description: 108,
                                                      cb_pixel_format: 40, off_pixel_format: 112 },
      "pixel format inside the header" => { cb_pixel_format: 40, off_pixel_format: 20 },
      "OpenGL flag 1" => { b_open_gl: 1 },
      "OpenGL flag with high bits" => { b_open_gl: 0xFFFF_FFFF },
      "byte and record counts that disagree with the stream" => { n_bytes: 5, n_records: 0xFFFF_FFFF },
      "nonzero reserved and handle counts" => { reserved: 0xFFFF, n_handles: 0xFFFF, n_pal_entries: 0xFFFF_FFFF },
      "unexpected version" => { version: 0 }
    }.each do |name, overrides|
      sizes.each do |size|
        it "treats #{name} in a #{size}-byte header identically to Ruby" do
          seen = expect_identical_and_exact(wire.stream(size, **overrides))

          expect(seen[:errors]).to be_empty
          expect(seen[:scalars]).to include(n_size: size)
        end
      end
    end
  end

  describe "streams around the header" do
    it "parses a header-only stream with no records" do
      seen = expect_identical_and_exact(wire.header(108))

      expect(seen[:records]).to be_empty
    end

    it "keeps bytes after a missing EOF record in both backends" do
      expect_identical_and_exact(wire.header(88) + wire::FOLLOWING)
    end

    it "reads records from byte 88 when a short header has trailing-field look-alike bytes" do
      seen = expect_identical_and_exact(wire.header(88) + ("\xEE".b * 12) + wire::EOF_RECORD)

      expect(seen[:scalars]).to include(n_size: 88, trailing: "".b)
    end
  end

  describe "headers both backends must reject" do
    {
      "a non-header first record type" => -> { wire.header(108, type: 2) + wire::EOF_RECORD },
      "a missing EMF signature" => -> { wire.stream(108, signature: 0x464D4521) },
      "an nSize below the 8-byte record head" => -> { wire.header(108, declared_size: 4) },
      "an nSize larger than the input" => -> { wire.header(108, declared_size: 4096) },
      "an nSize of 0xFFFFFFFF" => -> { wire.header(108, declared_size: 0xFFFF_FFFF) },
      "input cut inside the fixed fields" => -> { wire.header(108).byteslice(0, 60) },
      "input cut inside the signature" => -> { wire.header(108).byteslice(0, 42) }
    }.each do |name, build|
      it "raises for #{name}" do
        input = instance_exec(&build)
        outcomes = backends.to_h do |backend|
          ENV["EMF_BACKEND"] = backend
          [backend, capture_error { Emf.parse(input) }]
        end

        expect(outcomes.fetch("ruby")).to be_a(StandardError)
        expect(outcomes.fetch("native")).to be_a(Emf::Error)
      end
    end

    # Ruby leaks BinData EOFError/IOError for these; native reports Emf::FormatError.
    # The tighter native class is deliberate; the Ruby leak is tracked separately.
    [8, 44, 87, 89, 92, 96, 99, 101, 104, 107].each do |declared|
      it "rejects nSize #{declared}, which cannot hold the fields it implies, with Emf::FormatError natively" do
        input = wire.header(124, declared_size: declared) + wire::FOLLOWING + wire::EOF_RECORD
        ENV["EMF_BACKEND"] = "native"

        expect { Emf.parse(input) }.to raise_error(Emf::FormatError)
        ENV["EMF_BACKEND"] = "ruby"
        expect { Emf.parse(input) }.to raise_error(StandardError)
      end
    end
  end

  def capture_error
    yield
    nil
  rescue StandardError => e
    e
  end
end
