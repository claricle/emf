# frozen_string_literal: true

require_relative "record_variants"

# Variants for the stream-control records: EMR_EOF (MS-EMF 2.3.4.1), EMR_COMMENT
# (2.3.3.1, including the EMF+ and public comment identifiers) and Raw, the
# fallback for type codes the registry does not name.
module RecordVariants
  self.catalog = :control
  EMF_PLUS_HEADER = [0x4001, 1, 28, 16, 0xDBC0_1002, 1, 96, 96].pack("vvV2V4").freeze

  module ControlBuilders
    def comment(payload, declared: nil)
      padded = payload + ("\0".b * ((4 - (payload.bytesize % 4)) % 4))
      u32("cb_data", declared || payload.bytesize) + raw("data", padded) + check("data", padded)
    end
  end
  Entry.include(ControlBuilders)

  define("Eof", 14) do
    valid("no palette", u32("n_pal_entries", 0), u32("off_pal_entries", 16), u32("n_size_last", 20))
    valid("size-last mismatch", u32("n_pal_entries", 0), u32("off_pal_entries", 16), u32("n_size_last", UINT_MAX))
    valid("palette entries declared and present", u32("n_pal_entries", 2), u32("off_pal_entries", 16),
          pad("\x01\x02\x03\x00\x04\x05\x06\x00".b), pad([28].pack("V")))
    valid("palette count with offset beyond record", u32("n_pal_entries", 7), u32("off_pal_entries", 4096), u32("n_size_last", 20))
    malformed("body shorter than fields", raw("body", [0, 16].pack("V2")))
  end

  define("Comment", 70) do
    valid("empty", u32("cb_data", 0), check("data", ""))
    valid("public GDIC comment", comment("GDIC#{[1, 2].pack('V2')}"))
    valid("EMF+ header", comment("EMF+#{EMF_PLUS_HEADER}"))
    valid("length not 4-aligned", comment("abcde"))
    valid("declared length below payload", u32("cb_data", 2), raw("data", "abcdefgh"), check("data", "abcdefgh"))
    malformed("declared length exceeds record", u32("cb_data", 4096), raw("data", "abcd"))
    malformed("body shorter than length field", raw("data", "\0\0".b))
  end

  define("Raw", 0xFFFF) do
    valid("unknown type, empty payload", check("i_type", 0xFFFF), check("payload", ""))
    valid("unknown type, payload", raw("payload", "RAW!"), check("i_type", 0xFFFF))
    [[0, "zero type"], [123, "type just above registry"], [0x7FFF_FFFF, "large type"], [UINT_MAX, "max type"]].each do |code, label|
      valid(label, raw("payload", "\x01\x02\x03\x04".b), check("i_type", code), type_code: code)
    end
  end
end
