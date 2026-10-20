# frozen_string_literal: true

module Emf
  module Native
    # Owns validated Ruby values, never a native document or its hydrator.
    class LazyWire
      XFORM_LEAVES = %i[m11 m12 m21 m22 dx dy].each_with_index.map { |name, index| [[:xform, name], 8 + (index * 4)] }.freeze
      TEXT_SCALE_LEAVES = [[[:ex_scale], 28], [[:ey_scale], 32]].freeze

      # Whole-record byte offsets of each float32 leaf, header included.
      FLOAT_LEAVES = {
        Emr::Binary::Records::SetWorldTransform => XFORM_LEAVES,
        Emr::Binary::Records::ModifyWorldTransform => XFORM_LEAVES,
        Emr::Binary::Records::AngleArc => [[[:start_angle], 20], [[:sweep_angle], 24]],
        Emr::Binary::Records::SetMiterLimit => [[[:miter_limit], 8]],
        Emr::Binary::Records::ExtTextOutA => TEXT_SCALE_LEAVES,
        Emr::Binary::Records::ExtTextOutW => TEXT_SCALE_LEAVES,
        Emr::Binary::Records::SmallTextOut => TEXT_SCALE_LEAVES
      }.freeze
      private_constant :XFORM_LEAVES, :TEXT_SCALE_LEAVES, :FLOAT_LEAVES

      def initialize(klass, fields, bytes, record)
        @klass = klass
        @fields = fields.merge(i_type: record.fetch(:type), n_size: bytes.bytesize)
        @bytes = bytes
      end

      def type_id
        @fields.fetch(:i_type)
      end

      def to_binary_s
        @bytes
      end

      def materialize
        @klass.new(**@fields).tap { |wire| restore_float_bits(wire) }
      end

      private

      # The constructor only receives Floats, and Ruby has already canonicalised
      # any NaN payload on the way in; the record bytes still hold the original.
      def restore_float_bits(wire)
        FLOAT_LEAVES.fetch(@klass, []).each do |path, offset|
          path.inject(wire) { |node, name| node.public_send(name) }
              .assign_bits(@bytes.byteslice(offset, 4).unpack1("V"))
        end
      end
    end
  end
end
