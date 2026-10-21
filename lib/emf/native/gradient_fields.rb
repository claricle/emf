# frozen_string_literal: true

module Emf
  module Native
    module GradientFields
      # The snapshot carries bounds, ulMode and the widened counts. Elements are
      # not sized here: Ruby keeps everything after the fixed prefix as body.
      def self.call(payload, raw)
        raise FormatError, "invalid native gradient payload" if payload.bytesize < 36 || raw.bytesize < 36

        mode, vertices, meshes = payload.byteslice(16, 20).unpack("VQ<2")
        unless raw.byteslice(8, 16) == payload.byteslice(0, 16) && raw.byteslice(24, 8).unpack("V2") == [vertices, meshes] &&
               raw.byteslice(32, 4).unpack1("V") == mode
          raise FormatError, "invalid native gradient fields"
        end

        [Emr::Binary::Records::GradientFill,
         { rcl_bounds: %i[left top right bottom].zip(payload.unpack("l<4")).to_h,
           n_ver: vertices, n_tri: meshes, ul_mode: mode, body: raw.byteslice(36..) }]
      end
    end
  end
end
