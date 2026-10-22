# frozen_string_literal: true

# State record rules (MS-EMF 2.3.11): fixed sizes, enumeration domains, nonzero
# divisors, RESTOREDC sign, and the length fields of the profile and UFI records.
module Emf
  module Conformance
    module StateRules
      EMF = %i[emf emf_plus].freeze

      # type => Size the record section states ("This value is 0x...").
      STATED_SIZE = { 16 => 12, 23 => 32, 34 => 12, 57 => 12, 98 => 12, 115 => 12 }.freeze
      # type => Size implied by a record that has fixed fields only (no Size value is stated).
      LAYOUT_SIZE = { 9 => 16, 10 => 16, 11 => 16, 12 => 16, 13 => 16, 17 => 12, 18 => 12, 19 => 12, 20 => 12, 21 => 12,
                      22 => 12, 24 => 12, 25 => 12, 27 => 16, 31 => 24, 32 => 24, 33 => 8, 52 => 8, 58 => 12, 104 => 48,
                      109 => 16, 120 => 16 }.freeze
      # Types whose Size BELOW the layout is the error emf.opaque.fixed_size (any record, decoded or Raw); this table
      # then only speaks of a Size above it, as a warning.
      SHORT_BY_OPAQUE = [104, 109].freeze
      SECTION = { 9 => "2.3.11.30", 10 => "2.3.11.31", 11 => "2.3.11.28", 12 => "2.3.11.29", 13 => "2.3.11.12",
                  16 => "2.3.11.20", 17 => "2.3.11.19", 18 => "2.3.11.11", 19 => "2.3.11.22", 20 => "2.3.11.23",
                  21 => "2.3.11.24", 22 => "2.3.11.25", 23 => "2.3.11.13", 24 => "2.3.11.26", 25 => "2.3.11.10",
                  27 => "2.3.11.4", 31 => "2.3.11.7", 32 => "2.3.11.8", 33 => "2.3.11", 34 => "2.3.11.6",
                  52 => "2.3.11", 57 => "2.3.11.9", 58 => "2.3.11.21", 98 => "2.3.11.14", 104 => "2.3.11.5",
                  109 => "2.3.11.2", 115 => "2.3.11.17", 120 => "2.3.11.27" }.freeze

      TEXT_ALIGN_MASK = 0x11F # TA_UPDATECP, horizontal 0x6, vertical 0x18, TA_RTLREADING
      HORIZONTAL_ALIGN = [0, 2, 6].freeze # TA_LEFT, TA_RIGHT, TA_CENTER
      VERTICAL_ALIGN = [0, 8, 24].freeze # TA_TOP, TA_BOTTOM, TA_BASELINE
      LAYOUT_BITS = 0x9 # LAYOUT_RTL, LAYOUT_BITMAPORIENTATIONPRESERVED (LAYOUT_LTR is 0)

      TEXT_ALIGN_SWEEP = "spec/fixtures/emf test-039 and test-040 write every alignment value 0x0..0x16, including the " \
                         "undefined 0x4, 0x10 and combinations of them; each component is still read from its own bits"

      # rule id => [type, wire field, valid?, enumeration label, record section, severity, tolerant reason]
      ENUMS = {
        "emf.state.map_mode" => [17, :map_mode, (1..8).method(:cover?), "MapMode (MM_TEXT..MM_ANISOTROPIC, 1..8)", "2.3.11.19", :error],
        "emf.state.bk_mode" => [18, :bk_mode, (1..2).method(:cover?), "BackgroundMode (TRANSPARENT 1, OPAQUE 2)", "2.3.11.11", :error],
        "emf.state.poly_fill_mode" => [19, :poly_fill_mode, (1..2).method(:cover?), "PolygonFillMode (ALTERNATE 1, WINDING 2)",
                                       "2.3.11.22", :error],
        "emf.state.rop2" => [20, :rop2, (1..16).method(:cover?), "Binary Raster Op (R2_BLACK..R2_WHITE, 1..16)", "2.3.11.23", :error],
        "emf.state.stretch_mode" => [21, :stretch_mode, (1..4).method(:cover?), "StretchMode (1..4); the record says MAY", "2.3.11.24",
                                     :warning],
        "emf.state.arc_direction" => [57, :arc_direction, (1..2).method(:cover?), "ArcDirection (AD_COUNTERCLOCKWISE 1, AD_CLOCKWISE 2)",
                                      "2.3.11.9", :error],
        "emf.state.icm_mode" => [98, :mode, (1..4).method(:cover?), "ICMMode (ICM_OFF..ICM_DONE_OUTSIDEDC, 1..4)", "2.3.11.14", :error],
        "emf.state.layout_mode" => [115, :mode, lambda { |v|
          v.nobits?(~LAYOUT_BITS)
        }, "LayoutMode flags (0x0, 0x1, 0x8)", "2.3.11.17", :error],
        "emf.state.mapper_flags" => [16, :flags, [0, 1].method(:include?), "font mapper Flags (0 or 1)", "2.3.11.20", :warning],
        "emf.state.text_align" => [22, :text_align_mode, lambda { |v|
          v.nobits?(~TEXT_ALIGN_MASK) && HORIZONTAL_ALIGN.include?(v & 0x6) && VERTICAL_ALIGN.include?(v & 0x18)
        }, "TextAlignmentMode flags (one horizontal and one vertical value, optional TA_UPDATECP and TA_RTLREADING)", "2.3.11.25", :error,
                                   TEXT_ALIGN_SWEEP]
      }.freeze

      # rule id => [type, [wire fields], record section]
      NONZERO = {
        "emf.state.scale_viewport_ext" => [31, %i[x_num x_denom y_num y_denom], "2.3.11.7"],
        "emf.state.scale_window_ext" => [32, %i[x_num x_denom y_num y_denom], "2.3.11.8"]
      }.freeze

      # type => [name field/prefix bytes, record section] for the cbName + cbData profile payload.
      PROFILE = { 112 => [12, "2.3.11.15"], 113 => [12, "2.3.11.16"], 121 => [16, "2.3.11.1"] }.freeze

      module_function

      def each_wire(context, types)
        context.records.each_with_index do |record, index|
          next unless types.include?(context.record_type(record))

          wire = record.wire
          yield(record, index, wire) if wire.is_a?(Emf::Emr::Binary::Record)
        end
      end

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end

      def size_findings(context, table, label)
        found = []
        each_wire(context, table.keys) do |record, index, _wire|
          type = context.record_type(record)
          size = context.record_size(record)
          next if size == table.fetch(type)
          next if size < table.fetch(type) && table.equal?(LAYOUT_SIZE) && SHORT_BY_OPAQUE.include?(type)

          found << at(record, index, "#{RecordTypes.name(type)} (#{SECTION.fetch(type)}) Size is #{size}, #{label} #{table.fetch(type)}")
        end
        found
      end

      def fixed_size(context) = size_findings(context, STATED_SIZE, "the record section states")

      def layout_size(context) = size_findings(context, LAYOUT_SIZE, "its fixed fields occupy")

      def enum_check(context, id)
        type, field, valid, label, section, = ENUMS.fetch(id)
        found = []
        each_wire(context, [type]) do |record, index, wire|
          value = wire.public_send(field).to_i
          next if valid.call(value)

          found << at(record, index, "#{RecordTypes.name(type)} (#{section}) #{field} 0x#{value.to_s(16)} is not a valid #{label}")
        end
        found
      end

      def nonzero(context, id)
        type, fields, section = NONZERO.fetch(id)
        found = []
        each_wire(context, [type]) do |record, index, wire|
          zero = fields.select { |field| wire.public_send(field).to_i.zero? }
          next if zero.empty?

          found << at(record, index, "#{RecordTypes.name(type)} (#{section}) #{zero.join(', ')} MUST NOT be zero")
        end
        found
      end

      def restoredc_negative(context)
        found = []
        each_wire(context, [34]) do |record, index, wire|
          saved = wire.saved_dc.to_i
          found << at(record, index, "EMR_RESTOREDC SavedDC is #{saved}, MUST be negative") unless saved.negative?
        end
        found
      end

      def color_adjustment(context)
        found = []
        each_wire(context, [23]) do |record, index, wire|
          # A body under 24 bytes is a Size under 32: emf.state.fixed_size already reports that.
          next if wire.body.to_s.bytesize < 24

          size = wire.adjustment_size
          found << at(record, index, "ColorAdjustment Size is #{size}, MUST be 0x0018") unless size == 24
          index_value = wire.illuminant_index
          if index_value > 8
            found << at(record, index,
                        "ColorAdjustment IlluminantIndex #{index_value} is not in the Illuminant enumeration (0..8)")
          end
        end
        found
      end

      def pixel_format_version(context)
        found = []
        each_wire(context, [104]) do |record, index, wire|
          next if wire.body.to_s.bytesize < 40

          version = wire.pfd_version
          found << at(record, index, "PixelFormatDescriptor nVersion is #{version}, MUST be 1") unless version == 1
        end
        found
      end

      def color_match_target(context)
        found = []
        each_wire(context, [121]) do |record, index, wire|
          next if wire.body.to_s.bytesize < 16

          unless (1..3).cover?(wire.dw_action)
            found << at(record, index,
                        "EMR_COLORMATCHTOTARGETW dwAction #{wire.dw_action} is not in the ColorSpace enumeration (1..3)")
          end
          unless (0..1).cover?(wire.dw_flags)
            found << at(record, index,
                        "EMR_COLORMATCHTOTARGETW dwFlags #{wire.dw_flags} is not in the ColorMatchToTarget enumeration (0..1)")
          end
        end
        found
      end

      def profile_bounds(context)
        found = []
        each_wire(context, PROFILE.keys) do |record, index, wire|
          prefix, section = PROFILE.fetch(context.record_type(record))
          body = wire.body.to_s.bytesize
          name = RecordTypes.name(context.record_type(record))
          if body < prefix
            next found << at(record, index,
                             "#{name} (#{section}) holds #{body} bytes after Size, fewer than its #{prefix}-byte fixed part")
          end

          need = prefix + wire.cb_name + wire.cb_data
          next unless need > body

          found << at(record, index,
                      "#{name} (#{section}) cbName #{wire.cb_name} + cbData #{wire.cb_data} need #{need} bytes after Size, " \
                      "the record holds #{body}")
        end
        found
      end

      def linked_ufis_bounds(context)
        found = []
        each_wire(context, [119]) do |record, index, wire|
          body = wire.body.to_s.bytesize
          next found << at(record, index, "EMR_SETLINKEDUFIS holds #{body} bytes after Size, fewer than uNumLinkedUFI") if body < 4

          count = wire.u_num_linked_ufi
          need = 12 + (count * 8) # uNumLinkedUFI + ufis + 8 reserved bytes
          if need > body
            found << at(record, index,
                        "EMR_SETLINKEDUFIS (2.3.11.18) uNumLinkedUFI #{count} needs #{need} bytes after Size, the record holds #{body}")
          end
        end
        found
      end
    end

    registry = Registry.loading
    state = StateRules::EMF

    registry.register(id: "emf.state.fixed_size", formats: state, citation: "MS-EMF 2.3.11", kind: :fixed_size, severity: :error) do |c|
      StateRules.fixed_size(c)
    end
    registry.register(id: "emf.state.layout_size", formats: state, citation: "MS-EMF 2.3.11", kind: :layout_size, severity: :warning) do |c|
      StateRules.layout_size(c)
    end
    StateRules::ENUMS.each do |id, (_type, _field, _valid, _label, section, severity, reason)|
      registry.register(id: id, formats: state, citation: "MS-EMF #{section}", kind: id.split(".").last.to_sym, severity: severity,
                        tolerant_reason: reason) do |c|
        StateRules.enum_check(c, id)
      end
    end
    StateRules::NONZERO.each do |id, (_type, _fields, section)|
      registry.register(id: id, formats: state, citation: "MS-EMF #{section}", kind: :nonzero_divisor) { |c| StateRules.nonzero(c, id) }
    end
    {
      "emf.state.restoredc_negative" => [:restoredc_negative, "MS-EMF 2.3.11.6", :saved_dc],
      "emf.state.color_adjustment" => [:color_adjustment, "MS-EMF 2.2.2", :color_adjustment],
      "emf.state.pixel_format_version" => [:pixel_format_version, "MS-EMF 2.2.22", :pixel_format_version],
      "emf.state.color_match_target" => [:color_match_target, "MS-EMF 2.3.11.1", :color_match_target],
      "emf.state.profile_bounds" => [:profile_bounds, "MS-EMF 2.3.11.15", :profile_bounds],
      "emf.state.linked_ufis_bounds" => [:linked_ufis_bounds, "MS-EMF 2.3.11.18", :linked_ufis_bounds]
    }.each do |id, (method, citation, kind)|
      registry.register(id: id, formats: state, citation: citation, kind: kind) { |c| StateRules.public_send(method, c) }
    end
  end
end
