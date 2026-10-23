# frozen_string_literal: true

module Emf
  module SpecSupport
    module ResourceContract
      def with_resource_backend(backend)
        original = ENV.fetch("EMF_BACKEND", nil)
        ENV["EMF_BACKEND"] = backend
        yield
      ensure
        original ? ENV["EMF_BACKEND"] = original : ENV.delete("EMF_BACKEND")
      end

      def native_resource_parse(loader, bytes, ceilings)
        limits = Fiddle::Pointer[[48, 1].pack("L2") + ceilings.pack("Q5")]
        output = Fiddle::Pointer["\0" * 8]
        loader.send(:checked, :emf_parse, bytes, bytes.bytesize, limits, output)
        true
      ensure
        handle = output[0, 8].unpack1("J") if output
        loader.send(:invoke, :emf_document_free, handle) if handle && !handle.zero?
      end

      def minimal_resource_emf
        bytes = "\0" * 88
        bytes[0, 8] = [1, 88].pack("V2")
        bytes[40, 4] = [0x464D4520].pack("V")
        bytes
      end

      def resource_loader(status, code: 1, limit: 9, actual: 10, view_status: 0)
        loader = Emf::Native::Loader.allocate
        functions = {
          emf_parse: lambda do |_bytes, _length, _limits, _output, error|
            error[0, 8] = [456].pack("J")
            status
          end,
          emf_error_resource_view: lambda do |_error, info|
            info[8, 24] = [code, 0, limit, actual].pack("L2Q2")
            view_status
          end,
          emf_error_free: ->(_error) {},
          emf_document_free: ->(_document) {},
          emf_error_view: ->(_error, _info) { 5 }
        }
        loader.instance_variable_set(:@functions, functions)
        loader
      end
    end
  end
end
