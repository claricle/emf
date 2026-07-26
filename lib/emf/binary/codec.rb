# frozen_string_literal: true

require "bindata"

module Emf
  module Binary
    module Codec
      module_function

      def utf16le_to_utf8(bytes)
        bytes.dup.force_encoding("UTF-16LE").encode("UTF-8")
      end

      def cp1252_to_utf8(bytes)
        bytes.dup.force_encoding("CP1252").encode("UTF-8")
      end
    end
  end
end
