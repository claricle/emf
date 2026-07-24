# frozen_string_literal: true

module Emf
  module Detector
    APM_MAGIC = 0x9AC6CDD7 # bytes 0xD7 0xCD 0xC6 0x9A, read as uint32 little-endian
    EMF_SIGNATURE = 1
    EMF_MAGIC_OFFSET = 0x28
    EMF_MAGIC = 0x464D4520

    module_function

    def call(bytes)
      raise FormatError, "input too short (#{bytes.bytesize} bytes)" if bytes.bytesize < 4

      case first_uint32_le(bytes)
      when APM_MAGIC then :wmf_apm
      when EMF_SIGNATURE
        return :emf if looks_like_emf?(bytes)
        return :wmf_standard if looks_like_wmf_metaheader?(bytes)

        raise FormatError, "unrecognised format (signature=1 but no EMF magic or WMF header)"
      else
        return :wmf_standard if looks_like_wmf_metaheader?(bytes)

        raise FormatError, format("unrecognised format (first uint32=0x%08X)", first_uint32_le(bytes))
      end
    end

    def looks_like_emf?(bytes)
      return false unless bytes.bytesize >= EMF_MAGIC_OFFSET + 4

      read_uint32_le(bytes, EMF_MAGIC_OFFSET) == EMF_MAGIC
    end

    def looks_like_wmf_metaheader?(bytes)
      return false unless bytes.bytesize >= 18

      mt = read_uint16_le(bytes, 0)
      hs = read_uint16_le(bytes, 2)
      [1, 2].include?(mt) && hs == 9
    end

    def first_uint32_le(bytes)
      read_uint32_le(bytes, 0)
    end

    def read_uint32_le(bytes, offset)
      bytes.getbyte(offset) |
        (bytes.getbyte(offset + 1) << 8) |
        (bytes.getbyte(offset + 2) << 16) |
        (bytes.getbyte(offset + 3) << 24)
    end

    def read_uint16_le(bytes, offset)
      bytes.getbyte(offset) | (bytes.getbyte(offset + 1) << 8)
    end
  end
end
