# frozen_string_literal: true

module Emf
  module SpecSupport
    # Builds raw EMF+ records; size and data_size can be overridden to make malformed ones.
    module EmfPlusRecords
      def record(type, data, flags: 0, size: 12 + data.bytesize, data_size: data.bytesize)
        [type, flags, size, data_size].pack("vvVV") + data
      end
    end
  end
end
