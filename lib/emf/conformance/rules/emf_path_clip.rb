# frozen_string_literal: true

# Path bracket (MS-EMF 2.3.10) and clipping (2.3.2) record rules, plus the
# RESTOREDC depth sequence rule (2.3.11.6).
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module PathClipRules
      EMF = %i[emf emf_plus].freeze
      BEGIN_PATH = 59
      END_PATH = 60
      CLOSE_FIGURE = 61
      ABORT_PATH = 68
      SAVE_DC = 33
      RESTORE_DC = 34
      PATH_TYPES = [BEGIN_PATH, END_PATH, CLOSE_FIGURE, 65, 66, ABORT_PATH].freeze # 65 FLATTENPATH, 66 WIDENPATH
      SELECT_CLIP_PATH = 67
      EXT_SELECT_CLIP_RGN = 75
      # Clipping records have no stated Size; their fixed fields occupy: type => size.
      CLIP_LAYOUT = { 26 => 16, 28 => 8, 29 => 24, 30 => 24, SELECT_CLIP_PATH => 12 }.freeze
      REGION_MODES = (1..5)
      SHIFTED = "a RESTOREDC below the saved depth leaves the rest of the stream readable; bad_corrupted_2014-12-02-215339.emf " \
                "(tolerant-valid by owner decision) reaches it after a record boundary shift"

      module_function

      def each_wire(context, types)
        context.records.each_with_index do |record, index|
          next unless types.include?(context.record_type(record))

          wire = record.wire
          yield(record, index, wire) if wire.is_a?(Emf::Emr::Binary::Record)
        end
      end

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end

      def path_size(context)
        found = []
        each_wire(context, PATH_TYPES) do |record, index, _wire|
          size = context.record_size(record)
          next if size == 8

          found << at(record, index,
                      "#{RecordTypes.name(context.record_type(record))} Size is #{size}, path bracket records are 0x00000008")
        end
        found
      end

      def clip_layout_size(context)
        found = []
        each_wire(context, CLIP_LAYOUT.keys) do |record, index, _wire|
          type = context.record_type(record)
          size = context.record_size(record)
          next if size == CLIP_LAYOUT.fetch(type)

          found << at(record, index, "#{RecordTypes.name(type)} Size is #{size}, its fixed fields occupy #{CLIP_LAYOUT.fetch(type)}")
        end
        found
      end

      def region_mode(context, type, field, name)
        found = []
        each_wire(context, [type]) do |record, index, wire|
          mode = wire.public_send(field).to_i
          unless REGION_MODES.cover?(mode)
            found << at(record, index,
                        "#{name} RegionMode #{mode} is not in the RegionMode enumeration (RGN_AND..RGN_COPY, 1..5)")
          end
        end
        found
      end

      def select_clip_path_mode(context) = region_mode(context, SELECT_CLIP_PATH, :region_mode, "EMR_SELECTCLIPPATH")

      def ext_select_clip_rgn_mode(context) = region_mode(context, EXT_SELECT_CLIP_RGN, :dw_mode, "EMR_EXTSELECTCLIPRGN")

      # Walks the records once, tracking whether path bracket construction is open.
      def bracket_findings(context)
        open_at = nil
        found = []
        context.records.each_with_index do |record, index|
          type = context.record_type(record)
          found.concat(bracket_step(type, record, index, open_at))
          open_at = bracket_open(type, record, index, open_at)
        end
        found << [:unclosed, at(*open_at, "EMR_BEGINPATH opens a path bracket that no EMR_ENDPATH or EMR_ABORTPATH closes")] if open_at
        found
      end

      def bracket_open(type, record, index, open_at)
        case type
        when BEGIN_PATH then open_at || [record, index]
        when END_PATH, ABORT_PATH then nil
        else open_at
        end
      end

      def bracket_step(type, record, index, open_at)
        if type == BEGIN_PATH && open_at
          [[:nested, at(record, index, "EMR_BEGINPATH while a path bracket is open (opened at record #{open_at[1] + 1})")]]
        elsif type == END_PATH && !open_at
          [[:unopened, at(record, index, "EMR_ENDPATH closes a path bracket but none is open")]]
        elsif type == CLOSE_FIGURE && !open_at
          [[:figure, at(record, index, "EMR_CLOSEFIGURE outside path bracket construction")]]
        else
          []
        end
      end

      def bracket(context, kind) = bracket_findings(context).filter_map { |k, finding| finding if k == kind }

      # Saved-state depth: SAVEDC pushes, RESTOREDC with a negative SavedDC of -n pops n.
      def restore_depth(context)
        depth = 0
        found = []
        context.records.each_with_index do |record, index|
          case context.record_type(record)
          when SAVE_DC then depth += 1
          when RESTORE_DC
            next unless record.wire.respond_to?(:saved_dc)

            saved = record.wire.saved_dc.to_i
            next unless saved.negative?

            if -saved > depth
              found << at(record, index, "EMR_RESTOREDC SavedDC #{saved} restores #{-saved} states deep but only #{depth} are saved")
              depth = 0
            else
              depth += saved
            end
          end
        end
        found
      end
    end

    registry = Registry.loading
    pc = PathClipRules::EMF
    {
      "emf.path.fixed_size" => [:path_size, "MS-EMF 2.3.10", :fixed_size, :error],
      "emf.clip.layout_size" => [:clip_layout_size, "MS-EMF 2.3.2", :layout_size, :warning],
      "emf.clip.select_clip_path_mode" => [:select_clip_path_mode, "MS-EMF 2.3.2.5", :region_mode, :error],
      "emf.clip.ext_select_clip_rgn_mode" => [:ext_select_clip_rgn_mode, "MS-EMF 2.3.2.2", :region_mode, :error],
      "emf.dc.restore_depth" => [:restore_depth, "MS-EMF 2.3.11.6", :restore_depth, :error, PathClipRules::SHIFTED]
    }.each do |id, (method, citation, kind, severity, reason)|
      registry.register(id: id, formats: pc, citation: citation, kind: kind, severity: severity, tolerant_reason: reason) do |c|
        PathClipRules.public_send(method, c)
      end
    end
    {
      "emf.path.begin_nested" => %i[nested error],
      "emf.path.unclosed" => %i[unclosed error],
      "emf.path.end_unopened" => %i[unopened warning],
      "emf.path.closefigure_outside" => %i[figure warning]
    }.each do |id, (kind, severity)|
      registry.register(id: id, formats: pc, citation: "MS-EMF 2.3.10", kind: kind, severity: severity) do |c|
        PathClipRules.bracket(c, kind)
      end
    end
  end
end
