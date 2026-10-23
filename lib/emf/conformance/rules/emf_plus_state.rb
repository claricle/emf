# frozen_string_literal: true

return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

require_relative "emf_plus_common"

# Save/Restore and BeginContainer/EndContainer matching over the record sequence.
# Restore and EndContainer name a StackIndex a previous Save or Begin record
# assigned (MS-EMFPLUS 2.3.7); the two are separate stacks in the spec's wording.
module Emf
  module Conformance
    module EmfPlusState
      Records = Emf::EmfPlus::Records
      Support = EmfPlusSupport

      # id => [opener classes, closer class, closer name, opener name, which defects the rule reports].
      # :unknown is a StackIndex no earlier opener ever assigned; :stale is one that was assigned and is already
      # popped (or skipped over). Only the Restore rule splits them; EndContainer reports both.
      PAIRS = {
        "emfplus.state.restore_unmatched" =>
          [[Records::Save], Records::Restore, "EmfPlusRestore", "EmfPlusSave", :stale],
        "emfplus.state.end_container_unmatched" =>
          [[Records::BeginContainer, Records::BeginContainerNoParams], Records::EndContainer, "EmfPlusEndContainer",
           "a begin-container record", :any]
      }.freeze

      # LibreOffice's TestEmfPlusSave.emf restores StackIndex 0 before any EmfPlusSave. GDI+ fails such a restore and
      # draws on, so the tolerant profile warns; a restore of a state that was saved and already popped stays an error.
      UNKNOWN_RESTORE = "emfplus.state.restore_unknown_state"
      UNKNOWN_RESTORE_REASON = "a Restore naming a StackIndex no earlier EmfPlusSave assigned fails in GDI+ and is " \
                               "ignored; the rest of the stream still renders"

      module_function

      # Restoring (or ending) index N pops every level pushed after N's push, like GDI+.
      def unmatched(context, opens, closer, closer_name, opener_name, report = :any)
        stack = []
        seen = {}
        Support.records(context).filter_map do |located|
          record = located.record
          if opens.any? { |klass| record.is_a?(klass) }
            stack.push(record.stack_index)
            seen[record.stack_index] = true
            next
          end
          next unless record.is_a?(closer)

          position = stack.rindex(record.stack_index)
          if position
            stack.slice!(position..)
            next
          end
          unknown = !seen.key?(record.stack_index)
          next if (report == :unknown && !unknown) || (report == :stale && unknown)

          Support.finding(located, "#{closer_name} StackIndex #{record.stack_index} matches no open #{opener_name}")
        end
      end
    end

    EmfPlusState::PAIRS.each do |id, args|
      Registry.loading.register(id: id, formats: [:emf_plus], citation: "MS-EMFPLUS 2.3.7", kind: :state_matching,
                                tolerant_reason: nil) { |context| EmfPlusState.unmatched(context, *args) }
    end

    Registry.loading.register(id: EmfPlusState::UNKNOWN_RESTORE, formats: [:emf_plus], citation: "MS-EMFPLUS 2.3.7",
                              kind: :state_matching, tolerant_reason: EmfPlusState::UNKNOWN_RESTORE_REASON) do |context|
      EmfPlusState.unmatched(context, *EmfPlusState::PAIRS.fetch("emfplus.state.restore_unmatched")[0..3], :unknown)
    end
  end
end
