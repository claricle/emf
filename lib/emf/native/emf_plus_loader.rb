# frozen_string_literal: true

require_relative "loader"

module Emf
  module Native
    # Adds the independent EMF+ snapshot call (emf_document_emf_plus_snapshot_v1)
    # to the production Loader without touching its outer-snapshot signatures.
    class EmfPlusLoader < Loader
      SNAPSHOT_VERSION = 1
      # struct_size, version, max_output_bytes
      DEFAULT_OPTIONS = [16, SNAPSHOT_VERSION, 1 << 30].pack("VVQ<").freeze

      def initialize(path)
        super
        signature = [POINTER, POINTER, POINTER, POINTER, POINTER]
        @functions[:emf_document_emf_plus_snapshot_v1] = Fiddle::Function.new(
          @library["emf_document_emf_plus_snapshot_v1"], signature, Fiddle::TYPE_INT
        )
      rescue Fiddle::DLError => e
        raise Unavailable, "native EMF+ snapshot could not load: #{e.message}"
      end

      # The EPSN buffer for the EMF file `bytes`; raises FormatError for malformed
      # nested EMF+ and Error for a resource limit.
      def emf_plus_snapshot(bytes)
        document(bytes.b) do |handle|
          buffer(:emf_document_emf_plus_snapshot_v1, handle, DEFAULT_OPTIONS, 0)
        end
      end
    end
  end
end
