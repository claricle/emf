# frozen_string_literal: true

module Emf
  module Native
    module GradientFields
      def self.call(payload, raw)
        raise FormatError, "invalid native gradient payload" if payload.bytesize < 36

        mode, vertices, meshes = payload.byteslice(16, 20).unpack("VQ<2")
        expected = 36 + (vertices * 16) + (meshes * 12)
        valid = mode <= 2 && vertices <= 1_000_000 && meshes <= 1_000_000
        valid &&= payload.bytesize == expected && raw.bytesize >= expected
        raise FormatError, "invalid native gradient length" unless valid

        body = payload.byteslice(36..) + raw.byteslice((expected)..)
        [Emr::Binary::Records::GradientFill,
         { rcl_bounds: %i[left top right bottom].zip(payload.unpack("l<4")).to_h,
           n_ver: vertices, n_tri: meshes, ul_mode: mode, body: body }]
      end
    end
  end
end
