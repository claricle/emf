# frozen_string_literal: true

require_relative "crafted_emf"

module Emf
  module SpecSupport
    # Crafted EMF+ streams for the emf_plus_* rule specs. Adds helpers only; the
    # shared crafted_emf.rb and rule_cases.rb are untouched.
    module EmfPlusBuilder
      CraftedEmf = Emf::SpecSupport::CraftedEmf
      HEADER_BODY = [(0xDBC01 << 12) | 1, 0, 96, 96].pack("V4").freeze

      module_function

      # One framed EMF+ record; Size and DataSize default to the real (4-padded) lengths.
      def record(type, flags: 0, body: "".b, size: nil, data_size: nil)
        padded = body.b + ("\0" * (-body.bytesize % 4))
        [type, flags, size || (12 + padded.bytesize), data_size || body.bytesize].pack("v2V2") + padded
      end

      def header(body: [(0xDBC01 << 12) | 1, 0, 96, 96].pack("V4")) = record(0x4001, body: body)

      def eof = record(0x4002)

      def comment(*records)
        payload = records.join.b
        CraftedEmf.record(70, [4 + payload.bytesize].pack("V") + "EMF+".b + payload)
      end

      # A metafile with Header first and EndOfFile last in a single EMR_COMMENT_EMFPLUS.
      def stream(*records, header: self.header, eof: self.eof)
        CraftedEmf.build(records: [comment(header, *records, eof)])
      end

      def diagnostics(bytes, id, profile: :strict)
        Emf::Conformance.check(bytes, profile: profile).diagnostics.select { |d| d.requirement_id == id }
      end

      def float(*values) = values.pack("e*")

      def rect_f = float(0, 0, 10, 10)

      def points(count) = Array.new(count) { |i| float(i, i) }.join

      # Body of a counted drawing record (`name` is the record class name) holding `count` points or rectangles.
      def counted_body(name, count)
        array = name.end_with?("Rects") ? Array.new(count) { rect_f }.join : points(count)
        head = { "DrawCurve" => float(0.5) + [0, 1].pack("V2"), "DrawClosedCurve" => float(0.5) }.fetch(name, "".b)
        brush = name.start_with?("Fill") ? [0xFF0000FF].pack("V") : "".b
        tension = name == "FillClosedCurve" ? float(0.5) : "".b
        brush + tension + head + [count].pack("V") + array
      end

      # Object record defining `type` (Objects::BRUSH=1, PEN=2, PATH=3, ...) in slot `id`.
      def object(type, id, data = [0].pack("V")) = record(0x4008, flags: (type << 8) | id, body: data)
    end
  end
end
