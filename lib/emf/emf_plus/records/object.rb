# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusObject (2.3.5.1). ObjectData stays opaque. When the C flag is
      # set the body starts with TotalObjectSize (counted inside DataSize and
      # repeated in every chunk); see ObjectChain for joining chunks.
      class Object < Base
        TYPE = 0x4008
        CONTINUED_FLAG = 0x8000
        TYPE_MASK = 0x7F00
        ID_MASK = 0x00FF

        class ObjectBody < BinData::Record
          endian :little
          mandatory_parameter :data_size
          mandatory_parameter :flags
          uint32 :total_object_size, onlyif: -> { flags.anybits?(CONTINUED_FLAG) }
          string :object_data, read_length: -> { data_size - (flags.anybits?(CONTINUED_FLAG) ? 4 : 0) }
        end
        BODY = ObjectBody

        def object_type = (flags & TYPE_MASK) >> 8
        def emf_object_id = flags & ID_MASK
        def continued? = flags.anybits?(CONTINUED_FLAG)
        def total_object_size = continued? ? body.total_object_size.to_i : nil
        def object_data = body.object_data.to_s
      end
    end
  end
end
