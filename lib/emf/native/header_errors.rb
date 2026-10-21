# frozen_string_literal: true

module Emf
  module Native
    # Native reports header truncation by byte position; the Ruby parser names the
    # header's own nSize. When Ruby would reject the same input with a FormatError,
    # report Ruby's wording. Anything Ruby would not reject as a FormatError
    # (it leaks BinData EOFError/IOError for nSize 8..107) keeps the native message.
    module HeaderErrors
      module_function

      def translate(error, input)
        return error if input.bytesize < 8

        size = input.unpack1("@4V")
        return FormatError.new("EMF header nSize too small: #{size}") if size < 8
        return FormatError.new("truncated EMF header (claimed #{size}, got #{input.bytesize})") if input.bytesize < size

        error
      end
    end
  end
end
