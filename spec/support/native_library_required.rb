# frozen_string_literal: true

# When EMF_TEST_NATIVE_LIBRARY is set (the native CI job), an example that would
# skip because the native library is missing or unloadable fails instead. Unset,
# skips stay skips so Ruby-only runs stay green.
module Emf
  module SpecSupport
    module NativeLibraryRequired
      MISSING = /EMF_TEST_NATIVE_LIBRARY|native library not built|native backend (?:could not load|is not installed)/

      def skip(message = nil)
        if ENV.key?("EMF_TEST_NATIVE_LIBRARY") && message.to_s.match?(MISSING)
          raise "native library required (EMF_TEST_NATIVE_LIBRARY=#{ENV.fetch('EMF_TEST_NATIVE_LIBRARY')}) " \
                "but example would skip: #{message}"
        end

        super
      end
    end
  end
end
