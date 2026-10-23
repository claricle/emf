# frozen_string_literal: true

module Emf
  module SpecSupport
    module ResourceBudgetCoreFixtures
      def budget_record(kind, payload = "".b)
        [kind, payload.bytesize + 8].pack("V2") + payload
      end

      def core_budget_fixtures
        {
          unknown_geometric_growth: [200, 201, 202, 203, 204].map { |kind| budget_record(kind) }.join,
          diagnostics_geometric_growth: [2, 3, 4, 5, 6].map { |kind| budget_record(kind) }.join,
          truncated_head: "x".b,
          short_record: [2, 4].pack("V2"),
          truncated_record: [2, 200].pack("V2"),
          poly: budget_record(3, [0, 0, 0, 0, 2, 1, 2, 3, 4].pack("V*")),
          poly16: budget_record(86, [0, 0, 0, 0, 2].pack("V*") + [1, 2, 3, 4].pack("v*")),
          multi_poly: budget_record(7, [0, 0, 0, 0, 1, 2, 2, 1, 2, 3, 4].pack("V*")),
          multi_poly16: budget_record(90, [0, 0, 0, 0, 1, 2, 2].pack("V*") + [1, 2, 3, 4].pack("v*")),
          poly_draw: budget_record(56, "#{[0, 0, 0, 0, 1, 1, 2].pack('V*')}\x01"),
          poly_draw16: budget_record(92, "#{[0, 0, 0, 0, 1].pack('V*')}#{[1, 2].pack('v*')}\x01"),
          palette: budget_record(49, "#{[1, 0x300, 2].pack('Vv2')}abcdefgh"),
          palette_entries: budget_record(50, "#{[1, 0, 2].pack('V3')}abcdefgh"),
          comment: budget_record(70, [17].pack("V") + ("x" * 17)),
          region: budget_region_record,
          font: budget_record(82, "\0" * 96),
          font_exdv: budget_record(82, ("\0" * 352) + [0x08007664, 2, 1, 2].pack("V*")),
          text_a: budget_text_record(83, "ab"),
          text_w: budget_text_record(84, "a\0b\0"),
          pen: budget_pen_record,
          eof_stops_before_tail: budget_record(14, "\0" * 12) + [2, 4].pack("V2")
        }.merge(malformed_budget_fixtures).transform_values { |body| minimal_resource_emf + body }
      end

      def malformed_budget_fixtures
        {
          malformed_poly: budget_record(3, [0, 0, 0, 0, 0xFFFFFFFF].pack("V*")),
          malformed_palette: budget_record(50, [1, 0, 0xFFFFFFFF].pack("V3")),
          malformed_region: budget_record(75, [32, 1, 31, 1, 0, 0, 0, 0, 0, 0].pack("V*")),
          malformed_font: budget_record(82, "\0" * 360),
          malformed_text: budget_record(84, "#{[0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 60, 0x100, 60].pack('V*')}paddingpadding"),
          malformed_pen: budget_record(95, [1, 4, 2, 0, 0, 0, 1, 0, 0, 0, 0].pack("V*"))
        }
      end

      def budget_region_record
        region = "#{[32, 1, 1, 16, 0, 0, 1, 1, 0, 0, 1, 1].pack('V*')}extra"
        budget_record(75, [region.bytesize, 1].pack("V2") + region)
      end

      def budget_text_record(kind, text)
        # ETO_NO_RECT, two characters, padding before text and before dx.
        payload = [0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 64, 0x100, 72].pack("V*")
        budget_record(kind, payload + ("p" * 4) + text + ("p" * (8 - text.bytesize)) + [1, 2].pack("V2"))
      end

      def budget_pen_record
        payload = [1, 60, 2, 64, 3, 0, 1, 0, 0, 0, 1, 3].pack("V*")
        budget_record(95, "#{payload}ppabppxyz")
      end

      def budget_outcome
        yield
        :accepted
      rescue Emf::ResourceLimitError => e
        [e.resource, e.limit, e.actual]
      end
    end
  end
end
