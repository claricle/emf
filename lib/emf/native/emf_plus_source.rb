# frozen_string_literal: true

module Emf
  module Native
    # Builds the Metafile#emf_plus_stream source for a native-backed metafile.
    # The library is resolved at parse time; Native::EmfPlusStream loads lazily.
    # A reload rebuilds from the current comment bytes, not the original input.
    module EmfPlusSource
      module_function

      def call(input)
        library = LibraryPath.new.call
        lambda do |metafile, reload|
          require_relative "emf_plus_stream"
          EmfPlusStream.from_metafile(metafile, bytes: reload ? nil : input, library: library)
        end
      end
    end
  end
end
