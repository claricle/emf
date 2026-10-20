# frozen_string_literal: true

module Emf
  module Native
    module LegacyStateFields
      def self.call(payload, family)
        raise FormatError, "invalid native opaque payload length" if payload.bytesize < 8

        count = payload.unpack1("Q<")
        raise FormatError, "invalid native opaque payload length" unless payload.bytesize == 8 + count

        body = payload.byteslice(8..)
        semantic_family = family == 68 ? 91 : 92
        length = semantic_family == 91 ? 16 : 8
        return [Emr::Binary::Records::Raw, { payload: body }] if count < length

        klass, fields = Fields.call(body.byteslice(0, length), semantic_family)
        [klass, fields.merge(trailing: body.byteslice(length..))]
      end
    end
  end
end
