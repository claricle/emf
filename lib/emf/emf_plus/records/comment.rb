# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusComment (2.3.3.4): opaque private data.
      class Comment < Base
        TYPE = 0x4003

        class CommentBody < Body
          endian :little
          mandatory_parameter :data_size
          string :private_data, read_length: :data_size
        end
        BODY = CommentBody

        def private_data = body.private_data.to_s
      end
    end
  end
end
