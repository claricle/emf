# frozen_string_literal: true

module Emf
  module EmfPlus
    module Serializer
      module_function

      def call(frames)
        frames.map(&:to_binary).join.b
      end

      # Re-serializes frames per originating comment: { record index => payload
      # bytes (without the "EMF+" identifier) }, ready to write back into the
      # matching EMR_COMMENT.
      def by_comment(frames)
        frames.group_by(&:comment_index).transform_values { |group| call(group) }
      end
    end
  end
end
