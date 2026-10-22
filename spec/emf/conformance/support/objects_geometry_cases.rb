# frozen_string_literal: true

require_relative "crafted_emf"

module Emf
  module SpecSupport
    # Crafted files for the object and geometry rules: id => { bad:, good: }.
    # `bad` breaks that rule; `good` is the closest conforming stream (preservation).
    module ObjectsGeometryCases
      CraftedEmf = Emf::SpecSupport::CraftedEmf
      BOUNDS = [0, 0, 10, 10].pack("l<4")
      PAD = [0, 0].freeze
      STOCK_BLACK_PEN = 0x80000007

      module_function

      def build(*records, handles: 8) = CraftedEmf.build(records: records, n_handles: handles)

      def rec(type, *words) = CraftedEmf.record(type, words.pack("V*"))

      def pen(handle, style: 0, width: 1) = rec(38, handle, style, width, 0, 0)

      def brush(handle, style: 0) = rec(39, handle, style, 0, 0)

      def ext_pen(handle, style:, brush:, hatch: 0) = rec(95, handle, 0, 0, 0, 0, style, 1, brush, 0, hatch, 0)

      def palette(handle, version: 0x300, count: 1, extra: 0)
        CraftedEmf.record(49, [handle].pack("V") + [version, count].pack("v2") + ("\0" * ((4 * count) + extra)).b)
      end

      def set_palette_entries(handle, count: 1, extra: 0)
        CraftedEmf.record(50, [handle, 0, count].pack("V3") + ("\0" * ((4 * count) + extra)).b)
      end

      def points32(count, extra: 0) = ([1, 2].pack("l<2") * count) + ("\0" * extra).b

      def points16(count, extra: 0) = ([1, 2].pack("s<2") * count) + ("\0" * extra).b

      def poly(type, count, points)
        CraftedEmf.record(type, BOUNDS + [count].pack("V") + points)
      end

      def poly_poly(type, counts, total, points, extra: 0)
        CraftedEmf.record(type, BOUNDS + [counts.size, total].pack("V2") + counts.pack("V*") + points + ("\0" * extra).b)
      end

      def poly_draw(type, count, types, extra: 0)
        points = type == 56 ? points32(count) : points16(count)
        padded = types.pack("C*").ljust((types.size + 3) & ~3, "\0".b)
        CraftedEmf.record(type, BOUNDS + [count].pack("V") + points + padded + ("\0" * extra).b)
      end

      def gradient(n_ver, n_tri, mode, indexes, extra: 0)
        vertexes = ([0, 0, 0, 0, 0, 0].pack("l<2v4") * n_ver)
        per = mode < 2 ? 2 : 3
        index_bytes = indexes.each_slice(per).map { |s| (s + PAD.first(3 - per)).pack("V3") }.join
        CraftedEmf.record(118, BOUNDS + [n_ver, n_tri, mode].pack("V3") + vertexes + index_bytes + ("\0" * extra).b)
      end

      def region(count: 1, rgn_size: nil, header_size: 32, type: 1)
        [header_size, type, count, rgn_size || (count * 16)].pack("V4") + BOUNDS + ([0, 0, 5, 5].pack("l<4") * count)
      end

      def fill_rgn(data, size: data.bytesize, extra: 0)
        CraftedEmf.record(71, BOUNDS + [size, 1].pack("V2") + data + ("\0" * extra).b)
      end

      def cases
        [pen_cases, handle_cases, palette_cases, point_cases, poly_cases, gradient_cases, region_cases].reduce(:merge)
      end

      def object_cases = [pen_cases, handle_cases, palette_cases].reduce(:merge)

      def geometry_cases = [point_cases, poly_cases, gradient_cases, region_cases].reduce(:merge)

      def pen_cases
        {
          "emf.object.fixed_size" => { bad: build(CraftedEmf.record(38, [1, 0, 1, 0, 0, 0].pack("V6"))), good: build(pen(1)) },
          "emf.object.font_size" => { bad: build(CraftedEmf.record(82, [1].pack("V") + ("\0" * 92).b)),
                                      good: build(CraftedEmf.record(82, [1].pack("V") + ("\0" * 320).b)) },
          "emf.object.pen_style" => { bad: build(pen(1, style: 9)), good: build(pen(1, style: 0x10000 | 0x200 | 0x2000 | 1)) },
          "emf.object.pen_cosmetic_width" => { bad: build(pen(1, width: 4)),
                                               good: build(pen(1, width: 1), pen(2, style: 0x10000, width: 4)) },
          "emf.object.brush_style" => { bad: build(brush(1, style: 3)), good: build(brush(1, style: 2)) },
          "emf.object.extpen_brush" => { bad: build(ext_pen(1, style: 0x10000, brush: 5)),
                                         good: build(ext_pen(1, style: 0x10000, brush: 2), ext_pen(2, style: 0x10005, brush: 1)) }
        }
      end

      def handle_cases
        valid = [brush(1), rec(37, 1)]
        {
          "emf.object.index_zero" => { bad: build(rec(37, 0)), good: build(*valid) },
          "emf.object.delete_stock" => { bad: build(rec(40, STOCK_BLACK_PEN)), good: build(*valid, rec(40, 1)) },
          "emf.object.handle_range" => { bad: build(brush(9), rec(37, 9)),
                                         good: build(brush(7), rec(37, 7), rec(37, STOCK_BLACK_PEN)) },
          "emf.object.lifecycle" => { bad: build(rec(37, 3)),
                                      good: build(brush(3), rec(37, 3), rec(40, 3), brush(3), rec(37, 3)) }
        }
      end

      def palette_cases
        {
          "emf.object.palette_version" => { bad: build(palette(1, version: 0x200)), good: build(palette(1)) },
          "emf.object.palette_entries" => { bad: build(palette(1, count: 0)), good: build(palette(1), rec(51, 1, 0x400)) },
          "emf.object.palette_size" => { bad: build(palette(1, extra: 4)), good: build(palette(1), set_palette_entries(1, count: 2)) }
        }
      end

      def point_cases
        {
          "emf.geometry.point_array_size" => { bad: build(poly(3, 1, points32(1, extra: 8))),
                                               good: build(poly(3, 2, points32(2)), poly(86, 3, points16(3))) },
          "emf.geometry.bezier_count" => { bad: build(poly(2, 2, points32(2))),
                                           good: build(poly(2, 4, points32(4)), poly(5, 3, points32(3))) }
        }
      end

      def poly_cases
        {
          "emf.geometry.poly_poly_size" => { bad: build(poly_poly(91, [3], 3, points16(3), extra: 4)),
                                             good: build(poly_poly(91, [3], 3, points16(3)), poly_poly(8, [2, 2], 4, points32(4))) },
          "emf.geometry.poly_poly_counts" => { bad: build(poly_poly(7, [1, 2], 4, points32(4))),
                                               good: build(poly_poly(7, [2, 2], 4, points32(4))) },
          "emf.geometry.poly_draw_size" => { bad: build(poly_draw(92, 2, [6, 2], extra: 4)),
                                             good: build(poly_draw(92, 2, [6, 2]), poly_draw(56, 1, [6])) },
          "emf.geometry.poly_draw_types" => { bad: build(poly_draw(92, 4, [1, 6, 4, 4])), good: build(poly_draw(92, 4, [6, 4, 4, 5])) }
        }
      end

      def gradient_cases
        {
          "emf.geometry.gradient_mode" => { bad: build(gradient(3, 1, 3, [0, 1, 2])), good: build(gradient(3, 1, 2, [0, 1, 2])) },
          "emf.geometry.gradient_size" => { bad: build(gradient(2, 1, 0, [0, 1], extra: 4)),
                                            good: build(gradient(2, 1, 0, [0, 1]), gradient(2, 1, 1, [0, 1])) },
          "emf.geometry.gradient_index" => { bad: build(gradient(3, 1, 2, [0, 1, 3])), good: build(gradient(3, 1, 2, [0, 1, 2])) }
        }
      end

      def region_cases
        {
          "emf.region.header" => { bad: build(fill_rgn(region(header_size: 16))), good: build(fill_rgn(region)) },
          "emf.region.rects" => { bad: build(fill_rgn(region(count: 1, rgn_size: 0))), good: build(fill_rgn(region(count: 2))) },
          "emf.region.size" => { bad: build(fill_rgn(region, extra: 4)), good: build(fill_rgn(region), rec(75, 0, 5)) }
        }
      end
    end
  end
end
