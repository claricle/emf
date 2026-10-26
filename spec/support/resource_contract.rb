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

      def resource_record(type, size)
        raw = "\0" * size
        raw[0, 8] = [type, size].pack("V2")
        raw
      end

      def resource_array_record(type, count, truncate: false, poly_count: count)
        if [2, 3, 4, 5, 6, 85, 86, 87, 88, 89, 56, 92].include?(type)
          width = { 56 => 9, 92 => 5 }.fetch(type) { type >= 85 ? 4 : 8 }
          raw = resource_record(type, 28 + (count * width))
          raw[24, 4] = [count].pack("V")
        elsif [7, 8, 90, 91].include?(type)
          width = type >= 90 ? 4 : 8
          raw = resource_record(type, 32 + (poly_count * 4) + (count * width))
          raw[24, 8] = [poly_count, count].pack("V2")
          raw[32, poly_count * 4] = ([count] + ([0] * (poly_count - 1))).pack("V*")
        elsif type == 50
          raw = resource_record(type, 20 + (count * 4))
          raw[16, 4] = [count].pack("V")
        elsif type == 95
          raw = resource_record(type, 52 + (count * 4))
          raw[48, 4] = [count].pack("V")
        else
          fixed = { 71 => 32, 72 => 40, 73 => 28, 74 => 28, 75 => 16 }.fetch(type)
          raw = resource_record(type, fixed + 32 + (count * 16))
          raw[type == 75 ? 8 : 24, 4] = [32 + (count * 16)].pack("V")
          raw[fixed, 16] = [32, 1, count, count * 16].pack("V4")
        end
        if truncate
          raw = raw.byteslice(0...-4)
          raw[4, 4] = [raw.bytesize].pack("V")
        end
        raw
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
