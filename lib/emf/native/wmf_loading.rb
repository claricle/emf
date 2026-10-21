# frozen_string_literal: true

module Emf
  module Native
    # The WMF entry points of the native library, loaded on first use. Mixed into Loader, which owns the
    # buffer, status and pointer helpers these call.
    module WmfLoading
      def wmf_document(bytes)
        load_wmf_functions
        output = slot
        checked(:emf_wmf_parse, bytes, bytes.bytesize, 0, output)
        yield pointer(output)
      ensure
        invoke(:emf_wmf_document_free, pointer(output)) if output && pointer(output) != 0
      end

      def wmf_snapshot(document)
        buffer(:emf_wmf_document_snapshot, document)
      end

      # The first phase of the Ruby WMF contract that rejects `bytes`, under the caller's limits (WMFR v1).
      def wmf_rejection(bytes, max_input_bytes, max_records)
        load_wmf_functions
        buffer(:emf_wmf_rejection, bytes, bytes.bytesize, max_input_bytes, max_records)
      end

      private

      def load_wmf_functions
        return if @functions.key?(:emf_wmf_parse)

        pointer = Loader::POINTER
        uint64 = Loader::UINT64
        signatures = {
          emf_wmf_parse: [[pointer, uint64, pointer, pointer, pointer], Fiddle::TYPE_INT],
          emf_wmf_document_snapshot: [[pointer, pointer, pointer], Fiddle::TYPE_INT],
          emf_wmf_rejection: [[pointer, uint64, uint64, uint64, pointer, pointer], Fiddle::TYPE_INT],
          emf_wmf_document_free: [[pointer], Fiddle::TYPE_VOID]
        }
        functions = signatures.to_h do |name, (arguments, result)|
          [name, Fiddle::Function.new(@library[name.to_s], arguments, result)]
        end
        @functions.merge!(functions)
      rescue Fiddle::DLError => e
        raise Unavailable, "native WMF backend could not load: #{e.message}"
      end
    end
  end
end
