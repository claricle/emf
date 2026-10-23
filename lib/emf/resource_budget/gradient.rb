# frozen_string_literal: true

module Emf
  class ResourceBudget
    module Gradient
      module_function

      def decode(_kind, payload, budget) # rubocop:disable Naming/PredicateMethod
        return false if payload.length < 28

        vertices = payload.u32(16)
        meshes = payload.u32(20)
        mode = payload.u32(24)
        element = mode == 2 ? 12 : 8
        indexed = 28 + (vertices * 16) + (meshes * element)
        return false if mode > 2 || indexed > payload.length

        # Native reserves work even when an invalid index later recovers as Raw.
        budget.charge_work(vertices + meshes)
        index_start = 28 + (vertices * 16)
        (meshes * element / 4).times do |index|
          return false if payload.u32(index_start + (index * 4)) >= vertices
        end
        # Native charges twelve bytes per rectangle even when padding is absent.
        budget.charge_alloc((vertices * budget.layout(:tri_vertex)) + (meshes * 12))
        true
      end
    end
  end
end
