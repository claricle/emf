# frozen_string_literal: true

module Emf
  module SpecSupport
    # Crafted non-placeable WMF files for the rules that cover the former coverage_gaps.yml records.
    # Header Size and MaxRecord are computed from the records, so the only defect in a case is the one it names.
    module GapWmf
      module_function

      # One record: function word and parameter words (Integer words are packed as unsigned 16-bit).
      def record(function, *words, size_words: nil)
        [size_words || (3 + words.size), function].pack("Vv") + words.pack("v*")
      end

      def dword(value) = [value & 0xFFFF, value >> 16]

      def file(*records)
        eof = record(0)
        body = records.join + eof
        largest = (records + [eof]).map { |r| r.bytesize / 2 }.max
        total = 9 + (body.bytesize / 2)
        header = [1, 9, 0x0300, total & 0xFFFF, total >> 16, 0, largest, 0].pack("v6Vv")
        header + body
      end

      def ids(bytes, profile: :strict)
        Emf::Conformance.check(bytes, profile: profile).diagnostics.map(&:requirement_id)
      end

      def report(bytes, profile: :strict) = Emf::Conformance.check(bytes, profile: profile)
    end
  end
end
