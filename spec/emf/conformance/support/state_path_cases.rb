# frozen_string_literal: true

require_relative "crafted_emf"

module Emf
  module SpecSupport
    # Crafted files for the state, transform, path bracket and clipping rules:
    # rule id => { bad: bytes that break it, good: bytes that satisfy it }.
    # The two files differ in the one thing the rule reads.
    module StatePathCases
      CraftedEmf = Emf::SpecSupport::CraftedEmf

      module_function

      def rec(type, body = [], pack: "V*", size: nil) = CraftedEmf.record(type, body.pack(pack), size: size)

      def file(*records) = CraftedEmf.build(records: records)

      def pair(bad, good) = { bad: file(*bad), good: file(*good) }

      def one_value(id, type, bad, good) = { id => pair([rec(type, [bad])], [rec(type, [good])]) }

      def values
        [
          [17, "emf.state.map_mode", 9, 8], [18, "emf.state.bk_mode", 0, 1], [19, "emf.state.poly_fill_mode", 3, 2],
          [20, "emf.state.rop2", 17, 16], [21, "emf.state.stretch_mode", 5, 4], [57, "emf.state.arc_direction", 0, 2],
          [98, "emf.state.icm_mode", 5, 4], [115, "emf.state.layout_mode", 2, 9], [16, "emf.state.mapper_flags", 2, 1],
          [22, "emf.state.text_align", 0x4, 0x119]
        ].map { |type, id, bad, good| one_value(id, type, bad, good) }.reduce(:merge)
      end

      def color_adjustment(size: 24, illuminant: 0)
        [size, 0, illuminant, 10_000, 10_000, 10_000, 0, 0, 0, 0, 0, 0].pack("v12")
      end

      def pixel_format(version) = [40, version].pack("v2") + ("\0" * 36)

      def matrix(*floats) = floats.pack("e6")

      def profile_with_data = CraftedEmf.record(112, "#{[0, 4, 4].pack('V3')}abcdwxyz")

      def state
        {
          "emf.state.fixed_size" => pair([rec(57, [1, 0])], [rec(57, [1])]),
          "emf.state.layout_size" => pair([rec(17, [1, 0])], [rec(17, [1])]),
          "emf.state.scale_viewport_ext" => pair([rec(31, [1, 0, 1, 1])], [rec(31, [1, 2, 3, 4])]),
          "emf.state.scale_window_ext" => pair([rec(32, [0, 1, 1, 1])], [rec(32, [1, 2, 3, 4])]),
          "emf.state.restoredc_negative" => pair([rec(34, [1], pack: "l<")], [rec(34, [-1], pack: "l<")]),
          "emf.state.color_adjustment" => { bad: file(CraftedEmf.record(23, color_adjustment(size: 20))),
                                            good: file(CraftedEmf.record(23, color_adjustment)) },
          "emf.state.pixel_format_version" => { bad: file(CraftedEmf.record(104, pixel_format(2))),
                                                good: file(CraftedEmf.record(104, pixel_format(1))) },
          "emf.state.color_match_target" => pair([rec(121, [4, 0, 0, 0])], [rec(121, [1, 0, 0, 0])]),
          "emf.state.profile_bounds" => pair([rec(112, [0, 10, 0])], [CraftedEmf.record(112, "#{[0, 4, 4].pack('V3')}abcdwxyz")]),
          "emf.state.linked_ufis_bounds" => pair([rec(119, [5, 0, 0])], [rec(119, [1] + ([0] * 4))])
        }.merge(values)
      end

      def transform
        identity = matrix(1, 0, 0, 1, 0, 0)
        {
          "emf.transform.fixed_size" => pair([CraftedEmf.record(35, identity + [0].pack("V"))], [CraftedEmf.record(35, identity)]),
          "emf.transform.modify_mode" => pair([CraftedEmf.record(36, identity + [5].pack("V"))],
                                              [CraftedEmf.record(36, identity + [4].pack("V"))]),
          "emf.transform.finite_matrix" => pair([CraftedEmf.record(35, matrix(Float::NAN, 0, 0, 1, 0, 0))],
                                                [CraftedEmf.record(35, identity)])
        }
      end

      def path_clip
        {
          "emf.path.fixed_size" => pair([rec(59, [0])], [rec(59)]),
          "emf.path.begin_nested" => pair([rec(59), rec(59), rec(60)], [rec(59), rec(60), rec(59), rec(60)]),
          "emf.path.unclosed" => pair([rec(59)], [rec(59), rec(68)]),
          "emf.path.end_unopened" => pair([rec(60)], [rec(59), rec(60)]),
          "emf.path.closefigure_outside" => pair([rec(61)], [rec(59), rec(61), rec(60)]),
          "emf.clip.layout_size" => pair([rec(29, [0, 0, 1, 1, 0])], [rec(29, [0, 0, 1, 1])]),
          "emf.clip.select_clip_path_mode" => pair([rec(67, [6])], [rec(67, [5])]),
          "emf.clip.ext_select_clip_rgn_mode" => pair([rec(75, [0, 0])], [rec(75, [0, 5])]),
          "emf.dc.restore_depth" => pair([rec(33), rec(34, [-2], pack: "l<")], [rec(33), rec(33), rec(34, [-2], pack: "l<")])
        }
      end

      def cases = state.merge(transform).merge(path_clip)
    end
  end
end
