# frozen_string_literal: true

require_relative "emf_plus_records"
require_relative "emf_plus_edit_examples"

module Emf
  module SpecSupport
    # Builds whole EMF files (header, EMR_COMMENT records carrying EMF+, EMR_EOF)
    # in memory for the EMF+ record types and the CustomLineCap object that no
    # corpus fixture covers. Record bodies come from EmfPlusEditExamples.
    module EmfPlusGeneratedFixtures
      extend EmfPlusRecords

      EMF_PLUS_IDENTIFIER = "EMF+".b.freeze
      VERSION = [0xDBC01002].pack("V").freeze
      STROKE_FILL_PATH = 0x4037
      OBJECT = 0x4008
      PEN_TYPE = 2
      CUSTOM_LINE_CAP_TYPE = 9

      module_function

      def u32(*values) = values.pack("V*")
      def f32(*values) = values.pack("e*")

      def klass(name) = Emf::EmfPlus::Records.const_get(name)

      def example(name) = EmfPlusEditExamples.for_class(klass(name))

      def typed_record(name)
        found = example(name)
        record(klass(name)::TYPE, found.body, flags: found.flags)
      end

      def plus_header = record(0x4001, VERSION + u32(0x1, 96, 96), flags: 0x1)
      def plus_eof = record(0x4002, "")

      def header_bytes(bytes_total, record_count)
        fields = [1, 88, 0, 0, 99, 99, 0, 0, 2000, 2000, 0x464D4520, 0x10000, bytes_total, record_count,
                  1, 0, 0, 0, 0, 1024, 768, 320, 240]
        fields.pack("V2l<4l<4V4v2V3l<2l<2")
      end

      def comment(payload)
        data = EMF_PLUS_IDENTIFIER + payload
        padded = data + ("\0" * (-data.bytesize % 4))
        [70, 12 + padded.bytesize, data.bytesize].pack("V3") + padded
      end

      EOF_RECORD = [14, 20, 0, 16, 20].pack("V5").freeze

      # payloads: one String of EMF+ records per EMR_COMMENT.
      def emf_file(payloads)
        body = payloads.map { |payload| comment(payload) }.join.b + EOF_RECORD
        total = 88 + body.bytesize
        header_bytes(total, payloads.size + 2) + body
      end

      def single_comment(*records) = emf_file([[plus_header, *records, plus_eof].join.b])

      def stroke_fill_path = record(STROKE_FILL_PATH, u32(0x11223344), flags: 0x55AA)

      def custom_line_cap(base_cap: 1)
        VERSION + u32(0) + [0, base_cap, 0.5, 2, 3, 4, 8.0, 1.0].pack("VVeVVVee") + ("\0" * 16)
      end

      def pen_with_custom_caps
        brush = VERSION + u32(0) + [1, 2, 3, 4].pack("C4")
        cap = custom_line_cap
        optional = u32(cap.bytesize) + cap + u32(cap.bytesize) + cap
        VERSION + [0, 0x1800, 2, 1.5].pack("VVVe") + optional + brush
      end

      def object_record(type, id, data) = record(OBJECT, data, flags: (type << 8) | id)

      def custom_line_cap_records
        [object_record(CUSTOM_LINE_CAP_TYPE, 1, custom_line_cap), object_record(PEN_TYPE, 2, pen_with_custom_caps)]
      end

      def balanced_stack_records
        container = f32(0, 0, 1, 1, 0, 0, 1, 1)
        [record(klass(:Save)::TYPE, u32(1)),
         record(klass(:BeginContainer)::TYPE, container + u32(2), flags: 0x0003),
         record(klass(:BeginContainerNoParams)::TYPE, u32(3)),
         record(klass(:EndContainer)::TYPE, u32(3)),
         record(klass(:EndContainer)::TYPE, u32(2)),
         record(klass(:Restore)::TYPE, u32(1))]
      end

      # name => EMF+ record bytes between the header and EOF records.
      def positive_cases
        names = %i[Clear SetCompositingMode Save Restore BeginContainer BeginContainerNoParams EndContainer
                   ScaleWorldTransform SetTSGraphics SetTSClip]
        names.to_h { |name| [name, [typed_record(name)]] }
             .merge(StrokeFillPath: [stroke_fill_path],
                    CustomLineCap: custom_line_cap_records,
                    BalancedStack: balanced_stack_records)
      end

      def all_records
        positive_cases.values.flatten
      end

      # Everything at once, spread over several comments.
      def combined_file
        chunks = all_records.each_slice(4).to_a
        chunks.first.unshift(plus_header)
        chunks.last.push(plus_eof)
        emf_file(chunks.map { |chunk| chunk.join.b })
      end

      def negative_cases
        { truncated_record: single_comment(record(klass(:Save)::TYPE, u32(1), size: 64)),
          data_size_beyond_size: single_comment(record(klass(:Save)::TYPE, u32(1), data_size: 40)),
          data_size_short: single_comment(record(klass(:Save)::TYPE, u32(1), data_size: 0)),
          reserved_flags_set: single_comment(record(klass(:Save)::TYPE, u32(1), flags: 0xFFFF),
                                             record(klass(:SetCompositingMode)::TYPE, "", flags: 0xFFFF)),
          unmatched_end_container: single_comment(record(klass(:EndContainer)::TYPE, u32(9)),
                                                  record(klass(:Restore)::TYPE, u32(5))),
          swapped_container_ids: single_comment(record(klass(:BeginContainerNoParams)::TYPE, u32(1)),
                                                record(klass(:BeginContainerNoParams)::TYPE, u32(2)),
                                                record(klass(:EndContainer)::TYPE, u32(1)),
                                                record(klass(:EndContainer)::TYPE, u32(2))) }
      end

      # A malformed frame followed by a plausible frame must stay opaque until
      # the next comment boundary, even when Size claims an enormous payload.
      def malformed_frames
        type = klass(:Clear)::TYPE
        { zero_size: record(type, "", size: 0),
          size_below_header: record(type, "", size: 8),
          unaligned_size: record(type, "", size: 13),
          oversized_data: record(type, "", data_size: 0xFFFFFFFF),
          oversized_record: record(type, "", size: 0xFFFFFFFC) }
      end

      def malformed_comment_file(malformed)
        clear = typed_record(:Clear)
        emf_file([plus_header + clear + malformed + clear, clear + plus_eof])
      end
    end
  end
end
