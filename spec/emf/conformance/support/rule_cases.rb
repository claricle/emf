# frozen_string_literal: true

require_relative "crafted_emf"

module Emf
  module SpecSupport
    # One crafted file per rule: id => bytes that break only that rule (others may fire as a consequence).
    module RuleCases
      CraftedEmf = Emf::SpecSupport::CraftedEmf
      COMMENT_EMFPLUS = ->(payload) { CraftedEmf.record(70, [4 + payload.bytesize].pack("V") + "EMF+".b + payload) }
      # EMF+ record: type, flags, size, data size, body.
      PLUS = ->(type, body = "".b) { [type, 0, 12 + body.bytesize, body.bytesize].pack("v2V2") + body }
      PLUS_HEADER = PLUS.call(0x4001, [0x10000, 0, 96, 96].pack("V4"))

      module_function

      def pixel_format
        CraftedEmf.build(size: 108).tap { |bytes| bytes[88, 8] = [40, 5000].pack("V2") }
      end

      def cases
        {
          "emf.header.bytes" => CraftedEmf.build(bytes: 999),
          "emf.header.records" => CraftedEmf.build(count: 7),
          "emf.header.handles" => CraftedEmf.build(records: [CraftedEmf.record(38, [5, 0, 1, 1, 0, 0, 0].pack("V7"))]),
          "emf.header.description_bounds" => CraftedEmf.build(n_description: 400, off_description: 88),
          "emf.header.pixel_format_bounds" => pixel_format,
          "emf.record.size_alignment" => CraftedEmf.build(eof: [14, 22, 0, 16, 22].pack("V5") + "\0\0".b),
          "emf.record.undefined_type" => CraftedEmf.build(records: [CraftedEmf.record(69, "\0\0\0\0".b)]),
          "emf.eof.missing" => CraftedEmf.build(eof: "".b, count: 1),
          "emf.eof.size_last" => CraftedEmf.build(eof: [14, 20, 0, 16, 24].pack("V5")),
          "emf.eof.trailing_bytes" => "#{CraftedEmf.build}abcd",
          "emf.comment.data_size" => CraftedEmf.build(records: [CraftedEmf.record(70, [0x7fff0000, 0x64636261].pack("V2"))]),
          "emf.record.truncated_header" => CraftedEmf.build(eof: "abcd".b, count: 1),
          "emf.record.size_minimum" => CraftedEmf.build(records: [CraftedEmf.record(37, "".b, size: 4)]),
          "emf.record.size_bounds" => CraftedEmf.build(records: [CraftedEmf.record(37, "\0\0\0\0".b, size: 4000)]),
          "emf.record.array_exceeds_size" => CraftedEmf.build(records: [CraftedEmf.record(4, ("\0" * 16).b + [100_000].pack("V"))]),
          "emf.record.undecodable" => CraftedEmf.build(records: [CraftedEmf.record(82, [1].pack("V"))]),
          "emf.parse.unparseable" => "this is not a metafile at all, not even close".b,
          "emfplus.record.reserved_type" => plus_stream(PLUS_HEADER, PLUS.call(0x4005)),
          "emfplus.record.stroke_fill_path" => plus_stream(PLUS_HEADER, PLUS.call(0x4037)),
          "emfplus.record.unknown_type" => plus_stream(PLUS_HEADER, PLUS.call(0x7FFF)),
          "emfplus.header.placement" => CraftedEmf.build(records: [CraftedEmf.record(70, [4, 0x64636261].pack("V2")),
                                                                   COMMENT_EMFPLUS.call(PLUS_HEADER)]),
          "emfplus.stream.framing" => plus_stream(PLUS_HEADER, [0x4002, 0, 8000, 0].pack("v2V2"))
        }
      end

      def plus_stream(*records)
        CraftedEmf.build(records: [COMMENT_EMFPLUS.call(records.join)])
      end
    end
  end
end
