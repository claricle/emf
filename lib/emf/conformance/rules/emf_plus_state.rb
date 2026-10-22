# frozen_string_literal: true

require_relative "emf_plus_common"

# Save/Restore and BeginContainer/EndContainer matching over the record sequence.
# Restore and EndContainer name a StackIndex a previous Save or Begin record
# assigned (MS-EMFPLUS 2.3.7); the two are separate stacks in the spec's wording.
module Emf
  module Conformance
    module EmfPlusState
      Records = Emf::EmfPlus::Records
      Support = EmfPlusSupport

      PAIRS = {
        "emfplus.state.restore_unmatched" => [[Records::Save], Records::Restore, "EmfPlusRestore", "EmfPlusSave"],
        "emfplus.state.end_container_unmatched" =>
          [[Records::BeginContainer, Records::BeginContainerNoParams], Records::EndContainer, "EmfPlusEndContainer",
           "a begin-container record"]
      }.freeze

      module_function

      # Restoring (or ending) index N pops every level pushed after N's push, like GDI+.
      def unmatched(context, opens, closer, closer_name, opener_name)
        stack = []
        Support.records(context).filter_map do |located|
          record = located.record
          if opens.any? { |klass| record.is_a?(klass) }
            stack.push(record.stack_index)
            next
          end
          next unless record.is_a?(closer)

          position = stack.rindex(record.stack_index)
          if position
            stack.slice!(position..)
            next
          end
          Support.finding(located, "#{closer_name} StackIndex #{record.stack_index} matches no open #{opener_name}")
        end
      end
    end

    EmfPlusState::PAIRS.each do |id, args|
      Registry.loading.register(id: id, formats: [:emf_plus], citation: "MS-EMFPLUS 2.3.7", kind: :state_matching,
                                tolerant_reason: nil) { |context| EmfPlusState.unmatched(context, *args) }
    end
  end
end
