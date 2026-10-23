# frozen_string_literal: true

module Emf
  module SpecSupport
    module ResourceBudgetFixtures
      def budget_record(kind, payload)
        minimal_resource_emf + [kind, payload.bytesize + 8].pack("V2") + payload
      end

      def budget_bitmap(malformed: nil)
        payload = "#{[1, 0, 32, 4, 36, 4].pack('V6')}infobits"
        payload[8, 4] = [400].pack("V") if malformed == :range
        payload[16, 4] = [34].pack("V") if malformed == :overlap
        budget_record(93, payload)
      end

      def budget_poly_text(wide: false, malformed: nil)
        # One descriptor without a rectangle, followed by text, padding and dx.
        payload = ("\0" * 28) + [1].pack("V")
        offset = malformed == :range ? 400 : 64
        dx = malformed == :overlap ? 64 : 68
        payload << [0, 0, 1, offset, 0x100, dx].pack("V6")
        payload << (wide ? "#{[65].pack('v')}\0\0" : "A\0\0\0")
        payload << [2].pack("V")
        payload[48, 4] = [0].pack("V") if malformed == :table
        budget_record(wide ? 97 : 96, payload)
      end

      def budget_gradient(mode: 0, malformed: nil)
        vertices = malformed == :range ? 20 : 1
        index = malformed == :index ? 1 : 0
        payload = ("\0" * 16) + [vertices, 1, mode].pack("V3") + ("\0" * 16)
        payload << ([index] * (mode == 2 ? 3 : 2)).pack("V*")
        budget_record(118, payload)
      end
    end
  end
end
