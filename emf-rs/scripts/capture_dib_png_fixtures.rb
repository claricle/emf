# frozen_string_literal: true

# Capture DIB→PNG ground-truth fixtures from the emfsvg Ruby chain.
#
# Runs the real renderer over the parity corpus with capture hooks prepended
# to Emfsvg::DibDecoder and Emfsvg::PngEncoder, then writes one fixture
# directory per decode call:
#
#   <out>/<emf-stem>-<nnn>/
#     dib.bin        the exact bytes passed to DibDecoder.decode
#     meta.json      bits_offset, mono_palette, decoded dims/color_type,
#                    and (for rgba) a sha256 of the RGBA surface
#     expected.png   PngEncoder.encode output (omitted for pass-through)
#     passthrough.bin raw embedded bytes for BI_PNG color_type
#     ruby_rgba.bin  the Ruby-decoded RGBA surface (pixel-exact oracle)
#
# Usage (from the emfsvg checkout, so its bundle provides emf + emfsvg):
#   EMF_FIXTURE_ROOT=/tmp/emfsvg-parity-corpus OUT=/tmp/dib-capture \
#     bundle exec ruby ../emf-rs/scripts/capture_dib_png_fixtures.rb
#
# The corpus root layout matches emfsvg's parity manifest (spec/fixtures/*/*.emf).

require "digest"
require "fileutils"
require "json"
require "emfsvg"

capture_root = ENV.fetch("OUT")
fixture_root = ENV.fetch("EMF_FIXTURE_ROOT")

# Per-render capture buffers and the anonymous hook modules that prepend to
# the codec singleton classes.
calls = { dib: [], png: [] }

dib_hook = Module.new do
  define_method(:decode) do |dib_bytes, bits_offset: nil, mono_palette: nil|
    # define_method blocks do not support implicit super; pass everything.
    result = super(dib_bytes, bits_offset: bits_offset, mono_palette: mono_palette)
    calls[:dib] << {
      dib: dib_bytes.dup,
      bits_offset: bits_offset,
      mono_palette: mono_palette,
      result: result
    }
    result
  end
end

png_hook = Module.new do
  define_method(:encode) do |width, height, rgba_bytes|
    out = super(width, height, rgba_bytes)
    calls[:png] << { width: width, height: height, rgba: rgba_bytes.dup, png: out }
    out
  end
end

Emfsvg::DibDecoder.singleton_class.prepend(dib_hook)
Emfsvg::PngEncoder.singleton_class.prepend(png_hook)

# Match each decode to the encode whose RGBA input digest equals the decode's
# rgba surface (the encoder is only ever fed decoded surfaces), then write the
# fixture directory for the call.
def write_capture(capture_root, stem, index, call, encode_by_digest)
  result = call[:result]
  return unless result

  dir = File.join(capture_root, "#{stem}-#{format('%03i', index)}")
  FileUtils.mkdir_p(dir)
  File.binwrite(File.join(dir, "dib.bin"), call[:dib])
  meta = {
    "bits_offset" => call[:bits_offset],
    "mono_palette" => call[:mono_palette],
    "width" => result.width,
    "height" => result.height,
    "color_type" => result.color_type.to_s
  }
  case result.color_type
  when :rgba
    rgba = result.pixels.to_s
    meta["rgba_sha256"] = Digest::SHA256.hexdigest(rgba)
    File.binwrite(File.join(dir, "ruby_rgba.bin"), rgba)
    matches = encode_by_digest[meta["rgba_sha256"]]
    if matches
      png = matches.first[:png].to_s
      # PngEncoder pads to a multiple of 3 for base64; strip the padding
      # zeros the base64 path appends after the IEND chunk.
      png = png.sub(/(\x00+)\z/, "") if png.end_with?("\x00")
      File.binwrite(File.join(dir, "expected.png"), png)
      # Pixel-exact oracle: the Ruby decoder's RGBA for the emitted PNG.
      decoded = Emfsvg::PngDecoder.decode(png)
      if decoded
        meta["decoded_width"] = decoded.width
        meta["decoded_height"] = decoded.height
        meta["decoded_rgba_sha256"] = Digest::SHA256.hexdigest(decoded.pixels.to_s)
      end
    else
      warn "no encode match: #{stem}##{index}"
    end
  when :png
    File.binwrite(File.join(dir, "passthrough.bin"), result.pixels.to_s)
  end
  File.write(File.join(dir, "meta.json"), JSON.pretty_generate(meta))
end

# Deterministic order fixes which same-payload call the dedup keeps.
emf_paths = Dir.glob(File.join(fixture_root, "spec", "fixtures", "**", "*.emf"), sort: true)
puts "corpus EMFs: #{emf_paths.size}"
rendered = 0
failed = 0

emf_paths.each do |path|
  stem = File.basename(path, ".emf")
  calls[:dib].clear
  calls[:png].clear
  begin
    Emfsvg.from_file(path)
    rendered += 1
  rescue StandardError, NotImplementedError => e
    failed += 1
    warn "render failed: #{stem}: #{e.class}: #{e.message}"
  end

  encode_by_digest = calls[:png].group_by do |call|
    Digest::SHA256.hexdigest(call[:rgba].to_s)
  end
  calls[:dib].each_with_index do |call, i|
    write_capture(capture_root, stem, i, call, encode_by_digest)
  end
end

count = Dir.glob(File.join(capture_root, "*", "meta.json")).size
puts "rendered: #{rendered} failed: #{failed} captured: #{count}"
