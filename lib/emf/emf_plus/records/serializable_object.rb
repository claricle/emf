# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSerializableObject (2.3.5.2): an image effect parameter block
      # identified by GUID. Flags are unused.
      class SerializableObject < Base
        TYPE = 0x4038

        class SerializableObjectBody < BinData::Record
          endian :little
          string :object_guid_bytes, length: 16
          uint32 :buffer_size
          string :buffer, read_length: :buffer_size
        end
        BODY = SerializableObjectBody

        def buffer_size = body.buffer_size
        def buffer = body.buffer.to_s

        def effect = Effects.decode(self)

        def object_guid
          raw = body.object_guid_bytes.to_s
          [raw[0, 4].reverse, raw[4, 2].reverse, raw[6, 2].reverse, raw[8, 2], raw[10, 6]]
            .map { |part| part.unpack1("H*") }.join("-")
        end
      end
    end
  end
end
