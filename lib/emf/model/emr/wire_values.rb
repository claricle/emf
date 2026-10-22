# frozen_string_literal: true

module Emf
  module Model
    module Emr
      # `WireAdapter#values`: the record's field values as plain frozen Ruby
      # objects, without making BinData field objects. See
      # Emf::Emr::Binary::ValueView for the shape.
      module WireValues
        # The field values the record holds now, or nil when its wire class
        # has no value view (variable-layout records such as ExtTextOut,
        # strings, bitmaps and Raw): use `wire` for those.
        #
        # A field of the wire not made yet is still the record's bytes, so
        # the values are unpacked from them (one String#unpack; kept and
        # returned again while no field has been made). A field made through
        # `wire` may have been edited, so it is read from the wire and the
        # rest from the bytes. An edit through `wire` is always reflected.
        # Equal on the Ruby and native backends.
        def values
          view = Emf::Emr::Binary::ValueView.for_class(@wire ? @wire.class : @wire_source.wire_class)
          return unless view

          data, base, untouched = byte_source
          if data
            found = untouched ? (@values ||= view.from_bytes(data, base)) : view.from_mixed(data, base, @wire)
            return found if found
          end
          view.from_wire(wire)
        end

        private

        # [data, offset, untouched] of the bytes the record is filled from.
        def byte_source
          return @wire_source.value_source unless @wire

          @wire.lazy_source if @wire.respond_to?(:lazy_source)
        end
      end
    end
  end
end
