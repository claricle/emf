# frozen_string_literal: true

module CanonicalObservationsHelpers
  def unpack_hex(hex)
    [hex].pack("H*")
  end

  def decode(node)
    Base64.strict_decode64(node.dig("binary", "base64"))
  end

  def xform(*words)
    Emf::Binary::Types::XForm.read(words.pack("V*"))
  end

  def floats(xform)
    BackendParity::WireWalker.new.call(xform).fetch("fields").transform_values { |f| f.dig("float", "wire_hex") }
  end
end
