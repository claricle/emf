# frozen_string_literal: true

module Emf
  module Emr
    module Serializer
      module_function

      def call(metafile)
        bytes = String.new(encoding: Encoding::BINARY)
        bytes << metafile.header.to_wire.to_binary_s
        metafile.records.each do |record|
          unless record.is_a?(Model::Emr::Records::WireAdapter)
            raise SerializeError, "cannot serialize #{record.class} (TODO 10 lands domain to_wire)"
          end

          record.append_to(bytes)
        end
        bytes << metafile.trailing
        bytes
      end
    end
  end
end
