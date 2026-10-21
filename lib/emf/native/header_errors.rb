# frozen_string_literal: true

module Emf
  module Native
    # Native reports header truncation by byte position; the Ruby parser names the
    # header's own nSize. When Ruby would reject the same input with a FormatError,
    # report Ruby's wording, including an nSize too small for the fields it implies.
    module HeaderErrors
      module_function

      def translate(error, input)
        return error if input.bytesize < 8

        size = input.unpack1("@4V")
        return FormatError.new("EMF header nSize too small: #{size}") if size < 8
        return FormatError.new("truncated EMF header (claimed #{size}, got #{input.bytesize})") if input.bytesize < size
        return FormatError.new("EMF header nSize #{size} cannot hold its fields") unless ruby_header_fits?(input, size)

        error
      end

      def ruby_header_fits?(input, size)
        Emr::Binary::Header.read(input.byteslice(0, size))
        true
      rescue IOError
        false
      end
    end
  end
end
