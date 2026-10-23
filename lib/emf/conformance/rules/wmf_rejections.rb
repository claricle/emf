# frozen_string_literal: true

# WMF rejected-input diagnostics and declared-size rules.
#
# Rejections: a WMF the parser refuses never becomes a Metafile, so the lens context is :unparseable and holds the
# exception. Its neutral Emf::ParseEvidence (check, offset, declared, actual) names the reason; each reason with a
# `wmf.reject.rNNNN` row becomes one finding citing that row. Rejection is a no-model outcome, so strict and
# tolerant both report an error (no tolerant_reason), like emf.parse.unparseable. Reasons that cannot surface
# are left to emf.parse.unparseable: 101 and 401 need a 200 MiB or million-record input, and 301-303 are shadowed by
# the format detector, which turns such inputs into :unrecognised_signature before any WMF check runs. 305 (header
# Size) and 1801 (MaxRecord) are not rejections: the parser recovers, keeps the model and records the drift in
# Metafile#errors, so the declared-size rules below (wmf.header.size_matches_records, wmf.header.max_record) report
# it, as a warning in the tolerant profile. The same holds for 203 (reported by wmf.placeable.checksum), 406, 701
# (a font short of its face name) and 801 (an object record with surplus bytes), reported by wmf.record.declared_size,
# 1003 (wmf.text.negative_length), and 1702 and the clip/paint/invert part of 1704 (the wmf.object.*_reference rules).
# 701, 801 and 1704 stay rejections for the shapes that cannot be recovered.
#
# Declared size: on an accepted model each record carries the rdSize read from the source file
# (Record#declared_size_words, nil for records built in memory). The rules compare it with the layout and with the
# header's MaxRecord and Size.
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module WmfRejectionRules
      WMF = %i[wmf unparseable].freeze
      SHADOWED = [101, 401, 301, 302, 303].freeze
      FUNCTION_OFFSET = 4
      FIRST_RECORD_REASON = 402

      # evidence check => reason code, for every reason that can produce a named finding
      CHECKS = Emf::Wmf::Evidence::REASONS.except(*SHADOWED, *Emf::Wmf::Evidence::DRIFT_REASONS,
                                                  *Emf::Wmf::Evidence::RETIRED_REASONS).to_h do |reason, (check, _text)|
        [check, reason]
      end.freeze

      module_function

      def id(reason) = format("wmf.reject.r%04d", reason)

      # The reason code a parse failure names, or nil when the failure is not a rejection with a wmf.reject row.
      def reason_for(failure)
        CHECKS[failure&.evidence&.check]
      end

      def findings(context, reason)
        failure = context.parse_failure
        return [] unless reason_for(failure) == reason

        evidence = failure.evidence
        [{ message: message(reason, evidence), offset: evidence.offset, record_type: function(context.bytes, evidence, reason) }]
      end

      def message(reason, evidence)
        text = Emf::Wmf::Evidence::REASONS.fetch(reason).last.sub("%d") { evidence.declared.to_s }
        values = { declared: evidence.declared, actual: evidence.actual }.compact.map { |name, value| "#{name} #{value}" }
        "#{text} at offset #{evidence.offset}#{" (#{values.join(', ')})" unless values.empty?}"
      end

      # Record function word of the failing record, for record-level reasons whose bytes are available.
      def function(bytes, evidence, reason)
        return if reason < FIRST_RECORD_REASON || bytes.nil? || evidence.offset.nil?
        return if evidence.offset + FUNCTION_OFFSET + 2 > bytes.bytesize

        bytes.unpack1("v", offset: evidence.offset + FUNCTION_OFFSET)
      end
    end

    module WmfDeclaredSizeRules
      WMF = %i[wmf].freeze
      R = Emf::Model::Wmf::Records
      B = Emf::Wmf::Binary
      MIN_WORDS = 3
      HEADER_WORDS = 9
      SIZE_RECOVERY = "the parser recovers by framing the record with its RecordSize: surplus bytes after an EOF or an " \
                      "object payload are ignored and a font face name shorter than 32 bytes is zero-padded; the " \
                      "departure is recorded in Metafile#errors (seen in LibreOffice test files)"
      HEADER_DRIFT = "the parser recovered: the model is built from the records actually present and the header drift " \
                     "is recorded in Metafile#errors (seen in files from Inkscape and ImageMagick)"

      module_function

      # [exact?, words] the record layout requires, or nil when the layout leaves the size open.
      def layout(record)
        case record
        when R::Eof then [true, MIN_WORDS]
        when R::CreateFontIndirect, *B::STATE_RECORDS.values then [false, MIN_WORDS + (record.class::PAYLOAD_BYTES / 2)]
        when *B::FIXED_RECORDS.values then [true, MIN_WORDS + record.class::WIRE_FIELDS.length]
        when *B::OBJECT_RECORDS.values then [true, MIN_WORDS + (record.class::PAYLOAD_BYTES / 2)]
        end
      end

      def declared_size(context)
        context.records.each_with_index.filter_map do |record, index|
          words = record.declared_size_words
          next unless words

          problem = size_problem(record, words)
          at(record, index, problem) if problem
        end
      end

      def size_problem(record, words)
        return "RecordSize is #{words} words, a record is at least #{MIN_WORDS} words" if words < MIN_WORDS

        exact, expected = layout(record)
        return unless expected

        name = record.class.name.split("::").last
        return "RecordSize is #{words} words, the #{name} layout is #{expected} words" if exact && words != expected
        return unless !exact && words < expected

        "RecordSize is #{words} words, the #{name} layout needs at least #{expected} words"
      end

      def buffer_declared_size(context)
        context.records.each_with_index.filter_map do |record, index|
          words = record.declared_size_words
          encoded = words && buffer_words(record)
          next unless encoded && encoded != words

          at(record, index, "RecordSize is #{words} words but the #{record.class.name.split('::').last} buffers occupy #{encoded} words")
        end
      end

      def buffer_words(record)
        return unless B.prefix_codec(record) || record.is_a?(R::TextOut)

        Emf::Wmf::Serializer.serialize_record(record).bytesize / 2
      rescue Emf::SerializeError
        nil
      end

      def max_record(context)
        sizes = context.records.map(&:declared_size_words)
        return [] if sizes.empty? || sizes.any?(&:nil?)

        largest = sizes.max
        declared = context.header.max_record_words.to_i
        return [] if declared == largest

        [{ message: "WMF header MaxRecord is #{declared} words, the largest record is #{largest} words",
           offset: context.header.placeable ? 34 : 12 }]
      end

      def size_matches_records(context)
        sizes = context.records.map(&:declared_size_words)
        return [] if sizes.empty? || sizes.any?(&:nil?)

        total = HEADER_WORDS + sizes.sum
        declared = context.header.size_words.to_i
        return [] if declared == total

        [{ message: "WMF header Size is #{declared} words, the header and the records add up to #{total} words",
           offset: context.header.placeable ? 28 : 6 }]
      end

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end
    end

    registry = Registry.loading
    manifest = Manifest.rows.to_h { |row| [row.id, row.citation] }
    WmfRejectionRules::CHECKS.each do |check, reason|
      id = WmfRejectionRules.id(reason)
      registry.register(id: id, formats: WmfRejectionRules::WMF, citation: manifest.fetch(id), kind: check) do |context|
        WmfRejectionRules.findings(context, reason)
      end
    end

    [
      ["wmf.record.declared_size", :declared_size, :declared_size, WmfDeclaredSizeRules::SIZE_RECOVERY],
      ["wmf.buffer.declared_size", :buffer_declared_size, :buffer_declared_size],
      ["wmf.header.max_record", :max_record, :max_record, WmfDeclaredSizeRules::HEADER_DRIFT],
      ["wmf.header.size_matches_records", :size_matches_records, :size_matches_records, WmfDeclaredSizeRules::HEADER_DRIFT]
    ].each do |id, method, kind, tolerant_reason|
      registry.register(id: id, formats: WmfDeclaredSizeRules::WMF, citation: manifest.fetch(id), kind: kind,
                        tolerant_reason: tolerant_reason) do |context|
        WmfDeclaredSizeRules.public_send(method, context)
      end
    end
  end
end
