# frozen_string_literal: true

module Emf
  module EmfPlus
    # An object ID outside the 64-slot table (0..63).
    class ObjectIdError < Emf::Error; end

    # The EMF+ object table (MS-EMFPLUS 2.3.5.1): 64 slots, IDs 0..63, over a
    # sequence of framed records. A stream index is a record's position in that
    # sequence. A new EmfPlusObject with an existing ID replaces the slot from
    # its position on, so lookups are time-indexed: `lookup(id, at: n)` returns
    # the object defined most recently before position n, and ID reuse never
    # changes what an earlier draw resolved to.
    #
    # An object's position is that of its last chunk, the point where it is
    # complete. Problems found while building are collected in `errors` and
    # never raised; a record or chain that cannot be placed keeps its records.
    class ObjectTable
      SLOTS = 64

      Diagnostic = Struct.new(:kind, :stream_index, :id, :message, :records, keyword_init: true)
      Resolution = Struct.new(:role, :raw_id, :object, :diagnostic, :solid_color, keyword_init: true)
      Placement = Struct.new(:stream_index, :logical)
      private_constant :Placement

      # Reads chain records off a queue of [record, stream index] pairs and
      # remembers them, so a failed chain can hand back everything it consumed.
      class Tape
        attr_reader :taken

        def initialize(queue)
          @queue = queue
          @taken = []
        end

        def shift
          pair = @queue.shift
          @taken << pair if pair
          pair&.first
        end
      end
      private_constant :Tape

      # What each draw record references: [role, object type, reader for the
      # ID, reader for the S flag or nil].
      module References
        PEN = [:pen, Objects::PEN, :pen_id, nil].freeze
        BRUSH = [:brush, Objects::BRUSH, :brush_id, :solid_color?].freeze
        FONT = [:font, Objects::FONT, :font_object_id, nil].freeze
        FORMAT = [:string_format, Objects::STRING_FORMAT, :format_id, nil].freeze
        IMAGE = [:image, Objects::IMAGE, :image_object_id, nil].freeze
        IMAGE_ATTRIBUTES = [:image_attributes, Objects::IMAGE_ATTRIBUTES, :image_attributes_id, nil].freeze
        PATH = [:path, Objects::PATH, :path_id, nil].freeze
        REGION = [:region, Objects::REGION, :region_id, nil].freeze
        CLIP_PATH = [:path, Objects::PATH, :emf_object_id, nil].freeze
        CLIP_REGION = [:region, Objects::REGION, :emf_object_id, nil].freeze

        BY_RECORD = {
          Records::DrawRects => [PEN], Records::DrawLines => [PEN], Records::DrawEllipse => [PEN],
          Records::DrawPie => [PEN], Records::DrawArc => [PEN], Records::DrawClosedCurve => [PEN],
          Records::DrawCurve => [PEN], Records::DrawBeziers => [PEN], Records::DrawPath => [PATH, PEN],
          Records::FillRects => [BRUSH], Records::FillPolygon => [BRUSH], Records::FillEllipse => [BRUSH],
          Records::FillPie => [BRUSH], Records::FillClosedCurve => [BRUSH], Records::FillPath => [PATH, BRUSH],
          Records::FillRegion => [REGION, BRUSH],
          Records::DrawString => [FONT, BRUSH, FORMAT], Records::DrawDriverString => [FONT, BRUSH],
          Records::DrawImage => [IMAGE, IMAGE_ATTRIBUTES], Records::DrawImagePoints => [IMAGE, IMAGE_ATTRIBUTES],
          Records::SetClipPath => [CLIP_PATH], Records::SetClipRegion => [CLIP_REGION]
        }.freeze
      end
      private_constant :References

      attr_reader :errors

      def initialize(records)
        @placements = Hash.new { |hash, id| hash[id] = [] }
        @errors = []
        build(records.to_a)
        @placements.default_proc = nil
        @placements.each_value(&:freeze)
        @errors.freeze
      end

      # The LogicalObject in slot `id` as of stream position `at` (objects
      # defined at earlier positions only), or nil when the slot is empty then.
      def lookup(id, at:) # rubocop:disable Naming/MethodParameterName
        check_id!(id)
        placements = @placements.fetch(id, [])
        placements.reverse_each { |placement| return placement.logical if placement.stream_index < at }
        nil
      end

      # All 64 slots as of stream position `at`.
      def at(stream_index)
        Array.new(SLOTS) { |id| lookup(id, at: stream_index) }
      end

      # One Resolution per object reference the record carries, resolved as of
      # its stream position `at`: the slot's object, or nil with a Diagnostic
      # (empty slot, wrong object type, ID outside the table). A solid-colour
      # BrushId is kept raw and not looked up. A record with no references
      # gives an empty array.
      def resolve(record, at:) # rubocop:disable Naming/MethodParameterName
        References::BY_RECORD.fetch(record.class, []).map { |reference| resolution(record, reference, at) }
      end

      private

      def build(records)
        queue = records.each_with_index.to_a
        until queue.empty?
          record, index = queue.shift
          place_chain(record, index, queue) if record.is_a?(Records::Object)
        end
      end

      def place_chain(first, first_index, queue)
        tape = Tape.new(queue)
        chunks = ObjectChain.take_chain(first, tape)
        place(ObjectChain::LogicalObject.new(chunks), tape.taken.last&.last || first_index)
      rescue ParseError => e
        unplaced_chain(first, first_index, queue, tape.taken, e)
      end

      def place(logical, index)
        id = logical.emf_object_id
        if id < SLOTS
          @placements[id] << Placement.new(index, logical)
        else
          add_error(:object_id_out_of_range, index, id, "object ID #{id} is outside 0..#{SLOTS - 1}", logical.split)
        end
      end

      def unplaced_chain(first, first_index, queue, taken, error)
        stray = taken.last
        queue.unshift(taken.pop) if stray && !chunk_of?(first, stray.first)
        records = [first] + taken.map(&:first)
        add_error(:incomplete_chain, taken.last&.last || first_index, first.emf_object_id, error.message, records)
      end

      def chunk_of?(first, record)
        record.is_a?(Records::Object) && record.object_type == first.object_type &&
          record.emf_object_id == first.emf_object_id
      end

      def add_error(kind, index, id, message, records)
        @errors << Diagnostic.new(kind: kind, stream_index: index, id: id, message: message, records: records).freeze
      end

      def check_id!(id)
        return if id.is_a?(Integer) && id >= 0 && id < SLOTS

        raise ObjectIdError, "object ID #{id.inspect} is outside 0..#{SLOTS - 1}"
      end

      def resolution(record, (role, type, id_reader, solid_reader), position)
        raw_id = record.public_send(id_reader).to_i
        return Resolution.new(role: role, raw_id: raw_id, solid_color: true) if solid_reader && record.public_send(solid_reader)

        found = lookup(raw_id, at: position)
        kind = problem(found, type)
        return Resolution.new(role: role, raw_id: raw_id, object: found) unless kind

        diagnostic = Diagnostic.new(kind: kind, stream_index: position, id: raw_id, records: [record],
                                    message: "#{role} reference #{raw_id}: #{kind.to_s.tr('_', ' ')}").freeze
        Resolution.new(role: role, raw_id: raw_id, diagnostic: diagnostic)
      rescue ObjectIdError
        Resolution.new(role: role, raw_id: raw_id, diagnostic: out_of_range(record, role, raw_id, position))
      end

      def out_of_range(record, role, raw_id, position)
        Diagnostic.new(kind: :object_id_out_of_range, stream_index: position, id: raw_id, records: [record],
                       message: "#{role} reference #{raw_id}: object ID outside 0..#{SLOTS - 1}").freeze
      end

      def problem(found, type)
        return :empty_slot unless found

        :wrong_type unless found.object_type == type
      end
    end
  end
end
