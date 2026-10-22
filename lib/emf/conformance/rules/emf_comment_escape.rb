# frozen_string_literal: true

# COMMENT dispatch, Escape, OpenGL and the opaque record types' outer size and count
# bounds (MS-EMF 2.3.3, 2.3.6, 2.3.9 and the record sections cited per rule). Payload
# semantics stay out: only offsets, sizes and counts are read from the record bytes.
module Emf
  module Conformance
    module CommentEscapeRules
      EMF = %i[emf emf_plus].freeze
      COMMENT = 70
      PUBLIC = 0x43494447
      SPOOL = 0
      FORMAT_SIGNATURES = [0x464D4520, 0x46535045].freeze
      EPS_SIGNATURE = 0x46535045
      COLOR_SPACE_TYPES = [0, 0x73524742, 0x57696E20].freeze
      GAMUT_INTENTS = [1, 2, 4, 8].freeze
      PUBLIC_IDS = { 2 => :begin_group, 3 => :end_group, 0x40000004 => :multiformats, 0x80000001 => :windows_metafile }.freeze

      # type => [name, minimum size, exact size or nil, [[count field offsets...], per-count bytes (0 = bytes), variable start]]
      # One diagnostic per defect (W37): types whose size or counts another rule states more precisely are not listed here.
      #   EMR_SETCOLORADJUSTMENT              emf.state.fixed_size (decoded), emf.record.fixed_size_raw (Raw)
      #   EMR_SETCOLORSPACE, _COLORCORRECTPALETTE  emf.object.fixed_size
      #   EMR_POLYTEXTOUTA / W                emf.opaque.text_arrays (fixed part and descriptor bounds)
      OPAQUE = {
        99 => ["EMR_CREATECOLORSPACE", 340, false, nil],
        101 => ["EMR_DELETECOLORSPACE", 12, false, nil],
        104 => ["EMR_PIXELFORMAT", 48, false, nil],
        109 => ["EMR_FORCEUFIMAPPING", 16, false, nil],
        112 => ["EMR_SETICMPROFILEA", 20, false, [[12, 16], 1]],
        113 => ["EMR_SETICMPROFILEW", 20, false, [[12, 16], 1]],
        119 => ["EMR_SETLINKEDUFIS", 20, false, [[8], 8]],
        121 => ["EMR_COLORMATCHTOTARGETW", 24, false, [[16, 20], 1]],
        122 => ["EMR_CREATECOLORSPACEW", 608, false, [[604], 1]]
      }.freeze
      # Types whose minimum size and counts a decoded record gets from the more specific emf.state.profile_bounds and
      # emf.state.linked_ufis_bounds (the same constraint, same threshold). A Raw record is only seen here.
      STATE_BOUNDS = [112, 113, 119, 121].freeze
      ESCAPES = { 105 => ["EMR_DRAWESCAPE", 16], 106 => ["EMR_EXTESCAPE", 16], 110 => ["EMR_NAMEDESCAPE", 20] }.freeze
      OPENGL = { 102 => ["EMR_GLSRECORD", 12], 103 => ["EMR_GLSBOUNDEDRECORD", 28] }.freeze

      PARSER_RECOVERS = "the parser keeps a malformed record's bytes and skips it by Size, so the stream stays readable"
      # id => [citation, kind, severity, tolerant_reason]
      RULES = {
        "emf.comment.padding" => ["MS-EMF 2.3.3", :comment_padding, :error, nil],
        "emf.comment.header_size" => ["MS-EMF 2.3.3.4", :comment_header_size, :error, nil],
        "emf.comment.public_payload" => ["MS-EMF 2.3.3.4", :comment_public_payload, :error, nil],
        "emf.comment.public_identifier" => ["MS-EMF 2.3.3.4", :comment_public_identifier, :warning, nil],
        "emf.comment.windows_metafile_reserved" => ["MS-EMF 2.3.3.4.4", :comment_wmf_reserved, :warning, nil],
        "emf.comment.group_unclosed" => ["MS-EMF 2.3.3.4.1", :comment_group_unclosed, :error,
                                         "producers leave groups open at the end of the file and readers only skip the group markers"],
        "emf.comment.group_end" => ["MS-EMF 2.3.3.4.2", :comment_group_end, :error, nil],
        "emf.comment.group_description" => ["MS-EMF 2.3.3.4.1", :comment_group_description, :warning, nil],
        "emf.comment.multiformats_signature" => ["MS-EMF 2.2.4", :comment_multiformats_signature, :error,
                                                 "Quartz-style producers embed PDF data (signature \"PDF \", test-186) in MULTIFORMATS"],
        "emf.comment.multiformats_eps_version" => ["MS-EMF 2.2.4", :comment_multiformats_eps_version, :error, nil],
        "emf.escape.record_size" => ["MS-EMF 2.3.6", :escape_size, :error, PARSER_RECOVERS],
        "emf.escape.payload_bounds" => ["MS-EMF 2.3.6", :escape_payload, :error, nil],
        "emf.escape.driver_name" => ["MS-EMF 2.3.6.3", :escape_driver_name, :error, nil],
        "emf.opengl.record_size" => ["MS-EMF 2.3.9", :opengl_size, :error, PARSER_RECOVERS],
        "emf.opengl.payload_bounds" => ["MS-EMF 2.3.9", :opengl_payload, :error, nil],
        "emf.opaque.fixed_size" => ["MS-EMF 2.3", :opaque_size, :error, PARSER_RECOVERS],
        "emf.opaque.payload_bounds" => ["MS-EMF 2.3", :opaque_payload, :error, nil],
        "emf.opaque.colorspace_fields" => ["MS-WMF 2.2.2.11", :colorspace_fields, :error, nil]
      }.freeze

      CACHE = ObjectSpace::WeakMap.new

      module_function

      def findings(context, id)
        # The WeakMap holds its values weakly: keep a strong reference until the lookup is done.
        grouped = CACHE[context] || (CACHE[context] = analyze(context))
        grouped.fetch(id, [])
      end

      def analyze(context)
        out = Hash.new { |hash, id| hash[id] = [] }
        open_groups = []
        context.records.each_with_index do |record, index|
          type = context.record_type(record)
          scan = Scan.new(record, index, context.record_size(record), out)
          if type == COMMENT then scan.comment(open_groups)
          elsif ESCAPES.key?(type) then scan.escape(*ESCAPES.fetch(type), type)
          elsif OPENGL.key?(type) then scan.opengl(*OPENGL.fetch(type))
          elsif OPAQUE.key?(type) && !state_bounded?(record, type) then scan.opaque(*OPAQUE.fetch(type))
          end
        end
        open_groups.each { |group| group.add("emf.comment.group_unclosed", "EMR_COMMENT_BEGINGROUP has no matching ENDGROUP") }
        out
      end

      def state_bounded?(record, type)
        STATE_BOUNDS.include?(type) && record.wire.is_a?(Emf::Emr::Binary::Record)
      end

      # Checks of the EMR_COMMENT_PUBLIC sub-records (MS-EMF 2.3.3.4.x); mixed into Scan.
      module PublicChecks
        private

        def public_comment(data_size, open_groups)
          return add("emf.comment.header_size", "public comment DataSize #{data_size} cannot hold PublicCommentIdentifier") if data_size < 8

          kind = PUBLIC_IDS[u32(16)]
          unless kind
            return add("emf.comment.public_identifier",
                       format("public comment identifier 0x%08X is not in the EmrComment enumeration", u32(16)))
          end

          send(:"public_#{kind}", data_size, open_groups)
        end

        def public_begin_group(data_size, open_groups)
          return add("emf.comment.header_size", "BEGINGROUP DataSize #{data_size} is smaller than its 28-byte fixed part") if data_size < 28

          open_groups << self
          unless (u32(36) * 2) <= data_size - 28
            return add("emf.comment.public_payload",
                       "BEGINGROUP description of #{u32(36)} characters runs past DataSize")
          end

          group_description(data_size)
        end

        # The description is a null-terminated string; nDescription may or may not count the terminator.
        def group_description(data_size)
          chars = u32(36)
          return if chars.zero?

          text = @bytes.byteslice(40, [(chars + 1) * 2, data_size - 28].min)
          return if text.unpack("v*").first(chars + 1).include?(0)

          add("emf.comment.group_description", "BEGINGROUP description of #{chars} characters is not null-terminated")
        end

        def public_end_group(_data_size, open_groups)
          return add("emf.comment.group_end", "EMR_COMMENT_ENDGROUP has no matching BEGINGROUP") if open_groups.empty?

          open_groups.pop
        end

        def public_multiformats(data_size, _open_groups)
          if data_size < 28
            return add("emf.comment.header_size",
                       "MULTIFORMATS DataSize #{data_size} is smaller than its 28-byte fixed part")
          end

          count = u32(36)
          if count * 16 > data_size - 28
            return add("emf.comment.public_payload",
                       "MULTIFORMATS CountFormats #{count} needs #{count * 16} bytes, #{data_size - 28} remain")
          end

          count.times do |i|
            format_identity(i)
            size = u32(48 + (i * 16))
            offset = u32(52 + (i * 16))
            if offset % 4 != 0 || offset + size > data_size
              add("emf.comment.public_payload",
                  "MULTIFORMATS format #{i} data #{offset}+#{size} is misaligned or past DataSize")
            end
          end
        end

        def format_identity(index)
          signature = u32(40 + (index * 16))
          unless FORMAT_SIGNATURES.include?(signature)
            return add("emf.comment.multiformats_signature",
                       "MULTIFORMATS format #{index} Signature #{hex(signature)} is not in the FormatSignature enumeration")
          end
          return unless signature == EPS_SIGNATURE && u32(44 + (index * 16)) != 1

          add("emf.comment.multiformats_eps_version",
              "MULTIFORMATS format #{index} is EPS but its Version is #{u32(44 + (index * 16))}, MUST be 1")
        end

        def public_windows_metafile(data_size, _open_groups)
          if data_size < 24
            return add("emf.comment.header_size",
                       "WINDOWS_METAFILE DataSize #{data_size} is smaller than its 24-byte fixed part")
          end

          reserved = @bytes.unpack1("v", offset: 22)
          flags = u32(28)
          unless reserved.zero? && flags.zero?
            add("emf.comment.windows_metafile_reserved",
                "Reserved #{reserved} and Flags #{flags} MUST be 0")
          end
          return unless u32(32) > data_size - 24

          add("emf.comment.public_payload",
              "WinMetafileSize #{u32(32)} exceeds the #{data_size - 24} bytes DataSize leaves")
        end
      end

      # One record's checks; every method adds to `out[rule id]`.
      class Scan
        include PublicChecks

        def initialize(record, index, size, out)
          @record = record
          @index = index
          @size = size
          @out = out
          @bytes = record.to_binary_s
        end

        def add(id, message)
          @out[id] << { message: message, offset: @record.offset, record_index: @index + 1, record_type: @record.type_id.to_i }
        end

        def comment(open_groups)
          return if @size < 12 || @bytes.bytesize < 12

          data_size = u32(8)
          return if data_size > @size - 12

          pad = @size - 12 - data_size
          if pad > 3
            add("emf.comment.padding",
                "comment has #{pad} bytes after DataSize bytes of data, at most 3 padding bytes are allowed")
          end
          return if data_size < 4

          case u32(12)
          when PUBLIC then public_comment(data_size, open_groups)
          when SPOOL then if data_size < 8
                            add("emf.comment.header_size",
                                "EMFSPOOL comment DataSize #{data_size} cannot hold its record identifier")
                          end
          end
        end

        def escape(name, fixed, type)
          return add("emf.escape.record_size", "#{name} Size #{@size} is smaller than its #{fixed}-byte fixed part") if @size < fixed

          if type == 110
            named_escape(name)
          elsif u32(12) > @size - fixed
            add("emf.escape.payload_bounds", "#{name} cjIn #{u32(12)} exceeds the #{@size - fixed} bytes the record holds")
          end
        end

        def opengl(name, fixed)
          return add("emf.opengl.record_size", "#{name} Size #{@size} is smaller than its #{fixed}-byte fixed part") if @size < fixed

          count = u32(fixed - 4)
          return unless count > @size - fixed

          add("emf.opengl.payload_bounds",
              "#{name} cbData #{count} exceeds the #{@size - fixed} bytes the record holds")
        end

        def opaque(name, minimum, exact, counted)
          if @size < minimum || (exact && @size != minimum)
            return add("emf.opaque.fixed_size", "#{name} Size #{@size} is not #{'at least ' unless exact}#{minimum}")
          end

          colorspace_fields(name) if [99, 122].include?(@record.type_id.to_i)
          return unless counted

          fields, unit = counted
          total = fields.sum { |pos| u32(pos) } * unit
          return unless total > @size - minimum

          add("emf.opaque.payload_bounds",
              "#{name} counts need #{total} bytes, the record holds #{@size - minimum}")
        end

        private

        def u32(pos) = @bytes.unpack1("V", offset: pos)

        def hex(value) = format("0x%<value>08X", value: value)

        # The embedded LogColorSpace / LogColorSpaceW starts after ihCS (MS-WMF 2.2.2.11, 2.2.2.12).
        def colorspace_fields(name)
          return if @bytes.bytesize < 32

          {
            "Signature" => [u32(12) == 0x50534F43, hex(u32(12)), "0x50534F43"],
            "Version" => [u32(16) == 0x400, hex(u32(16)), "0x00000400"],
            "ColorSpaceType" => [COLOR_SPACE_TYPES.include?(u32(24)), hex(u32(24)), "a LogicalColorSpace value"],
            "Intent" => [GAMUT_INTENTS.include?(u32(28)), u32(28).to_s, "a GamutMappingIntent value"]
          }.each do |field, (ok, got, want)|
            add("emf.opaque.colorspace_fields", "#{name} LogColorSpace #{field} #{got} MUST be #{want}") unless ok
          end
        end

        def named_escape(name)
          driver = u32(12)
          data = u32(16)
          add("emf.escape.driver_name", "#{name} cjDriver #{driver} MUST be an even number") if driver.odd?
          if driver + data > @size - 20
            add("emf.escape.payload_bounds", "#{name} cjDriver #{driver} + cjIn #{data} exceed the #{@size - 20} bytes the record holds")
          elsif driver < 2 || @bytes.byteslice(20 + driver - 2, 2) != "\0\0".b
            add("emf.escape.driver_name", "#{name} DriverName is not null-terminated within cjDriver #{driver}")
          end
        end
      end
    end

    CommentEscapeRules::RULES.each do |id, (citation, kind, severity, reason)|
      Registry.loading.register(id: id, formats: CommentEscapeRules::EMF, citation: citation, kind: kind, severity: severity,
                                tolerant_reason: reason) { |context| CommentEscapeRules.findings(context, id) }
    end
  end
end
