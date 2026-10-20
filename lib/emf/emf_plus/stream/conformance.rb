# frozen_string_literal: true

module Emf
  module EmfPlus
    class Stream
      # Reports records MS-EMFPLUS 2.1.1.1 does not allow in a conformant file.
      # Only reports: the records stay Records::Unknown with their bytes intact.
      # `kind` is :reserved_type, :stroke_fill_path, :unknown_type or
      # :header_not_after_emf_header.
      module Conformance
        Diagnostic = Struct.new(:kind, :comment_index, :offset, :record_type, :message, keyword_init: true) do
          def initialize(**)
            super
            freeze
          end
        end

        RESERVED = (0x4005..0x4007)
        STROKE_FILL_PATH = 0x4037
        DEFINED = (0x4001..0x403A)

        module_function

        HEADER_PLACEMENT = "EmfPlusHeader record MUST be embedded in an EMR_COMMENT_EMFPLUS record, " \
                           "which MUST be the record immediately following the EMF header (MS-EMFPLUS 2.3.3.3)"

        def check(handles, segments)
          (type_diagnostics(handles, segments) + header_diagnostics(handles, segments)).freeze
        end

        def type_diagnostics(handles, segments)
          handles.filter_map do |handle|
            next unless handle.record.is_a?(Records::Unknown)

            kind, message = classify(handle.record.type)
            next unless kind

            Diagnostic.new(kind: kind, comment_index: segments[handle.segment_index].record_index,
                           offset: handle.offset, record_type: handle.record.type, message: message)
          end
        end

        # Only the first header is placed: the text does not forbid further
        # headers, and corpus files carry a second one in a later comment.
        def header_diagnostics(handles, segments)
          handle = handles.find { |candidate| candidate.record.is_a?(Records::Header) }
          comment_index = handle && segments[handle.segment_index].record_index
          return [] if handle.nil? || comment_index.zero?

          [Diagnostic.new(kind: :header_not_after_emf_header, comment_index: comment_index, offset: handle.offset,
                          record_type: handle.record.type, message: HEADER_PLACEMENT)]
        end

        def classify(type)
          if RESERVED.cover?(type)
            [:reserved_type, format("reserved EMF+ record type 0x%04X MUST NOT be used", type)]
          elsif type == STROKE_FILL_PATH
            [:stroke_fill_path, "EmfPlusStrokeFillPath (0x4037) has no record layout"]
          elsif !DEFINED.cover?(type)
            [:unknown_type, format("EMF+ record type 0x%04X is outside 0x4001-0x403A", type)]
          end
        end

        private_class_method :type_diagnostics, :header_diagnostics, :classify
      end
    end
  end
end
