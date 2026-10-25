# frozen_string_literal: true

module Emf
  module Native
    module ResourceFailure
      RESOURCES = { 1 => :input_bytes, 2 => :record_bytes, 3 => :record_count,
                    4 => :allocated_bytes, 5 => :work_units, 6 => :output_bytes }.freeze

      private

      def resource_failure(error)
        # Older ABI-1 libraries expose only the original status and message.
        return FormatError.new(error_message(error, 3)) unless @functions.key?(:emf_error_resource_view)
        return Error.new("native resource failure has no error detail") if error.zero?

        info = Fiddle::Pointer[[32, 1].pack("L2") + ("\0" * 24)]
        return Error.new("native resource failure detail is unreadable") unless invoke(:emf_error_resource_view, error, info).zero?

        code = info[8, 4].unpack1("L")
        resource = RESOURCES[code]
        return Error.new("native resource failure has unknown resource #{code}") unless resource

        limit, actual = info[16, 16].unpack("Q2")
        ResourceLimitError.new(resource: resource, limit: limit, actual: actual)
      end
    end
  end
end
