# frozen_string_literal: true

require "fiddle"

module Emf
  module Native
    class Loader
      POINTER = Fiddle::TYPE_VOIDP
      UINT64 = Fiddle::TYPE_LONG_LONG
      SIGNATURES = {
        emf_abi_version: [[], Fiddle::TYPE_INT],
        emf_parse: [[POINTER, UINT64, POINTER, POINTER, POINTER], Fiddle::TYPE_INT],
        emf_document_snapshot: [[POINTER, POINTER, POINTER], Fiddle::TYPE_INT],
        emf_record_bytes: [[POINTER, UINT64, POINTER, POINTER], Fiddle::TYPE_INT],
        emf_buffer_view: [[POINTER, POINTER, POINTER], Fiddle::TYPE_INT],
        emf_error_view: [[POINTER, POINTER], Fiddle::TYPE_INT],
        emf_document_free: [[POINTER], Fiddle::TYPE_VOID],
        emf_buffer_free: [[POINTER], Fiddle::TYPE_VOID],
        emf_error_free: [[POINTER], Fiddle::TYPE_VOID]
      }.freeze

      def initialize(path)
        raise Unavailable, "native backend requires a 64-bit process" unless Fiddle::SIZEOF_VOIDP == 8

        @library = Fiddle.dlopen(path)
        @functions = SIGNATURES.to_h do |name, (arguments, result)|
          [name, Fiddle::Function.new(@library[name.to_s], arguments, result)]
        end
        raise Unavailable, "native backend ABI version mismatch (expected 1)" unless invoke(:emf_abi_version) == 1
      rescue Fiddle::DLError => e
        raise Unavailable, "native backend could not load: #{e.message}"
      end

      def document(bytes)
        output = slot
        checked(:emf_parse, bytes, bytes.bytesize, 0, output)
        yield pointer(output)
      ensure
        invoke(:emf_document_free, pointer(output)) if output && pointer(output) != 0
      end

      def snapshot(document)
        buffer(:emf_document_snapshot, document)
      end

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

      def record_bytes(document, index)
        buffer(:emf_record_bytes, document, index)
      end

      private

      def load_wmf_functions
        return if @functions.key?(:emf_wmf_parse)

        signatures = {
          emf_wmf_parse: [[POINTER, UINT64, POINTER, POINTER, POINTER], Fiddle::TYPE_INT],
          emf_wmf_document_snapshot: [[POINTER, POINTER, POINTER], Fiddle::TYPE_INT],
          emf_wmf_document_free: [[POINTER], Fiddle::TYPE_VOID]
        }
        functions = signatures.to_h do |name, (arguments, result)|
          [name, Fiddle::Function.new(@library[name.to_s], arguments, result)]
        end
        @functions.merge!(functions)
      rescue Fiddle::DLError => e
        raise Unavailable, "native WMF backend could not load: #{e.message}"
      end

      def invoke(name, *arguments)
        @functions.fetch(name).call(*arguments)
      end

      def slot
        Fiddle::Pointer["\0" * 8]
      end

      def pointer(output)
        output[0, 8].unpack1("J")
      end

      def checked(name, *arguments)
        error = slot
        status = invoke(name, *arguments, error)
        return if status.zero?

        message = error_message(pointer(error), status)
        raise FormatError, message
      ensure
        invoke(:emf_error_free, pointer(error)) if error && pointer(error) != 0
      end

      def error_message(error, status)
        return "native operation failed (status #{status})" if error.zero?

        info = Fiddle::Pointer[[48, 1].pack("L2") + ("\0" * 40)]
        return "native operation failed (status #{status})" unless invoke(:emf_error_view, error, info).zero?

        address, length = info[32, 16].unpack("JQ")
        Fiddle::Pointer.new(address)[0, length].force_encoding(Encoding::UTF_8)
      end

      def buffer(name, *arguments)
        output = slot
        checked(name, *arguments, output)
        data = slot
        length = slot
        status = invoke(:emf_buffer_view, pointer(output), data, length)
        raise FormatError, "native buffer view failed (status #{status})" unless status.zero?

        Fiddle::Pointer.new(pointer(data))[0, pointer(length)]
      ensure
        invoke(:emf_buffer_free, pointer(output)) if output && pointer(output) != 0
      end
    end
  end
end
