# frozen_string_literal: true

# Drawing geometry rules: point arrays, PolyDraw, GradientFill and region data
# (MS-EMF 2.3.5, 2.2.7, 2.2.8, 2.2.24-2.2.26, 2.1.15, 2.1.26).
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module GeometryRules
      EMF = %i[emf emf_plus].freeze
      # type => [count field, bytes per point]
      POINT_ARRAYS = { 2 => [:cptl, 8], 3 => [:cptl, 8], 4 => [:cptl, 8], 5 => [:cptl, 8], 6 => [:cptl, 8],
                       85 => [:cpts, 4], 86 => [:cpts, 4], 87 => [:cpts, 4], 88 => [:cpts, 4], 89 => [:cpts, 4] }.freeze
      POLY_POLY = { 7 => [:c_ptl_total, 8], 8 => [:c_ptl_total, 8], 90 => [:c_pts_total, 4], 91 => [:c_pts_total, 4] }.freeze
      POLY_DRAW = { 56 => [:cptl, 8], 92 => [:cpts, 4] }.freeze
      POLYLINES = [7, 90].freeze
      BEZIER = 4
      POINT_TYPES = [0x02, 0x03, 0x04, 0x05, 0x06].freeze # LINETO, BEZIERTO and MOVETO, optionally with CLOSEFIGURE (not on MOVETO)
      GRADIENT_FIXED = 36
      GRADIENT_MODES = [0, 1, 2].freeze
      GRADIENT_TRIANGLE = 2
      REGION_RECORDS = { 71 => 32, 72 => 40, 73 => 28, 74 => 28, 75 => 16 }.freeze # fixed part before RgnData
      BEZIER_COUNT = { 0 => "a multiple of 3", 1 => "one more than a multiple of 3" }.freeze
      COUNT_WINS = "readers take Count points and ignore the rest of the record"
      EXTRA_POINTS = "the spec says extra points MUST be ignored, so a reader still draws the curve or polygon"

      module_function

      def field(record, name)
        wire = record.wire
        wire.respond_to?(name) ? wire.public_send(name).to_i : nil
      end

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end

      def each_of(context, types)
        context.records.each_with_index do |record, index|
          type = context.record_type(record)
          yield record, index, type if types.include?(type)
        end
      end

      def padded(bytes) = (bytes + 3) & ~3

      def size_finding(context, record, index, type, expected, what)
        size = context.record_size(record)
        return if size == expected

        at(record, index, "#{RecordTypes.name(type)} #{what}, so Size MUST be #{expected}, not #{size}")
      end

      def point_array_size(context)
        found = []
        each_of(context, POINT_ARRAYS.keys) do |record, index, type|
          name, width = POINT_ARRAYS.fetch(type)
          count = field(record, name)
          next if count.nil?

          found << size_finding(context, record, index, type, 28 + padded(count * width), "holds #{count} points")
        end
        found.compact
      end

      def bezier_count(context)
        found = []
        each_of(context, [2, 85, 5, 88]) do |record, index, type|
          count = field(record, POINT_ARRAYS.fetch(type).first)
          next if count.nil?

          expected = [2, 85].include?(type) ? 1 : 0
          next if (count % 3) == expected

          found << at(record, index, "#{RecordTypes.name(type)} Count #{count} MUST be #{BEZIER_COUNT.fetch(expected)}")
        end
        found
      end

      def poly_poly_totals(record, type)
        total_name = POLY_POLY.fetch(type).first
        counts = record.wire.a_poly_counts.to_a.map(&:to_i)
        [counts, field(record, total_name)]
      end

      def poly_poly_size(context)
        found = []
        each_of(context, POLY_POLY.keys) do |record, index, type|
          polys = field(record, :n_polys)
          total = field(record, POLY_POLY.fetch(type).first)
          next if polys.nil? || total.nil?

          found << size_finding(context, record, index, type, 32 + (4 * polys) + padded(total * POLY_POLY.fetch(type).last),
                                "holds #{polys} polygons and #{total} points")
        end
        found.compact
      end

      def poly_poly_counts(context)
        found = []
        each_of(context, POLY_POLY.keys) do |record, index, type|
          next unless record.wire.respond_to?(:a_poly_counts)

          counts, total = poly_poly_totals(record, type)
          sum = counts.sum
          found << at(record, index, "#{RecordTypes.name(type)} per-figure counts sum to #{sum} but Count says #{total}") if sum != total
          short = counts.count { |c| c < 2 }
          if POLYLINES.include?(type) && short.positive?
            found << at(record, index,
                        "#{RecordTypes.name(type)} has #{short} polyline(s) with fewer than 2 points, each count MUST be >= 2")
          end
        end
        found
      end

      def poly_draw_size(context)
        found = []
        each_of(context, POLY_DRAW.keys) do |record, index, type|
          name, width = POLY_DRAW.fetch(type)
          count = field(record, name)
          next if count.nil?

          found << size_finding(context, record, index, type, 28 + padded((count * width) + count), "holds #{count} points and types")
        end
        found.compact
      end

      def bezier_runs(types)
        types.chunk_while { |a, b| (a & ~1) == BEZIER && (b & ~1) == BEZIER }
             .select { |run| (run.first & ~1) == BEZIER }.map(&:size)
      end

      def poly_draw_types(context)
        found = []
        each_of(context, POLY_DRAW.keys) do |record, index, type|
          next unless record.wire.respond_to?(:ab_types)

          types = record.wire.ab_types.to_a.map(&:to_i)
          bad = types.reject { |t| POINT_TYPES.include?(t) }.uniq
          unless bad.empty?
            found << at(record, index, "#{RecordTypes.name(type)} point types #{bad.map do |t|
              format('0x%02X', t)
            end.join(', ')} are not in the Point enumeration")
          end
          odd = bezier_runs(types - bad).reject { |run| (run % 3).zero? }
          unless odd.empty?
            found << at(record, index,
                        "#{RecordTypes.name(type)} has PT_BEZIERTO runs of #{odd.join(', ')} points, they MUST come in sets of three")
          end
        end
        found
      end

      # GradientFill: header, nVer TriVertex (16 bytes), then nTri index objects (12 bytes each,
      # a rectangle's 8 bytes plus its mandatory 4 bytes of padding).
      def gradient_fields(record)
        %i[n_ver n_tri ul_mode].map { |name| field(record, name) }
      end

      def gradient_mode(context)
        found = []
        each_of(context, [118]) do |record, index, _type|
          mode = field(record, :ul_mode)
          next if mode.nil? || GRADIENT_MODES.include?(mode)

          found << at(record, index, "GRADIENTFILL ulMode #{mode} is not GRADIENT_FILL_RECT_H, RECT_V or TRIANGLE")
        end
        found
      end

      def gradient_size(context)
        found = []
        each_of(context, [118]) do |record, index, type|
          n_ver, n_tri, = gradient_fields(record)
          next if n_ver.nil?

          found << size_finding(context, record, index, type, GRADIENT_FIXED + (16 * n_ver) + (12 * n_tri),
                                "holds #{n_ver} vertexes and #{n_tri} index objects")
        end
        found.compact
      end

      def gradient_index(context)
        found = []
        each_of(context, [118]) do |record, index, _type|
          n_ver, n_tri, mode = gradient_fields(record)
          next if n_ver.nil?

          bad = out_of_range_indexes(record.wire.body.to_s.b, n_ver, n_tri, mode)
          found << at(record, index, "GRADIENTFILL vertex index #{bad.first} is not below nVer (#{n_ver})") if bad.any?
        end
        found
      end

      def out_of_range_indexes(body, n_ver, n_tri, mode)
        per = mode == GRADIENT_TRIANGLE ? 3 : 2
        start = 16 * n_ver
        available = [(body.bytesize - start) / 12, n_tri].min
        return [] if available <= 0

        (0...available).flat_map { |i| body.byteslice(start + (12 * i), 4 * per).unpack("V#{per}") }.reject { |v| v < n_ver }
      end

      def region_data(record)
        wire = record.wire
        return unless wire.respond_to?(:rgn_data) && field(record, :cb_rgn_data).to_i.positive?

        wire.rgn_data
      end

      def region_header(context)
        found = []
        each_of(context, REGION_RECORDS.keys) do |record, index, type|
          data = region_data(record)
          next unless data

          unless data.header_size.to_i == 32
            found << at(record, index,
                        "#{RecordTypes.name(type)} RegionDataHeader Size is #{data.header_size.to_i}, MUST be 32")
          end
          unless data.region_type.to_i == 1
            found << at(record, index,
                        "#{RecordTypes.name(type)} RegionDataHeader Type is #{data.region_type.to_i}, MUST be 1")
          end
        end
        found
      end

      def region_rects(context)
        found = []
        each_of(context, REGION_RECORDS.keys) do |record, index, type|
          data = region_data(record)
          next unless data

          count = data.count_rects.to_i
          size = data.rgn_size.to_i
          cb = field(record, :cb_rgn_data)
          if size != count * 16
            found << at(record, index,
                        "#{RecordTypes.name(type)} CountRects #{count} needs #{count * 16} bytes but RgnSize is #{size}")
          end
          if cb != 32 + size
            found << at(record, index,
                        "#{RecordTypes.name(type)} RgnDataSize #{cb} is not the 32-byte header plus RgnSize #{size}")
          end
        end
        found
      end

      def region_size(context)
        found = []
        each_of(context, REGION_RECORDS.keys) do |record, index, type|
          cb = field(record, :cb_rgn_data)
          next if cb.nil?

          found << size_finding(context, record, index, type, REGION_RECORDS.fetch(type) + cb, "carries #{cb} bytes of region data")
        end
        found.compact
      end
    end

    registry = Registry.loading
    {
      "emf.geometry.point_array_size" => [:point_array_size, "MS-EMF 2.3.5", :point_array_size, GeometryRules::COUNT_WINS],
      "emf.geometry.bezier_count" => [:bezier_count, "MS-EMF 2.3.5.16", :bezier_count, GeometryRules::EXTRA_POINTS],
      "emf.geometry.poly_poly_size" => [:poly_poly_size, "MS-EMF 2.3.5.28", :poly_poly_size, nil],
      "emf.geometry.poly_poly_counts" => [:poly_poly_counts, "MS-EMF 2.3.5.28", :poly_poly_counts, GeometryRules::EXTRA_POINTS],
      "emf.geometry.poly_draw_size" => [:poly_draw_size, "MS-EMF 2.3.5.20", :poly_draw_size, nil],
      "emf.geometry.poly_draw_types" => [:poly_draw_types, "MS-EMF 2.1.26", :poly_draw_types, nil],
      "emf.geometry.gradient_mode" => [:gradient_mode, "MS-EMF 2.1.15", :gradient_mode, nil],
      "emf.geometry.gradient_size" => [:gradient_size, "MS-EMF 2.3.5.12", :gradient_size, nil],
      "emf.geometry.gradient_index" => [:gradient_index, "MS-EMF 2.2.7", :gradient_index, nil],
      "emf.region.header" => [:region_header, "MS-EMF 2.2.25", :region_header, nil],
      "emf.region.rects" => [:region_rects, "MS-EMF 2.2.25", :region_rects, nil],
      "emf.region.size" => [:region_size, "MS-EMF 2.3.5", :region_size, nil]
    }.each do |id, (method, citation, kind, reason)|
      registry.register(id: id, formats: GeometryRules::EMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        GeometryRules.public_send(method, context)
      end
    end
  end
end
