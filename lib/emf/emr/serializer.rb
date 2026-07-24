# frozen_string_literal: true

module Emf
  module Emr
    module Serializer
      module_function

      def call(metafile)
        bytes = +""
        bytes << metafile.header.to_wire.to_binary_s
        metafile.records.each do |record|
          case record
          when Model::Emr::Records::WireAdapter
            bytes << record.wire.to_binary_s
          else
            raise SerializeError, "cannot serialize #{record.class} (TODO 10 lands domain to_wire)"
          end
        end
        bytes << metafile.trailing
        bytes
      end
    end
  end
end
