# frozen_string_literal: true

# Text output rules (MS-EMF 2.2.5 EmrText, 2.3.5.7/.8 EXTTEXTOUT, 2.3.5.32/.33 POLYTEXTOUT,
# 2.3.5.37 SMALLTEXTOUT). Offsets, counts and option bits are read from the record's own
# bytes; the characters themselves are never decoded.
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module TextRules
      EMF = %i[emf emf_plus].freeze
      ETO_PDY = 0x2000
      ETO_NO_RECT = 0x100
      ETO_SMALL_CHARS = 0x200
      # ExtTextOutOptions (MS-EMF 2.1.11).
      DEFINED_OPTIONS = [0x2, 0x4, 0x10, 0x80, 0x100, 0x200, 0x400, 0x800, 0x1000, 0x2000, 0x10000].sum.freeze

      # type => [name, wide characters?]
      EXT = { 83 => ["EMR_EXTTEXTOUTA", false], 84 => ["EMR_EXTTEXTOUTW", true] }.freeze
      POLY = { 96 => ["EMR_POLYTEXTOUTA", false], 97 => ["EMR_POLYTEXTOUTW", true] }.freeze
      SMALL = 108
      EXT_TEXT_AT = 36
      POLY_TABLE_AT = 40
      UNREADABLE = "the record Size still delimits the stream, so a string or Dx array that cannot be located is skipped by readers"

      # id => [citation, kind, severity, tolerant_reason]
      RULES = {
        "emf.exttextout.string_bounds" => ["MS-EMF 2.2.5", :string_bounds, :error, UNREADABLE],
        "emf.exttextout.string_offset_alignment" => ["MS-EMF 2.2.5", :string_alignment, :error, nil],
        "emf.exttextout.dx_bounds" => ["MS-EMF 2.2.5", :dx_bounds, :error, UNREADABLE],
        "emf.exttextout.dx_offset_alignment" => ["MS-EMF 2.2.5", :dx_alignment, :error, nil],
        "emf.exttextout.options_defined" => ["MS-EMF 2.1.11", :exttextout_options, :warning, nil],
        "emf.exttextout.string_encoding" => ["MS-EMF 2.2.5", :string_encoding, :error,
                                             "readers decode a damaged UTF-16LE string character by character and still draw the rest"],
        "emf.smalltextout.text_string" => ["MS-EMF 2.3.5.37", :small_text, :error, UNREADABLE],
        "emf.smalltextout.options_defined" => ["MS-EMF 2.1.11", :smalltextout_options, :warning, nil],
        "emf.polytextout.strings" => ["MS-EMF 2.3.5.32", :poly_strings, :error, UNREADABLE],
        "emf.polytextout.dx" => ["MS-EMF 2.3.5.32", :poly_dx, :error, UNREADABLE],
        "emf.polytextout.options_defined" => ["MS-EMF 2.1.11", :polytextout_options, :warning, nil],
        "emf.opaque.text_arrays" => ["MS-EMF 2.3.5.32", :poly_table, :error, UNREADABLE]
      }.freeze

      # Findings of one metafile, grouped by rule id; computed once and shared by all rules.
      CACHE = ObjectSpace::WeakMap.new

      module_function

      def findings(context, id)
        # The WeakMap holds its values weakly: keep a strong reference until the lookup is done.
        grouped = CACHE[context] || (CACHE[context] = analyze(context))
        grouped.fetch(id, [])
      end

      def analyze(context)
        out = Hash.new { |hash, id| hash[id] = [] }
        context.records.each_with_index do |record, index|
          type = context.record_type(record)
          next unless EXT.key?(type) || POLY.key?(type) || type == SMALL

          Scan.new(record, index, context.record_size(record), out).run(type)
        end
        out
      end

      # Option, string and Dx checks shared by the EXTTEXTOUT and POLYTEXTOUT descriptors; mixed into Scan.
      module BufferChecks
        private

        def check_options(id, label, options)
          undefined = options & ~DEFINED_OPTIONS
          return if undefined.zero?

          add(id,
              format("%<label>s Options 0x%<options>X sets bits outside ExtTextOutOptions (0x%<bits>X)",
                     label: label, options: options, bits: undefined))
        end

        def check_string(label, entry, wide, fixed_end, bounds_id, alignment_id)
          width = wide ? 2 : 1
          length = entry[:chars] * width
          return if entry[:chars].zero?

          if entry[:off_string] < fixed_end || entry[:off_string] + length > @size
            add(bounds_id,
                "#{label} string of #{entry[:chars]} chars at #{entry[:off_string]} is outside the record body (#{fixed_end}..#{@size})")
          elsif (entry[:off_string] % width).positive?
            add(alignment_id, "#{label} offString #{entry[:off_string]} is not #{width * 8}-bit aligned")
          elsif wide
            check_encoding(label, entry, length)
          end
        end

        # UTF16-LE: an unpaired surrogate is not a character (MS-EMF 2.2.5, OutputString).
        def check_encoding(label, entry, length)
          text = @bytes.byteslice(entry[:off_string], length).force_encoding(Encoding::UTF_16LE)
          return if text.valid_encoding?

          add("emf.exttextout.string_encoding",
              "#{label} string at offset #{entry[:off_string]} is not valid UTF-16LE (unpaired surrogate)")
        end

        def check_dx(label, entry, fixed_end, bounds_id, alignment_id)
          return if entry[:chars].zero? || entry[:off_dx].zero?

          length = entry[:chars] * (entry[:options].anybits?(ETO_PDY) ? 2 : 1) * 4
          if entry[:off_dx] < fixed_end || entry[:off_dx] + length > @size
            add(bounds_id,
                "#{label} Dx array of #{length / 4} values at #{entry[:off_dx]} is outside the record body (#{fixed_end}..#{@size})")
          elsif (entry[:off_dx] % 4).positive?
            add(alignment_id, "#{label} offDx #{entry[:off_dx]} is not 32-bit aligned")
          end
        end
      end

      # One record's checks; every method adds to `out[rule id]`.
      class Scan
        include BufferChecks

        def initialize(record, index, size, out)
          @record = record
          @index = index
          @out = out
          @bytes = record.to_binary_s
          @size = [size.to_i, @bytes.bytesize].min
        end

        def run(type)
          if EXT.key?(type)
            ext_text(*EXT.fetch(type))
          elsif POLY.key?(type)
            poly_text(*POLY.fetch(type))
          else
            small_text
          end
        end

        private

        def add(id, message)
          @out[id] << { message: message, offset: @record.offset, record_index: @index + 1, record_type: @record.type_id.to_i }
        end

        def u32(pos) = @bytes.unpack1("V", offset: pos)

        # EmrText fixed part: Reference, Chars, offString, Options, [Rectangle], offDx.
        # offDx is nil when the record ends before it; callers check `length` first.
        def text_entry(start)
          options = u32(start + 16)
          length = options.anybits?(ETO_NO_RECT) ? 24 : 40
          off_dx = u32(start + length - 4) if start + length <= @bytes.bytesize
          { chars: u32(start + 8), off_string: u32(start + 12), options: options, off_dx: off_dx, length: length }
        end

        def ext_text(name, wide)
          return unless @size >= EXT_TEXT_AT + 24

          entry = text_entry(EXT_TEXT_AT)
          if @size < EXT_TEXT_AT + entry[:length]
            return add("emf.exttextout.string_bounds",
                       "#{name} is shorter than its #{EXT_TEXT_AT + entry[:length]}-byte EmrText fixed part")
          end

          check_options("emf.exttextout.options_defined", name, entry[:options])
          check_string(name, entry, wide, EXT_TEXT_AT + entry[:length], "emf.exttextout.string_bounds",
                       "emf.exttextout.string_offset_alignment")
          check_dx(name, entry, EXT_TEXT_AT + entry[:length], "emf.exttextout.dx_bounds", "emf.exttextout.dx_offset_alignment")
        end

        def poly_text(name, wide)
          entries = poly_table(name) or return

          entries.each_with_index do |entry, i|
            label = "#{name} string #{i}"
            check_options("emf.polytextout.options_defined", label, entry[:options])
            check_string(label, entry, wide, @table_end, "emf.polytextout.strings", "emf.polytextout.strings")
            check_dx(label, entry, @table_end, "emf.polytextout.dx", "emf.polytextout.dx")
          end
        end

        # cStrings descriptors, each 24 bytes (ETO_NO_RECT) or 40, must fit in the record; nil when they do not.
        def poly_table(name)
          count = u32(POLY_TABLE_AT - 4) if @size >= POLY_TABLE_AT
          unless count
            add("emf.opaque.text_arrays", "#{name} Size #{@size} is smaller than its 40-byte fixed part")
            return nil
          end

          @table_end = POLY_TABLE_AT
          (0...count).map do |i|
            length = @table_end + 24 <= @size && (u32(@table_end + 16).anybits?(ETO_NO_RECT) ? 24 : 40)
            if !length || @table_end + length > @size
              add("emf.opaque.text_arrays", "#{name} cStrings #{count} descriptors run past the record at descriptor #{i}")
              return nil
            end

            text_entry(@table_end).tap { @table_end += length }
          end
        end

        def small_text
          return unless @size >= 36

          options = u32(20)
          check_options("emf.smalltextout.options_defined", "EMR_SMALLTEXTOUT", options)
          start = options.anybits?(ETO_NO_RECT) ? 36 : 52
          length = u32(16) * (options.anybits?(ETO_SMALL_CHARS) ? 1 : 2)
          return unless start + length > @size

          add("emf.smalltextout.text_string",
              "EMR_SMALLTEXTOUT TextString of #{length} bytes at offset #{start} runs past the #{@size}-byte record")
        end
      end
    end

    TextRules::RULES.each do |id, (citation, kind, severity, reason)|
      Registry.loading.register(id: id, formats: TextRules::EMF, citation: citation, kind: kind, severity: severity,
                                tolerant_reason: reason) { |context| TextRules.findings(context, id) }
    end
  end
end
