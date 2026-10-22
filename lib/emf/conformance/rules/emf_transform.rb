# frozen_string_literal: true

# Transform record rules (MS-EMF 2.3.12, 2.2.28): fixed sizes, the
# ModifyWorldTransformMode enumeration and the XForm matrix values.
module Emf
  module Conformance
    module TransformRules
      EMF = %i[emf emf_plus].freeze
      SET_WORLD = 35
      MODIFY_WORLD = 36
      STATED_SIZE = { SET_WORLD => 32, MODIFY_WORLD => 36 }.freeze
      MATRIX_FIELDS = %i[m11 m12 m21 m22 dx dy].freeze
      MWT_IDENTITY = 1

      module_function

      def each_wire(context)
        context.records.each_with_index do |record, index|
          next unless STATED_SIZE.key?(context.record_type(record))

          wire = record.wire
          yield(record, index, wire) if wire.is_a?(Emf::Emr::Binary::Record)
        end
      end

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end

      def fixed_size(context)
        found = []
        each_wire(context) do |record, index, _wire|
          type = context.record_type(record)
          size = context.record_size(record)
          next if size == STATED_SIZE.fetch(type)

          found << at(record, index, "#{RecordTypes.name(type)} Size is #{size}, the record section states #{STATED_SIZE.fetch(type)}")
        end
        found
      end

      def modify_mode(context)
        found = []
        each_wire(context) do |record, index, wire|
          next unless context.record_type(record) == MODIFY_WORLD

          mode = wire.modify_mode.to_i
          next if (1..4).cover?(mode)

          found << at(record, index,
                      "EMR_MODIFYWORLDTRANSFORM ModifyWorldTransformMode #{mode} is not in the enumeration (MWT_IDENTITY..MWT_SET, 1..4)")
        end
        found
      end

      # MWT_IDENTITY ignores the transform data, so its matrix is not inspected.
      def finite_matrix(context)
        found = []
        each_wire(context) do |record, index, wire|
          next if context.record_type(record) == MODIFY_WORLD && wire.modify_mode.to_i == MWT_IDENTITY

          bad = MATRIX_FIELDS.reject { |field| wire.xform.public_send(field).to_f.finite? }
          next if bad.empty?

          found << at(record, index, "#{RecordTypes.name(context.record_type(record))} XForm #{bad.join(', ')} is not a finite number")
        end
        found
      end
    end

    registry = Registry.loading
    transform = TransformRules::EMF
    registry.register(id: "emf.transform.fixed_size", formats: transform, citation: "MS-EMF 2.3.12", kind: :fixed_size) do |c|
      TransformRules.fixed_size(c)
    end
    registry.register(id: "emf.transform.modify_mode", formats: transform, citation: "MS-EMF 2.3.12.1", kind: :modify_mode) do |c|
      TransformRules.modify_mode(c)
    end
    # The XForm section defines six FLOAT values and states no finiteness requirement.
    registry.register(id: "emf.transform.finite_matrix", formats: transform, citation: "MS-EMF 2.2.28", kind: :finite_matrix,
                      severity: :warning) { |c| TransformRules.finite_matrix(c) }
  end
end
