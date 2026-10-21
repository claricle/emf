# frozen_string_literal: true

module Emf
  module Wmf
    # Read-only views of recognized Escape subtypes. Data stays inert: nothing is
    # executed, interpreted or decoded, and the record's raw fields remain the source
    # of truth, so serialization is unaffected by taking a view.
    module EscapeViews
      # kind is the subtype name; fields holds the raw numeric fields (empty for empty subtypes).
      Payload = Struct.new(:kind, :fields, keyword_init: true)
      # kind names a counted subtype; data is the exact counted bytes.
      CountedPayload = Struct.new(:kind, :data, keyword_init: true)
      SpecialPassthrough2 = Struct.new(:reserved, :data, keyword_init: true)

      EMPTY = {
        0x0002 => :abort_doc, 0x1000 => :begin_path, 0x1010 => :close_channel, 0x0202 => :download_face,
        0x100F => :download_header, 0x1002 => :end_path, 0x000B => :end_doc, 0x0200 => :ext_text_out,
        0x002A => :get_device_units, 0x0100 => :get_extended_text_metrics, 0x0201 => :get_face_name,
        0x0102 => :get_pair_kern_table, 0x000C => :get_phys_page_size, 0x000D => :get_printing_offset,
        0x000E => :get_scaling_factor, 0x0801 => :metafile_driver, 0x0001 => :new_frame, 0x0003 => :next_band,
        0x0026 => :postscript_ignore, 0x100E => :open_channel, 0x0C01 => :query_dib_support
      }.freeze

      # [kind, byte length, unpack format, value names] keyed by escape function.
      FIXED = {
        0x1001 => [:clip_to_path, 4, "v2", %i[clip_function reserved1]],
        0x0019 => [:draw_pattern_rect, 20, "l<4v2", %i[position_x position_y size_width size_height style pattern]],
        0x0021 => [:eps_printing, 2, "v", %i[set_eps_printing]],
        0x1019 => [:get_ps_feature_setting, 4, "l<", %i[feature]],
        0x0008 => [:query_esc_support, 2, "v", %i[query]],
        0x0011 => [:set_copy_count, 2, "v", %i[copy_count]],
        0x0015 => [:set_line_cap, 4, "l<", %i[cap]],
        0x0016 => [:set_line_join, 4, "l<", %i[join]],
        0x0017 => [:set_miter_limit, 4, "l<", %i[miter_limit]]
      }.freeze

      COUNTED = {
        0x0013 => :passthrough, 0x0025 => :postscript_data, 0x1013 => :postscript_passthrough, 0x000A => :start_doc,
        0x1017 => :check_jpeg_format, 0x1018 => :check_png_format, 0x0004 => :set_color_table
      }.freeze
      START_DOC_LIMIT = 260
      SPCLPASSTHROUGH2 = 0x11D8

      module_function

      # Empty or fixed-size payload; nil for unknown subtypes, unexpected sizes or padding.
      def typed_payload(record)
        return unless dc_escape?(record) && record.padding.nil?

        data = record.data
        return (kind = EMPTY[record.escape_function]) && Payload.new(kind: kind, fields: {}) if data.empty?

        kind, length, format, names = FIXED[record.escape_function]
        return unless kind && data.bytesize == length

        Payload.new(kind: kind, fields: names.zip(data.unpack(format)).to_h)
      end

      # The complete counted payload; nil for other subtypes, invalid alignment or oversized STARTDOC.
      def typed_counted_payload(record)
        return unless dc_escape?(record) && aligned?(record)

        kind = COUNTED[record.escape_function] or return
        return if kind == :start_doc && record.data.bytesize >= START_DOC_LIMIT

        CountedPayload.new(kind: kind, data: record.data)
      end

      # SPCLPASSTHROUGH2 only when its inner size consumes the exact payload.
      def typed_special_passthrough2_payload(record)
        return unless dc_escape?(record) && record.escape_function == SPCLPASSTHROUGH2 && aligned?(record)
        return unless record.data.bytesize >= 6

        reserved, size = record.data.unpack("Vv")
        return unless record.data.bytesize == 6 + size

        SpecialPassthrough2.new(reserved: reserved, data: record.data.byteslice(6..))
      end

      def dc_escape?(record)
        record.type_id & 0xFF == 0x26
      end

      def aligned?(record)
        record.padding.nil? != record.data.bytesize.odd? && record.data.bytesize <= 0xFFFF
      end
    end
  end
end
